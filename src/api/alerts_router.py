"""Unified alerts facade. Owns every provider (NWS, EC, MeteoAlarm, BoM) and
delegates based on the user-selected provider. QML sees a single
``alertsClient`` context property whose ``alerts``/``count``/etc. always
reflect whichever provider is currently active."""

from __future__ import annotations

import logging
from typing import Optional

from PySide6.QtCore import Property, QObject, Signal, Slot

from api.bom         import BomAlertsClient
from api.ec_alerts   import EnvCanadaAlertsClient
from api.meteoalarm  import MeteoAlarmAlertsClient
from api.nws         import NwsAlertsClient

logger = logging.getLogger(__name__)


class AlertsRouter(QObject):
    """Delegates to one of several alert providers based on setting."""

    alertsChanged   = Signal()
    enabledChanged  = Signal()
    providerChanged = Signal()

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        # Instantiate all providers once; only the active one polls.
        self._providers: dict = {
            "nws":        NwsAlertsClient(self),
            "ec":         EnvCanadaAlertsClient(self),
            "meteoalarm": MeteoAlarmAlertsClient(self),
            "bom":        BomAlertsClient(self),
        }

        self._active: Optional[QObject] = None
        self._active_id: str = "off"
        self._requested: str = "off"    # default until user picks one
        self._poll_minutes: int = 15
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None

        # Forward signals from whatever provider is active
        for p in self._providers.values():
            p.alertsChanged.connect(self._on_active_alerts_changed)
            p.enabledChanged.connect(self._on_active_enabled_changed)

    # --- lifecycle ------------------------------------------------

    @Slot()
    def start(self):
        # Start the currently-active provider (if any)
        if self._active is not None:
            self._active.start()

    @Slot()
    def stop(self):
        for p in self._providers.values():
            p.stop()

    # --- settings entrypoints -------------------------------------

    @Slot(str)
    def setProvider(self, requested: str):
        # Any unknown value (including legacy "auto") falls back to "off".
        self._requested = (requested or "off").lower()
        self._resolve_and_switch()

    @Slot(int)
    def setPollInterval(self, minutes: int):
        self._poll_minutes = int(minutes) if minutes is not None else 15
        for p in self._providers.values():
            p.setPollInterval(self._poll_minutes)
        # Router's enabled mirrors the active provider; re-emit for safety
        self.enabledChanged.emit()

    @Slot(str)
    def setGridSquare(self, grid: str):
        if self._active is not None:
            self._active.setGridSquare(grid)
        # Cache for later provider switches
        from api.geo import maidenhead_to_latlon
        try:
            self._lat, self._lon = maidenhead_to_latlon(grid)
        except Exception:
            pass

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        self._lat = float(lat)
        self._lon = float(lon)
        for p in self._providers.values():
            p.setLocation(lat, lon)

    @Slot(str)
    def setCountry(self, slug: str):
        # MeteoAlarm-specific
        self._providers["meteoalarm"].setCountry(slug)

    @Slot(str)
    def setState(self, code: str):
        # BoM-specific
        self._providers["bom"].setState(code)

    # --- resolution ----------------------------------------------

    def _resolve_effective(self) -> str:
        r = self._requested
        if r in self._providers:
            return r
        # "off" or anything unrecognized (incl. legacy "auto") → disabled
        return "off"

    def _resolve_and_switch(self):
        new_id = self._resolve_effective()
        if new_id == self._active_id:
            return

        # Stop whichever was active
        for p in self._providers.values():
            p.stop()

        self._active_id = new_id
        self._active = self._providers.get(new_id)
        logger.info("Alerts provider → %s", self.providerName)

        if self._active is not None:
            # Apply current poll cadence + location, then start
            self._active.setPollInterval(self._poll_minutes)
            if self._lat is not None and self._lon is not None:
                self._active.setLocation(self._lat, self._lon)
            self._active.start()

        self.providerChanged.emit()
        self.alertsChanged.emit()
        self.enabledChanged.emit()

    # --- signal forwarding ---------------------------------------

    def _on_active_alerts_changed(self):
        if self.sender() is self._active:
            self.alertsChanged.emit()

    def _on_active_enabled_changed(self):
        if self.sender() is self._active:
            self.enabledChanged.emit()

    # --- QML surface proxied from active provider -----------------

    @Property("QVariant", notify=alertsChanged)
    def alerts(self):
        return self._active.alerts if self._active is not None else []

    @Property(int, notify=alertsChanged)
    def count(self):
        return len(self._active.alerts) if self._active is not None else 0

    @Property(bool, notify=alertsChanged)
    def hasExtremeOrSevere(self):
        return bool(self._active.hasExtremeOrSevere) if self._active is not None else False

    @Property(bool, notify=enabledChanged)
    def enabled(self):
        if self._active is None:
            return False
        return bool(self._active.enabled) and self._poll_minutes > 0

    @Property(str, notify=providerChanged)
    def providerId(self):
        return self._active_id

    @Property(str, notify=providerChanged)
    def providerName(self):
        names = {
            "nws":        "NWS (United States)",
            "ec":         "Environment Canada",
            "meteoalarm": "MeteoAlarm (Europe)",
            "bom":        "Australian BoM",
            "off":        "Disabled",
        }
        return names.get(self._active_id, "Disabled")
