from __future__ import annotations

import logging
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


class OpenMeteoClient(QObject):
    """Free forecast API — no key required. Polls every 30 minutes.

    Data shape emitted:
      {
        "lat": ..., "lon": ...,
        "current":   {temp, apparent, humidity, precip, weather_code, wind_speed, wind_dir, is_day},
        "daily":     [{date, hi, lo, pop_max, weather_code, sunrise, sunset}, ...],
        "hourly":    [{time, temp, weather_code, pop}, ...]   # next 24 hours
      }
    """

    dataUpdated = Signal("QVariant")
    errorOccurred = Signal(str)

    URL = "https://api.open-meteo.com/v1/forecast"
    POLL_MS = 30 * 60 * 1000

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._latest: dict = {}
        self._timer = QTimer(self)
        self._timer.setInterval(self.POLL_MS)
        self._timer.timeout.connect(self._poll)

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid:
            return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("Invalid grid square %r: %s", grid, e)
            self.errorOccurred.emit(f"Invalid grid: {e}")
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat = float(lat)
        self._lon = float(lon)
        logger.info("Forecast location set to %.4f, %.4f", self._lat, self._lon)
        self._poll()

    @Slot()
    def start(self):
        self._timer.start()
        if self._lat is not None:
            self._poll()

    @Slot()
    def stop(self):
        self._timer.stop()

    def _poll(self):
        if self._lat is None or self._lon is None:
            return
        params = {
            "latitude":  f"{self._lat:.4f}",
            "longitude": f"{self._lon:.4f}",
            "current": ",".join([
                "temperature_2m", "apparent_temperature", "relative_humidity_2m",
                "precipitation", "weather_code", "wind_speed_10m",
                "wind_direction_10m", "is_day",
            ]),
            "hourly": ",".join([
                "temperature_2m", "weather_code", "precipitation_probability",
            ]),
            "daily": ",".join([
                "temperature_2m_max", "temperature_2m_min",
                "precipitation_probability_max", "weather_code",
                "sunrise", "sunset",
            ]),
            "timezone": "auto",
            "forecast_days": 10,
            "forecast_hours": 24,
            "temperature_unit": "fahrenheit",
            "wind_speed_unit": "mph",
            "precipitation_unit": "inch",
        }
        try:
            with httpx.Client(timeout=15.0) as client:
                r = client.get(self.URL, params=params)
                r.raise_for_status()
                j = r.json()
        except Exception as e:
            logger.warning("Open-Meteo poll failed: %s", e)
            self.errorOccurred.emit(str(e))
            return

        parsed = self._parse(j)
        parsed["lat"] = self._lat
        parsed["lon"] = self._lon
        self._latest = parsed
        logger.info(
            "Open-Meteo OK: cur_temp=%s, days=%d",
            (parsed.get("current") or {}).get("temp"),
            len(parsed.get("daily") or []),
        )
        self.dataUpdated.emit(self._latest)

    @staticmethod
    def _parse(j: dict) -> dict:
        cur = j.get("current") or {}
        current = {
            "temp":         cur.get("temperature_2m"),
            "apparent":     cur.get("apparent_temperature"),
            "humidity":     cur.get("relative_humidity_2m"),
            "precip":       cur.get("precipitation"),
            "weather_code": cur.get("weather_code"),
            "wind_speed":   cur.get("wind_speed_10m"),
            "wind_dir":     cur.get("wind_direction_10m"),
            "is_day":       cur.get("is_day"),
            "time":         cur.get("time"),
        }

        dly = j.get("daily") or {}
        daily = []
        times = dly.get("time") or []
        for i in range(len(times)):
            daily.append({
                "date":         times[i],
                "hi":           (dly.get("temperature_2m_max") or [None])[i] if i < len(dly.get("temperature_2m_max") or []) else None,
                "lo":           (dly.get("temperature_2m_min") or [None])[i] if i < len(dly.get("temperature_2m_min") or []) else None,
                "pop_max":      (dly.get("precipitation_probability_max") or [None])[i] if i < len(dly.get("precipitation_probability_max") or []) else None,
                "weather_code": (dly.get("weather_code") or [None])[i] if i < len(dly.get("weather_code") or []) else None,
                "sunrise":      (dly.get("sunrise") or [None])[i] if i < len(dly.get("sunrise") or []) else None,
                "sunset":       (dly.get("sunset") or [None])[i] if i < len(dly.get("sunset") or []) else None,
            })

        hly = j.get("hourly") or {}
        hourly = []
        htimes = hly.get("time") or []
        for i in range(len(htimes)):
            hourly.append({
                "time":         htimes[i],
                "temp":         (hly.get("temperature_2m") or [None])[i] if i < len(hly.get("temperature_2m") or []) else None,
                "weather_code": (hly.get("weather_code") or [None])[i] if i < len(hly.get("weather_code") or []) else None,
                "pop":          (hly.get("precipitation_probability") or [None])[i] if i < len(hly.get("precipitation_probability") or []) else None,
            })

        return {"current": current, "daily": daily, "hourly": hourly}

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest
