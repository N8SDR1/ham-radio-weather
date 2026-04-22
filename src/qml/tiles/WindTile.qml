import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../" as App

// Note: the "Antenna Swayer!" mood trigger and the needle wobble both
// read from App.AppSettings.moodWindSwayerMph so the title change and
// the visual effect stay locked together.

Tile {
    id: root
    property var data: ({})

    implicitHeight: 280

    readonly property real speedMph: data.windspeedmph || 0
    readonly property real gustMph:  data.windgustmph  || 0
    readonly property real peakMph:  data.maxdailygust || 0
    readonly property real dirDeg:   data.winddir || 0
    readonly property real maxScale: 40

    // "Antenna Swayer!" kicks in off user-tunable gust threshold —
    // gusts are what actually sway an antenna, not steady wind. Falls
    // through to the regular Moods.wind() ladder (based on sustained
    // speed) for every other tier.
    readonly property bool _swayer:
        App.AppSettings.effectForceSwayer ||
        gustMph >= App.AppSettings.moodWindSwayerMph
    readonly property var _mood: App.Moods.wind(speedMph)
    title:       _swayer ? "Antenna Swayer!" : _mood.title
    iconEmoji:   _swayer ? "📡"              : _mood.icon
    accentColor: _swayer ? App.Theme.bad
               : speedMph >= 35 ? App.Theme.warn
               : App.Theme.accent

    function dirLabel(deg) {
        var names = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                     "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return names[Math.round(((deg % 360) / 22.5)) % 16]
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // compass + gauge
        Item {
            id: compass
            Layout.preferredWidth: Math.min(parent.height, 220)
            Layout.preferredHeight: Math.min(parent.height, 220)
            Layout.alignment: Qt.AlignVCenter

            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real ringR: Math.min(width, height) / 2 - 20

            // full-circle compass ring
            Rectangle {
                anchors.centerIn: parent
                width: compass.ringR * 2
                height: width
                radius: width / 2
                color: "transparent"
                border.color: App.Theme.border
                border.width: 1
            }

            // tick marks every 30° (major at 0/90/180/270)
            Repeater {
                model: 12
                delegate: Item {
                    anchors.fill: parent
                    rotation: index * 30
                    transformOrigin: Item.Center
                    Rectangle {
                        x: parent.width / 2 - width / 2
                        y: compass.cy - compass.ringR - height / 2 + 2
                        width: index % 3 === 0 ? 2 : 1
                        height: index % 3 === 0 ? 10 : 6
                        color: index % 3 === 0 ? App.Theme.text : App.Theme.textFaint
                        radius: 1
                    }
                }
            }

            // cardinal labels positioned just outside the ring
            Repeater {
                model: [
                    { angle:   0, text: "N", color: App.Theme.bad },
                    { angle:  90, text: "E", color: App.Theme.text },
                    { angle: 180, text: "S", color: App.Theme.text },
                    { angle: 270, text: "W", color: App.Theme.text }
                ]
                delegate: Label {
                    readonly property real rad: (modelData.angle - 90) * Math.PI / 180
                    x: compass.cx + Math.cos(rad) * (compass.ringR + 11) - width / 2
                    y: compass.cy + Math.sin(rad) * (compass.ringR + 11) - height / 2
                    text: modelData.text
                    color: modelData.color
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.family: App.Theme.displayFont
                }
            }

            // colored speed arc (inside the compass ring)
            GaugeRing {
                id: gauge
                anchors.centerIn: parent
                width: compass.ringR * 2 - 16
                height: width
                thickness: 8
                color: root.accentColor
                trackColor: Qt.rgba(root.accentColor.r, root.accentColor.g,
                                    root.accentColor.b, 0.12)
                value: Math.min(1, root.speedMph / root.maxScale)
            }

            // wind direction needle — clean triangular pointer, stays inside ring
            Item {
                id: needle
                anchors.centerIn: parent
                width: compass.ringR * 2
                height: width
                rotation: root.dirDeg
                Behavior on rotation { RotationAnimation { duration: 600; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic } }

                readonly property real cx: width / 2
                readonly property real cy: height / 2

                // Flutter offset applied on TOP of `rotation` via a
                // separate transform so it doesn't fight the Behavior
                // that smooths the base direction changes.
                property real wobbleAngle: 0
                transform: Rotation {
                    angle: needle.wobbleAngle
                    origin.x: needle.cx
                    origin.y: needle.cy
                }

                // Needle flutters when the tile is in Antenna Swayer
                // territory. Irregular sequence so it looks like wind,
                // not a metronome.
                SequentialAnimation on wobbleAngle {
                    running: root._swayer
                    loops:   Animation.Infinite
                    NumberAnimation { to:  4.5; duration: 130; easing.type: Easing.OutSine }
                    NumberAnimation { to: -5.5; duration: 170; easing.type: Easing.InOutSine }
                    NumberAnimation { to:  2.5; duration: 110; easing.type: Easing.OutSine }
                    NumberAnimation { to: -3.5; duration: 150; easing.type: Easing.InOutSine }
                    NumberAnimation { to:  1.5; duration: 100; easing.type: Easing.OutSine }
                    NumberAnimation { to:  0.0; duration: 180; easing.type: Easing.InOutSine }
                    PauseAnimation  { duration: 140 }
                }
                // keep the needle well inside the ring (inner gauge has thickness 8)
                readonly property real tipR: compass.ringR - 22

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    layer.enabled: true
                    layer.samples: 8

                    // main arrow pointing up (direction)
                    ShapePath {
                        fillColor: App.Theme.bad
                        strokeColor: Qt.darker(App.Theme.bad, 1.3)
                        strokeWidth: 1
                        startX: needle.cx;        startY: needle.cy - needle.tipR
                        PathLine { x: needle.cx - 7; y: needle.cy + 6 }
                        PathLine { x: needle.cx;     y: needle.cy + 2 }
                        PathLine { x: needle.cx + 7; y: needle.cy + 6 }
                        PathLine { x: needle.cx;     y: needle.cy - needle.tipR }
                    }
                    // back tail (smaller, muted)
                    ShapePath {
                        fillColor: App.Theme.textFaint
                        strokeColor: "transparent"
                        startX: needle.cx;        startY: needle.cy + 2
                        PathLine { x: needle.cx - 5; y: needle.cy + 6 }
                        PathLine { x: needle.cx;     y: needle.cy + needle.tipR * 0.45 }
                        PathLine { x: needle.cx + 5; y: needle.cy + 6 }
                        PathLine { x: needle.cx;     y: needle.cy + 2 }
                    }
                }

                // center hub on top
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: App.Theme.bg
                    border.color: App.Theme.bad
                    border.width: 2
                }
            }

            // center speed
            ColumnLayout {
                anchors.centerIn: parent
                spacing: -4
                BigNumber {
                    Layout.alignment: Qt.AlignHCenter
                    text: App.Units.fmt(App.Units.windMph(root.speedMph), 1)
                    color: App.Theme.text
                    glowColor: root.accentColor
                    pixelSize: 34
                    glowOpacity: 0.7
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: App.Units.windUnit()
                    color: App.Theme.textDim
                    font.pixelSize: 11
                }
            }
        }

        // side stats
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 14

            ColumnLayout {
                spacing: 2
                Label {
                    text: "FROM"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                Label {
                    text: root.dirLabel(root.dirDeg)
                    color: App.Theme.text
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
                Label {
                    text: root.dirDeg.toFixed(0) + "°"
                    color: App.Theme.bad
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    font.family: App.Theme.displayFont
                    font.styleName: "SemiBold SemiCondensed"
                    font.letterSpacing: -0.3
                }
            }

            // Today's peak requires continuous local-sensor polling to roll
            // up a daily max — no equivalent in None mode (Open-Meteo gives
            // hourly current, not station-style rolling peaks).
            ColumnLayout {
                visible: !App.StationSource.isOnlineOnly(App.AppSettings.stationType)
                spacing: 2
                Label {
                    text: "TODAY'S PEAK"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                Label {
                    text: App.Units.fmt(App.Units.windMph(root.peakMph), 1) + " " + App.Units.windUnit()
                    color: App.Theme.text
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
            }

            ColumnLayout {
                spacing: 2
                Label {
                    text: "GUST"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                Label {
                    text: App.Units.fmt(App.Units.windMph(root.gustMph), 1) + " " + App.Units.windUnit()
                    color: App.Theme.text
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
            }
        }
    }
}
