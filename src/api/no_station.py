"""Station-less mode: pull live weather from Open-Meteo + free public APIs.

When the user doesn't own a physical weather station, this client populates
the same tiles AmbientClient / EcowittClient would, pulling:

    - Open-Meteo ``/v1/forecast``  —  current temp, humidity, wind, pressure,
      dew point, precipitation, UV index, solar radiation (shortwave).
    - (future) Blitzortung.org regional JSON  —  lightning strikes filtered
      by distance from the user's grid square.
    - (future) NWS alerts  —  active watches/warnings feeding the Alerts tile.

Output uses the same flat Ambient-compatible schema every tile consumes, so
no tile changes are needed.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


class NoStationClient(QObject):
    """Surface-compatible with AmbientClient — exposes ``start``, ``stop``,
    ``dataUpdated``, ``connected``, ``latest``, plus the diagnostics bundle."""

    dataUpdated        = Signal("QVariant")
    connectionChanged  = Signal(bool)
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()
    # Stub to match AmbientClient's interface. None mode has no station
    # and therefore no history; this signal is declared but never fires,
    # so sparklines and history-derived fields naturally hide.
    historyUpdated     = Signal("QVariant")

    URL     = "https://api.open-meteo.com/v1/forecast"
    POLL_MS = 5 * 60 * 1000   # 5 minutes

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._latest: dict = {}
        self._connected = False
        self._raw_text: str = ""
        self._last_status: int = 0
        self._last_poll_iso: str = ""
        self._last_error: str = ""

        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    # ----- lifecycle ---------------------------------------------------

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid:
            return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("Invalid grid for no-station mode: %s", e)
            self._last_error = f"Invalid grid: {e}"
            self.diagnosticsChanged.emit()
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat, self._lon = float(lat), float(lon)
        logger.info("No-station location set to %.4f, %.4f", self._lat, self._lon)
        QTimer.singleShot(0, self._poll)

    @Slot()
    def start(self):
        if self._lat is None or self._lon is None:
            logger.warning(
                "NoStationClient has no grid square yet — set one in "
                "Settings → Operator so Open-Meteo has a location."
            )
        else:
            QTimer.singleShot(0, self._poll)
        self._timer.start()

    @Slot()
    def stop(self):
        self._timer.stop()

    # ----- polling -----------------------------------------------------

    def _poll(self):
        if self._lat is None or self._lon is None:
            return
        params = {
            "latitude":  f"{self._lat:.4f}",
            "longitude": f"{self._lon:.4f}",
            "current": ",".join([
                "temperature_2m",
                "apparent_temperature",
                "relative_humidity_2m",
                "dew_point_2m",
                "precipitation",
                "rain",
                "weather_code",
                "wind_speed_10m",
                "wind_direction_10m",
                "wind_gusts_10m",
                "pressure_msl",
                "surface_pressure",
                "is_day",
            ]),
            # Hourly gives us the current hour's UV index + solar radiation,
            # which Open-Meteo doesn't expose in the `current` block.
            "hourly": ",".join([
                "uv_index",
                "shortwave_radiation",
            ]),
            # Daily precipitation_sum lets us surface a real "rain today"
            # value in the Rain tile (otherwise None mode shows 0.00 all
            # day until the current hour has rain).
            "daily": "precipitation_sum",
            "forecast_hours":   2,    # just current hour (and one ahead for safety)
            "forecast_days":    1,    # just today for daily rollup
            "timezone":         "auto",
            "temperature_unit": "fahrenheit",
            "wind_speed_unit":  "mph",
            "precipitation_unit": "inch",
        }
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        try:
            with httpx.Client(timeout=15.0) as client:
                r = client.get(self.URL, params=params)
                self._last_status = r.status_code
                self._raw_text    = r.text[:20000]
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            err = str(e)
            logger.warning("No-station (Open-Meteo) poll failed: %s", err)
            self._last_error = err
            self._set_connected(False)
            self.errorOccurred.emit(err)
            self.diagnosticsChanged.emit()
            return

        flat = self._flatten(j)
        self._latest     = flat
        self._last_error = ""
        self._set_connected(True)
        self.dataUpdated.emit(self._latest)
        self.diagnosticsChanged.emit()
        logger.info(
            "No-station OK: tempf=%s humidity=%s keys=%d",
            flat.get("tempf"), flat.get("humidity"), len(flat),
        )

    # ----- field mapping ----------------------------------------------

    @staticmethod
    def _hpa_to_inhg(hpa):
        if hpa is None:
            return None
        try:
            return float(hpa) * 0.02953
        except (TypeError, ValueError):
            return None

    @classmethod
    def _flatten(cls, j: dict) -> dict:
        cur  = (j.get("current") or {})
        hrly = (j.get("hourly")  or {})
        dly  = (j.get("daily")   or {})

        # pick the value at the current-hour index from the hourly arrays
        now_iso = (cur.get("time") or "")
        times   = hrly.get("time") or []
        idx     = times.index(now_iso) if now_iso in times else 0
        def hour(field):
            vals = hrly.get(field) or []
            if 0 <= idx < len(vals):
                return vals[idx]
            return None

        # Daily precipitation_sum — index 0 is today (we asked for forecast_days=1).
        daily_precip = None
        _dp = dly.get("precipitation_sum") or []
        if isinstance(_dp, list) and _dp:
            daily_precip = _dp[0]

        out = {
            # outdoor
            "tempf":       cur.get("temperature_2m"),
            "feelsLike":   cur.get("apparent_temperature"),
            "dewPoint":    cur.get("dew_point_2m"),
            "humidity":    cur.get("relative_humidity_2m"),

            # wind
            "windspeedmph": cur.get("wind_speed_10m"),
            "windgustmph":  cur.get("wind_gusts_10m"),
            "winddir":      cur.get("wind_direction_10m"),

            # pressure — Ambient uses inHg, Open-Meteo returns hPa
            "baromrelin":   cls._hpa_to_inhg(cur.get("pressure_msl")),
            "baromabsin":   cls._hpa_to_inhg(cur.get("surface_pressure")),

            # rain — Open-Meteo's "precipitation" is the current hour total;
            # daily comes from the daily.precipitation_sum rollup. No
            # concept of "event total" (since-start-of-rain) online —
            # RainTile.qml hides the EVENT column in None mode.
            "hourlyrainin": cur.get("rain") or cur.get("precipitation"),
            "dailyrainin":  daily_precip,

            # solar + UV (from hourly)
            "solarradiation": hour("shortwave_radiation"),
            "uv":             hour("uv_index"),

            # Source marker for tooling — keeps tiles honest about origin.
            "__source": "open-meteo",
            "__is_day": cur.get("is_day"),
        }
        return {k: v for k, v in out.items() if v is not None}

    # ----- connection + QML surface ----------------------------------

    def _set_connected(self, v: bool):
        if self._connected != v:
            self._connected = v
            self.connectionChanged.emit(v)

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest

    @Property(bool, notify=connectionChanged)
    def connected(self):
        return self._connected

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
        try:
            return json.dumps(self._latest, indent=2, sort_keys=True)
        except Exception:
            return str(self._latest)
