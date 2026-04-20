from __future__ import annotations


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
