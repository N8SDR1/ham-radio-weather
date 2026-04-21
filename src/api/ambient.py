from __future__ import annotations

import logging
from typing import Optional

import httpx
import socketio
from PySide6.QtCore import (
    Property,
    QObject,
    QThread,
    QTimer,
    Signal,
    Slot,
)

logger = logging.getLogger(__name__)


class _SocketWorker(QObject):
    """Runs the Socket.IO client on its own thread so Qt's event loop stays free.

    Ambient's realtime server speaks Socket.IO v2. We log verbosely so any
    handshake issue is visible in the console — share that output if the
    green 'Live' light never comes on from the socket path.
    """

    data = Signal(dict)
    connectedSig = Signal()
    disconnectedSig = Signal()
    error = Signal(str)

    def __init__(self, application_key: str, api_key: str):
        super().__init__()
        self._app_key = application_key
        self._api_key = api_key
        self._sio: Optional[socketio.Client] = None

    @Slot()
    def run(self):
        sio = socketio.Client(
            reconnection=True,
            logger=logger,
            engineio_logger=logger,
        )
        self._sio = sio

        @sio.event
        def connect():
            logger.info("Socket.IO connected; subscribing")
            try:
                sio.emit("subscribe", {"apiKeys": [self._api_key]})
            except Exception as e:
                self.error.emit(f"subscribe failed: {e}")
            self.connectedSig.emit()

        @sio.event
        def disconnect():
            logger.info("Socket.IO disconnected")
            self.disconnectedSig.emit()

        @sio.on("data")
        def on_data(payload):
            if isinstance(payload, dict):
                self.data.emit(payload)

        @sio.on("subscribed")
        def on_subscribed(payload):
            if not isinstance(payload, dict):
                return
            for d in payload.get("devices", []) or []:
                last = d.get("lastData") if isinstance(d, dict) else None
                if isinstance(last, dict):
                    self.data.emit(last)
                    break

        url = (
            "https://rt2.ambientweather.net/"
            f"?api=1&applicationKey={self._app_key}"
        )
        try:
            sio.connect(url, transports=["websocket"])
            sio.wait()
        except Exception as e:
            logger.exception("Socket.IO connect failed")
            self.error.emit(f"socket connect: {e}")

    @Slot()
    def stop(self):
        if self._sio is not None:
            try:
                self._sio.disconnect()
            except Exception:
                pass


