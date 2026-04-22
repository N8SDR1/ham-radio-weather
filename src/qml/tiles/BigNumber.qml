import QtQuick
import QtQuick.Effects
import "../" as App

// Reusable "display" number with the Outdoor-tile dazzle treatment:
// Bahnschrift SemiBold SemiCondensed, deep accent, thin outline, soft glow.
//
// `moodEffect` adds animated personality on top of the base glow:
//   ""       — neutral (default; static glow in `glowColor`)
//   "fire"   — flickering yellow/orange/red halo with irregular breathing
//              for Scorcher / Melt Mode / Hell Mode territory
//   "ice"    — slower pulsing cyan/white halo for Deep Freeze / Frozen Shack
//   "strobe" — fast bright-white flashes for Lightning "Unplug the Rig!"
//              — the number literally strobes like a strike is landing
// Everything else (color, outline, font) stays the same so the number
// itself remains perfectly legible — the drama is all in the halo.
Item {
    id: root
    property string text: ""
    property color color: App.Theme.text
    property color glowColor: color
    property int pixelSize: 72
    property real glowOpacity: 0.85
    property bool glow: true
    property string moodEffect: ""   // "" | "fire" | "ice"

    implicitWidth:  numText.implicitWidth + 12
    implicitHeight: numText.implicitHeight + 12

    // Animated color for fire/ice; falls through to `glowColor` otherwise.
    property color _animatedGlow: glowColor
    // Animated blur for breathing / flicker; falls through to 1.0.
    property real  _animatedBlur: 1.0

    Text {
        id: numText
        anchors.centerIn: parent
        text: root.text
        color: root.color
        font.family: App.Theme.displayFont
        font.pixelSize: root.pixelSize
        font.weight: Font.Bold
        font.styleName: "SemiBold SemiCondensed"
        style: Text.Outline
        styleColor: Qt.rgba(1, 1, 1, 0.18)
        renderType: Text.NativeRendering
    }

    MultiEffect {
        source: numText
        anchors.fill: numText
        visible: root.glow
        shadowEnabled: root.glow
        shadowBlur: root._animatedBlur
        shadowColor: root.moodEffect === "" ? root.glowColor : root._animatedGlow
        shadowOpacity: root.glowOpacity
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }

    // ---- Fire flicker ------------------------------------------------
    // Irregular flicker between flame colors + a breathing blur. Timing
    // is ~1.3 s per cycle — fast enough to feel alive, slow enough to
    // not look like a broken bulb.
    SequentialAnimation {
        running: root.moodEffect === "fire"
        loops: Animation.Infinite
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ff9500"; duration: 300; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ffd54f"; duration: 260; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ff3d00"; duration: 400; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ff6e40"; duration: 300; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        running: root.moodEffect === "fire"
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.8; duration: 360; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 0.9; duration: 260; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.5; duration: 320; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.1; duration: 400; easing.type: Easing.InOutQuad }
    }

    // ---- Lightning strobe --------------------------------------------
    // Sharp white FLASH followed by a lingering amber afterglow that
    // slowly fades back to dim — the visual equivalent of "did you see
    // that bolt light up the whole sky?". Real strikes leave a retinal
    // afterimage, so the animation mirrors that arc: flash → hot glow
    // → slow cool-down → secondary flicker → settle.
    SequentialAnimation {
        running: root.moodEffect === "strobe"
        loops: Animation.Infinite
        // Dim amber baseline (the "quiet before the strike")
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ffd54f"; duration: 120 }
        PauseAnimation { duration: 1400 }

        // ⚡ STRIKE — sharp punch to near-white
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ffffff"; duration: 35 }
        // Hot afterglow — hold the bright white for a beat (the thunder)
        PauseAnimation { duration: 180 }
        // Slow cool-down through amber back toward dim — this is the
        // actual afterglow, the part that makes it feel like a real bolt
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ffb64a"; duration: 700; easing.type: Easing.OutCubic }

        // Secondary flicker a beat later — leader flash / return stroke
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#fff4c9"; duration: 40 }
        PauseAnimation { duration: 100 }
        // Final relaxation back to dim baseline
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#ff9f3a"; duration: 450; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 500 }
    }
    SequentialAnimation {
        running: root.moodEffect === "strobe"
        loops: Animation.Infinite
        // Baseline dim
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 0.9;  duration: 100 }
        PauseAnimation { duration: 1400 }

        // Flash: blur SPIKES hard
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 2.8;  duration: 35 }
        // Afterglow: blur holds elevated briefly, then glides down slowly
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 2.2;  duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.3;  duration: 700; easing.type: Easing.OutCubic }

        // Secondary flicker bump
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 2.0;  duration: 40 }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.2;  duration: 100; easing.type: Easing.OutCubic }
        // Settle
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 0.9;  duration: 450; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 500 }
    }

    // ---- Ice pulse ---------------------------------------------------
    // Steady, colder, no flicker — a glacier doesn't twitch. Cycle is
    // a touch quicker than v1.0.9 defaults so the tile feels alive
    // instead of asleep, but still clearly slower than fire.
    SequentialAnimation {
        running: root.moodEffect === "ice"
        loops: Animation.Infinite
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#b3e5fc"; duration: 900; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#4fc3f7"; duration: 900; easing.type: Easing.InOutSine }
        ColorAnimation { target: root; property: "_animatedGlow"
                         to: "#e1f5fe"; duration: 900; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        running: root.moodEffect === "ice"
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 1.4; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "_animatedBlur"
                          to: 0.9; duration: 1000; easing.type: Easing.InOutSine }
    }

    // Reset blur to the static default when the effect turns off.
    onMoodEffectChanged: {
        if (moodEffect === "") {
            _animatedBlur = 1.0
            _animatedGlow = glowColor
        }
    }
}
