import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real rate:  data.hourlyrainin !== undefined ? data.hourlyrainin : 0
    readonly property real day:   data.dailyrainin  !== undefined ? data.dailyrainin  : 0
    readonly property real event: data.eventrainin  !== undefined ? data.eventrainin  : 0

    readonly property var _mood: App.Moods.rain(day)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: App.Theme.rain

    implicitHeight: 280

    // EVENT (since-rain-started) is a station-stateful value — Open-Meteo
    // has no equivalent, so the column is hidden in None mode.
    readonly property bool _showEvent: !App.StationSource.isOnlineOnly(App.AppSettings.stationType)

    // Is the rain effect currently visible? When the rain rate is > 0 OR
    // the dev-test force toggle is on. Stays hidden when dry so the tile
    // shows a calm big number.
    readonly property bool _raining:
        App.AppSettings.effectForceRain || rate > 0

    // --- Rate → animation speed mapping ------------------------------
    // The animation intensity scales with the actual hourly rain rate so
    // a sprinkle looks like a sprinkle and a downpour looks like a
    // downpour, with a hard cap beyond which speed doesn't increase
    // further (past a certain point, "more rain" no longer reads
    // visually — the tile is already maxed out).
    //
    // RATE_MAX: inches/hour at which the rain animation hits maximum
    // speed + minimum rest. 0.75 in/hr is honest "heavy rain" territory;
    // anything above is a downpour and just clamps here.
    readonly property real _rateMax: 0.75
    readonly property real _rateFactor: {
        // When the dev-test force toggle is on and there's no real rain,
        // fake a light-sprinkle rate (~0.08 in/hr) so the preview shows
        // the slow end of the scale.
        if (rate <= 0 && App.AppSettings.effectForceRain) return 0.08 / _rateMax
        return Math.max(0, Math.min(1, rate / _rateMax))
    }
    // Small linear-interpolation helper for the delegate's reseed logic.
    function _lerp(a, b, t) { return a + (b - a) * t }

    // Animated rain layer — drops fall from above the tile to the
    // bottom where they splash out in a brief fading ellipse. Each
    // delegate owns one full vertical track (drop + splash) so the
    // splash stays horizontally aligned with its drop.
    Item {
        id: rainLayer
        anchors.fill: parent
        anchors.margins: 4
        z: -1
        visible: root._raining
        clip: true

        Repeater {
            model: 5
            delegate: Item {
                id: dropItem

                // Mutable properties reseeded at the top of every cycle
                // so each drop lands at a new x, with its own fall speed
                // and its own rest period. Net effect: drops hit
                // irregular spots at irregular intervals.
                property real _xSeed:   Math.random()   // 0..1 across full tile
                property int  _fallMs:  8000
                property int  _pauseMs: 3000
                property real _drift:   0                // px of horizontal sway during fall
                readonly property real _len: 22 + Math.random() * 10
                readonly property real _opa: 0.45 + Math.random() * 0.25
                readonly property int  _initialDelay: Math.floor(Math.random() * 10000)

                // Re-randomizes x, fall time, pause time, and sway on
                // every cycle so consecutive drops from the same lane
                // never repeat. Fall and pause durations are derived
                // from the parent tile's `_rateFactor` (0 = sprinkle,
                // 1 = clamped heavy) so the animation intensity tracks
                // the actual hourly rain rate. Math.random() is fresh
                // each call.
                function _reseed() {
                    _xSeed = Math.random()
                    var f = root._rateFactor
                    // Slower base at sprinkle rates, faster base at heavy.
                    // Variance also shrinks at high rate — downpours look
                    // more uniformly frantic, sprinkles more irregular.
                    var fallBase  = root._lerp(12000, 2500, f)   // 12.0 s → 2.5 s
                    var fallRange = root._lerp( 6000, 2000, f)
                    _fallMs  = Math.floor(fallBase + Math.random() * fallRange)
                    var pauseBase  = root._lerp(3500, 200, f)    // 3.5 s → 0.2 s
                    var pauseRange = root._lerp(5000, 800, f)
                    _pauseMs = Math.floor(pauseBase + Math.random() * pauseRange)
                    // ±8 px sideways drift during fall — simulates the
                    // drop catching a breath of wind on the way down.
                    _drift = (Math.random() - 0.5) * 16
                }

                Component.onCompleted: _reseed()

                width:  20
                height: rainLayer.height
                // x is bound to _xSeed so reseeding jumps the whole lane
                // instantly. Because the drop is off-screen (y = -height)
                // at reseed time, the jump is invisible to the user.
                x: _xSeed * (rainLayer.width - width)

                Rectangle {
                    id: drop
                    width:  3
                    height: dropItem._len
                    radius: 1.5
                    color:  App.Theme.rain
                    opacity: dropItem._opa
                    // Base-centered in the lane, plus a per-cycle drift
                    // that eases in during the fall so the drop appears
                    // to drift on an angle rather than straight down.
                    x: (dropItem.width - width) / 2
                    y: -height

                    SequentialAnimation on y {
                        running: rainLayer.visible
                        loops:   Animation.Infinite

                        PauseAnimation  { duration: dropItem._initialDelay }
                        ScriptAction    { script: dropItem._reseed() }
                        NumberAnimation { to: rainLayer.height - drop.height - 2
                                          duration: dropItem._fallMs
                                          easing.type: Easing.InQuad }
                        ScriptAction    { script: splashAnim.restart() }
                        PropertyAction  { value: -dropItem._len }
                        PauseAnimation  { duration: dropItem._pauseMs }
                    }

                    // Parallel sideways drift during the fall — runs in
                    // its own timeline so it doesn't fight the main y
                    // animation. Snaps back to center during the rest
                    // period so the next cycle starts cleanly.
                    SequentialAnimation on x {
                        running: rainLayer.visible
                        loops:   Animation.Infinite
                        PauseAnimation  { duration: dropItem._initialDelay }
                        // Slight "loading" delay so drift starts after the
                        // drop becomes visible at the top
                        PauseAnimation  { duration: 50 }
                        NumberAnimation {
                            to: (dropItem.width - drop.width) / 2 + dropItem._drift
                            duration: dropItem._fallMs - 50
                            easing.type: Easing.InOutSine
                        }
                        // Snap back to center for the next cycle
                        PropertyAction { value: (dropItem.width - drop.width) / 2 }
                        PauseAnimation { duration: dropItem._pauseMs }
                    }
                }

                // Splash — wider fading ellipse to match the bigger drops
                Rectangle {
                    id: splash
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  6
                    height: 3
                    radius: 1.5
                    color:  App.Theme.rain
                    opacity: 0
                    scale:   1

                    ParallelAnimation {
                        id: splashAnim
                        NumberAnimation { target: splash; property: "opacity"
                                          from: 0.80; to: 0; duration: 650 }
                        NumberAnimation { target: splash; property: "scale"
                                          from: 1; to: 7.0; duration: 650
                                          easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        RainStat { label: "RATE";  valueIn: root.rate;  suffix: "/hr"; Layout.fillWidth: true; Layout.fillHeight: true }
        Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 10; Layout.bottomMargin: 10 }
        RainStat { label: "DAY";   valueIn: root.day;   Layout.fillWidth: true; Layout.fillHeight: true }
        Rectangle {
            visible: root._showEvent
            width: 1; Layout.fillHeight: true; color: App.Theme.border
            Layout.topMargin: 10; Layout.bottomMargin: 10
        }
        RainStat {
            visible: root._showEvent
            label: "EVENT"; valueIn: root.event
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }

    component RainStat: ColumnLayout {
        property string label: ""
        property real valueIn: 0
        property string suffix: ""
        spacing: 2

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: parent.label
            color: App.Theme.textFaint
            font.pixelSize: 11
            font.letterSpacing: 1.0
            font.weight: Font.Bold
        }
        Item { Layout.fillHeight: true }
        BigNumber {
            Layout.alignment: Qt.AlignHCenter
            text: App.Units.fmt(App.Units.rainIn(parent.valueIn), 2)
            color: parent.valueIn > 0 ? root.accentColor : App.Theme.text
            glowColor: root.accentColor
            glowOpacity: parent.valueIn > 0 ? 0.85 : 0.3
            pixelSize: 40
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: App.Units.rainUnit() + parent.suffix
            color: App.Theme.textDim
            font.pixelSize: 12
        }
        Item { Layout.fillHeight: true }
    }
}
