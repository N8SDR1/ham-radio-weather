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

    REST_BASE = "https://rt.ambientweather.net/v1"
    POLL_MS = 60_000

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

        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(self.POLL_MS)
        self._poll_timer.timeout.connect(self._rest_poll)

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

    @Slot()
    def stop(self):
        self._poll_timer.stop()
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
                    last = devices[0].get("lastData", {})
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
        self.dataUpdated.emit(self._latest)

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
