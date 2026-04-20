from __future__ import annotations

# --- Rough country / region bbox detection for auto-picking alert providers.
# Order matters (first match wins), so narrower / higher-priority regions come
# before broader ones. Bounds: (minLat, maxLat, minLon, maxLon).
_REGION_BBOXES = [
    # United States (contiguous + Alaska + Hawaii + PR/VI)
    ("nws", (24.0, 50.0, -125.0, -66.0)),    # contiguous
    ("nws", (51.0, 72.0, -180.0, -129.0)),   # Alaska
    ("nws", (18.0, 23.0, -161.0, -154.0)),   # Hawaii
    ("nws", (17.5, 18.7,  -67.5,  -64.5)),   # Puerto Rico / USVI
    # Canada (after US so US bits win)
    ("ec",  (41.5, 84.0, -141.0, -52.0)),
    # Europe + UK
    ("meteoalarm", (34.0, 72.0, -11.0, 45.0)),
    # Australia / NZ
    ("bom", (-44.0, -10.0, 112.0, 154.0)),
]

# MeteoAlarm country slugs; used for per-country ATOM feed URLs.
# Keys are ISO-2 lower-case; values are MeteoAlarm slug.
METEOALARM_COUNTRIES = {
    "at": "austria",         "be": "belgium",         "bg": "bulgaria",
    "hr": "croatia",         "cy": "cyprus",          "cz": "czech-republic",
    "dk": "denmark",         "ee": "estonia",         "fi": "finland",
    "fr": "france",          "de": "germany",         "gr": "greece",
    "hu": "hungary",         "is": "iceland",         "ie": "ireland",
    "il": "israel",          "it": "italy",           "lv": "latvia",
    "lt": "lithuania",       "lu": "luxembourg",      "mt": "malta",
    "md": "moldova",         "me": "montenegro",      "nl": "netherlands",
    "mk": "north-macedonia", "no": "norway",          "pl": "poland",
    "pt": "portugal",        "ro": "romania",         "rs": "serbia",
    "sk": "slovakia",        "si": "slovenia",        "es": "spain",
    "se": "sweden",          "ch": "switzerland",     "gb": "united-kingdom",
}

# Very rough country-bbox table for MeteoAlarm auto-pick.
_EU_COUNTRY_BBOXES = [
    ("united-kingdom", (49.0, 61.0,  -8.5,   2.0)),
    ("ireland",        (51.0, 55.5, -10.7,  -5.3)),
    ("iceland",        (62.5, 67.5, -25.0, -13.0)),
    ("germany",        (47.0, 55.2,   5.5,  15.1)),
    ("france",         (41.0, 51.5,  -5.5,   9.8)),
    ("spain",          (35.5, 44.5,  -9.4,   4.3)),
    ("portugal",       (36.8, 42.2, -10.0,  -6.0)),
    ("italy",          (35.5, 47.3,   6.5,  18.6)),
    ("netherlands",    (50.6, 53.8,   3.2,   7.3)),
    ("belgium",        (49.5, 51.6,   2.5,   6.5)),
    ("switzerland",    (45.8, 47.9,   5.9,  10.5)),
    ("austria",        (46.4, 49.1,   9.5,  17.2)),
    ("poland",         (49.0, 55.0,  14.1,  24.2)),
    ("czech-republic", (48.5, 51.1,  12.0,  18.9)),
    ("norway",         (57.9, 71.2,   4.4,  31.2)),
    ("sweden",         (55.3, 69.1,  10.9,  24.2)),
    ("finland",        (59.8, 70.1,  20.5,  31.6)),
    ("denmark",        (54.5, 57.8,   8.0,  15.2)),
    ("greece",         (34.8, 41.8,  19.3,  28.3)),
    ("hungary",        (45.7, 48.6,  16.1,  22.9)),
    ("romania",        (43.6, 48.3,  20.3,  29.7)),
    ("bulgaria",       (41.2, 44.2,  22.4,  28.6)),
    ("croatia",        (42.4, 46.6,  13.5,  19.4)),
    ("slovakia",       (47.7, 49.6,  16.8,  22.6)),
    ("slovenia",       (45.4, 46.9,  13.4,  16.6)),
    ("serbia",         (42.2, 46.2,  18.8,  23.0)),
    ("estonia",        (57.5, 59.7,  21.8,  28.2)),
    ("latvia",         (55.7, 58.1,  20.9,  28.2)),
    ("lithuania",      (53.9, 56.5,  20.9,  26.8)),
    ("cyprus",         (34.6, 35.7,  32.3,  34.6)),
    ("malta",          (35.8, 36.1,  14.1,  14.6)),
    ("luxembourg",     (49.4, 50.2,   5.7,   6.5)),
    ("israel",         (29.4, 33.4,  34.2,  35.9)),
]

