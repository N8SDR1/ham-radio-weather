pragma Singleton
import QtQuick

// Rule catalog + evaluation. Each rule:
//   id           — unique string key
//   label        — human-readable name
//   icon         — emoji
//   severity     — "warning" | "watch" | "info"  (maps to red / amber / blue)
//   defaultEnabled
//   defaultThreshold
//   unit         — display suffix for the threshold
//   comparator   — ">=" | "<=" | "=="
//   field        — key in Ambient `latest` (or "forecast" for forecast-based)
//   format(v)    — optional formatter for the current value
QtObject {
    id: root

    // --- Lightning-Nearby sticky state --------------------------------
    // The Ambient / Blitzortung `lightning_distance` field reflects the
    // distance of the most recent strike, which can bounce around wildly
    // during a live storm (one strike at 3 mi, the next at 15 mi). If
    // the alert cleared the moment a further strike landed, operators
    // would see the warning flicker off while lightning is still
    // actively striking the area.
    //
    // Solution: once any strike lands within the threshold, keep the
    // alert active for `stickyMs` milliseconds afterward — a grace
    // window that better matches real storm behavior. User-tunable via
    // AppSettings.alertLightningStickyMin (minutes), defaulting to 15.
    property real _lightningNearbyUntilMs: 0
    property real _lightningNearbyLastDist: 0

    readonly property var catalog: [
        { id: "heat",          label: "Heat Warning",        icon: "🥵",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 95,  unit: "°F",
          comparator: ">=",    field: "tempf",        kind: "number" },

        { id: "freeze",        label: "Hard Freeze",         icon: "🥶",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 20,  unit: "°F",
          comparator: "<=",    field: "tempf",        kind: "number" },

        { id: "highWind",      label: "High Wind",           icon: "💨",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 40,  unit: "mph",
          comparator: ">=",    field: "windspeedmph", kind: "number" },

        { id: "damagingGust",  label: "Damaging Gust",       icon: "🌪",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 58,  unit: "mph",
          comparator: ">=",    field: "windgustmph",  kind: "number" },

        { id: "heavyRain",     label: "Heavy Rain Rate",     icon: "🌧",
          severity: "watch",   defaultEnabled: true,  defaultThreshold: 1.0, unit: "in/hr",
          comparator: ">=",    field: "hourlyrainin", kind: "number" },

        { id: "floodRain",     label: "Flash Flood Risk",    icon: "🌊",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 3.0, unit: "in/day",
          comparator: ">=",    field: "dailyrainin",  kind: "number" },

        { id: "lightningNear", label: "Lightning Nearby",    icon: "⚡",
          severity: "warning", defaultEnabled: true,  defaultThreshold: 5,   unit: "mi",
          comparator: "<=",    field: "lightning_distance", kind: "number",
          requiresStrike: true },

        { id: "muggy",         label: "Muggy Air",           icon: "💦",
          severity: "info",    defaultEnabled: true,  defaultThreshold: 70,  unit: "°F",
          comparator: ">=",    field: "dewPoint",     kind: "number" },

        { id: "lowHumidity",   label: "Fire Weather / Dry",  icon: "🔥",
          severity: "watch",   defaultEnabled: true,  defaultThreshold: 20,  unit: "%",
          comparator: "<=",    field: "humidity",     kind: "number" },

        { id: "shackHot",      label: "Shack Overheating",   icon: "😈",
          severity: "watch",   defaultEnabled: true,  defaultThreshold: 90,  unit: "°F",
          comparator: ">=",    field: "tempinf",      kind: "number" }
    ]

    function getRule(id) {
        for (var i = 0; i < catalog.length; i++)
            if (catalog[i].id === id) return catalog[i]
        return null
    }

    function _cmp(comparator, a, b) {
        if (comparator === ">=") return a >= b
        if (comparator === "<=") return a <= b
        if (comparator === "==") return a === b
        return false
    }

    // Evaluate all enabled rules against live data. Returns sorted array:
    //   [{id, label, icon, severity, value, threshold, comparator, unit,
    //     sticky}, ...]
    //
    // `options` (optional 3rd arg) supports:
    //   lightningStickyMin — minutes to hold the Lightning Nearby alert
    //                        after the last close strike (default 15).
    function evaluate(data, settings, options) {
        var out = []
        if (!data) return out
        var sevOrder = { "warning": 0, "watch": 1, "info": 2 }
        var opts = options || {}

        for (var i = 0; i < catalog.length; i++) {
            var r = catalog[i]
            var s = settings && settings[r.id] ? settings[r.id] : {}
            var enabled = s.enabled !== undefined ? s.enabled : r.defaultEnabled
            if (!enabled) continue
            var threshold = s.threshold !== undefined ? Number(s.threshold) : r.defaultThreshold

            // Lightning-specific: sticky-alert behavior. See
            // _lightningNearbyUntilMs docs above for the "why". Flow:
            //   1. If the current latest reports a strike within the
            //      threshold, (re)arm the sticky window from now.
            //   2. Emit the alert if either (a) we have a live close
            //      strike, OR (b) we're still inside a previously-armed
            //      sticky window.
            if (r.id === "lightningNear") {
                var dist = data.lightning_distance
                var cnt  = data.lightning_day || 0
                var now  = Date.now()
                var stickyMin = (opts.lightningStickyMin !== undefined)
                              ? Number(opts.lightningStickyMin) : 15
                var stickyMs  = Math.max(0, stickyMin * 60 * 1000)

                // Strike freshness — Ambient keeps reporting the LAST
                // strike's distance between strikes, so without this
                // check we'd keep re-arming the sticky window forever
                // against a stale strike. Only arm if the reported
                // strike timestamp is within the sticky window itself.
                var strikeIso  = data.lightning_time || ""
                var strikeTime = strikeIso ? new Date(strikeIso).getTime() : 0
                var strikeFresh = strikeTime > 0 && (now - strikeTime) < stickyMs

                var liveClose = dist !== undefined && dist !== null && cnt > 0
                              && _cmp(r.comparator, Number(dist), threshold)

                // Live fresh close strike → (re)arm the sticky window
                if (liveClose && strikeFresh) {
                    root._lightningNearbyLastDist = Number(dist)
                    root._lightningNearbyUntilMs  = now + stickyMs
                }

                // Decide whether to emit the alert
                var stickyActive = now < root._lightningNearbyUntilMs
                if (liveClose && strikeFresh) {
                    out.push({ id: r.id, label: r.label, icon: r.icon,
                               severity: r.severity, value: Number(dist),
                               threshold: threshold, comparator: r.comparator,
                               unit: r.unit, sticky: false })
                } else if (stickyActive) {
                    // Hold the alert at the last known close distance
                    // until the sticky window expires.
                    out.push({ id: r.id, label: r.label, icon: r.icon,
                               severity: r.severity,
                               value: root._lightningNearbyLastDist,
                               threshold: threshold, comparator: r.comparator,
                               unit: r.unit, sticky: true })
                }
                continue
            }

            var v = data[r.field]
            if (v === undefined || v === null) continue
            var n = Number(v)
            if (isNaN(n)) continue
            if (_cmp(r.comparator, n, threshold)) {
                out.push({ id: r.id, label: r.label, icon: r.icon,
                           severity: r.severity, value: n,
                           threshold: threshold, comparator: r.comparator, unit: r.unit })
            }
        }
        out.sort(function(a, b) { return sevOrder[a.severity] - sevOrder[b.severity] })
        return out
    }

    function severityColor(sev) {
        if (sev === "warning") return "#ef5350"
        if (sev === "watch")   return "#ffb74d"
        return "#4fc3f7"
    }
}
