from __future__ import annotations

import logging
import math
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
from sgp4.api import Satrec, jday

from api.geo import maidenhead_to_latlon

logger = logging.getLogger(__name__)


# ----- coordinate / geometry helpers -----

_WGS84_A = 6378.137   # km
_WGS84_F = 1 / 298.257223563


def _gmst_rad(jd: float) -> float:
    """Greenwich Mean Sidereal Time in radians for UT1 Julian date."""
    T = (jd - 2451545.0) / 36525.0
    deg = 280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * T * T
    return math.radians(deg % 360.0)


def _eci_to_ecef(r_eci, gmst: float):
    x, y, z = r_eci
    c, s = math.cos(gmst), math.sin(gmst)
    return (c * x + s * y, -s * x + c * y, z)


def _observer_ecef(lat_deg: float, lon_deg: float, alt_m: float = 0.0):
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    sin_lat = math.sin(lat)
    e2 = _WGS84_F * (2 - _WGS84_F)
    N = _WGS84_A / math.sqrt(1 - e2 * sin_lat * sin_lat)
    x = (N + alt_m / 1000.0) * math.cos(lat) * math.cos(lon)
    y = (N + alt_m / 1000.0) * math.cos(lat) * math.sin(lon)
    z = (N * (1 - e2) + alt_m / 1000.0) * sin_lat
    return (x, y, z)


def _az_el(sat_ecef, obs_ecef, lat_deg: float, lon_deg: float):
    dx = sat_ecef[0] - obs_ecef[0]
    dy = sat_ecef[1] - obs_ecef[1]
    dz = sat_ecef[2] - obs_ecef[2]
    lat = math.radians(lat_deg)
    lon = math.radians(lon_deg)
    sin_lat, cos_lat = math.sin(lat), math.cos(lat)
    sin_lon, cos_lon = math.sin(lon), math.cos(lon)
    east  = -sin_lon * dx + cos_lon * dy
    north = -sin_lat * cos_lon * dx - sin_lat * sin_lon * dy + cos_lat * dz
    up    =  cos_lat * cos_lon * dx + cos_lat * sin_lon * dy + sin_lat * dz
    horiz = math.hypot(east, north)
    el = math.degrees(math.atan2(up, horiz))
    az = math.degrees(math.atan2(east, north)) % 360.0
    return az, el


def _el_az_for_sat(sat: Satrec, lat: float, lon: float, dt: datetime):
    jd, fr = jday(dt.year, dt.month, dt.day,
                  dt.hour, dt.minute, dt.second + dt.microsecond / 1e6)
    err, r, _v = sat.sgp4(jd, fr)
    if err != 0:
        return (0.0, -90.0)
    gmst = _gmst_rad(jd + fr)
    sat_ecef = _eci_to_ecef(r, gmst)
    obs = _observer_ecef(lat, lon)
    return _az_el(sat_ecef, obs, lat, lon)


def _compass(deg: float) -> str:
    names = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
             "S","SSW","SW","WSW","W","WNW","NW","NNW"]
    return names[round((deg % 360) / 22.5) % 16]


def _next_pass(sat: Satrec, lat: float, lon: float,
               start: datetime, hours: int = 24):
    """Step-scan 1-minute cadence for the next pass. Returns dict or None."""
    step = timedelta(minutes=1)
    end = start + timedelta(hours=hours)

    t = start
    prev_el = None
    aos = None
    aos_az = 0.0
    max_el = -90.0
    max_el_t = None
    max_el_az = 0.0

    while t < end:
        az, el = _el_az_for_sat(sat, lat, lon, t)
        if prev_el is not None:
            if aos is None and prev_el < 0 and el >= 0:
                aos = t
                aos_az = az
                max_el = el
                max_el_t = t
                max_el_az = az
            elif aos is not None:
                if el > max_el:
                    max_el = el
                    max_el_t = t
                    max_el_az = az
                if prev_el >= 0 and el < 0:
                    return {
                        "aos": aos.isoformat(),
                        "los": t.isoformat(),
                        "duration_s": int((t - aos).total_seconds()),
                        "max_el": round(max_el, 1),
                        "max_el_t": max_el_t.isoformat() if max_el_t else None,
                        "aos_az": round(aos_az, 0),
                        "los_az": round(az, 0),
                        "aos_dir": _compass(aos_az),
                        "los_dir": _compass(az),
                        "max_el_dir": _compass(max_el_az),
                    }
        prev_el = el
        t += step
    return None


# ----- client -----

