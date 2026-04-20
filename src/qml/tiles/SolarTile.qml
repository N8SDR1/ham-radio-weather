import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    // Ambient's `solarradiation` is actually W/m², not lux — same for
    // Open-Meteo's `shortwave_radiation`. We report it honestly as W/m².
    readonly property real wm2: data.solarradiation !== undefined ? data.solarradiation : NaN
    readonly property var _mood: App.Moods.solar(wm2)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: wm2 > 800 ? App.Theme.hot
               : wm2 > 200 ? App.Theme.lightning
               : App.Theme.accent

    implicitHeight: 280

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: {
                    if (isNaN(root.wm2)) return "—"
                    if (root.wm2 >= 1000) return (root.wm2 / 1000).toFixed(2) + "k"
                    return root.wm2.toFixed(0)
                }
                color: root.accentColor
                glowColor: root.accentColor
                glowOpacity: 0.85
                pixelSize: 72
            }
            Label {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 16
                text: "W/m²"
                color: App.Theme.textDim
                font.pixelSize: 22
                font.family: App.Theme.displayFont
                font.weight: Font.Medium
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 180
            Layout.preferredHeight: 24

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 6
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: App.Theme.textFaint }
                    GradientStop { position: 0.5; color: App.Theme.lightning }
                    GradientStop { position: 1.0; color: App.Theme.hot }
                }
            }
            Rectangle {
                y: parent.height / 2 - 8
                x: {
                    if (isNaN(root.wm2)) return 0
                    // ~1200 W/m² = very clear noon at high altitude
                    var t = Math.min(1, root.wm2 / 1200)
                    return t * (parent.width - 16)
                }
                width: 16; height: 16; radius: 8
                color: "#ffffff"
                border.color: root.accentColor
                border.width: 2
                Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