# Australian state bboxes for BoM.
_AU_STATE_BBOXES = [
    ("wa",  (-35.5, -13.7, 112.0, 129.0)),   # Western Australia
    ("nt",  (-26.0, -10.8, 129.0, 138.0)),   # Northern Territory
    ("sa",  (-38.1, -26.0, 129.0, 141.0)),   # South Australia
    ("qld", (-29.2, -10.6, 138.0, 154.0)),   # Queensland
    ("nsw", (-37.5, -28.1, 140.9, 153.7)),   # New South Wales
    ("vic", (-39.2, -34.0, 140.9, 150.0)),   # Victoria
    ("tas", (-44.0, -39.5, 143.8, 148.5)),   # Tasmania
    ("act", (-35.9, -35.1, 148.8, 149.4)),   # ACT
]


def detect_region(lat: float, lon: float) -> str:
    """Pick a default alerts-provider id from coordinates.  Returns one of
    'nws', 'ec', 'meteoalarm', 'bom', or 'off' if no region matches."""
    for provider, (lo_lat, hi_lat, lo_lon, hi_lon) in _REGION_BBOXES:
        if lo_lat <= lat <= hi_lat and lo_lon <= lon <= hi_lon:
            return provider
    return "off"


def detect_eu_country(lat: float, lon: float) -> str:
    """For MeteoAlarm: auto-pick a country slug. Empty string if none."""
    for slug, (lo_lat, hi_lat, lo_lon, hi_lon) in _EU_COUNTRY_BBOXES:
        if lo_lat <= lat <= hi_lat and lo_lon <= lon <= hi_lon:
            return slug
    return ""


def detect_au_state(lat: float, lon: float) -> str:
    """For BoM: auto-pick an Australian state code. Empty string if none."""
    for code, (lo_lat, hi_lat, lo_lon, hi_lon) in _AU_STATE_BBOXES:
        if lo_lat <= lat <= hi_lat and lo_lon <= lon <= hi_lon:
            return code
    return ""


def maidenhead_to_latlon(grid: str) -> tuple[float, float]:
    """Convert a 4- or 6-character Maidenhead locator to (lat, lon) in degrees.

    Returns the center of the reported precision cell.
    Raises ValueError on malformed input.
    """
    g = (grid or "").strip()
    if len(g) < 4:
        raise ValueError("grid must be at least 4 characters (e.g. 'EN80')")

    field = g[0:2].upper()
    square = g[2:4]
    if not (field[0].isalpha() and field[1].isalpha()):
        raise ValueError("first two chars must be letters A-R")
    if not (square[0].isdigit() and square[1].isdigit()):
        raise ValueError("chars 3-4 must be digits 0-9")

    lon = (ord(field[0]) - ord("A")) * 20 - 180
    lat = (ord(field[1]) - ord("A")) * 10 - 90
    lon += int(square[0]) * 2
    lat += int(square[1]) * 1

    if len(g) >= 6:
        sub = g[4:6].lower()
        if not (sub[0].isalpha() and sub[1].isalpha()):
            raise ValueError("chars 5-6 must be letters a-x")
        lon += (ord(sub[0]) - ord("a")) * (5 / 60)
        lat += (ord(sub[1]) - ord("a")) * (2.5 / 60)
        lon += 2.5 / 60
        lat += 1.25 / 60
    else:
        lon += 1.0
        lat += 0.5

    return lat, lon
