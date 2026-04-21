r"""Generate docs/HamRadioWeather-OnePager.pdf — single-page flyer.

Run from the project root (venv activated):
    python tools\make_onepager_pdf.py
"""

from __future__ import annotations

from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate,
    Paragraph, Spacer, Table, TableStyle, Image,
)

# ----------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_PATH     = PROJECT_ROOT / "docs" / "HamRadioWeather-OnePager.pdf"
LOGO_PATH    = PROJECT_ROOT / "assets" / "wxham_clean.png"
if not LOGO_PATH.exists():
    LOGO_PATH = PROJECT_ROOT / "assets" / "wxham.png"

APP_VERSION = "1.0.9"

# Palette (same as the multi-page doc so branding stays consistent)
ACCENT   = colors.HexColor("#3b82f6")
ACCENT2  = colors.HexColor("#8b5cf6")
INK      = colors.HexColor("#0f172a")
MUTED    = colors.HexColor("#475569")
PAPER    = colors.white
RULE     = colors.HexColor("#cbd5e1")
TINT     = colors.HexColor("#eff6ff")

# ----------------------------------------------------------------------
# Styles — smaller than the multi-page doc to fit everything on one page
# ----------------------------------------------------------------------
_base = getSampleStyleSheet()

S_TITLE = ParagraphStyle(
    "Title", parent=_base["Title"],
    fontName="Helvetica-Bold", fontSize=20, leading=23,
    textColor=INK, alignment=TA_LEFT, spaceAfter=1,
)
S_SUB = ParagraphStyle(
    "Sub", parent=_base["Normal"],
    fontName="Helvetica", fontSize=10, leading=12,
    textColor=ACCENT, alignment=TA_LEFT, spaceAfter=2,
)
S_META = ParagraphStyle(
    "Meta", parent=_base["Normal"],
    fontName="Helvetica-Oblique", fontSize=8, leading=10,
    textColor=MUTED, alignment=TA_LEFT, spaceAfter=0,
)
S_H2 = ParagraphStyle(
    "H2", parent=_base["Heading2"],
    fontName="Helvetica-Bold", fontSize=10.5, leading=13,
    textColor=ACCENT, alignment=TA_LEFT,
    spaceBefore=5, spaceAfter=2,
)
S_BODY = ParagraphStyle(
    "Body", parent=_base["Normal"],
    fontName="Helvetica", fontSize=8.5, leading=11,
    textColor=INK, alignment=TA_JUSTIFY, spaceAfter=3,
)
S_BULLET = ParagraphStyle(
    "Bullet", parent=S_BODY,
    leftIndent=10, bulletIndent=2, spaceAfter=1,
    alignment=TA_LEFT,
)
S_FOOT = ParagraphStyle(
    "Foot", parent=_base["Normal"],
    fontName="Helvetica-Oblique", fontSize=7.5, leading=9,
    textColor=MUTED, alignment=TA_CENTER,
)
S_CELL = ParagraphStyle(
    "Cell", parent=_base["Normal"],
    fontName="Helvetica", fontSize=8, leading=10,
    textColor=INK, alignment=TA_LEFT,
)
S_CELL_B = ParagraphStyle(
    "CellB", parent=S_CELL, fontName="Helvetica-Bold",
)
S_CELL_HEAD = ParagraphStyle(
    "CellHead", parent=S_CELL,
    fontName="Helvetica-Bold", textColor=PAPER,
)


def bullets(items: list[str]) -> list:
    return [Paragraph("• " + it, S_BULLET) for it in items]


