# Ham Radio Weather Dashboard

A Qt6 / PySide6 desktop weather dashboard for amateur radio operators. Connects
to your Ambient Weather or Ecowitt station (or runs station-less against free
online feeds) and layers ham-specific overlays on top: HF propagation,
amateur-satellite pass prediction, lightning proximity warnings, and NOAA
geomagnetic storm indicators.

*Built by a fellow ham, for the community. Free to use, free to share.
73 de N8SDR.*

<!-- Drop a screenshot of the main dashboard here once you have one you like -->
![Dashboard screenshot](docs/screenshot-main.png)

---

## Why another weather dashboard?

Because the bundled web dashboards that ship with personal weather stations are
generic — and nothing off-the-shelf puts the lightning tile next to the HF
propagation tile next to the next-ISS-pass tile. This one does.

**Useful if you:**
- Own an Ambient (WS-2000 / WS-2902 / WS-5000 / WS-1965) or Ecowitt station
- Want a wall-mounted dashboard showing both weather and HF band conditions
- Want immediate "unplug the rig" lightning warnings tied to your actual location
- Don't own a station at all — "None" mode runs entirely on free online feeds

## Features

### Weather
- Live data from **Ambient Weather** (REST + realtime Socket.IO) or **Ecowitt Cloud API v3**
- **"None" mode** — no station required, pulls current conditions from Open-Meteo using your Maidenhead grid square
- Tiles: Outdoor, Wind (with full compass), Lightning, Rain, Indoor (Shack), Humidity, UV, Solar Radiation, Pressure
- 7-day Forecast (Open-Meteo)
- Sun/Moon (sunrise/sunset + computed moon phase)

### Ham-specific
- **HF Propagation** tile — SFI, K/A index, 8-cell band conditions grid, NOAA G-scale geomagnetic storm badge (data via hamqsl.com)
- **Space Weather** tile — 72-hour planetary-Kp forecast from NOAA SWPC with peak prediction and 24-bar 3-hour forecast chart; pairs with HF Propagation (now vs next 3 days)
- **Amateur Satellite passes** — tracks 13 active birds (ISS, AO-7, AO-73, SO-50, RS-44, HADES-ICM, and more) using Celestrak TLEs + SGP4
- **Lightning proximity warnings** — "Unplug the Rig!" when strikes are within 5 mi; None-mode users get the Blitzortung real-time global feed
- **Antenna Swayer!** mode when wind exceeds 50 mph
- **Weather Alerts** — NWS (US), Environment Canada, MeteoAlarm (Europe), or Australian BoM — pick your region

### UX
- Dark / light / auto theme (follows OS)
- °F / °C toggle
- Mood titles that change with data (Deep Freeze → Scorcher, Dry as a Bone → Biblical, etc.)
- Drag-to-reorder tiles with before/after insertion and empty-space drop
- Per-tile size controls (Small / Medium / Large / XL)
- Per-tile hide/show in Settings
- Configurable alert thresholds (heat, freeze, high wind, lightning nearby, low humidity/fire weather, etc.)
- Configurable satellite tracking list
- Built-in Help guide and About with support link

### Architecture
- Qt6 / PySide6 desktop application (Windows, macOS, Linux)
- QML for UI, Python for data adapters
- Settings persist to native store (Windows registry / macOS plist / Linux INI)
- Build chain produces a one-click Windows installer (Inno Setup)

## Installation

### Windows (end users)

1. Download the latest `HamRadioWeather-Setup-X.Y.Z.exe` from the
   [Releases](https://github.com/N8SDR1/ham-radio-weather/releases) page.
2. Run the installer (per-user install, no admin required).
3. Launch from the desktop shortcut or Start menu.
4. On first run, accept the disclaimer.
5. Open **Settings ⚙** → **Weather Station** and either:
   - Pick **Ambient** / **Ecowitt** and enter your API keys, *or*
   - Pick **None — no local station (use online sources)** and set your
     Maidenhead grid square in Settings → Operator.
6. Restart if you changed station type — the "Live" badge in the header
   should turn green within a few seconds.

### macOS / Linux

Binary installers are Windows-only for now. To run from source, see below.

## Run from source

Requires **Python 3.11 or newer** (3.13 recommended; 3.14 works but watch
PyInstaller wheel availability).

```bash
git clone https://github.com/N8SDR1/ham-radio-weather.git
cd ham-radio-weather
python -m venv .venv
.venv\Scripts\activate              # Windows
# source .venv/bin/activate         # macOS / Linux
pip install -r requirements.txt
python src/main.py
```

Optional: copy `.env.example` to `.env` and drop in your Ambient Weather API
keys. They can also be entered through the Settings dialog at runtime.

## Build the installer (Windows)

```bash
.venv\Scripts\activate
build.bat
```

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php) installed for the
final installer step. Without it, the standalone bundle at
`dist\HamRadioWeather\` still runs.

## Data sources

| Source | Used for | Auth |
|---|---|---|
| Ambient Weather Network | Your Ambient station | App key + API key |
| Ecowitt Cloud API v3 | Your Ecowitt station | App key + API key + station MAC |
| [Open-Meteo](https://open-meteo.com) | Forecast + None-mode current weather | None |
| [HamQSL](https://www.hamqsl.com) | Solar flux, K/A index, band conditions | None |
| [NOAA SWPC](https://services.swpc.noaa.gov) | 72-hour planetary-Kp forecast | None |
| [Celestrak](https://celestrak.org) | Amateur satellite TLEs | None |
| [Blitzortung](https://www.blitzortung.org) | Real-time global lightning (None mode) | None |
| [NWS](https://api.weather.gov) / Environment Canada / MeteoAlarm / BoM | Weather alerts by region | None |

Planned: Ecowitt LAN polling (direct `get_livedata_info` calls, no cloud).

## Supported hardware

Currently wired end-to-end:
- Ambient WS-2000, WS-2902, WS-5000, WS-1965 (anything that reports to ambientweather.net)
- Ecowitt Wittboy, GW1100, HP2551, HP2564 (anything with the GW / HP gateways)

Planned roadmap:
- **v1.0.9** WeatherFlow Tempest (personal access token, UDP local broadcasts)
- **v1.1.0** Davis Instruments (WeatherLink v2 HMAC-signed REST + local HTTP)
- **v1.1.1** Netatmo (OAuth 2.0)

## Support this project

It's free, and it always will be. But if it's useful around your shack, a
coffee helps keep the code flowing.

**[☕ Buy me a coffee — PayPal](https://www.paypal.com/donate/?business=NP2ZQS4LR454L&no_recurring=0&item_name=Built+by+a+fellow+ham%2C+for+the+community.++Free+to+use%2C+free+to+share.+A+small+donation+keeps+the+code+flowing.+73+de+N8SDR&currency_code=USD)**

## Disclaimer

All data is informational only. **Do not rely on this app as a primary safety
system.** For weather emergencies, lightning avoidance, or station protection,
consult official weather services (NWS in the US) and your own judgment. The
"Unplug the Rig!" indicator is a convenience alert, not a substitute for
proper station grounding and surge protection.

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 N8SDR · Rick Langford.

## Author

**Rick Langford · N8SDR**  
Ham radio operator, Hamilton OH.  
Also author of [SDRLogger+](https://github.com/N8SDR1/) (amateur-radio QSO
logger with POTA, satellite tracking, and propagation forecasting).

73 to all.
