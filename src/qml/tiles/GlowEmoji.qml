import QtQuick
import QtQuick.Effects

// Emoji Label with a soft white halo behind it. Universal fix for Segoe UI
// Emoji glyphs whose dark-cloud fills vanish against the dark theme — the
// glow gives every icon a subtle luminous edge so it reads on any
// background. In light mode the halo is invisible (white on white), in
// dark mode it picks the icon out cleanly. No per-codepoint guesswork.
Item {
    id: root
    property string text: ""
    property int    pixelSize: 32
    property real   glowOpacity: 0.40
    property real   glowBlur: 0.55
    property color  glowColor: "white"

    implicitWidth:  iconLabel.implicitWidth  + 8
    implicitHeight: iconLabel.implicitHeight + 4

    Text {
        id: iconLabel
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: root.pixelSize
        // Emoji fonts ignore `color`; keeping this so non-emoji fallback
        // (❓) still shows up in the right tone.
        color: "white"
    }

    MultiEffect {
        source: iconLabel
        anchors.fill: iconLabel
        shadowEnabled: true
        shadowBlur: root.glowBlur
        shadowColor: root.glowColor
        shadowOpacity: root.glowOpacity
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }
}
