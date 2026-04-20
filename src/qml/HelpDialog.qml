import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

Dialog {
    id: dialog
    title: "Help & Guide"
    modal: true
    standardButtons: Dialog.Close
    width: 780
    height: Math.min(parent ? parent.height * 0.9 : 700, 700)
    anchors.centerIn: parent

    background: Rectangle {
        color: App.Theme.surface
        border.color: App.Theme.border
        radius: 12
    }

    readonly property var gettingStarted: [
        { h: "1. Pick your weather station (or 'None')",
          b: "Settings → Weather Station. If you own an Ambient or Ecowitt station, pick that brand and enter the two API keys. If you don't have any station, pick 'None — no local station (use online sources)' and the dashboard pulls live current-weather data from Open-Meteo using your Maidenhead grid square. Header shows an ONLINE / AMBIENT / ECOWITT badge so you always know what source is feeding the tiles." },
        { h: "2. Set your Maidenhead grid square",
          b: "Settings → Operator → Grid Square. Accepts 4-char (e.g. EN80) or 6-char (e.g. EN80pb). This drives the forecast, satellite passes, Sun/Moon times, and online-only weather. If grid-square precision isn't enough, tick 'Override with explicit latitude / longitude' and enter exact coordinates." },
        { h: "3. Optional: ham callsign",
          b: "Shown in the header as personalization. Not used in any API call." },
        { h: "4. Arrange your dashboard",
          b: "Drag the ⋮⋮ handle on any tile's header to reorder. Drop on the LEFT half of another tile to insert BEFORE it, RIGHT half to insert AFTER. Dropping in empty grid space works too — the dashboard snaps it next to the nearest tile.\n\nClick the ⋯ menu on any tile to resize (Small / Medium / Large / Extra Large) or hide it. Size only affects column width; row height stays uniform so rows stay aligned." },
        { h: "4a. Why some tiles don't offer every size",
          b: "A few tiles need horizontal room for their content. Forecast needs 7 day-columns side-by-side; HF Propagation has a band × day/night grid that collapses at narrow widths. Those tiles don't offer Small (and in some cases Medium) — the ⋯ menu and Settings → Panels size picker only list the sizes that actually render cleanly. Simple-number tiles (Humidity, UV, Solar) can go as small as Small. This prevents the overflow / text-clipping we hit earlier in development." },
        { h: "4b. Resetting layout",
          b: "Settings → Panels → Reset Layout to Defaults clears your reorder + sizes and restores the default arrangement. Add-on sensor tiles (Air Quality, Soil Probes, Leak Detectors) return to hidden-by-default on reset since most users don't own those sensors." },
        { h: "5. Tune your alert thresholds",
          b: "Settings → Alerts. Each rule has an enable toggle and a numeric threshold. The Alerts tile aggregates anything that's tripped. Heat, freeze, high wind, lightning-near, fire-weather, etc." },
        { h: "6. Pick which satellites to track",
          b: "Settings → Satellites. 13 defaults correspond to currently-active amateur birds. Uncheck any you don't care about; they won't appear in the upcoming-passes list." }
    ]

    readonly property var tilesList: [
        { h: "Outdoor",         b: "Current outdoor temperature, feels-like, dew point, humidity. Mood title shifts by temperature (Deep Freeze → Melt Mode). Source: your station, or Open-Meteo in None mode." },
        { h: "Wind",            b: "Live compass with wind needle, speed gauge, direction label + degree, today's peak, gust." },
        { h: "Lightning",       b: "Strike count + distance. 'Unplug the Rig!' mood when strikes are within 5 miles. Uses your local lightning sensor; in None mode this tile will come alive once Blitzortung integration lands in v1.0.8." },
        { h: "Rain Fall",       b: "Current rate, today's total, event total. From your station's tipping bucket (or Open-Meteo rainfall in None mode)." },
        { h: "Shack or Hell",   b: "Indoor temp + humidity. Title and icon change by temperature: Frozen Shack → Shack → Heating → Hell Mode. Auto-hidden in None mode (no way to get indoor readings online)." },
        { h: "Humidity",        b: "Outdoor humidity with a mood (Desert → Comfy → Swamp)." },
        { h: "UV Index",        b: "UV value + risk band + 12-step scale bar." },
        { h: "Solar Radiation", b: "Incoming solar irradiance in W/m². Typical clear-sky noon is ~1000 W/m²." },
        { h: "Pressure",        b: "Barometric pressure with a 28.0–31.0 inHg scale indicator." },
        { h: "Forecast",        b: "7-day outlook via Open-Meteo, keyed off your grid square. Today summary plus a per-day strip with high/low and precip probability." },
        { h: "Sun / Moon",      b: "Sunrise/sunset times and computed moon phase for today." },
        { h: "HF Propagation",  b: "SFI, K-index, A-index, 8-cell band-condition grid (80m-40m / 30m-20m / 17m-15m / 12m-10m × day/night), and NOAA G-scale geomagnetic storm badge. Data via HamQSL — works regardless of weather station." },
        { h: "Satellites",      b: "Next amateur satellite pass with time, direction, max elevation, duration. Plus an upcoming-passes list. TLE via Celestrak, orbit math via SGP4." },
        { h: "Alerts",          b: "Aggregates tripped thresholds. Pulsing card for warnings, amber for watches, blue for info." },
        { h: "Air Quality, Soil, Leak", b: "Hidden by default. Enable in Settings → Panels when you add the corresponding sensor (AQIN, WH51, WH55). Auto-populate once data arrives." }
    ]

    readonly property var controls: [
        { h: "F11", b: "Toggle fullscreen / windowed." },
        { h: "⋮⋮ (tile header)",   b: "Click and drag to reorder. Drop on left half of target = insert BEFORE; right half = insert AFTER. Drop in empty grid space works too (snaps to nearest tile)." },
        { h: "⋯ (tile header)",   b: "Menu: Hide Panel, or resize to Small / Medium / Large / Extra Large. Tiles with minimum-size requirements (Forecast, HF Propagation) hide disallowed options." },
        { h: "Header buttons",    b: "°F/°C toggles units. Auto/Dark/Light cycles the theme. ⚙ opens Settings." },
        { h: "Header indicators", b: "Pulsing dot = station feed status (green=live, red=offline). Source badge (ONLINE/AMBIENT/ECOWITT/etc.) shows the active data source — click to jump to station settings. Battery pill = sensor battery state (hidden in None mode). Alerts pill = active alert count." },
        { h: "Disclaimer",        b: "Shown on first run. Must be accepted to use the app. Lists all third-party sources and clarifies the tool is informational only — not a safety system." }
    ]

    readonly property var hamRadio: [
        { h: "HF Propagation",
          b: "Tile pulls SFI / K / A from hamqsl.com's solar XML feed every 15 min. The 8-cell band grid shows day/night reliability for four HF band pairs. The G-scale badge (G0 Quiet → G5 Extreme) is derived from K-index per NOAA's geomagnetic storm scale — it pulses when G3+ to warn of HF blackout conditions. Works regardless of weather station choice." },
        { h: "Satellites",
          b: "Tracks 13 active amateur birds by default (ISS, AO-7, AO-27, AO-73, AO-123, FO-29, SO-50, RS-44, HADES-ICM, HADES-SA, IO-86, JO-97, NANOZOND-1). TLEs refresh from Celestrak's amateur group every 6h. Passes computed with SGP4 using your grid square (or lat/lon override) for the next 24 hours. Shows AOS → max-elevation → LOS compass directions." },
        { h: "Lightning tie-in",
          b: "The lightning tile's 'Unplug the Rig!' title (under 5 mi) is a real equipment warning — WS-2000 lightning detector picks up strikes faster than most rigs' surge protection can respond." },
        { h: "Location",
          b: "Everything location-dependent keys off your Maidenhead grid square in Settings. Override with explicit lat/lon if you need tighter precision than the grid provides. Changing either triggers an immediate refresh of all three location-aware clients." }
    ]

    readonly property var troubleshoot: [
        { h: "No live data (offline badge)",
          b: "Open Settings → Weather Station. If a brand is selected, check your keys are entered and restart. If you don't own a station, pick 'None — no local station' and make sure your grid square is set. The source badge in the header tells you which mode you're in." },
        { h: "Wrong / stale readings",
          b: "Settings → Weather Station → tick 'Show debug / diagnostic info' to see the raw API response, last poll time, HTTP status, and last error. The 'Copy All' button grabs everything for a bug report. Wind readings between your station's head unit and this app can differ by a few mph — that's because the Ambient API serves a 1-minute average, not instantaneous." },
        { h: "HF Propagation tile blank",
          b: "hamqsl.com occasionally returns partial data. Tile shows 'Waiting for hamqsl.com data…' until the first successful poll. Retry cadence is 15 min." },
        { h: "Satellite tile empty / 'Fetching TLEs…'",
          b: "First TLE fetch on startup takes 5–15s. If persistent, check your grid square is set and sgp4 is installed (pip install sgp4). Celestrak occasionally rate-limits — retry in a few minutes." },
        { h: "No forecast / Sun-Moon",
          b: "Both require a valid grid square (at least 4 chars like EN80). If you prefer explicit coordinates, enable 'Override with explicit latitude / longitude' under Settings → Operator." },
        { h: "Tiles missing in None mode",
          b: "Shack or Hell auto-hides in None mode (no indoor sensor data online). Battery indicator also disappears. Lightning and Rain tiles may be blank until Blitzortung + NWS integrations land in v1.0.8." },
        { h: "Dashboard text looks wrong on macOS / Linux",
          b: "Display font is Bahnschrift on Windows, Helvetica Neue on macOS, Roboto Condensed on Linux. Edit Theme.qml's displayFont if you want something different." },
        { h: "Share a bug report",
          b: "Open Settings → Weather Station → tick 'Show debug / diagnostic info' → click 'Copy All'. Paste the block into your bug report — it contains everything needed to diagnose API issues." }
    ]

    contentItem: ColumnLayout {
        spacing: 6

        TabBar {
            id: bar
            Layout.fillWidth: true
            TabButton { text: "Start" }
            TabButton { text: "Tiles" }
            TabButton { text: "Controls" }
            TabButton { text: "Ham Radio" }
            TabButton { text: "Troubleshoot" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: bar.currentIndex

            HelpPage { heading: "First-run setup";    blocks: dialog.gettingStarted }
            HelpPage { heading: "Tile catalog";       blocks: dialog.tilesList }
            HelpPage { heading: "Keyboard & mouse";   blocks: dialog.controls }
            HelpPage { heading: "Ham radio features"; blocks: dialog.hamRadio }
            HelpPage { heading: "Troubleshooting";    blocks: dialog.troubleshoot }
        }
    }

    component HelpPage: ScrollView {
        id: page
        property string heading: ""
        property var blocks: []
        clip: true

        background: Rectangle { color: "transparent" }

        ColumnLayout {
            width: page.availableWidth
            spacing: 14

            Label {
                text: page.heading
                color: App.Theme.text
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.topMargin: 8
                Layout.leftMargin: 4
            }

            Repeater {
                model: page.blocks
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.preferredHeight: entryCol.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(App.Theme.accent.r, App.Theme.accent.g, App.Theme.accent.b, App.Theme.dark ? 0.06 : 0.08)
                    border.color: Qt.rgba(App.Theme.accent.r, App.Theme.accent.g, App.Theme.accent.b, 0.18)
                    border.width: 1

                    ColumnLayout {
                        id: entryCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Label {
                            text: modelData.h
                            color: App.Theme.accent
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            text: modelData.b
                            color: App.Theme.text
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 12 }
        }
    }
}