class AmbientClient(QObject):
    """Combines REST polling + Ambient's realtime Socket.IO stream.

    REST poll every 60s is the reliable baseline. Socket adds realtime
    pushes on top. `connected` reflects fresh data from either source.
    """

    dataUpdated = Signal("QVariant")
    connectionChanged = Signal(bool)
    errorOccurred = Signal(str)
    diagnosticsChanged = Signal()
    # Rolling history from /devices/{MAC}?limit=288 — list of record dicts,
    # newest first. Used by Tier-1 trend consumers (pressure delta, daily
    # peak wind, humidityFromYesterday) and Tier-2 sparklines/charts.
    historyUpdated = Signal("QVariant")

    REST_BASE = "https://rt.ambientweather.net/v1"
    POLL_MS = 60_000
    HISTORY_POLL_MS = 20 * 60 * 1000   # 20 min — history doesn't need to be live
    HISTORY_LIMIT = 288                 # Ambient's per-call cap

    def __init__(self, application_key: str, api_key: str, parent=None):
        super().__init__(parent)
        self._app_key = application_key
        self._api_key = api_key
        self._latest: dict = {}
        self._connected = False
        self._socket_connected = False
        self._rest_ok = False
        # diagnostics
        self._raw_text: str = ""
        self._last_status: int = 0
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        # history state
        self._mac: str = ""
        self._history: list = []          # newest first, list of record dicts
        self._last_history_iso: str = ""
        self._last_history_error: str = ""

        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(self.POLL_MS)
        self._poll_timer.timeout.connect(self._rest_poll)

        self._history_timer = QTimer(self)
        self._history_timer.setInterval(self.HISTORY_POLL_MS)
        self._history_timer.timeout.connect(self._fetch_history)

        self._thread = QThread(self)
        self._worker = _SocketWorker(application_key, api_key)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.data.connect(self._handle_data)
        self._worker.connectedSig.connect(self._on_socket_connected)
        self._worker.disconnectedSig.connect(self._on_socket_disconnected)
        self._worker.error.connect(self.errorOccurred)

    @Slot()
    def start(self):
        if not self._app_key or not self._api_key:
            logger.warning(
                "AmbientClient starting with no keys — station tiles will stay empty. "
                "Configure via Settings → Ambient Weather and restart."
            )
            return
        self._rest_poll()
        self._poll_timer.start()
        self._thread.start()
        # Defer the first history fetch by ~10 s so the current-conditions
        # poll has had a chance to grab the MAC address from /devices. Then
        # the 20-min timer takes over.
        self._history_timer.start()
        QTimer.singleShot(10_000, self._fetch_history)

    @Slot()
    def stop(self):
        self._poll_timer.stop()
        self._history_timer.stop()
        self._worker.stop()
        self._thread.quit()
        self._thread.wait(2000)

    def _rest_poll(self):
        from datetime import datetime, timezone
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        try:
            with httpx.Client(timeout=10.0) as client:
                r = client.get(
                    f"{self.REST_BASE}/devices",
                    params={
                        "applicationKey": self._app_key,
                        "apiKey": self._api_key,
                    },
                )
                self._last_status = r.status_code
                self._raw_text    = r.text[:20000]
                r.raise_for_status()
                devices = r.json()
                if isinstance(devices, list) and devices:
                    dev0 = devices[0] if isinstance(devices[0], dict) else {}
                    # Cache MAC for the history endpoint — /devices/{MAC}
                    mac = str(dev0.get("macAddress", "") or "").strip()
                    if mac and mac != self._mac:
                        self._mac = mac
                        logger.info("Ambient MAC captured: %s", mac)
                    last = dev0.get("lastData", {})
                    if isinstance(last, dict):
                        self._handle_data(last)
                        self._rest_ok = True
                        self._last_error = ""
                        self._recompute_connected()
                        self.diagnosticsChanged.emit()
                        return
            self._rest_ok = False
            self._last_error = "REST response had no devices"
            self._recompute_connected()
            self.diagnosticsChanged.emit()
        except Exception as e:
            err = str(e)
            logger.warning("REST poll failed: %s", err)
            self._rest_ok = False
            self._last_error = err
            self._recompute_connected()
            self.errorOccurred.emit(err)
            self.diagnosticsChanged.emit()

    @Slot(dict)
    def _handle_data(self, data: dict):
        self._latest = {**self._latest, **data}
        # Overlay history-derived trend fields (humidityFromYesterday,
        # pressureTrend3h) so tiles see them alongside the live snapshot.
        # No-op until _history is populated (~10 s after startup).
        derived = self._compute_history_derived()
        if derived:
            self._latest = {**self._latest, **derived}
        self.dataUpdated.emit(self._latest)

    # -- History-derived fields -----------------------------------------

    def _compute_history_derived(self) -> dict:
        """Walk self._history (newest-first) and produce derived fields.

        Returns a dict of fields to merge into self._latest. Empty when
        history is not yet populated or the required current values are
        missing. Called after every history fetch AND every current-data
        update so the trends stay in sync.
        """
        if not self._history:
            return {}

        from datetime import datetime, timezone, timedelta
        now = datetime.now(timezone.utc)

        def _parse_ts(s):
            """Parse Ambient's '2026-04-21T12:00:00.000Z' timestamp."""
            if not s:
                return None
            try:
                return datetime.fromisoformat(str(s).replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                return None

        def _value_at(target_dt, field):
            """Value of `field` in the history record whose timestamp is
            closest to target_dt. Only considers records where the field
            is numeric."""
            best_val = None
            best_diff = None
            for rec in self._history:
                ts = _parse_ts(rec.get("date"))
                if ts is None:
                    continue
                v = rec.get(field)
                if not isinstance(v, (int, float)):
                    continue
                diff = abs((ts - target_dt).total_seconds())
                if best_diff is None or diff < best_diff:
                    best_val = v
                    best_diff = diff
            return best_val

        out: dict = {}

        cur_h = self._latest.get("humidity")
        if isinstance(cur_h, (int, float)):
            y_h = _value_at(now - timedelta(hours=24), "humidity")
            if y_h is not None:
                out["humidityFromYesterday"] = round(float(cur_h) - float(y_h), 1)

        cur_p = self._latest.get("baromrelin")
        if isinstance(cur_p, (int, float)):
            p_3h = _value_at(now - timedelta(hours=3), "baromrelin")
            if p_3h is not None:
                out["pressureTrend3h"] = round(float(cur_p) - float(p_3h), 3)

        return out

    # -- History ---------------------------------------------------------

    def _fetch_history(self):
        """Pull the last HISTORY_LIMIT records from /devices/{MAC}.

        Ambient returns newest-first. Each record is a full snapshot (same
        shape as `lastData`), so downstream consumers can walk backwards
        through `self._history` looking for the fields they need.

        Silently skips if the MAC hasn't been captured yet — the 20-min
        timer will retry, and the initial 10-s deferred call gives the
        first current-conditions poll room to land.
        """
        if not self._app_key or not self._api_key:
            return
        if not self._mac:
            logger.info(
                "Ambient history: no MAC yet (waiting on first /devices poll)"
            )
            return

        from datetime import datetime, timezone
        self._last_history_iso = datetime.now(timezone.utc).isoformat()
        try:
            with httpx.Client(timeout=15.0) as client:
                r = client.get(
                    f"{self.REST_BASE}/devices/{self._mac}",
                    params={
                        "applicationKey": self._app_key,
                        "apiKey": self._api_key,
                        "limit": self.HISTORY_LIMIT,
                    },
                )
                r.raise_for_status()
                records = r.json()
        except Exception as e:
            err = str(e)
            logger.warning("Ambient history fetch failed: %s", err)
            self._last_history_error = err
            self.diagnosticsChanged.emit()
            return

        if not isinstance(records, list):
            self._last_history_error = "history response not a list"
            self.diagnosticsChanged.emit()
            return

        self._history = records
        self._last_history_error = ""
        # Records come newest-first. Log the covered window so it's
        # obvious in the console whether the station is on 1-min or
        # 5-min reporting cadence.
        first_ts = records[0].get("date")  if records else None
        last_ts  = records[-1].get("date") if records else None
        logger.info(
            "Ambient history OK: %d records covering %s -> %s",
            len(records), last_ts, first_ts,   # last_ts is oldest, first_ts is newest
        )
        self.historyUpdated.emit(self._history)

        # Recompute derived fields (humidityFromYesterday, pressureTrend3h)
        # now that history is in hand, and re-emit the current snapshot so
        # tiles pick up the new values immediately (rather than waiting for
        # the next 60-s current-conditions poll).
        derived = self._compute_history_derived()
        if derived:
            self._latest = {**self._latest, **derived}
            self.dataUpdated.emit(self._latest)
            logger.info(
                "Ambient derived: humidityFromYesterday=%s pressureTrend3h=%s",
                derived.get("humidityFromYesterday"),
                derived.get("pressureTrend3h"),
            )

        self.diagnosticsChanged.emit()

    @Slot()
    def _on_socket_connected(self):
        self._socket_connected = True
        self._recompute_connected()

    @Slot()
    def _on_socket_disconnected(self):
        self._socket_connected = False
        self._recompute_connected()

    def _recompute_connected(self):
        value = self._socket_connected or self._rest_ok
        if self._connected != value:
            self._connected = value
            self.connectionChanged.emit(value)

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest

    # --- diagnostics (mirrors EcowittClient surface for the Settings dialog) --

    @Property(str, notify=diagnosticsChanged)
    def rawResponse(self):
        return self._raw_text

    @Property(int, notify=diagnosticsChanged)
    def httpStatus(self):
        return self._last_status

    @Property(str, notify=diagnosticsChanged)
    def lastPollIso(self):
        return self._last_poll_iso

    @Property(str, notify=diagnosticsChanged)
    def lastError(self):
        return self._last_error

    @Property(str, notify=dataUpdated)
    def flattenedJson(self):
        import json
        try:
            return json.dumps(self._latest, indent=2, sort_keys=True)
        except Exception:
            return str(self._latest)

    @Property(bool, notify=connectionChanged)
    def connected(self):
        return self._connected

    # --- History surface (consumed by Tier-1 trend tiles in Batch 3+) ---

    @Property("QVariant", notify=historyUpdated)
    def history(self):
        """Newest-first list of snapshot records. Empty until the first
        fetch completes (~10 s after start). Tiles should treat empty
        list as 'no trend yet' rather than an error."""
        return self._history

    @Property(str, notify=diagnosticsChanged)
    def lastHistoryPollIso(self):
        return self._last_history_iso

    @Property(str, notify=diagnosticsChanged)
    def lastHistoryError(self):
        return self._last_history_error

    @Property(str, notify=diagnosticsChanged)
    def stationMac(self):
        return self._mac