class SatellitesClient(QObject):
    """Fetches amateur-satellite TLEs from Celestrak and predicts upcoming passes."""

    dataUpdated   = Signal("QVariant")
    errorOccurred = Signal(str)

    TLE_URL = "https://celestrak.org/NORAD/elements/gp.php?GROUP=amateur&FORMAT=tle"
    TLE_TTL_MS  = 6 * 3600 * 1000   # refresh TLE every 6 hours
    COMPUTE_MS  = 2 * 60 * 1000     # recompute passes every 2 minutes

    # Default set — mirrors SatelliteCatalog.qml's default-enabled list.
    # Matched to the active amateur birds shown in CSN Technologies S.A.T.
    # Removed deorbited sats: PO-101 (Diwata-2), TEVEL 1-8.
    DEFAULT_TRACKED = [
        "ISS (ZARYA)",
        "AO-7",
        "AO-27",
        "AO-73",
        "AO-123",
        "FO-29",
        "SO-50",
        "RS-44",
        "HADES-ICM",
        "HADES-SA",
        "IO-86",
        "JO-97",
        "NANOZOND-1",
    ]

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._lat: Optional[float] = None
        self._lon: Optional[float] = None
        self._tles: dict[str, tuple[str, str]] = {}
        self._latest: dict = {}
        self._tracked: list[str] = list(self.DEFAULT_TRACKED)

        self._tle_timer = QTimer(self)
        self._tle_timer.setInterval(self.TLE_TTL_MS)
        self._tle_timer.timeout.connect(self._fetch_tle)

        self._compute_timer = QTimer(self)
        self._compute_timer.setInterval(self.COMPUTE_MS)
        self._compute_timer.timeout.connect(self._compute)

    @Slot(list)
    def setTrackedList(self, names):
        """Set which satellites to track. Empty list falls back to defaults."""
        new_list = [str(n) for n in (names or []) if n]
        if not new_list:
            new_list = list(self.DEFAULT_TRACKED)
        if new_list == self._tracked:
            return
        self._tracked = new_list
        logger.info("Tracking %d satellites: %s", len(new_list), ", ".join(new_list))
        self._compute()

    @Slot(str)
    def setGridSquare(self, grid: str):
        if not grid:
            return
        try:
            lat, lon = maidenhead_to_latlon(grid)
        except Exception as e:
            logger.warning("Invalid grid for satellites: %s", e)
            self.errorOccurred.emit(f"Invalid grid: {e}")
            return
        self.setLocation(lat, lon)

    @Slot(float, float)
    def setLocation(self, lat: float, lon: float):
        if (lat, lon) == (self._lat, self._lon):
            return
        self._lat = float(lat)
        self._lon = float(lon)
        logger.info("Satellite location set to %.4f, %.4f", self._lat, self._lon)
        self._compute()

    @Slot()
    def start(self):
        self._fetch_tle()
        self._tle_timer.start()
        self._compute_timer.start()

    @Slot()
    def stop(self):
        self._tle_timer.stop()
        self._compute_timer.stop()

    def _fetch_tle(self):
        try:
            with httpx.Client(timeout=15.0) as c:
                r = c.get(self.TLE_URL)
                r.raise_for_status()
                self._parse_tle(r.text)
                logger.info("TLE fetched: %d satellites", len(self._tles))
        except Exception as e:
            logger.warning("TLE fetch failed: %s", e)
            self.errorOccurred.emit(f"TLE fetch: {e}")
        self._compute()

    def _parse_tle(self, text: str):
        lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
        tles: dict[str, tuple[str, str]] = {}
        i = 0
        while i < len(lines) - 2:
            name = lines[i].strip()
            l1 = lines[i + 1]
            l2 = lines[i + 2]
            if l1.startswith("1 ") and l2.startswith("2 "):
                tles[name] = (l1, l2)
                i += 3
            else:
                i += 1
        self._tles = tles

    def _find_tle(self, wanted: str):
        """Locate a TLE by a loose name match.

        Tries in order: exact key, exact case-insensitive, prefix match
        (``NAME (...)`` or ``NAME ...``), then a word-boundary substring so
        ``AO-7`` doesn't accidentally match ``AO-73``.
        """
        if not wanted:
            return None
        if wanted in self._tles:
            return self._tles[wanted]

        import re
        u = wanted.upper().strip()

        # 1) exact case-insensitive
        for k, v in self._tles.items():
            if k.upper() == u:
                return v

        # 2) Celestrak often uses "NAME (DESIGNATION)" or "NAME - DESIGNATION"
        for k, v in self._tles.items():
            up = k.upper()
            if up.startswith(u + " ") or up.startswith(u + "(") or up.startswith(u + "-"):
                return v

        # 3) Word-boundary substring (prevents AO-7 -> AO-73 collision)
        pat = re.compile(r"(?<![A-Z0-9])" + re.escape(u) + r"(?![A-Z0-9])")
        for k, v in self._tles.items():
            if pat.search(k.upper()):
                return v
        return None

    def _compute(self):
        if self._lat is None or self._lon is None or not self._tles:
            self._latest = {"passes": [], "now": datetime.now(timezone.utc).isoformat()}
            self.dataUpdated.emit(self._latest)
            return

        now = datetime.now(timezone.utc)
        passes = []
        for name in self._tracked:
            tle = self._find_tle(name)
            if not tle:
                continue
            try:
                sat = Satrec.twoline2rv(tle[0], tle[1])
            except Exception as e:
                logger.warning("TLE parse fail for %s: %s", name, e)
                continue

            # current elevation — is it overhead right now?
            az_now, el_now = _el_az_for_sat(sat, self._lat, self._lon, now)
            currently_up = el_now > 0

            p = _next_pass(sat, self._lat, self._lon, now)
            if p:
                p["name"] = name
                p["currently_up"] = currently_up
                p["current_el"]   = round(el_now, 1)
                p["current_az"]   = round(az_now, 0)
                passes.append(p)

        passes.sort(key=lambda x: x["aos"])
        self._latest = {"passes": passes, "now": now.isoformat()}
        self.dataUpdated.emit(self._latest)

    @Property("QVariant", notify=dataUpdated)
    def latest(self):
        return self._latest
