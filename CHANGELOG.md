# Changelog

All notable changes to Ham Radio Weather Dashboard are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.10] — 2026-04-21

### Added — Ecowitt feature parity
- **Ecowitt history plumbing** — `EcowittClient` now pulls 24 hours of 5-minute history from `api.ecowitt.net/api/v3/device/history` every 20 minutes, pivots the nested response into the same newest-first record shape `AmbientClient` produces, and feeds the same `_compute_history_derived()` logic. Ecowitt users now get the full Tier-1 experience: **24-hour sparklines** on Outdoor / Humidity / Pressure tiles, **3-hour pressure trend arrow**, and the **"From Yesterday" humidity delta**. Parity with Ambient at last.

### Added — Tile Personality (user-configurable mood thresholds)
New **Settings → Tile Personality** section. Every user-facing mood trigger is now tunable. Defaults match v1.0.9 behavior; change them to suit your climate and shack.
- **Outdoor**: Fire ≥ X °F, Ice ≤ X °F (drive both the tile color palette and the fire/ice halo)
- **Shack (Indoor)**: Hell Mode ≥ X °F, Heating ≥ X °F, Frozen Shack ≤ X °F (with warning label when the ladder gets out of order)
- **Lightning**: "Unplug the Rig!" panic distance (shared with the Lightning Nearby alert threshold so the mood and alert stay in lockstep)
- **Wind**: "Antenna Swayer!" gust threshold (drives both the mood title flip and the needle wobble)

### Added — Dramatic mood effects
Reach-for-your-screenshot moments when conditions get spicy. Every effect has a **"Preview effects"** force toggle in the same Settings panel so you can see them on a calm day without waiting for weather.
- **🔥 Fire** — flickering yellow/orange/red halo + orange digits on Outdoor and Shack tiles when hot. Irregular color/blur cycle (~1.3 s) reads as a live flame.
- **🧊 Ice** — slower cyan/white pulse + blue digits for Deep Freeze / Frozen Shack. Glaciers don't twitch.
- **⚡ Lightning** — when strikes are within panic distance:
  - **Three zigzag bolts** (lavender stroke, indigo halo) flash behind the tile with different cycle lengths (10 / 12 / 15 s) so they naturally phase in and out of alignment — sometimes a lone bolt, sometimes two overlap briefly, sometimes quiet.
  - **Strike count scale punch + horizontal jitter + afterglow-white strobe** on the big number. Panic title rotates every 2.2 s through "Unplug the Rig!" → "NO SERIOUSLY UNPLUG" → "⚡ THE RIG! ⚡" → "SAVE YOURSELF" → "The antenna! THE ANTENNA!".
- **💧 Rain** — 5 independent drop lanes, each with its own re-seeded cycle (x position, fall time, rest period, horizontal wind-drift) so drops hit irregular spots at irregular intervals. Splashes fan outward at the bottom of the tile. **Animation speed scales with the actual hourly rain rate** (sprinkle = slow drift, clamped at 0.75 in/hr = frantic downpour).
- **📡 Antenna Swayer** — wind-direction needle flutters ±5° with an irregular sequence when gusts cross the threshold. Doesn't fight the smooth direction tracking.
- **☀ Sunburst** — 12 ray spokes slowly rotating behind the Solar tile's number when W/m² ≥ 900 (Supernova). Each ray breathes independently for a shimmering effect.
- **🥵 Heat wave** — upward-drifting red horizontal bands + tiny horizontal shimmer on the digit when UV ≥ 11 (Face Melter).
- **📻 HF static** — drifting red scanline overlay on the HF Propagation tile during G3+ geomagnetic storms (K-index ≥ 7). Subtle interference that reads as "bands are degraded".
- **🛰 Sat countdown pulse** — gentle opacity + scale breathing on the countdown label when the next satellite pass is within 10 minutes.
- **🌌 Aurora** — slow-drifting green + violet gradient ribbons in the Space Weather tile background at G4/G5 (peak Kp ≥ 8).

### Technical
- New reusable `GlowEmoji` wrapper from v1.0.9 continues to serve; new effects use a combination of `QML.Shape` + `MultiEffect` + `SequentialAnimation` patterns that can be reused across tiles.
- Signal shape for `historyUpdated` unified across Ambient + Ecowitt + NoStation — QML binds regardless of station brand.
- All preview toggles persist in QSettings but default to off on first launch.

### Known limitations
- Ecowitt history only the first time: requires up to 10 s after startup before the history-derived fields (humidity delta, pressure arrow, sparklines) appear. Normal — same behavior as Ambient.
- Pressure trend ±0.02 inHg / 3 h deadband is currently a fixed constant (not user-exposed). Left as a calibration parameter we'll tune in code if field testing shows it needs it — not something to burden users with.

## [1.0.9] — 2026-04-21

