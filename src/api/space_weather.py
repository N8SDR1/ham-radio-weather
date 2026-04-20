"""NOAA SWPC 3-day planetary-K forecast.

Pulls the public JSON forecast feed and emits:
    {
        "current_kp":   float,       # most recent observed Kp
        "peak_kp":      float,       # highest upcoming Kp in the 72 h window
        "peak_time":    ISO str,     # when peak occurs
        "peak_g":       int 0-5,     # NOAA G-scale at peak
        "observed":     [ {time, kp, g}, ...  ]   # recent past (for context)
        "forecast":     [ {time, kp, g}, ...  ]   # next 72 h in 3-hour slots
    }

Complements the HF Propagation tile: that one shows *now*, this one shows
*next 72 hours* so operators can plan around upcoming storms.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

logger = logging.getLogger(__name__)


def _kp_to_g(kp: float) -> int:
    """NOAA geomagnetic storm scale from planetary-K value."""
    if kp >= 9:  return 5
    if kp >= 8:  return 4
    if kp >= 7:  return 3
    if kp >= 6:  return 2
    if kp >= 5:  return 1
    return 0


def _parse_swpc_time(s) -> Optional[datetime]:
    if not s:
        return None
    s = str(s).strip().replace("T", " ").rstrip("Z")
    for fmt in ("%Y-%m-%d %H:%M:%S.%f",
                "%Y-%m-%d %H:%M:%S",
                "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


class SpaceWeatherClient(QObject):
    """Polls https://services.swpc.noaa.gov/ for the planetary-K forecast."""

    dataUpdated        = Signal("QVariant")
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()

    URL     = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json"
    POLL_MS = 60 * 60 * 1000   # 1 hour — SWPC updates every 3 h anyway

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._latest: dict = {}
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    @Slot()
    def start(self):
        self._timer.start()
        QTimer.singleShot(0, self._poll)

    @Slot()
    def stop(self):
        self._timer.stop()

    def _poll(self):
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (github.com/N8SDR1/ham-radio-weather)",
            "Accept": "application/json",
        }
        try:
            with httpx.Client(timeout=15.0, headers=headers) as client:
                r = client.get(self.URL)
                r.raise_for_status()
                rows = r.json()
        except Exception as e:
            logger.warning("Space Weather poll failed: %s", e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        if not isinstance(rows, list) or len(rows) < 1:
            self._last_error = "SWPC response format unexpected"
            self.diagnosticsChanged.emit()
            return

        # SWPC now returns an array of objects:
        #   {"time_tag": "...", "kp": 1.00, "observed": "observed", "noaa_scale": null}
        # Older endpoints used an array-of-arrays with a header row. We support
        # both for safety.
        parsed: list[dict] = []
        for row in rows:
            if isinstance(row, dict):
                ts_raw  = row.get("time_tag")
                kp_raw  = row.get("kp")
                obs_raw = row.get("observed")
            elif isinstance(row, list) and len(row) >= 3:
                # Skip the header row, which is all strings
                if str(row[0]).lower() == "time_tag":
                    continue
                ts_raw, kp_raw, obs_raw = row[0], row[1], row[2]
            else:
                continue

            ts = _parse_swpc_time(ts_raw)
            if ts is None:
                continue
            try:
                kp = float(kp_raw)
            except (TypeError, ValueError):
                continue
            observed_flag = str(obs_raw or "").lower()
            parsed.append({
                "time":     ts.isoformat(),
                "_ts":      ts,
                "kp":       round(kp, 2),
                "g":        _kp_to_g(kp),
                "observed": observed_flag == "observed",
            })

        if not parsed:
            self._last_error = "SWPC returned no parseable rows"
            self.diagnosticsChanged.emit()
            return

        now = datetime.now(timezone.utc)
        observed_rows = [p for p in parsed if p["_ts"] <= now and p["observed"]]
        forecast_rows = [p for p in parsed if p["_ts"] >  now][:24]    # next 72 h

        # Current Kp = most recent observed, fall back to last parsed value
        current_kp = observed_rows[-1]["kp"] if observed_rows else parsed[0]["kp"]

        peak = max(forecast_rows, key=lambda p: p["kp"], default=None)

        def _strip_ts(p):
            q = dict(p)
            q.pop("_ts", None)
            return q

        self._latest = {
            "current_kp":  current_kp,
            "current_g":   _kp_to_g(current_kp),
            "peak_kp":     peak["kp"]       if peak else current_kp,
            "peak_g":      peak["g"]        if peak else _kp_to_g(current_kp),
            "peak_time":   peak["time"]     if peak else "",
            "observed":    [_strip_ts(p) for p in observed_rows[-8:]],   # last 24 h context
            "forecast":    [_strip_ts(p) for p in forecast_rows],
        }
        self._last_error = ""
        self.dataUpdated.emit(self._latest)
        self.diagnosticsChanged.emit()
        logger.info(
            "Space Weather OK: current Kp=%s, peak Kp=%s (G%s) in %d forecast slots",
            current_kp, self._latest["peak_kp"], self._latest["peak_g"],
            len(forecast_rows),
        )

    # --- QML surface ---------------------------------------------

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest

    @Property(str, notify=diagnosticsChanged)
    def lastPollIso(self):
        return self._last_poll_iso

    @Property(str, notify=diagnosticsChanged)
    def lastError(self):
        return self._last_error
