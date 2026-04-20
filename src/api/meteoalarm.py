"""MeteoAlarm (EUMETNET) alerts — Europe-wide aggregator.

Polls per-country ATOM feeds at
``https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-<country>`` and
parses CAP (Common Alerting Protocol) entries. Country is either
user-configured or auto-detected from lat/lon.

Supports 38 European countries plus Israel.
"""

from __future__ import annotations

import logging
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon, detect_eu_country

logger = logging.getLogger(__name__)

# CAP + ATOM XML namespaces used by MeteoAlarm
_NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "cap":  "urn:oasis:names:tc:emergency:cap:1.2",
}


class MeteoAlarmAlertsClient(QObject):
    """European alerts via MeteoAlarm's per-country ATOM/CAP feeds."""

    alertsChanged      = Signal()
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()
    enabledChanged     = Signal()

    URL_TEMPLATE = "https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-{country}"
    POLL_MS      = 15 * 60 * 1000

    PROVIDER_NAME = "MeteoAlarm"
    PROVIDER_ID   = "meteoalarm"

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._country: str = ""          # slug like "germany"
        self._country_manual: str = ""   # user override
        self._alerts: list[dict] = []
        self._last_poll_iso: str = ""
        self._last_error: str = ""
        self._enabled = True

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # --- config ---------------------------------------------------

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid: return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("MeteoAlarm: invalid grid: %s", e)
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        self._lat = float(lat)
        self._lon = float(lon)
        self._refresh_country()

    @Slot(str)
    def setCountry(self, slug: str):
        """User-specified country slug (empty = auto-detect)."""
        self._country_manual = (slug or "").strip().lower()
        self._refresh_country()

    def _refresh_country(self):
        new_country = self._country_manual
        if not new_country and self._lat is not None:
            new_country = detect_eu_country(self._lat, self._lon)
        if new_country != self._country:
            self._country = new_country
            logger.info("MeteoAlarm country: %s", self._country or "(none)")
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

    # --- polling --------------------------------------------------

    def _poll(self):
        if not self._enabled or not self._country:
            return
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        url = self.URL_TEMPLATE.format(country=self._country)
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (github.com/N8SDR1/ham-radio-weather)",
            "Accept": "application/atom+xml, application/xml, */*",
        }
        try:
            with httpx.Client(timeout=15.0, headers=headers) as client:
                r = client.get(url)
                r.raise_for_status()
                xml_text = r.text
        except Exception as e:
            logger.warning("MeteoAlarm poll (%s) failed: %s", self._country, e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        alerts = self._parse_atom(xml_text)
        order = {"extreme": 0, "severe": 1, "moderate": 2, "minor": 3, "unknown": 4}
        alerts.sort(key=lambda a: (order.get(a["severity"], 5), a["expires"]))
        self._alerts = alerts
        self._last_error = ""
        self.alertsChanged.emit()
        self.diagnosticsChanged.emit()
        logger.info("MeteoAlarm %s: %d alerts", self._country, len(alerts))

    @staticmethod
    def _parse_atom(xml_text: str) -> list[dict]:
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as e:
            logger.warning("MeteoAlarm XML parse error: %s", e)
            return []
        out: list[dict] = []
        for entry in root.findall("atom:entry", _NS):
            title = (entry.findtext("atom:title", default="", namespaces=_NS) or "").strip()
            updated = (entry.findtext("atom:updated", default="", namespaces=_NS) or "").strip()
            entry_id = (entry.findtext("atom:id", default="", namespaces=_NS) or "").strip()
            summary = (entry.findtext("atom:summary", default="", namespaces=_NS) or "").strip()

            # Look for nested cap:alert (newer feeds) or use atom fields
            alert_el = entry.find("cap:alert", _NS)
            info_el = alert_el.find("cap:info", _NS) if alert_el is not None else None

            if info_el is not None:
                event = (info_el.findtext("cap:event", default="", namespaces=_NS) or title).strip()
                severity = (info_el.findtext("cap:severity", default="", namespaces=_NS) or "unknown").lower()
                urgency  = (info_el.findtext("cap:urgency",  default="", namespaces=_NS) or "").lower()
                certainty= (info_el.findtext("cap:certainty",default="", namespaces=_NS) or "").lower()
                headline = (info_el.findtext("cap:headline", default="", namespaces=_NS) or title).strip()
                desc     = (info_el.findtext("cap:description", default="", namespaces=_NS) or summary or "").strip()[:600]
                expires  = (info_el.findtext("cap:expires",  default="", namespaces=_NS) or "").strip()
                sent     = (info_el.findtext("cap:onset",    default="", namespaces=_NS)
                            or info_el.findtext("cap:effective", default="", namespaces=_NS)
                            or updated).strip()
                area_el = info_el.find("cap:area", _NS)
                area = (area_el.findtext("cap:areaDesc", default="", namespaces=_NS) if area_el is not None else "").strip()
                sender = (info_el.findtext("cap:senderName", default="", namespaces=_NS) or "MeteoAlarm").strip()
            else:
                # Fallback: extract severity from title like "Moderate - Thunderstorm"
                event = title
                sev = "unknown"
                for key in ("extreme", "severe", "moderate", "minor"):
                    if key in title.lower():
                        sev = key
                        break
                severity = sev
                urgency = certainty = ""
                headline = title
                desc     = summary[:600]
                expires  = ""
                sent     = updated
                area     = ""
                sender   = "MeteoAlarm"

            out.append({
                "id": entry_id,
                "event": event,
                "headline": headline,
                "desc": desc,
                "severity": severity,
                "urgency": urgency,
                "certainty": certainty,
                "sent": sent,
                "expires": expires,
                "areaDesc": area,
                "sender": sender,
            })
        return out

    # --- QML surface ---------------------------------------------

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
