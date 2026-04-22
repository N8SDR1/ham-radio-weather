import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real uv: data.uv !== undefined ? data.uv : NaN
    readonly property var _mood: App.Moods.uv(uv)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: App.Theme.uvColor(uv)

    readonly property string riskLabel: {
        if (isNaN(uv)) return "—"
        if (uv < 3)  return "LOW RISK"
        if (uv < 6)  return "MODERATE RISK"
        if (uv < 8)  return "HIGH RISK"
        if (uv < 11) return "VERY HIGH RISK"
        return             "EXTREME RISK"
    }

    implicitHeight: 280

    // Face Melter territory = UV >= 11 (or the preview toggle). Add
    // a heat-shimmer effect: subtle warm horizontal bands scrolling
    // upward behind the big number.
    readonly property bool _faceMelter:
        App.AppSettings.effectForceFaceMelt || uv >= 11

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Heat-shimmer wrapper — number sits inside, scrolling bands
        // behind give the "rising heat waves" impression without needing
        // a proper shader. Only active at Face Melter levels.
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  uvNum.implicitWidth
            implicitHeight: uvNum.implicitHeight
            clip: true

            Item {
                id: heatLayer
                anchors.fill: parent
                visible: root._faceMelter
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        readonly property int _offset: index * 24
                        readonly property int _dur:    2400 + index * 300
                        width:  parent.width
                        height: 1
                        radius: 0
                        color:  App.Theme.hot
                        opacity: 0.28
                        y: parent.height
                        SequentialAnimation on y {
                            running: heatLayer.visible
                            loops:   Animation.Infinite
                            PauseAnimation  { duration: index * 400 }
                            NumberAnimation {
                                from: heatLayer.height + 4
                                to: -4
                                duration: _dur
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }

            BigNumber {
                id: uvNum
                anchors.centerIn: parent
                text: isNaN(root.uv) ? "—" : root.uv.toFixed(0)
                color: root.accentColor
                glowColor: root.accentColor
                glowOpacity: 0.85
                pixelSize: 90

                // Tiny horizontal shimmer on the number itself at Face Melter
                // — mimics the "air is wavy" illusion on blistering days.
                SequentialAnimation on x {
                    running: root._faceMelter
                    loops:   Animation.Infinite
                    NumberAnimation { to:  1; duration: 220; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1; duration: 260; easing.type: Easing.InOutSine }
                    NumberAnimation { to:  0; duration: 200; easing.type: Easing.InOutSine }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.riskLabel
            color: root.accentColor
            font.pixelSize: 12
            font.letterSpacing: 1.2
            font.weight: Font.Bold
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 2
            color: root.accentColor
            radius: 1
        }

        Item { Layout.fillHeight: true }

        // simple 11-step scale bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: 12
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    radius: 2
                    color: App.Theme.uvColor(index)
                    opacity: !isNaN(root.uv) && index <= Math.round(root.uv) ? 1.0 : 0.18
                }
            }
        }
    }
}
