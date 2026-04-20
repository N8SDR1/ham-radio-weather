pragma Singleton
import QtQuick

QtObject {
    id: theme

    // modes: "auto" | "light" | "dark"
    property string mode: "auto"

    readonly property bool dark: {
        if (mode === "light") return false
        if (mode === "dark")  return true
        return Qt.styleHints.colorScheme === Qt.Dark
    }

    // — Surfaces —
    readonly property color bg:         dark ? "#070a14" : "#c9cdd4"
    readonly property color bgAccent:   dark ? "#0d1220" : "#bfc4cc"
    readonly property color surface:    dark ? "#121826" : "#dde1e7"
    readonly property color surfaceTop: dark ? "#1a2336" : "#e4e7ec"
    readonly property color surfaceBot: dark ? "#0f1624" : "#d5d9e0"
    readonly property color border:     dark ? "#1f2a3f" : "#a0a6b0"
    readonly property color glow:       dark ? "#1a2a44" : "#b4bbc4"

    // — Text — (bolder/brighter than before)
    readonly property color text:       dark ? "#f4f6fa" : "#12161c"
    readonly property color textDim:    dark ? "#b0bacb" : "#2e343f"   // was too faint; now readable
    readonly property color textFaint:  dark ? "#94a0b5" : "#4a525e"

    // — Accent palette: two tuned sets per mode —
    // Used for tile accent strips, gauge fills, mood colors.
    readonly property color accent:     dark ? "#4fc3f7" : "#0277bd"   // cyan
    readonly property color accent2:    dark ? "#7c4dff" : "#4527a0"   // violet
    readonly property color hot:        dark ? "#ff6e40" : "#c1380f"   // warm
    readonly property color hotGlow:    dark ? "#ff3d00" : "#b71c1c"
    readonly property color cold:       dark ? "#42a5f5" : "#0d47a1"   // cool
    readonly property color coldGlow:   dark ? "#1976d2" : "#0d47a1"
    readonly property color accentGlow: dark ? "#0288d1" : "#01579b"
    readonly property color good:       dark ? "#4caf50" : "#1b5e20"
    readonly property color warn:       dark ? "#ffb74d" : "#e65100"
    readonly property color bad:        dark ? "#ef5350" : "#b71c1c"
    readonly property color lightning:  dark ? "#ffd54f" : "#ef6c00"   // amber → deeper orange in light
    readonly property color rain:       dark ? "#4dd0e1" : "#00695c"
    readonly property color shackHue:   dark ? "#b388ff" : "#4a148c"

    // — HF band condition colors (used by HF Propagation tile) —
    readonly property color bandExcellent: dark ? "#39ff14" : "#1b5e20"
    readonly property color bandGood:      dark ? "#3a7a40" : "#2e7d32"
    readonly property color bandFair:      dark ? "#b9881f" : "#ef6c00"
    readonly property color bandPoor:      dark ? "#8a3a2f" : "#b71c1c"
    readonly property color bandClosed:    dark ? "#2a3140" : "#616161"

    function bandColor(condition) {
        var c = (condition || "").toLowerCase()
        if (c.indexOf("excel") === 0)  return bandExcellent
        if (c.indexOf("good") === 0)   return bandGood
        if (c.indexOf("fair") === 0)   return bandFair
        if (c.indexOf("poor") === 0)   return bandPoor
        return bandClosed
    }

    // UV index band colors
    function uvColor(uv) {
        if (uv === undefined || uv === null) return textDim
        if (uv < 3)  return dark ? "#4caf50" : "#1b5e20"
        if (uv < 6)  return dark ? "#ffb300" : "#e65100"
        if (uv < 8)  return dark ? "#ff6f00" : "#bf360c"
        if (uv < 11) return dark ? "#e53935" : "#b71c1c"
        return dark ? "#8e24aa" : "#4a148c"
    }

    readonly property int  tilePad:    18
    readonly property int  tileRadius: 18
    readonly property int  gap:        14

    readonly property string fontFamily: Qt.application.font.family
    // Platform-aware display font for big dashboard numerics.
    // Windows ships Bahnschrift. macOS has Helvetica Neue. Linux distros
    // typically ship Roboto Condensed (or fall back to sans).
    readonly property string displayFont: {
        if (Qt.platform.os === "windows") return "Bahnschrift"
        if (Qt.platform.os === "osx" || Qt.platform.os === "macos") return "Helvetica Neue"
        return "Roboto Condensed"
    }

    // Global UI scale — applied as a transform on the main grid in Main.qml.
    // Scales every tile's text/spacing/padding uniformly.
    property real uiScale: 1.0
}
