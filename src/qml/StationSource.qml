pragma Singleton
import QtQuick

// Mapping from AppSettings.stationType → user-facing label + icon + accent
// used by the active-source badge in the header.
QtObject {
    readonly property var _map: ({
        "none":    { label: "ONLINE",  icon: "🌐", color: "#4fc3f7" },
        "ambient": { label: "AMBIENT", icon: "📡", color: "#4caf50" },
        "ecowitt": { label: "ECOWITT", icon: "🌀", color: "#7c4dff" },
        "tempest": { label: "TEMPEST", icon: "🌪", color: "#ff8a65" },
        "davis":   { label: "DAVIS",   icon: "📊", color: "#ffb74d" },
        "netatmo": { label: "NETATMO", icon: "🏠", color: "#4dd0e1" }
    })

    readonly property var fallback: { "label": "UNKNOWN", "icon": "❓", "color": "#8892a8" }

    function info(kind) {
        var k = (kind || "ambient").toLowerCase()
        return _map[k] || fallback
    }

    // True when the station type never provides indoor sensors / batteries /
    // local lightning readings. Used to auto-hide related UI elements.
    function isOnlineOnly(kind) {
        return (kind || "").toLowerCase() === "none"
    }
}
