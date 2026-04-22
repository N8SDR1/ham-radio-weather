r"""Generate docs/HamRadioWeather-Overview.pdf — marketing / intro sheet.

Run from the project root (venv activated):
    python tools\make_overview_pdf.py
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
    Paragraph, Spacer, Table, TableStyle, PageBreak, Image, KeepTogether,
)

# ----------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_PATH     = PROJECT_ROOT / "docs" / "HamRadioWeather-Overview.pdf"
LOGO_PATH    = PROJECT_ROOT / "assets" / "wxham_clean.png"
if not LOGO_PATH.exists():
    LOGO_PATH = PROJECT_ROOT / "assets" / "wxham.png"

APP_VERSION = "1.0.10"

# ----------------------------------------------------------------------
# Palette (matches the dashboard's dark theme accents, but print-friendly)
# ----------------------------------------------------------------------
ACCENT   = colors.HexColor("#3b82f6")    # blue
ACCENT2  = colors.HexColor("#8b5cf6")    # violet
GOOD     = colors.HexColor("#10b981")    # green
WARN     = colors.HexColor("#f59e0b")    # amber
BAD      = colors.HexColor("#ef4444")    # red
INK      = colors.HexColor("#0f172a")    # near-black
MUTED    = colors.HexColor("#475569")    # slate
PAPER    = colors.white
RULE     = colors.HexColor("#cbd5e1")

# ----------------------------------------------------------------------
# Styles
# ----------------------------------------------------------------------
_base = getSampleStyleSheet()

S_TITLE = ParagraphStyle(
    "Title", parent=_base["Title"],
    fontName="Helvetica-Bold", fontSize=26, leading=30,
    textColor=INK, alignment=TA_LEFT, spaceAfter=2,
)
S_SUB = ParagraphStyle(
    "Subtitle", parent=_base["Normal"],
    fontName="Helvetica", fontSize=12, leading=16,
    textColor=ACCENT, alignment=TA_LEFT, spaceAfter=4,
)
S_META = ParagraphStyle(
    "Meta", parent=_base["Normal"],
    fontName="Helvetica-Oblique", fontSize=9.5, leading=13,
    textColor=MUTED, alignment=TA_LEFT, spaceAfter=14,
)
S_H2 = ParagraphStyle(
    "H2", parent=_base["Heading2"],
    fontName="Helvetica-Bold", fontSize=15, leading=20,
    textColor=ACCENT, alignment=TA_LEFT,
    spaceBefore=14, spaceAfter=6,
)
S_H3 = ParagraphStyle(
    "H3", parent=_base["Heading3"],
    fontName="Helvetica-Bold", fontSize=11.5, leading=15,
    textColor=INK, alignment=TA_LEFT,
    spaceBefore=8, spaceAfter=3,
)
S_BODY = ParagraphStyle(
    "Body", parent=_base["Normal"],
    fontName="Helvetica", fontSize=10.5, leading=14.5,
    textColor=INK, alignment=TA_JUSTIFY, spaceAfter=6,
)
S_BULLET = ParagraphStyle(
    "Bullet", parent=S_BODY,
    leftIndent=14, bulletIndent=2, spaceAfter=3,
    alignment=TA_LEFT,
)
S_FOOT = ParagraphStyle(
    "Foot", parent=_base["Normal"],
    fontName="Helvetica-Oblique", fontSize=8.5, leading=11,
    textColor=MUTED, alignment=TA_CENTER,
)
S_CELL = ParagraphStyle(
    "Cell", parent=_base["Normal"],
    fontName="Helvetica", fontSize=9.5, leading=13,
    textColor=INK, alignment=TA_LEFT,
)
S_CELL_BOLD = ParagraphStyle(
    "CellBold", parent=S_CELL,
    fontName="Helvetica-Bold",
)

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
def bullets(items: list[str]) -> list:
    flow = []
    for it in items:
        flow.append(Paragraph("• " + it, S_BULLET))
    return flow


def page_frame(canvas, doc):
    canvas.saveState()
    # Header rule
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.5)
    canvas.line(0.75 * inch, LETTER[1] - 0.55 * inch,
                LETTER[0] - 0.75 * inch, LETTER[1] - 0.55 * inch)
    # Left-aligned header label
    canvas.setFont("Helvetica-Bold", 8.5)
    canvas.setFillColor(ACCENT)
    canvas.drawString(0.75 * inch, LETTER[1] - 0.42 * inch,
                      "HAM RADIO WEATHER DASHBOARD")
    canvas.setFont("Helvetica", 8.5)
    canvas.setFillColor(MUTED)
    canvas.drawRightString(LETTER[0] - 0.75 * inch,
                           LETTER[1] - 0.42 * inch,
                           f"Overview  ·  v{APP_VERSION}")
    # Footer rule + page number
    canvas.line(0.75 * inch, 0.55 * inch,
                LETTER[0] - 0.75 * inch, 0.55 * inch)
    canvas.setFont("Helvetica-Oblique", 8.5)
    canvas.setFillColor(MUTED)
    footer_text = ("Built by a fellow ham, for the community.  "
                   "github.com/N8SDR1/ham-radio-weather   ·  73 de N8SDR")
    footer_y = 0.38 * inch
    footer_center_x = LETTER[0] / 2.0
    canvas.drawCentredString(footer_center_x, footer_y, footer_text)

    # Clickable hyperlink over the GitHub URL inside the footer text.
    # We measure just the URL substring so the click target is tight
    # instead of covering the whole footer line.
    url_text = "github.com/N8SDR1/ham-radio-weather"
    url_width = canvas.stringWidth(url_text, "Helvetica-Oblique", 8.5)
    full_width = canvas.stringWidth(footer_text, "Helvetica-Oblique", 8.5)
    footer_left_x = footer_center_x - full_width / 2.0
    url_offset = canvas.stringWidth(
        "Built by a fellow ham, for the community.  ",
        "Helvetica-Oblique", 8.5,
    )
    url_x1 = footer_left_x + url_offset
    url_x2 = url_x1 + url_width
    canvas.linkURL(
        "https://github.com/N8SDR1/ham-radio-weather",
        (url_x1, footer_y - 2, url_x2, footer_y + 9),
        relative=0,
        thickness=0,
    )

    canvas.drawRightString(LETTER[0] - 0.75 * inch, footer_y,
                           f"Page {doc.page}")
    canvas.restoreState()


# ----------------------------------------------------------------------
# Document build
# ----------------------------------------------------------------------
def build():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    doc = BaseDocTemplate(
        str(OUT_PATH),
        pagesize=LETTER,
        leftMargin=0.75 * inch, rightMargin=0.75 * inch,
        topMargin=0.85 * inch,  bottomMargin=0.75 * inch,
        title="Ham Radio Weather Dashboard — Overview",
        author="N8SDR — Rick Langford",
        subject="Qt6 / PySide6 desktop weather dashboard for amateur radio operators",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin,
                  doc.width, doc.height, id="content")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame],
                                       onPage=page_frame)])

    story: list = []

    # --------------------------------------------------------------
    # HEADER BLOCK: logo + title stacked
    # --------------------------------------------------------------
    header_cells = [[
        Image(str(LOGO_PATH), width=0.95 * inch, height=0.95 * inch)
            if LOGO_PATH.exists() else Paragraph("", S_BODY),
        [
            Paragraph("Ham Radio Weather Dashboard", S_TITLE),
            Paragraph("A weather dashboard built for amateur radio operators",
                      S_SUB),
            Paragraph(f"Version {APP_VERSION}  ·  Qt6 / PySide6  ·  "
                      f"Windows today, macOS &amp; Linux from source",
                      S_META),
        ],
    ]]
    ht = Table(header_cells, colWidths=[1.1 * inch, None])
    ht.setStyle(TableStyle([
        ("VALIGN",       (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",  (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 0),
        ("TOPPADDING",   (0, 0), (-1, -1), 0),
    ]))
    story.append(ht)

    # Accent underline rule
    story.append(Spacer(1, 4))
    rule = Table([[""]], colWidths=[doc.width], rowHeights=[2])
    rule.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), ACCENT)]))
    story.append(rule)
    story.append(Spacer(1, 10))

    # --------------------------------------------------------------
    # WHAT IT IS
    # --------------------------------------------------------------
    story.append(Paragraph("What it is", S_H2))
    story.append(Paragraph(
        "Ham Radio Weather Dashboard is a modern desktop weather application built "
        "specifically for amateur radio operators. It pulls live data from your "
        "personal weather station, layers on ham-specific information — HF propagation, "
        "amateur-satellite pass prediction, lightning-proximity warnings, and "
        "geomagnetic storm indicators — and presents everything in a single, "
        "configurable dashboard designed to live on a spare monitor in the shack or on "
        "a wall-mounted panel.",
        S_BODY))
    story.append(Paragraph(
        "The bundled web dashboards that ship with personal weather stations are "
        "generic; nothing off-the-shelf puts the lightning tile next to the HF "
        "propagation tile next to the next-ISS-pass tile. This one does. And for "
        "hams who don't own a station, a dedicated \"None\" mode runs the entire "
        "dashboard on free online feeds, keyed to a Maidenhead grid square.",
        S_BODY))

    # --------------------------------------------------------------
    # FEATURES
    # --------------------------------------------------------------
    story.append(Paragraph("Features at a glance", S_H2))

    story.append(Paragraph("Weather tiles", S_H3))
    story.extend(bullets([
        "<b>Outdoor</b> — current temperature, feels-like, dew point and humidity with mood-driven color shifts (Deep Freeze → Melt Mode). 24-hour temperature sparkline traces the day's shape under the big value.",
        "<b>Wind</b> — full 360° compass with live needle, cardinal labels, speed gauge, today's peak and gust readout.",
        "<b>Rain</b> — current rate, day total and event total from your station's tipping bucket (or Open-Meteo rainfall in None mode).",
        "<b>Lightning</b> — strike count and distance with a pulsing \"Unplug the Rig!\" mood when strikes track within 5 miles.",
        "<b>Indoor</b> — shack temperature and humidity with ham-joke mood tiers: Frozen Shack → Shack → Heating → Hell Mode.",
        "<b>Humidity</b> <i>(new in 1.0.9)</i> — outdoor humidity with a mood (Desert → Comfy → Swamp), a \"From Yesterday\" delta, and a 24-hour sparkline.",
        "<b>Pressure</b> <i>(new in 1.0.9)</i> — barometric pressure with a 28.0–31.0 inHg scale indicator, a 3-hour trend arrow (▲/▼/→) with signed delta, and a 24-hour sparkline. Mood title (Steady → Falling → Storm Brewing ⛈) often catches a front hours before it arrives.",
        "<b>UV Index, Solar Radiation</b> — supporting tiles with theme-aware scales and risk bands.",
        "<b>Forecast</b> — 7-day outlook via Open-Meteo, keyed off your grid square, with per-day high/low and precip probability.",
        "<b>Sun / Moon</b> — sunrise/sunset times and locally-computed moon phase.",
        "<b>Air Quality, Soil Probes, Leak Detectors</b> — auto-populate when the corresponding sensor add-on reports data.",
    ]))

    story.append(Paragraph("Ham-radio overlays", S_H3))
    story.extend(bullets([
        "<b>HF Propagation</b> — SFI, K-index, A-index, an 8-cell band-condition grid (80 m–10 m × day/night) and a NOAA G-scale geomagnetic-storm badge that pulses on G3+. Sourced from hamqsl.com, refreshed every 15 minutes.",
        "<b>Space Weather</b> <i>(new in 1.0.8)</i> — 72-hour planetary-Kp forecast from NOAA SWPC. Shows current Kp, upcoming peak with G-scale badge, and a 24-bar chart of predicted Kp values in 3-hour slots over the next three days. Pairs with HF Propagation: that tile shows <i>now</i>, this one shows <i>next</i>, so operators can plan DX sessions around quiet bands.",
        "<b>Amateur Satellites</b> — next pass with time, direction, peak elevation and duration, plus an upcoming-passes list. Tracks 13 active birds by default (ISS, AO-7, AO-27, AO-73, AO-123, FO-29, SO-50, RS-44, HADES-ICM, HADES-SA, IO-86, JO-97, NANOZOND-1). TLEs via Celestrak, orbit math via SGP4.",
        "<b>Lightning proximity warnings</b> — pulsing red alert whenever strikes are within a user-configurable radius.",
        "<b>Antenna Swayer!</b> mood — the wind tile changes personality when gusts exceed 50 mph.",
    ]))

    story.append(Paragraph("Dashboard experience", S_H3))
    story.extend(bullets([
        "Dark, light and auto (OS-following) themes with a custom accent palette.",
        "°F / °C toggle and Imperial/Metric unit switching in a single click.",
        "Drag-to-reorder tiles, per-tile Small / Medium / Large / XL sizing, and persistent layout across sessions.",
        "<b>24-hour sparkline trend charts</b> under the main value on the Outdoor, Humidity, and Pressure tiles — now available on both Ambient <i>and</i> Ecowitt stations <i>(new in 1.0.10)</i>.",
        "<b>Tile Personality</b> <i>(new in 1.0.10)</i> — every user-facing mood trigger is now tunable: Outdoor fire/ice temperatures, Shack Hell Mode, Lightning panic distance, Wind Antenna Swayer gust threshold.",
        "<b>Dramatic mood effects</b> <i>(new in 1.0.10)</i> — tiles come alive when conditions match: flickering fire halos on hot temps, pulsing ice for cold, animated lightning bolts behind the Lightning tile during nearby strikes, falling rain drops that scale with the actual hourly rate, rotating sunbursts at Supernova solar levels, aurora ribbons at G4/G5 geomagnetic storms, and more. Preview toggles in Settings so every effect can be seen on demand.",
        "Configurable alert thresholds (heat, freeze, high wind, damaging gust, heavy rain, flash flood, lightning nearby, fire weather, shack overheat).",
        "In-app disclaimer gate on first run; built-in Help guide and About dialog.",
        "Header badges: live-feed pulse dot, active-source pill (ONLINE / AMBIENT / ECOWITT), sensor-battery indicator and active-alert counter.",
        "Automatic GitHub-release update notification: a pulsing pill appears in the header the moment a newer version is published.",
    ]))

    # --------------------------------------------------------------
    # WEATHER STATION SUPPORT
    # --------------------------------------------------------------
    story.append(Paragraph("Weather station support", S_H2))
    story.append(Paragraph(
        "The dashboard is designed around a pluggable adapter layer. Every supported "
        "station translates its native schema into a common flat shape, so every tile "
        "renders identically regardless of the brand providing the data.",
        S_BODY))

    station_data = [
        [Paragraph("<b>Brand / mode</b>", S_CELL_BOLD),
         Paragraph("<b>Connection</b>",   S_CELL_BOLD),
         Paragraph("<b>Status</b>",       S_CELL_BOLD)],
        [Paragraph("<b>Ambient Weather</b> (WS-2000, WS-2902, WS-5000, WS-1965, anything reporting to ambientweather.net)", S_CELL),
         Paragraph("REST polling (60 s) + Socket.IO realtime stream",     S_CELL),
         Paragraph("Fully supported",                                     S_CELL)],
        [Paragraph("<b>Ecowitt</b> (Wittboy, GW1100, HP2551, HP2564, anything with the GW / HP gateways)", S_CELL),
         Paragraph("Ecowitt Cloud API v3 (60 s polling)",                 S_CELL),
         Paragraph("Fully supported",                                     S_CELL)],
        [Paragraph("<b>None — no station required</b>",                    S_CELL),
         Paragraph("Open-Meteo + Blitzortung + NOAA SWPC + HamQSL",       S_CELL),
         Paragraph("Fully supported",                                     S_CELL)],
        [Paragraph("<b>Ecowitt LAN polling</b>",                           S_CELL),
         Paragraph("Direct <i>get_livedata_info</i> calls over LAN",      S_CELL),
         Paragraph("Planned",                                              S_CELL)],
        [Paragraph("<b>WeatherFlow Tempest</b>",                           S_CELL),
         Paragraph("Personal access token + UDP local broadcasts",         S_CELL),
         Paragraph("Planned (v1.0.9)",                                     S_CELL)],
        [Paragraph("<b>Davis Instruments</b>",                             S_CELL),
         Paragraph("WeatherLink v2 HMAC-signed REST + local HTTP",         S_CELL),
         Paragraph("Planned (v1.1.0)",                                     S_CELL)],
        [Paragraph("<b>Netatmo</b>",                                       S_CELL),
         Paragraph("OAuth 2.0",                                            S_CELL),
         Paragraph("Planned (v1.1.1)",                                     S_CELL)],
    ]
    t = Table(station_data, colWidths=[2.4 * inch, 2.7 * inch, 1.8 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  ACCENT),
        ("TEXTCOLOR",     (0, 0), (-1, 0),  PAPER),
        ("FONTNAME",      (0, 0), (-1, 0),  "Helvetica-Bold"),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [colors.whitesmoke, colors.white]),
        ("GRID",          (0, 0), (-1, -1), 0.25, RULE),
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",   (0, 0), (-1, -1), 6),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 6),
        ("TOPPADDING",    (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(t)

    # --------------------------------------------------------------
    # NONE MODE
    # --------------------------------------------------------------
    story.append(Paragraph("Running without a weather station", S_H2))
    story.append(Paragraph(
        "Operators who don't own a personal weather station can still run the full "
        "dashboard. In Settings → Weather Station, select "
        "<b>\"None — no local station (use online sources)\"</b>, then enter a "
        "Maidenhead grid square (such as EM79RJ) or explicit latitude/longitude "
        "under Settings → Operator. The dashboard will then pull:",
        S_BODY))
    story.extend(bullets([
        "<b>Current conditions and forecast</b> from <i>Open-Meteo</i> — a free, no-API-key forecasting service with global coverage.",
        "<b>Lightning</b> from the <i>Blitzortung</i> real-time global lightning network, filtered to a user-configurable radius so you see strikes relevant to <i>your</i> location.",
        "<b>HF propagation</b> from hamqsl.com and <b>space weather</b> from NOAA SWPC — both are global feeds that work identically whether or not you have a station.",
        "<b>Satellite passes</b> computed locally using Celestrak TLEs and the SGP4 propagator, keyed to the same grid square.",
        "<b>Weather alerts</b> from whichever regional provider matches your location (see below).",
    ]))
    story.append(Paragraph(
        "Tiles that genuinely require a physical station (Indoor shack readings, "
        "battery status) are auto-hidden in None mode so the dashboard never shows "
        "empty placeholders.",
        S_BODY))

    # --------------------------------------------------------------
    # ALERTS
    # --------------------------------------------------------------
    story.append(Paragraph("Active severe-weather alerts", S_H2))
    story.append(Paragraph(
        "The dashboard aggregates two distinct kinds of alerts side by side:",
        S_BODY))
    story.append(Paragraph("<b>1.  Threshold-based alerts</b> (always on)", S_H3))
    story.append(Paragraph(
        "User-configurable rules evaluated against live station data — heat, freeze, "
        "high wind, damaging gusts, heavy rain rate, flash-flood rainfall totals, "
        "lightning within your configured radius, muggy conditions, fire-weather "
        "combos and shack-overheat detection. Thresholds live in Settings → Alerts; "
        "results show as pulsing cards in the Alerts tile.",
        S_BODY))
    story.append(Paragraph("<b>2.  Official regional severe-weather feeds</b>", S_H3))
    story.append(Paragraph(
        "The dashboard ships an <i>Alerts Router</i> that plugs into the appropriate "
        "official feed for your part of the world. The router is wired to four "
        "providers today:",
        S_BODY))

    alert_data = [
        [Paragraph("<b>Region</b>",   S_CELL_BOLD),
         Paragraph("<b>Provider</b>", S_CELL_BOLD),
         Paragraph("<b>Feed</b>",     S_CELL_BOLD)],
        [Paragraph("<b>United States</b>", S_CELL),
         Paragraph('<link href="https://www.weather.gov" color="#1d4ed8">'
                   'National Weather Service (NWS)</link>', S_CELL),
         Paragraph('<link href="https://api.weather.gov" color="#1d4ed8">'
                   'api.weather.gov</link> — CAP alerts by state/zone', S_CELL)],
        [Paragraph("<b>Canada</b>", S_CELL),
         Paragraph('<link href="https://weather.gc.ca" color="#1d4ed8">'
                   'Environment and Climate Change Canada</link>', S_CELL),
         Paragraph("Public weather-alert CAP feed per province", S_CELL)],
        [Paragraph("<b>Europe</b>", S_CELL),
         Paragraph('<link href="https://meteoalarm.org" color="#1d4ed8">'
                   'MeteoAlarm</link>', S_CELL),
         Paragraph("Pan-European severe-weather CAP aggregator", S_CELL)],
        [Paragraph("<b>Australia</b>", S_CELL),
         Paragraph('<link href="http://www.bom.gov.au" color="#1d4ed8">'
                   'Bureau of Meteorology (BoM)</link>', S_CELL),
         Paragraph("Public warnings feed per state", S_CELL)],
    ]
    t2 = Table(alert_data, colWidths=[1.5 * inch, 2.4 * inch, 3.0 * inch])
    t2.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  ACCENT2),
        ("TEXTCOLOR",     (0, 0), (-1, 0),  PAPER),
        ("FONTNAME",      (0, 0), (-1, 0),  "Helvetica-Bold"),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [colors.whitesmoke, colors.white]),
        ("GRID",          (0, 0), (-1, -1), 0.25, RULE),
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",   (0, 0), (-1, -1), 6),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 6),
        ("TOPPADDING",    (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(t2)
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "Select your region in Settings → Alerts. Polling cadence is configurable; "
        "an \"Off\" setting hides the official-alerts tile entirely for users who "
        "prefer only the threshold-based rules. Additional providers (including "
        "fallback coverage for New Zealand and other regions) are on the roadmap.",
        S_BODY))

    # --------------------------------------------------------------
    # HOW TO OBTAIN
    # --------------------------------------------------------------
    story.append(Paragraph("How to obtain it", S_H2))
    story.append(Paragraph("Windows end users", S_H3))
    story.extend(bullets([
        'Visit the project\'s GitHub Releases page: '
        '<link href="https://github.com/N8SDR1/ham-radio-weather/releases" color="#1d4ed8">'
        '<b><u>github.com/N8SDR1/ham-radio-weather/releases</u></b></link>',
        "Download the latest <i>HamRadioWeather-Setup-X.Y.Z.exe</i> installer.",
        "Run the installer (per-user, no admin privileges required).",
        "Launch from the desktop shortcut or Start menu, accept the disclaimer on first run, "
        "and configure your station (or select None mode) under Settings → Weather Station.",
        "The app will check GitHub on startup and display a pulsing \"Update\" pill in the "
        "header whenever a newer release is published.",
    ]))

    story.append(Paragraph("macOS and Linux", S_H3))
    story.append(Paragraph(
        "Pre-built installers are Windows-only at this stage. The application runs from "
        "source on macOS and Linux with Python 3.11 or newer. Clone the repository, "
        "create a virtual environment, install requirements, and launch <i>src/main.py</i> "
        "directly. Full instructions are in the project README.",
        S_BODY))

    story.append(Paragraph("License and support", S_H3))
    story.append(Paragraph(
        "Free and open source. Built by a fellow ham for the community. "
        "The project README links an optional PayPal donation for operators who want to "
        "support ongoing development, but the software itself carries no licensing fee. "
        "Bug reports and pull requests are welcome through GitHub.",
        S_BODY))

    # --------------------------------------------------------------
    # FOOTER BYLINE
    # --------------------------------------------------------------
    story.append(Spacer(1, 14))
    byline = Table([[""]], colWidths=[doc.width], rowHeights=[1.25])
    byline.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), RULE)]))
    story.append(byline)
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "Built by N8SDR — Rick Langford, Hamilton OH (grid EM79RJ). "
        "Free to use, free to share.  73.",
        S_FOOT))

    doc.build(story)
    print(f"Wrote {OUT_PATH}  ({OUT_PATH.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    build()