### Added
- **Historical station data** — `AmbientClient` now polls `/devices/{MAC}?limit=288` every 20 minutes, keeping a rolling 24-hour buffer of 5-minute snapshots available to the UI. Exposed to QML via `weatherClient.history` and a new `historyUpdated` signal. Foundation for every trend feature in this release and for the Trends tile coming in v1.1.0.
- **3-hour pressure trend arrow** — Pressure tile now shows a compact ▲/▼/→ badge next to the value with the signed delta (e.g. "+0.04") and a small "3 H" label. Colors: green rising, amber falling, dim steady. ±0.02 inHg deadband keeps tiny wobbles from looking like storms. Mood title now reflects reality — "Pressure · Storm Brewing ⛈" when the bottom drops out.
- **"From Yesterday" humidity delta** — the block below the big % reading now populates with a signed delta vs. ~24 h ago (▲ 4% / ▼ 3%). Previously a placeholder; now wired to real history.
- **24-hour sparklines** — tiny inline trend charts under the main value on the Outdoor, Humidity, and Pressure tiles. Canvas-rendered polyline with a small current-value dot at the right edge. Auto-scales to the 24 h min/max range per tile.
- **Sparkline settings** — Settings → Appearance now has a "Show 24 h sparkline trends" toggle plus a color picker: "Tile accent" (each tile uses its own mood color) or "Red" (all sparklines in alert red).
- **Update-available pill** in the header — pulsing green "Update v1.0.X" badge appears automatically when a newer GitHub release is published. Click to jump to the release page. One-shot check 5 s after startup; no UI if you're already on the latest.

### Changed
- **None-mode audit** — sub-elements that can't be computed without a local sensor now hide cleanly instead of showing empty placeholders:
  - Wind tile: "Today's Peak" column hidden
  - Rain tile: "Event" column + divider hidden
- **Rain · Day** in None mode now sources from Open-Meteo's `daily.precipitation_sum` (was previously always 0.00 until the current hour had rain).
- **Humidity tile**: the "From Yesterday" block is now properly gated on station mode + data-present; cleanly hidden in None mode and during the first ~10 s of startup.
- **Forecast tile icons** — replaced 🌤 (partly-cloudy-day) with ⛅ which renders with a lighter cloud on Windows' Segoe UI Emoji; applied a universal `GlowEmoji` wrapper so every forecast icon gets a subtle white halo, guaranteeing visibility against the dark theme without affecting light mode.
- **Light-mode background** deepened from `#c9cdd4` → `#b7bcc4` for better tile/background contrast; tile surfaces unchanged so tiles now pop against the deeper backdrop.
- Removed the cosmetic "From Yesterday" label row on the Humidity tile that previously floated alone when no data was available.

### Fixed
- NoStationClient now includes `daily=precipitation_sum&forecast_days=1` in its Open-Meteo query so None-mode users get real daily rainfall totals instead of a permanent 0.00.
- Stub `historyUpdated` signal added to `EcowittClient` and `NoStationClient` so QML's global `Connections { target: weatherClient }` binding doesn't log warnings regardless of selected station type.

### Technical notes
- New reusable `GlowEmoji.qml` wrapper in `src/qml/tiles/` applies a `MultiEffect` halo to any emoji Label — reach for it anywhere on the dashboard going forward, not just Forecast.
- New reusable `Sparkline.qml` component — Canvas-based polyline with configurable `values`, `lineColor`, `dotColor`, `lineWidth`, `dotRadius`, `newestFirst`. Auto-hides when fewer than 2 points or when `AppSettings.sparklinesEnabled` is off.

## [1.0.8] — 2026-04-20

### Added
- **Space Weather tile** — 72-hour planetary-Kp forecast from NOAA SWPC. Shows current Kp, upcoming peak with G-scale badge, and a 24-bar chart of predicted Kp values in 3-hour slots over the next 3 days. Pairs with HF Propagation (now) — this one tells you what's coming, so you can plan DX sessions around quiet bands and duck before storms. Mood titles lean into the ham joke: "Smooth Bands Ahead" → "G2 · Buckle Up the Beam" → "G5 · Carrington Jr!"
- Dedicated `SpaceWeatherClient` polling `services.swpc.noaa.gov` every 60 min (non-blocking startup via `QTimer.singleShot(0)`)

### Changed
- Panel name in the tile header is now nudged slightly right of center (`horizontalCenterOffset: 30`) so the mood title and canonical name coexist without elide cutting off punchlines
- "Magnetic storm" readout inside the HF Propagation tile bumped a tick larger for readability
- Space Weather legend and day labels (Today / +1 day / +2 days) use larger, higher-contrast typography and bigger color swatches

### Fixed
- Space Weather parser now handles both new (array-of-objects) and legacy (array-of-arrays + header row) SWPC JSON shapes — SWPC changed format and the original parser was skipping every row

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