# ----------------------------------------------------------------------
def build():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    doc = BaseDocTemplate(
        str(OUT_PATH),
        pagesize=LETTER,
        leftMargin=0.5 * inch, rightMargin=0.5 * inch,
        topMargin=0.45 * inch,  bottomMargin=0.4 * inch,
        title="Ham Radio Weather Dashboard — One-Page Overview",
        author="N8SDR — Rick Langford",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin,
                  doc.width, doc.height, id="content")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame])])

    story: list = []

    # ---------- Header: logo + title + subtitle --------------------
    header_cells = [[
        Image(str(LOGO_PATH), width=0.75 * inch, height=0.75 * inch)
            if LOGO_PATH.exists() else Paragraph("", S_BODY),
        [
            Paragraph("Ham Radio Weather Dashboard", S_TITLE),
            Paragraph("A weather dashboard built for amateur radio operators",
                      S_SUB),
            Paragraph(f"Version {APP_VERSION}  ·  Qt6 / PySide6  ·  "
                      f"Free &amp; open source  ·  github.com/N8SDR1/ham-radio-weather",
                      S_META),
        ],
    ]]
    ht = Table(header_cells, colWidths=[0.9 * inch, None])
    ht.setStyle(TableStyle([
        ("VALIGN",       (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",  (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 0),
        ("TOPPADDING",   (0, 0), (-1, -1), 0),
    ]))
    story.append(ht)
    rule = Table([[""]], colWidths=[doc.width], rowHeights=[1.5])
    rule.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), ACCENT)]))
    story.append(Spacer(1, 3))
    story.append(rule)
    story.append(Spacer(1, 4))

    # ---------- What it is (tight single paragraph) ----------------
    story.append(Paragraph("What it is", S_H2))
    story.append(Paragraph(
        "A modern desktop weather application built specifically for amateur radio operators. "
        "Pulls live data from your Ambient or Ecowitt station and layers ham-specific overlays on "
        "top — HF propagation, amateur-satellite passes, lightning proximity warnings, and "
        "NOAA geomagnetic-storm indicators — in a single drag-to-reorder dashboard. "
        "A \"None\" mode runs the entire app on free online feeds for operators without a station.",
        S_BODY))

    # ---------- Two-column features block -------------------------
    # Left column: tiles. Right column: ham overlays + UX.
    left = [
        Paragraph("Weather tiles", S_H2),
        *bullets([
            "<b>Outdoor</b>, <b>Wind</b> (360° compass), <b>Rain</b>, <b>Lightning</b>, <b>Indoor</b>",
            "<b>Humidity</b>, <b>UV</b>, <b>Solar Radiation</b>, <b>Pressure</b>",
            "<b>24 h sparklines</b> <i>(new in 1.0.9)</i> on Outdoor / Humidity / Pressure",
            "<b>3 h pressure trend arrow</b> <i>(new in 1.0.9)</i> — catches fronts early",
            "<b>7-day Forecast</b> + <b>Sun / Moon</b> (locally computed)",
            "Air Quality, Soil, Leak — auto-populate on sensor detect",
        ]),
    ]
    right = [
        Paragraph("Ham-radio overlays", S_H2),
        *bullets([
            "<b>HF Propagation</b> — SFI, K/A, band-condition grid, G-scale badge",
            "<b>Space Weather</b> — 72 h Kp forecast, 24-bar chart, G-scale peak",
            "<b>Satellites</b> — 13 birds, SGP4 pass prediction via Celestrak TLEs",
            "\"Unplug the Rig!\" lightning pulse, \"Antenna Swayer!\" at 50 mph+",
            "Pressure mood shifts to \"Storm Brewing ⛈\" as the bottom drops out",
        ]),
    ]
    two_col = Table([[left, right]],
                    colWidths=[doc.width * 0.5 - 6, doc.width * 0.5 - 6])
    two_col.setStyle(TableStyle([
        ("VALIGN",       (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",  (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING",   (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 0),
    ]))
    story.append(two_col)

    # ---------- UX / dashboard experience ------------------------
    story.append(Paragraph("Dashboard experience", S_H2))
    story.extend(bullets([
        "Dark / light / auto themes  ·  °F / °C toggle  ·  drag-to-reorder with per-tile S/M/L/XL sizing",
        "Configurable alert thresholds (heat, freeze, high wind, lightning nearby, fire weather, shack overheat)",
        "Header update-pill pulses automatically when a new GitHub release is published",
    ]))

    # ---------- Station support (compact table) -------------------
    story.append(Paragraph("Weather station support", S_H2))
    station_data = [
        [Paragraph("<b>Brand / mode</b>", S_CELL_HEAD),
         Paragraph("<b>Connection</b>",   S_CELL_HEAD),
         Paragraph("<b>Status</b>",       S_CELL_HEAD)],
        [Paragraph("Ambient Weather (WS-2000/2902/5000/1965)", S_CELL),
         Paragraph("REST polling + Socket.IO realtime", S_CELL),
         Paragraph("Fully supported", S_CELL_B)],
        [Paragraph("Ecowitt (Wittboy, GW/HP gateways)", S_CELL),
         Paragraph("Ecowitt Cloud API v3 (60 s poll)", S_CELL),
         Paragraph("Fully supported", S_CELL_B)],
        [Paragraph("None — no station required", S_CELL),
         Paragraph("Open-Meteo + Blitzortung + NOAA SWPC + HamQSL", S_CELL),
         Paragraph("Fully supported", S_CELL_B)],
        [Paragraph("Tempest / Davis / Netatmo / Ecowitt LAN", S_CELL),
         Paragraph("Various (see roadmap)", S_CELL),
         Paragraph("Planned", S_CELL)],
    ]
    st = Table(station_data, colWidths=[2.4 * inch, 3.0 * inch, 2.0 * inch])
    st.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  ACCENT),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [TINT, colors.white]),
        ("GRID",          (0, 0), (-1, -1), 0.25, RULE),
        ("VALIGN",        (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING",   (0, 0), (-1, -1), 5),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 5),
        ("TOPPADDING",    (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.append(st)

    # ---------- None mode (compact) -------------------------------
    story.append(Paragraph("Running without a weather station", S_H2))
    story.append(Paragraph(
        "Pick <b>None</b> in Settings → Weather Station and enter a Maidenhead grid square. "
        "Open-Meteo provides current conditions and the 7-day forecast; Blitzortung provides "
        "real-time lightning filtered to a user-configurable radius; HamQSL and NOAA SWPC "
        "cover HF propagation and space weather; Celestrak TLEs drive satellite passes. "
        "Station-only tiles (Indoor shack, battery) auto-hide so nothing shows empty.",
        S_BODY))

    # ---------- Active alerts (compact table) ---------------------
    story.append(Paragraph("Active severe-weather alerts", S_H2))
    story.append(Paragraph(
        "Two layers side by side: user-configurable <b>threshold rules</b> evaluated against "
        "live data, plus <b>official regional feeds</b> selected in Settings → Alerts:",
        S_BODY))
    alert_data = [
        [Paragraph("<b>Region</b>",   S_CELL_HEAD),
         Paragraph("<b>Provider</b>", S_CELL_HEAD),
         Paragraph("<b>Feed</b>",     S_CELL_HEAD)],
        [Paragraph("United States", S_CELL),
         Paragraph("National Weather Service (NWS)", S_CELL),
         Paragraph("api.weather.gov CAP alerts", S_CELL)],
        [Paragraph("Canada", S_CELL),
         Paragraph("Environment and Climate Change Canada", S_CELL),
         Paragraph("Public CAP feed per province", S_CELL)],
        [Paragraph("Europe", S_CELL),
         Paragraph("MeteoAlarm", S_CELL),
         Paragraph("Pan-European severe-weather aggregator", S_CELL)],
        [Paragraph("Australia", S_CELL),
         Paragraph("Bureau of Meteorology", S_CELL),
         Paragraph("Public warnings feed per state", S_CELL)],
    ]
    at = Table(alert_data, colWidths=[1.2 * inch, 2.3 * inch, 3.9 * inch])
    at.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  ACCENT2),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [TINT, colors.white]),
        ("GRID",          (0, 0), (-1, -1), 0.25, RULE),
        ("VALIGN",        (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING",   (0, 0), (-1, -1), 5),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 5),
        ("TOPPADDING",    (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.append(at)

    # ---------- How to get it -------------------------------------
    story.append(Paragraph("How to obtain it", S_H2))
    story.append(Paragraph(
        "<b>Windows:</b> download the latest <i>HamRadioWeather-Setup-X.Y.Z.exe</i> installer from "
        "<b>github.com/N8SDR1/ham-radio-weather/releases</b>. Per-user install, no admin "
        "required. Accept the disclaimer on first run, pick your station (or None mode), and "
        "go. &nbsp;&nbsp; <b>macOS / Linux:</b> runs from source with Python 3.11+ — see the "
        "project README. &nbsp;&nbsp; <b>License:</b> free and open source; optional PayPal "
        "donation linked from the About dialog.",
        S_BODY))

    # ---------- Footer byline -------------------------------------
    story.append(Spacer(1, 4))
    rule2 = Table([[""]], colWidths=[doc.width], rowHeights=[1])
    rule2.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), RULE)]))
    story.append(rule2)
    story.append(Spacer(1, 3))
    story.append(Paragraph(
        "Built by N8SDR — Rick Langford, Hamilton OH (grid EM79RJ). "
        "Free to use, free to share.  73.",
        S_FOOT))

    doc.build(story)
    print(f"Wrote {OUT_PATH}  ({OUT_PATH.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    build()
