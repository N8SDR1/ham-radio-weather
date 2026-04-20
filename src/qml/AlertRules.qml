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
    //   [{id, label, icon, severity, value, threshold, comparator, unit}, ...]
    function evaluate(data, settings) {
        var out = []
        if (!data) return out
        var sevOrder = { "warning": 0, "watch": 1, "info": 2 }

        for (var i = 0; i < catalog.length; i++) {
            var r = catalog[i]
            var s = settings && settings[r.id] ? settings[r.id] : {}
            var enabled = s.enabled !== undefined ? s.enabled : r.defaultEnabled
            if (!enabled) continue
            var threshold = s.threshold !== undefined ? Number(s.threshold) : r.defaultThreshold

            // Lightning-specific: only alert if distance is reported AND there was a strike today.
            if (r.id === "lightningNear") {
                var dist = data.lightning_distance
                var cnt  = data.lightning_day || 0
                if (dist === undefined || dist === null || cnt === 0) continue
                if (_cmp(r.comparator, Number(dist), threshold)) {
                    out.push({ id: r.id, label: r.label, icon: r.icon,
                               severity: r.severity, value: Number(dist),
                               threshold: threshold, comparator: r.comparator, unit: r.unit })
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
