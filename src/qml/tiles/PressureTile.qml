import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})
    property var history: []

    readonly property real baro: data.baromrelin !== undefined ? data.baromrelin : NaN

    readonly property var _baroSeries: {
        if (!history || history.length === 0) return []
        var r = []
        for (var i = 0; i < history.length; i++) {
            var v = history[i].baromrelin
            if (typeof v === "number") r.push(v)
        }
        return r
    }

    // 3-hour pressure delta in inHg (+ = rising). Populated by the
    // weather client from the last 3 h of history. Undefined in None
    // mode and during the first ~10 s of startup before history lands —
    // in both cases the arrow/badge simply hide.
    readonly property bool hasTrend: data.pressureTrend3h !== undefined
    readonly property real trend3h:  data.pressureTrend3h !== undefined
                                     ? Number(data.pressureTrend3h) : 0
    // Moods.pressure() thresholds are per-hour, so divide the 3h delta.
    readonly property real trendPerHr: hasTrend ? trend3h / 3.0 : 0

    readonly property var _mood: App.Moods.pressure(hasTrend ? trendPerHr : NaN)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: App.Theme.accent

    implicitHeight: 280

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: isNaN(root.baro) ? "—" : App.Units.fmt(App.Units.presIn(root.baro), 2)
                color: App.Theme.text
                glowColor: root.accentColor
                glowOpacity: 0.7
                pixelSize: 64
            }
            Label {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 14
                text: App.Units.presUnit()
                color: App.Theme.textDim
                font.pixelSize: 20
                font.family: App.Theme.displayFont
                font.weight: Font.Medium
            }

            // 3-hour trend badge. Hidden entirely when no history is
            // available (None mode, pre-first-fetch). Color + glyph pick
            // rising / falling / steady with a ±0.02 inHg deadband over
            // 3 h so tiny wobbles don't look like storms.
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 8
                visible: root.hasTrend
                spacing: 0

                readonly property real _t: root.trend3h
                readonly property bool _rising:  _t >=  0.02
                readonly property bool _falling: _t <= -0.02
                readonly property color _color: _rising  ? App.Theme.good
                                              : _falling ? App.Theme.warn
                                                         : App.Theme.textDim
                readonly property string _glyph: _rising  ? "▲"
                                                : _falling ? "▼"
                                                           : "→"

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: parent._glyph
                    color: parent._color
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: (parent._t >= 0 ? "+" : "") + parent._t.toFixed(2)
                    color: parent._color
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.family: App.Theme.displayFont
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "3 H"
                    color: App.Theme.textFaint
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                    font.weight: Font.Bold
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 24 h pressure sparkline. Sits just below the value + trend badge.
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            Layout.topMargin: 18
            values: root._baroSeries
            lineColor: App.AppSettings.sparklineColor === "red"
                       ? App.Theme.bad : root.accentColor
            dotColor:  lineColor
        }

        Item { Layout.fillHeight: true }

        // 28.0 – 31.0 inHg scale indicator
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32

            readonly property real minP: 28.0
            readonly property real maxP: 31.0
            readonly property real t: {
                if (isNaN(root.baro)) return 0
                return Math.max(0, Math.min(1, (root.baro - minP) / (maxP - minP)))
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: App.Theme.bad }      // very low
                    GradientStop { position: 0.5; color: App.Theme.good }     // normal
                    GradientStop { position: 1.0; color: App.Theme.warn }     // very high
                }
                opacity: 0.5
            }

            // tick marks
            Row {
                anchors.bottom: parent.bottom
                width: parent.width
                Repeater {
                    model: 7
                    delegate: Item {
                        width: parent.width / 7
                        height: 14
                        Rectangle {
                            width: 1; height: 5
                            color: App.Theme.textFaint
                            anchors.top: parent.top
                        }
                        Label {
                            text: (28 + index * 0.5).toFixed(1)
                            color: App.Theme.textFaint
                            font.pixelSize: 9
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            // marker
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.t * (parent.width - 14)
                width: 14; height: 14; radius: 7
                color: "#ffffff"
                border.color: root.accentColor
                border.width: 2
                Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }
}
