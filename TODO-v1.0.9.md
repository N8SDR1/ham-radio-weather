# v1.0.9 — SHIPPED

All items moved to `CHANGELOG.md` under `## [1.0.9] — 2026-04-21`.

## Completed in v1.0.9

- [x] **UI fixes** — Humidity "From Yesterday" restored & gated; Forecast
      partly-cloudy icon contrast (🌤 → ⛅) + universal `GlowEmoji` halo;
      light-mode background deepened for better tile contrast.
- [x] **None-mode audit** — Wind "Today's Peak" hidden, Rain "Event"
      hidden, Rain "Day" sourced from Open-Meteo daily precipitation.
- [x] **Historical API plumbing** — `AmbientClient.fetch_history()`, MAC
      capture, 20-min QTimer, `historyUpdated` signal, QML-visible
      properties, stub signals on Ecowitt/NoStation.
- [x] **Tier-1 trend consumers** — `humidityFromYesterday` computed from
      history, populates the restored humidity-delta block; `pressureTrend3h`
      computed, drives new ▲/▼/→ badge on Pressure tile with signed delta
      and "3 H" label; real pressure moods (Storm Brewing ⛈, Rising Fast 📈).
- [x] **24-hour sparklines** on Outdoor, Humidity, Pressure tiles — reusable
      `Sparkline.qml` Canvas component, auto-scales to 24 h min/max.
- [x] **Sparkline settings** — on/off toggle + Tile accent / Red color
      picker in Settings → Appearance. Persists across restarts.
- [x] **Update-pill** in header — pulsing green "Update v1.0.X" badge
      when GitHub has a newer release; auto-check 5 s after startup.

---

# Carried forward (target: v1.0.10 / v1.1.0)

Items originally listed for v1.0.9 that were deliberately deferred or
never needed after scope review. Create a fresh `TODO-v1.0.10.md` or
`TODO-v1.1.0.md` from this block when starting the next release.

## Trends / history (Tier 2 — target v1.1.0)

- [ ] **Dedicated "Trends" tile** — L-sized with multi-series line chart
      (Temp / Humidity / Pressure / Wind). Time-range chips (1h / 6h /
      24h / 48h / 7d) — NOT a scrolling scrollbar. Hover crosshair +
      tooltip. Flag `requiresLocalStation: true` in TileCatalog so it
      auto-hides in None mode.
- [ ] **Ecowitt history** — implement `fetch_history()` on `EcowittClient`
      using `/api/v3/device/history` so Ecowitt users get the same
      Tier-1 trend features Ambient users already have.
- [ ] **Self-computed peak wind / gust** — deferred in v1.0.9 because
      Ambient's vendor-provided `maxdailygust` is reliable. Revisit if
      Tempest / Davis / Netatmo turn out to have flaky peak fields.

## Trends / history (Tier 3 — stretch, post-v1.1.0)

- [ ] Full-history drill-down dialog (⋯ menu → "Open full history…") with
      pinch/drag-to-zoom time axis, date picker, CSV export, per-sensor
      toggles.

## New station brands

- [ ] **WeatherFlow Tempest** — personal access token + UDP local
      broadcasts. Implements the standard flat-schema translation.
- [ ] **Ecowitt LAN polling** — direct `get_livedata_info` calls. Client
      already accepts `local_ip` but the code path is stubbed.
- [ ] **Davis WeatherLink v2** — HMAC-signed REST + local HTTP.
- [ ] **Netatmo** — OAuth 2.0 flow.

## Distribution

- [ ] **Cross-platform installers via GitHub Actions** — three-matrix
      workflow (windows-latest / macos-latest / ubuntu-latest). Mac needs
      Apple Dev code-signing or Gatekeeper will warn; Linux path of least
      resistance is AppImage via `appimagetool`.

## Stretch

- [ ] **Radar tile** — stretch goal.
- [ ] **Fog icon (🌫) contrast** — borderline on dark backgrounds. Leave
      alone unless user reports it's actually hard to read in real use.
      Universal `GlowEmoji` wrapper is already available if needed.

---

## When ready to tag the next release

Same flow as 1.0.8 / 1.0.9:

1. Work through items above (or a focused subset — don't try to ship everything).
2. Bump version in four places: `src/main.py` (`APP_VERSION`),
   `src/qml/AppVersion.qml`, `installer.iss`, `build.bat` final echo line.
3. Add a new `## [X.Y.Z]` section at the top of `CHANGELOG.md`, moving
   completed items from this file into it.
4. `build.bat` to produce the installer.
5. Smoke-test, then tag + push + GitHub release (web UI or `gh` CLI).
