"""Ecowitt Cloud API v3 adapter.

Polls ``https://api.ecowitt.net/api/v3/device/real_time`` and translates the
nested ``{time,unit,value}`` response into the flat Ambient-style dict that
QML tiles already consume (``tempf``, ``humidity``, ``windspeedmph``, etc.).

Ecowitt is the OEM behind Ambient Weather, so the sensors and field meanings
line up almost 1:1 — this adapter is mostly a JSON-shape translation layer.

Current scope:
    - Cloud polling only (60-second cadence)
    - Local LAN polling (``http://<ip>/get_livedata_info``) is deferred to a
      later pass — the `local_ip` arg is accepted but unused for now.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

logger = logging.getLogger(__name__)


class EcowittClient(QObject):
    """QObject adapter. Public surface matches AmbientClient so QML and the
    factory in ``main.py`` can swap them freely."""

    dataUpdated       = Signal("QVariant")
    connectionChanged = Signal(bool)
    errorOccurred     = Signal(str)
    diagnosticsChanged= Signal()
    # Stub to match AmbientClient's interface. Ecowitt history will be
    # wired up in a later batch via the /api/v3/device/history endpoint;
    # for now the signal never fires and `history` stays an empty list,
    # so sparklines simply hide on Ecowitt setups.
    historyUpdated    = Signal("QVariant")

    CLOUD_URL = "https://api.ecowitt.net/api/v3/device/real_time"
    POLL_MS   = 60_000

    def __init__(
        self,
        application_key: str,
        api_key: str,
        mac: str,
        local_ip: str = "",
        parent: Optional[QObject] = None,
    ):
        super().__init__(parent)
        self._app_key  = (application_key or "").strip()
        self._api_key  = (api_key or "").strip()
        self._mac      = (mac or "").strip()
        self._local_ip = (local_ip or "").strip()  # reserved for LAN polling
        self._latest: dict = {}
        self._connected = False
        # diagnostics — last raw response text, HTTP status, poll time, error
        self._raw_text: str = ""
        self._last_status: int = 0
        self._last_poll_iso: str = ""
        self._last_error: str = ""

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # --- lifecycle -----------------------------------------------------

    @Slot()
    def start(self):
        if not (self._app_key and self._api_key and self._mac):
            logger.warning(
                "EcowittClient has no credentials — tiles will stay empty. "
                "Configure Settings → Weather Station and restart."
            )
            return
        self._poll()
        self._timer.start()

    @Slot()
    def stop(self):
        self._timer.stop()

    # --- polling -------------------------------------------------------

    def _poll(self):
        params = {
            "application_key": self._app_key,
            "api_key":          self._api_key,
            "mac":              self._mac,
            "call_back":        "all",
            "temp_unitid":      "1",    # 1 = °F
            "pressure_unitid":  "3",    # 3 = inHg
            "wind_unitid":      "6",    # 6 = mph
            "rainfall_unitid": "12",    # 12 = in
            "solar_irradiance_unitid": "16",  # 16 = W/m²
        }
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        try:
            with httpx.Client(timeout=15.0) as client:
                r = client.get(self.CLOUD_URL, params=params)
                self._last_status = r.status_code
                self._raw_text    = r.text[:20000]   # cap at 20 KB for UI
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            err = str(e)
            logger.warning("Ecowitt cloud poll failed: %s", err)
            self._last_error = err
            self._set_connected(False)
            self.errorOccurred.emit(err)
            self.diagnosticsChanged.emit()
            return

        code = j.get("code")
        if code not in (0, "0"):
            msg = j.get("msg", "unknown error")
            logger.warning("Ecowitt API error code=%s msg=%s", code, msg)
            self._last_error = f"API code={code}: {msg}"
            self._set_connected(False)
            self.errorOccurred.emit(f"Ecowitt API: {msg}")
            self.diagnosticsChanged.emit()
            return

        data = j.get("data") or {}
        flat = self._flatten(data)
        if not flat:
            logger.warning("Ecowitt response had no recognized fields")
            self._last_error = "response parsed OK but no recognized fields"
            self._set_connected(False)
            self.diagnosticsChanged.emit()
            return

        self._latest     = flat
        self._last_error = ""
        self._set_connected(True)
        self.dataUpdated.emit(self._latest)
        self.diagnosticsChanged.emit()
        logger.info(
            "Ecowitt OK: tempf=%s humidity=%s keys=%d",
            flat.get("tempf"), flat.get("humidity"), len(flat),
        )

    # --- flattening ----------------------------------------------------

    @staticmethod
    def _leaf(d, *path):
        """Walk nested dict; return the leaf's `value` (or the leaf itself if
        it's already a scalar). Returns None if any path segment missing."""
        cur = d
        for p in path:
            if not isinstance(cur, dict):
                return None
            cur = cur.get(p)
            if cur is None:
                return None
        if isinstance(cur, dict):
            cur = cur.get("value")
        return cur

    @staticmethod
    def _num(v):
        if v in (None, ""):
            return None
        try:
            return float(v)
        except (TypeError, ValueError):
            return None

    @classmethod
    def _flatten(cls, data: dict) -> dict:
        """Map Ecowitt's nested cloud response to the Ambient flat schema."""
        def n(*path):
            return cls._num(cls._leaf(data, *path))

        out = {
            # --- outdoor ---
            "tempf":        n("outdoor", "temperature"),
            "feelsLike":    n("outdoor", "feels_like"),
            "dewPoint":     n("outdoor", "dew_point"),
            "humidity":     n("outdoor", "humidity"),

            # --- indoor ---
            "tempinf":      n("indoor", "temperature"),
            "humidityin":   n("indoor", "humidity"),

            # --- wind ---
            "windspeedmph":  n("wind", "wind_speed"),
            "windgustmph":   n("wind", "wind_gust"),
            "maxdailygust":  n("wind", "wind_gust_max") or n("wind", "max_daily_gust"),
            "winddir":       n("wind", "wind_direction"),

            # --- pressure ---
            "baromrelin":   n("pressure", "relative"),
            "baromabsin":   n("pressure", "absolute"),

            # --- rain ---
            "hourlyrainin":  n("rainfall", "hourly"),
            "eventrainin":   n("rainfall", "event"),
            "dailyrainin":   n("rainfall", "daily"),
            "weeklyrainin":  n("rainfall", "weekly"),
            "monthlyrainin": n("rainfall", "monthly"),
            "yearlyrainin":  n("rainfall", "yearly"),
            "totalrainin":   n("rainfall", "total"),

            # --- solar / UV ---
            "solarradiation": n("solar_and_uvi", "solar"),
            "uv":             n("solar_and_uvi", "uvi"),

            # --- lightning ---
            "lightning_day":      n("lightning", "count"),
            "lightning_hour":     n("lightning", "count_hour"),
            "lightning_distance": n("lightning", "distance"),

            # --- air quality (AQIN) ---
            "pm25":         n("pm25_ch1", "real_time_aqi") or n("pm25_ch1", "pm25"),
            "pm25_24h":     n("pm25_ch1", "24_hours_aqi"),
            "aqi_pm25":     n("pm25_ch1", "real_time_aqi"),
            "co2":          n("co2", "co2"),
            "co2_in_aqin":  n("indoor_co2", "co2"),
        }

        # Lightning timestamp (epoch seconds → ISO)
        ts = cls._leaf(data, "lightning", "timestamp")
        if ts:
            try:
                out["lightning_time"] = datetime.fromtimestamp(
                    int(float(ts)), tz=timezone.utc
                ).isoformat()
            except (TypeError, ValueError):
                pass

        # Batteries. Ecowitt convention: 0 = OK, 1+ = LOW (OPPOSITE of Ambient
        # which uses 1 = OK, 0 = low). Invert as we map.
        batt = data.get("battery") or {}
        for raw_key, raw_val in batt.items():
            if isinstance(raw_val, dict):
                raw_val = raw_val.get("value")
            n_val = cls._num(raw_val)
            if n_val is None:
                continue
            ambient_flag = 0 if n_val and n_val > 0 else 1   # invert
            # Keep the original Ecowitt key naming but prefix uniformly
            out[f"batt_{raw_key}"] = ambient_flag

        # Soil moisture / temp — Ecowitt uses soil_ch1..ch10 and soil_temp_ch1..ch10
        for i in range(1, 11):
            m = n(f"soil_ch{i}", "soilmoisture") or n(f"soil_ch{i}", "moisture")
            t = n(f"temp_and_humidity_ch{i}", "temperature") or n(f"soil_temp_ch{i}", "temperature")
            if m is not None:
                out[f"soilmoisture{i}"] = m
            if t is not None:
                out[f"soiltemp{i}"] = t

        # Leak detectors — ecowitt keys vary; best effort
        for i in range(1, 5):
            v = n(f"water_leak_ch{i}", "status") or n(f"leak_ch{i}", "status")
            if v is not None:
                out[f"leak{i}"] = int(v)

        # Drop None values so tiles' "undefined" checks behave correctly
        return {k: v for k, v in out.items() if v is not None}

    # --- properties for QML --------------------------------------------

    def _set_connected(self, value: bool):
        if self._connected != value:
            self._connected = value
            self.connectionChanged.emit(value)

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest

    @Property(bool, notify=connectionChanged)
    def connected(self):
        return self._connected

    # --- diagnostics for Settings > Weather Station > Debug section --

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
