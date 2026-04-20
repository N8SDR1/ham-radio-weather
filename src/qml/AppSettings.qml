pragma Singleton
import QtCore
import QtQuick

// Persisted user preferences — auto-saved to native store
// (Windows registry: HKCU\Software\wx-dashboard\wx-dashboard).
Settings {
    id: root

    property string callsign:   ""
    property string gridSquare: ""   // Maidenhead 4 or 6 char, e.g. "EN80"

    // Optional explicit lat/lon — overrides the grid-square-derived location
    // for precise Open-Meteo / satellite / Blitzortung queries. Leave disabled
    // to auto-compute from grid square.
    property bool   overrideLocationEnabled: false
    property real   overrideLat: 0.0
    property real   overrideLon: 0.0
    property string unitSystem: "imperial"
    property string themeMode:  "auto"
    property real   uiScale:    1.0   // 0.85 / 1.0 / 1.15 / 1.30
    // When true, each tile's header shows the canonical panel name centered
    // between the mood title (left) and the drag/menu controls (right).
    property bool   showCanonicalNames: false

    // Legal / liability — app does not operate until user accepts on first run
    property bool   disclaimerAccepted: false

    // Gentle donate-nudge tracking (one-time prompt on the 7th launch)
    property int    launchCount:       0
    property bool   donateNudgeShown:  false

    // --- Weather station selection (multi-brand support) ---
    // Supported values: "ambient" | "ecowitt" | "tempest" | "davis" | "netatmo"
    // Only "ambient" is wired to live data in the current release.
    property string stationType: "ambient"

    // Ambient Weather Network  (API + Application key)
    property string ambientAppKey: ""
    property string ambientApiKey: ""

    // Ecowitt Cloud API  (API + Application key + station MAC)
    property string ecowittApiKey: ""
    property string ecowittAppKey: ""
    property string ecowittMac:    ""
    property string ecowittLocalIp: ""   // optional LAN IP for local polling

    // WeatherFlow Tempest  (single personal access token + station id)
    property string tempestToken:     ""
    property string tempestStationId: ""

    // Davis WeatherLink v2  (API key + API secret + station id)
    property string davisApiKey:    ""
    property string davisApiSecret: ""
    property string davisStationId: ""

    // Netatmo  (OAuth 2.0: client id + secret, plus tokens after auth)
    property string netatmoClientId:     ""
    property string netatmoClientSecret: ""
    property string netatmoAccessToken:  ""
    property string netatmoRefreshToken: ""

    // --- None-mode (station-less) extras ---
    // Blitzortung lightning-strike radius (km stored; UI converts to user's
    // preferred unit). Applies only in stationType == "none".
    property real   lightningRadiusKm:  160.9      // ~100 mi default
    // Comma-separated region codes. Default covers the Americas;
    // Europe=1, Oceania=2, East Asia=4, Africa/SW Asia=5, South America=6.
    property string blitzortungRegions: "7,12,13"

    // Weather-alerts polling cadence, in minutes. 0 = disabled (tile hidden).
    // Valid: 0, 5, 10, 15, 30, 45, 60.
    property int    nwsPollMinutes:     15

    // Weather-alerts provider:
    //   "nws"        — US NWS
    //   "ec"         — Environment Canada
    //   "meteoalarm" — Europe (38 countries, ATOM/CAP feed)
    //   "bom"        — Australia Bureau of Meteorology
    //   "off"        — no alerts provider (tile hidden) — default
    //
    // (Auto-detect was removed — it caused a startup hang on slow networks
    //  and obscured which feed was actually in use.)
    property string alertsProvider: "off"
    // MeteoAlarm country slug (e.g. "germany", "united-kingdom").
    // Empty = auto-detect from lat/lon.
    property string alertsCountry:  ""
    // Australian state code for BoM ("nsw", "vic", "qld", "sa", "wa", "tas", "nt", "act").
    property string alertsState:    ""

    // Panel layout state — stored as JSON strings because QtCore.Settings
    // only persists basic scalar types cleanly.
    property string panelOrderJson:  ""   // JSON array of tile ids
    property string panelHiddenJson: ""   // JSON array of hidden tile ids
    property string panelSizesJson:  ""   // JSON object: id -> "S"|"M"|"L"|"XL"
    property string alertsJson:      ""   // JSON object: ruleId -> {enabled, threshold}
    property string trackedSatsJson: ""   // JSON array of satellite names to track

    // --- helpers (not persisted) ---

    function _parse(s, fallback) {
        if (!s) return fallback
        try { return JSON.parse(s) } catch (e) { return fallback }
    }

    function getPanelOrder()   { return _parse(panelOrderJson,  []) }
    function getPanelHidden()  { return _parse(panelHiddenJson, []) }
    function getPanelSizes()   { return _parse(panelSizesJson,  ({})) }

    function setPanelOrder(arr)  { panelOrderJson  = JSON.stringify(arr || []) }
    function setPanelHidden(arr) { panelHiddenJson = JSON.stringify(arr || []) }
    function setPanelSizes(obj)  { panelSizesJson  = JSON.stringify(obj || {}) }

    function hidePanel(id) {
        var h = getPanelHidden()
        if (h.indexOf(id) === -1) { h.push(id); setPanelHidden(h) }
    }
    function showPanel(id) {
        var h = getPanelHidden().filter(function(x) { return x !== id })
        setPanelHidden(h)
    }
    function togglePanel(id, visible) { visible ? showPanel(id) : hidePanel(id) }

    function setPanelSize(id, size) {
        var s = getPanelSizes()
        s[id] = size
        setPanelSizes(s)
    }

    function movePanel(id, toIndex) {
        var order = getPanelOrder()
        var from = order.indexOf(id)
        if (from === -1) return
        order.splice(from, 1)
        order.splice(Math.max(0, Math.min(order.length, toIndex)), 0, id)
        setPanelOrder(order)
    }

    function resetLayout() {
        setPanelOrder([])
        // Intentionally do NOT reset to empty hidden list — default-hidden
        // sensor tiles (Air Quality / Soil / Leak) should stay hidden unless
        // the user explicitly enables them. Main.qml applies defaults on
        // first-run when panelHiddenJson is empty string.
        panelHiddenJson = ""
        setPanelSizes({})
    }

    // --- alerts ---
    function getAlertSettings() { return _parse(alertsJson, ({})) }
    function setAlertSettings(obj) { alertsJson = JSON.stringify(obj || {}) }
    function setAlertRule(id, enabled, threshold) {
        var s = getAlertSettings()
        s[id] = { enabled: !!enabled, threshold: Number(threshold) }
        setAlertSettings(s)
    }
    function resetAlerts() { alertsJson = "" }

    // --- tracked satellites ---
    function getTrackedSats() {
        var list = _parse(trackedSatsJson, null)
        return (list === null) ? [] : list   // empty array when never set yet
    }
    function setTrackedSats(list) { trackedSatsJson = JSON.stringify(list || []) }
    function isSatTracked(id)    { return getTrackedSats().indexOf(id) !== -1 }
    function toggleSat(id, enabled) {
        var list = getTrackedSats()
        var i = list.indexOf(id)
        if (enabled && i === -1)      list.push(id)
        else if (!enabled && i !== -1) list.splice(i, 1)
        setTrackedSats(list)
    }
    function resetTrackedSats() { trackedSatsJson = "" }
}
