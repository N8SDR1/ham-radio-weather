"""Australia Bureau of Meteorology (BoM) warnings adapter.

Polls the BoM v1 warnings JSON feed and filters by state. State is either
user-configured (nsw/vic/qld/sa/wa/tas/nt/act) or auto-detected from lat/lon.

Note: BoM's public warnings endpoint's response schema isn't formally
documented; this adapter parses defensively and falls back to empty when
fields are missing. If readings don't populate correctly, flip on the debug
panel in Settings and share the raw output so the mapper can be tuned.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon, detect_au_state

logger = logging.getLogger(__name__)


class BomAlertsClient(QObject):
    """Best-effort Australian BoM active-warnings adapter."""

    alertsChanged      = Signal()
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()
    enabledChanged     = Signal()

    URL     = "https://api.weather.bom.gov.au/v1/warnings"
    POLL_MS = 15 * 60 * 1000

    PROVIDER_NAME = "Australian BoM"
    PROVIDER_ID   = "bom"

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._state: str = ""            # auto-resolved
        self._state_manual: str = ""     # user override
        self._alerts: list[dict] = []
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        self._enabled = True

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # --- config --------------------------------------------------

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid: return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("BoM: invalid grid: %s", e)
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        self._lat = float(lat)
        self._lon = float(lon)
        self._refresh_state()

    @Slot(str)
    def setState(self, code: str):
        self._state_manual = (code or "").strip().lower()
        self._refresh_state()

    def _refresh_state(self):
        new_state = self._state_manual
        if not new_state and self._lat is not None:
            new_state = detect_au_state(self._lat, self._lon)
        if new_state != self._state:
            self._state = new_state
            logger.info("BoM state: %s", self._state or "(none)")
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
            if prev: self.enabledChanged.emit()
        else:
            self._enabled = True
            self._timer.setInterval(max(1, min(60, m)) * 60 * 1000)
            self._timer.start()
            if not prev:
                self.enabledChanged.emit()
                QTimer.singleShot(0, self._poll)

    @Slot()
    def start(self):
        if self._enabled:
            self._timer.start()
            QTimer.singleShot(0, self._poll)

    @Slot()
    def stop(self):
        self._timer.stop()

    # --- polling -------------------------------------------------

    def _poll(self):
        if not self._enabled or not self._state:
            return
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (github.com/N8SDR1/ham-radio-weather)",
            "Accept": "application/json",
        }
        try:
            with httpx.Client(timeout=15.0, headers=headers) as client:
                r = client.get(self.URL)
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            logger.warning("BoM poll failed: %s", e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        items = j.get("data") if isinstance(j, dict) else None
        if not isinstance(items, list):
            # Some deployments wrap differently; accept top-level list too
            items = j if isinstance(j, list) else []

        state_upper = self._state.upper()
        alerts = []
        for it in items:
            if not isinstance(it, dict):
                continue
            # Filter: state field may be "NSW" or "nsw" or in nested "state_code"
            st = (it.get("state") or it.get("state_code") or "").upper()
            if st and st != state_upper:
                continue

            title = it.get("title") or it.get("short_title") or "Warning"
            raw_type = (it.get("type") or "").lower()
            # Sniff severity from type / title
            severity = "unknown"
            low = (title + " " + raw_type).lower()
            if "extreme"  in low: severity = "extreme"
            elif "severe" in low: severity = "severe"
            elif "moderate" in low or "major" in low: severity = "moderate"
            elif "minor"  in low or "advice" in low: severity = "minor"

            alerts.append({
                "id":        str(it.get("id") or ""),
                "event":     title,
                "headline":  it.get("short_title") or title,
                "desc":      (it.get("description") or "").strip()[:600],
                "severity":  severity,
                "urgency":   (it.get("urgency") or "").lower(),
                "certainty": (it.get("certainty") or "").lower(),
                "sent":      it.get("issue_time") or "",
                "expires":   it.get("expiry_time") or "",
                "areaDesc":  it.get("area") or state_upper,
                "sender":    "Australian BoM",
            })

        order = {"extreme": 0, "severe": 1, "moderate": 2, "minor": 3, "unknown": 4}
        alerts.sort(key=lambda a: (order.get(a["severity"], 5), a["expires"]))
        self._alerts = alerts
        self._last_error = ""
        self.alertsChanged.emit()
        self.diagnosticsChanged.emit()
        logger.info("BoM %s: %d warnings", state_upper, len(alerts))

    # --- QML surface --------------------------------------------

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
