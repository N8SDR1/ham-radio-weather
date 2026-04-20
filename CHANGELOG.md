# Changelog

All notable changes to Ham Radio Weather Dashboard are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.7] — 2026-04-20

### First public release

#### Weather station support
- **Ambient Weather Network** — REST polling (60 s) + Socket.IO realtime stream
- **Ecowitt Cloud API v3** — 60 s polling with nested-JSON → flat-schema translation
- **"None" mode** — no station required; Open-Meteo current-weather + forecast using Maidenhead grid square
- Per-brand credential fields, status banner, "Clear Credentials" button, and debug diagnostics (raw response, flattened output, copy-to-clipboard) in Settings → Weather Station

#### Tiles
- **Outdoor** — current temp with Bahnschrift display font, glow, and mood-driven color
- **Wind** — full 360° compass with tick marks + N/E/S/W cardinal labels, live direction needle, speed gauge, and red-accent compass degrees
- **Lightning** — strike count + distance with "Unplug the Rig!" mood under 5 mi
- **Rain Fall** — rate / day / event with cylindrical-style readout
- **Shack or Hell** — indoor temp/humidity with mood tiers (Frozen Shack → Shack → Heating → Hell Mode at 85°F)
- **Humidity** — outdoor RH with mood (Desert → Swamp)
- **UV Index** — value + risk band + 12-step scale bar
- **Solar Radiation** — W/m² with gradient scale indicator
- **Pressure** — barometric with 28–31 inHg scale
- **Forecast** — 7-day via Open-Meteo
- **Sun / Moon** — sunrise/sunset + moon phase (computed locally)
- **HF Propagation** — SFI, K/A index, 8-cell band-conditions grid, NOAA G-scale geomagnetic-storm badge (pulses on G3+)
- **Satellites** — next pass + 4 upcoming; 13 active amateur birds tracked by default (ISS, AO-7, AO-27, AO-73, AO-123, FO-29, SO-50, RS-44, HADES-ICM, HADES-SA, IO-86, JO-97, NANOZOND-1)
- **Alerts** — aggregates tripped thresholds (heat, freeze, high wind, damaging gust, heavy rain, flash flood, lightning nearby, muggy, fire weather, shack overheat)
- **Air Quality / Soil Probes / Leak Detectors** — auto-hidden until sensor data is detected

#### UX
- Auto / dark / light theme with OS follow
- °F ↔ °C unit toggle
- Drag-to-reorder tiles with before/after half-drop and empty-space snap
- Per-tile S/M/L/XL sizing (minimum sizes enforced per tile to prevent overflow)
- Uniform 300 px tile height across the grid
- Active-source badge in header (ONLINE / AMBIENT / ECOWITT / etc.)
- Battery status indicator in header (auto-hidden in "None" mode)
- Pulsing alert badge in header
- Dynamic mood titles ("Deep Freeze", "Scorcher", "Dry as a Bone", "Antenna Swayer!", "Hell Mode", "DX Paradise", and more)
- Optional canonical-name subtitle in tile headers (Settings → UI Size)
- Hover tooltips on icon badge (panel name) and drag handle (reorder instructions)
- Platform-aware display font (Bahnschrift / Helvetica Neue / Roboto Condensed)
- UI scale presets (85% / 100% / 115% / 130%)

#### Settings
- Operator: callsign, Maidenhead grid square, optional lat/lon override
- Alerts: 10 configurable threshold rules
- Panels: per-tile visibility + size
- Satellites: 13 default / 20 total amateur birds with checkbox selection
- Battery Status: live per-sensor read-out
- Help guide (5-tab) and About dialog

#### Legal
- First-run disclaimer blocks app use until accepted
- Clear "informational only" messaging throughout

#### Build & distribution
- PyInstaller one-folder bundle
- Inno Setup Windows installer with custom icon
- `build.bat` one-click pipeline
- Silent `pythonw.exe` launcher (`run.bat`) — no console window
- Custom logo with auto-transparent-background generation via Pillow

#### Hidden polish
- MultiEffect-based glow on display numerics
- SGP4-based satellite propagation with word-boundary fuzzy TLE name matching
- Automatic PM2.5/CO₂/soil/leak sensor detection and tile activation
- Gentle one-time donate nudge on 7th launch
- "Buy me a coffee" button in header with warm-amber styling

### Known limitations
- Installer is Windows-only (macOS/Linux from-source only for now)
- Tempest / Davis / Netatmo brand adapters not yet implemented
- Blitzortung lightning + NWS alerts deferred to v1.0.8 (will be station-less-mode features)
- Ecowitt LAN polling deferred to v1.0.8 (Cloud works today)

---

## Legend

- `[Major.Minor.Patch]` — release version
- Added / Changed / Fixed / Removed / Deprecated sections used on subsequent releases
