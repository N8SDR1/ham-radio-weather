"""NOAA / National Weather Service active-alert adapter.

Polls ``https://api.weather.gov/alerts/active?point={lat},{lon}`` and emits a
simplified list of active alerts that the Alerts tile consumes alongside its
threshold-based rules. Requires a User-Agent header per NWS policy.

Works for any station type when a grid square or lat/lon is configured —
these are NOAA-issued public alerts, not station data.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


class NwsAlertsClient(QObject):
    """Fetches active NWS alerts for the user's location."""

    alertsChanged      = Signal()
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()
    enabledChanged     = Signal()

    URL     = "https://api.weather.gov/alerts/active"
    POLL_MS = 15 * 60 * 1000   # 15 min — friendly to NWS, matches HamQSL cadence

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._alerts: list[dict] = []
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        self._enabled: bool = True

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # --- configuration ------------------------------------------------

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid:
            return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("NWS: invalid grid: %s", e)
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat = float(lat)
        self._lon = float(lon)
        logger.info("NWS alerts location set to %.4f, %.4f", self._lat, self._lon)
        # Defer to next event-loop tick so callers don't block on HTTP
        QTimer.singleShot(0, self._poll)

    @Slot(int)
    def setPollInterval(self, minutes: int):
        """Set polling cadence in minutes. 0 disables polling entirely."""
        try:
            m = int(minutes)
        except (TypeError, ValueError):
            m = 15
        prev_enabled = self._enabled
        if m <= 0:
            self._enabled = False
            self._timer.stop()
            # Clear stale alerts so the UI shows the disabled state cleanly
            if self._alerts:
                self._alerts = []
                self.alertsChanged.emit()
            logger.info("NWS alerts: polling disabled")
            if prev_enabled:
                self.enabledChanged.emit()
        else:
            m = max(1, min(60, m))
            self._enabled = True
            self._timer.setInterval(m * 60 * 1000)
            self._timer.start()
            logger.info("NWS alerts: polling every %d min", m)
            if not prev_enabled:
                self.enabledChanged.emit()
                if self._lat is not None:
                    QTimer.singleShot(0, self._poll)

    # --- lifecycle ----------------------------------------------------

    @Slot()
    def start(self):
        if self._enabled:
            self._timer.start()
            if self._lat is not None:
                QTimer.singleShot(0, self._poll)

    @Slot()
    def stop(self):
        self._timer.stop()

    # --- polling ------------------------------------------------------

    def _poll(self):
        if not self._enabled:
            return
        if self._lat is None or self._lon is None:
            return
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (github.com/N8SDR1/ham-radio-weather)",
            "Accept": "application/geo+json",
        }
        params = {"point": f"{self._lat:.4f},{self._lon:.4f}"}
        try:
            with httpx.Client(timeout=10.0, headers=headers) as client:
                r = client.get(self.URL, params=params)
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            logger.warning("NWS alerts poll failed: %s", e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        features = j.get("features") or []
        alerts = []
        for feat in features:
            p = (feat or {}).get("properties") or {}
            severity = (p.get("severity") or "Unknown").lower()
            alerts.append({
                "id":        p.get("id") or feat.get("id") or "",
                "event":     p.get("event") or "",
                "headline":  p.get("headline") or "",
                "desc":      (p.get("description") or "").strip()[:600],
                "severity":  severity,
                "urgency":   (p.get("urgency")  or "").lower(),
                "certainty": (p.get("certainty") or "").lower(),
                "sent":      p.get("sent") or "",
                "expires":   p.get("expires") or "",
                "areaDesc":  p.get("areaDesc") or "",
                "sender":    p.get("senderName") or "",
            })

        # Sort: extreme/severe first, then by expires
        sev_order = {"extreme": 0, "severe": 1, "moderate": 2, "minor": 3, "unknown": 4}
        alerts.sort(key=lambda a: (sev_order.get(a["severity"], 5), a["expires"]))

        self._alerts = alerts
        self._last_error = ""
        self.alertsChanged.emit()
        self.diagnosticsChanged.emit()
        logger.info("NWS alerts: %d active for (%.3f, %.3f)",
                    len(alerts), self._lat, self._lon)

    # --- QML surface --------------------------------------------------

    @Property("QVariant", notify=alertsChanged)
    def alerts(self):
        return self._alerts

    @Property(int, notify=alertsChanged)
    def count(self):
        return len(self._alerts)

    @Property(bool, notify=alertsChanged)
    def hasExtremeOrSevere(self):
        return any(a["severity"] in ("extreme", "severe") for a in self._alerts)

    @Property(bool, notify=enabledChanged)
    def enabled(self):
        return self._enabled

    @Property(str, notify=diagnosticsChanged)
    def lastPollIso(self):
        return self._last_poll_iso

    @Property(str, notify=diagnosticsChanged)
    def lastError(self):
        return self._last_error
