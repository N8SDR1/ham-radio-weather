"""Blitzortung.org public strike feed adapter for None-mode lightning.

Polls Blitzortung's regional strike endpoints, filters by haversine distance
from the user's location, deduplicates by timestamp, and exposes a rolling
1-hour / 24-hour count plus the nearest recent strike. Output fields match
the Ambient ``lightning_*`` schema so LightningTile consumes it unchanged.

This client is relevant only in stationType == "none" — when a user has a
physical Ambient/Ecowitt station, that station's own sensor reports strikes
directly without needing aggregated network data.
"""

from __future__ import annotations

import logging
import math
from collections import deque
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in kilometers."""
    lat1r, lon1r, lat2r, lon2r = map(math.radians, (lat1, lon1, lat2, lon2))
    dlat = lat2r - lat1r
    dlon = lon2r - lon1r
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1r) * math.cos(lat2r) * math.sin(dlon / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(a))


def _km_to_mi(km: float) -> float:
    return km * 0.621371


class BlitzortungClient(QObject):
    """Polls Blitzortung regional strike feeds and emits lightning_* fields."""

    dataUpdated        = Signal("QVariant")   # {lightning_day, lightning_hour, lightning_distance, lightning_time}
    errorOccurred      = Signal(str)
    diagnosticsChanged = Signal()

    URL_TEMPLATE = "https://map.blitzortung.org/GEOjson/getjson.php?f=s&n={region:02d}"
    POLL_MS      = 30_000   # 30 s — Blitzortung updates strike data frequently

    # Region 1 Europe, 2 Oceania, 4 East Asia, 6 South America,
    # 7 Central Americas, 12 East Americas, 13 West Americas.
    # Default covers the contiguous US + Canada; advanced users can override.
    DEFAULT_REGIONS = (7, 12, 13)

    # Keep strikes in memory for 24 h so we can compute rolling counts.
    HISTORY_HOURS = 24

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._radius_km: float = 160.9  # ~100 mi default
        self._regions: tuple[int, ...] = self.DEFAULT_REGIONS
        self._strikes: deque = deque(maxlen=5000)   # (timestamp_utc, lat, lon, dist_km)
        self._latest: dict = {}
        self._last_poll_iso: str = ""
        self._last_error: str = ""

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
            logger.warning("Blitzortung: invalid grid: %s", e)
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat = float(lat)
        self._lon = float(lon)
        logger.info("Blitzortung location set to %.4f, %.4f", self._lat, self._lon)
        # recompute distances against existing cache
        self._recompute_stats()

    @Slot(float)
    def setRadiusKm(self, km: float):
        km = max(1.0, float(km))
        if abs(km - self._radius_km) < 0.1:
            return
        self._radius_km = km
        logger.info("Blitzortung radius set to %.1f km (%.0f mi)", km, _km_to_mi(km))
        self._recompute_stats()

    @Slot(str)
    def setRegions(self, csv: str):
        """e.g. '7,12,13'.  Resets to defaults on empty string."""
        try:
            regs = tuple(int(x.strip()) for x in (csv or "").split(",") if x.strip())
            self._regions = regs or self.DEFAULT_REGIONS
        except Exception:
            self._regions = self.DEFAULT_REGIONS
        logger.info("Blitzortung regions: %s", self._regions)

    # --- lifecycle -----------------------------------------------------

    @Slot()
    def start(self):
        QTimer.singleShot(0, self._poll)
        self._timer.start()

    @Slot()
    def stop(self):
        self._timer.stop()

    # --- polling -------------------------------------------------------

    def _poll(self):
        if self._lat is None or self._lon is None:
            return
        self._last_poll_iso = datetime.now(timezone.utc).isoformat()
        headers = {
            "User-Agent": "ham-radio-weather/1.0 (N8SDR)",
            "Accept": "application/json, text/plain, */*",
        }
        cutoff = datetime.now(timezone.utc) - timedelta(hours=self.HISTORY_HOURS)
        any_ok = False
        try:
            with httpx.Client(timeout=10.0, headers=headers) as client:
                for region in self._regions:
                    try:
                        r = client.get(self.URL_TEMPLATE.format(region=region))
                        r.raise_for_status()
                        rows = r.json()
                    except Exception as e:
                        logger.debug("Blitzortung region %d failed: %s", region, e)
                        continue
                    any_ok = True
                    for row in rows:
                        # Each row is an array; layout varies slightly by version.
                        # First three fields are reliably [lon, lat, time_iso].
                        if not isinstance(row, list) or len(row) < 3:
                            continue
                        try:
                            lon = float(row[0])
                            lat = float(row[1])
                            ts_raw = row[2]
                        except (TypeError, ValueError):
                            continue

                        ts = self._parse_ts(ts_raw)
                        if ts is None or ts < cutoff:
                            continue

                        dist_km = _haversine_km(self._lat, self._lon, lat, lon)
                        if dist_km > self._radius_km:
                            continue

                        # dedupe by timestamp + coords (2dp rounding)
                        key = (ts.replace(microsecond=0).isoformat(),
                               round(lat, 2), round(lon, 2))
                        if any(s[4] == key for s in self._strikes):
                            continue
                        self._strikes.append((ts, lat, lon, dist_km, key))
        except Exception as e:
            logger.warning("Blitzortung poll error: %s", e)
            self._last_error = str(e)
            self.errorOccurred.emit(str(e))
            self.diagnosticsChanged.emit()
            return

        if not any_ok:
            self._last_error = "no Blitzortung regions responded"
            self.diagnosticsChanged.emit()
            return

        self._last_error = ""
        # age out old strikes
        while self._strikes and self._strikes[0][0] < cutoff:
            self._strikes.popleft()

        self._recompute_stats()
        self.diagnosticsChanged.emit()

    # --- aggregation --------------------------------------------------

    def _recompute_stats(self):
        if self._lat is None or self._lon is None:
            return
        now = datetime.now(timezone.utc)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        hour_start  = now - timedelta(hours=1)

        day_count  = 0
        hour_count = 0
        nearest: Optional[tuple] = None

        for ts, lat, lon, dist_km, _key in self._strikes:
            if ts >= today_start:
                day_count += 1
            if ts >= hour_start:
                hour_count += 1
            if nearest is None or dist_km < nearest[3]:
                nearest = (ts, lat, lon, dist_km)

        out = {
            "lightning_day":  day_count,
            "lightning_hour": hour_count,
        }
        if nearest is not None:
            out["lightning_distance"] = round(_km_to_mi(nearest[3]), 1)  # Ambient schema is mi
            out["lightning_time"]     = nearest[0].isoformat()

        self._latest = out
        self.dataUpdated.emit(out)
        logger.info(
            "Blitzortung: %d strikes last 24h, %d in last hour, radius=%.0f km",
            day_count, hour_count, self._radius_km,
        )

    @staticmethod
    def _parse_ts(raw) -> Optional[datetime]:
        """Accept ISO string, Unix seconds, or nanosecond-scale integers."""
        try:
            if isinstance(raw, (int, float)):
                v = float(raw)
                # Blitzortung sometimes returns nanoseconds since epoch
                if v > 1e14:
                    v /= 1e9
                elif v > 1e11:
                    v /= 1e3
                return datetime.fromtimestamp(v, tz=timezone.utc)
            s = str(raw).strip()
            if s.endswith("Z"):
                s = s[:-1] + "+00:00"
            try:
                return datetime.fromisoformat(s)
            except ValueError:
                return datetime.fromtimestamp(float(s), tz=timezone.utc)
        except Exception:
            return None

    # --- QML surface --------------------------------------------------

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest

    @Property(str, notify=diagnosticsChanged)
    def lastPollIso(self):
        return self._last_poll_iso

    @Property(str, notify=diagnosticsChanged)
    def lastError(self):
        return self._last_error

    @Property(float, constant=True)
    def radiusKm(self):
        return self._radius_km
