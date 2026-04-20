from __future__ import annotations

import logging
import xml.etree.ElementTree as ET
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

logger = logging.getLogger(__name__)


class HamQslClient(QObject):
    """Polls https://www.hamqsl.com/solarxml.php for solar + HF band data.

    Public, no auth. Refreshes every 15 minutes by default — courteous cadence
    that matches hamlog's existing cache TTL.
    """

    dataUpdated = Signal("QVariant")
    errorOccurred = Signal(str)

    URL = "https://www.hamqsl.com/solarxml.php"
    POLL_MS = 15 * 60 * 1000

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._latest: dict = {}
        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    @Slot()
    def start(self):
        self._poll()
        self._timer.start()

    @Slot()
    def stop(self):
        self._timer.stop()

    def _poll(self):
        headers = {
            "User-Agent": "wx-dashboard/0.1 (ham radio weather app; +https://example.invalid)",
            "Accept": "application/xml, text/xml",
        }
        try:
            with httpx.Client(timeout=15.0, headers=headers, follow_redirects=True) as client:
                r = client.get(self.URL)
                r.raise_for_status()
                parsed = self._parse(r.text)
                if parsed:
                    self._latest = parsed
                    logger.info(
                        "HamQSL poll OK: SFI=%s A=%s K=%s bands=%d",
                        parsed.get("sfi"), parsed.get("aindex"),
                        parsed.get("kindex"), len(parsed.get("bands") or {}),
                    )
                    self.dataUpdated.emit(self._latest)
                else:
                    logger.warning(
                        "HamQSL parse returned empty; first 200 chars: %r",
                        r.text[:200],
                    )
                    self.errorOccurred.emit("HamQSL XML parsed empty")
        except Exception as e:
            logger.warning("HamQSL poll failed: %s", e)
            self.errorOccurred.emit(str(e))

    @staticmethod
    def _parse(xml_text: str) -> dict:
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as e:
            logger.warning("HamQSL XML parse error: %s", e)
            return {}

        solar = root.find("solardata")
        if solar is None:
            return {}

        def txt(tag: str) -> str:
            el = solar.find(tag)
            return (el.text or "").strip() if el is not None else ""

        def num(tag: str) -> Optional[float]:
            v = txt(tag)
            try:
                return float(v)
            except (TypeError, ValueError):
                return None

        bands: dict[str, dict[str, str]] = {}
        cc = solar.find("calculatedconditions")
        if cc is not None:
            for b in cc.findall("band"):
                name = (b.get("name") or "").strip()
                time = (b.get("time") or "").strip().lower()   # "day" | "night"
                cond = (b.text or "").strip()
                if not name or not time:
                    continue
                bands.setdefault(name, {})[time] = cond

        return {
            "sfi": num("solarflux"),
            "aindex": num("aindex"),
            "kindex": num("kindex"),
            "sunspots": num("sunspots"),
            "xray": txt("xray"),
            "solarwind": num("solarwind"),
            "updated": txt("updated"),
            "bands": bands,   # e.g. {"80m-40m": {"day": "Fair", "night": "Good"}, ...}
        }

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest
