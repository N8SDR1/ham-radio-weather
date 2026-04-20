"""Environment Canada alerts via the GeoMet OGC API.

Queries ``https://api.weather.gc.ca/collections/alerts/items`` with a small
bbox around the user's location. Returns GeoJSON FeatureCollection; each
feature's properties carry CAP-style fields that we normalize to match the
NWS output schema consumed by the Weather Alerts tile.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


class EnvCanadaAlertsClient(QObject):
    """Environment Canada active-alerts adapter."""

    alertsChanged      = Signal()
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()
    enabledChanged     = Signal()

    URL     = "https://api.weather.gc.ca/collections/alerts-realtime/items"
    POLL_MS = 15 * 60 * 1000

    PROVIDER_NAME = "Environment Canada"
    PROVIDER_ID   = "ec"

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._alerts: list[dict] = []
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        self._enabled = True

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # --- config / location -----------------------------------------

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid: return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("EC: invalid grid: %s", e)
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat = float(lat)
        self._lon = float(lon)
        QTimer.singleShot(0, self._poll)

    @Slot(int)
    def setPollInterval(self, minutes: int):
        try:
            m = int(minutes)
        except (TypeError, ValueError):
            m = 15
        prev = self._enabled
        if m <= 0:
            self._enabled = False
            self._timer.stop()
            if self._alerts:
                self._alerts = []
                self.alertsChanged.emit()
            if prev:
                self.enabledChanged.emit()
        else:
            self._enabled = True
            self._timer.setInterval(max(1, min(60, m)) * 60 * 1000)
            self._timer.start()
            if not prev:
                self.enabledChanged.emit()
                if self._lat is not None:
                    QTimer.singleShot(0, self._poll)

    @Slot()
    def start(self):
        if self._enabled:
            self._timer.start()
            if self._lat is not None:
                QTimer.singleShot(0, self._poll)

    @Slot()
    def stop(self):
        self._timer.stop()

    # --- polling ---------------------------------------------------

    def _poll(self):
        if not self._enabled or self._lat is None or self._lon is None:
            return
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        # Small bounding box around user (~100 km either side)
        d = 1.0
        bbox = f"{self._lon - d},{self._lat - d},{self._lon + d},{self._lat + d}"
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (github.com/N8SDR1/ham-radio-weather)",
            "Accept": "application/geo+json",
        }
        params = {"bbox": bbox, "f": "json", "limit": 50}
        try:
            with httpx.Client(timeout=10.0, headers=headers) as client:
                r = client.get(self.URL, params=params)
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            logger.warning("EC alerts poll failed: %s", e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        features = j.get("features") or []
        alerts = []
        for feat in features:
            p = (feat or {}).get("properties") or {}
            sev = (p.get("severity") or "unknown").lower()
            alerts.append({
                "id":        p.get("identifier") or feat.get("id") or "",
                "event":     p.get("alertType") or p.get("descriptiveName") or p.get("headline") or "",
                "headline":  p.get("headline") or "",
                "desc":      (p.get("description") or "").strip()[:600],
                "severity":  sev,
                "urgency":   (p.get("urgency") or "").lower(),
                "certainty": (p.get("certainty") or "").lower(),
                "sent":      p.get("effective") or "",
                "expires":   p.get("expires") or "",
                "areaDesc":  p.get("areas") or p.get("areaDesc") or "",
                "sender":    p.get("sender") or "Environment Canada",
            })
        # Severity sort
        order = {"extreme": 0, "severe": 1, "moderate": 2, "minor": 3, "unknown": 4}
        alerts.sort(key=lambda a: (order.get(a["severity"], 5), a["expires"]))

        self._alerts = alerts
        self._last_error = ""
        self.alertsChanged.emit()
        self.diagnosticsChanged.emit()
        logger.info("EC alerts: %d active for (%.3f, %.3f)",
                    len(alerts), self._lat, self._lon)

    # --- QML surface ----------------------------------------------

    @Property("QVariant", notify=alertsChanged)
    def alerts(self): return self._alerts

    @Property(int, notify=alertsChanged)
    def count(self): return len(self._alerts)

    @Property(bool, notify=alertsChanged)
    def hasExtremeOrSevere(self):
        return any(a["severity"] in ("extreme", "severe") for a in self._alerts)

    @Property(bool, notify=enabledChanged)
    def enabled(self): return self._enabled

    @Property(str, notify=diagnosticsChanged)
    def lastPollIso(self): return self._last_poll_iso

    @Property(str, notify=diagnosticsChanged)
    def lastError(self): return self._last_error

    @Property(str, constant=True)
    def providerName(self): return self.PROVIDER_NAME
