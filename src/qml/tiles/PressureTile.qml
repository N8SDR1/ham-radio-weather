import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real baro: data.baromrelin !== undefined ? data.baromrelin : NaN
    // Ambient doesn't send a trend field; show 0 trend until we track deltas ourselves.
    readonly property real trendPerHr: 0

    readonly property var _mood: App.Moods.pressure(trendPerHr)
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
            Item { Layout.fillWidth: true }
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
