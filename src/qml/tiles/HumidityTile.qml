import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real hum: data.humidity !== undefined ? data.humidity : NaN
    readonly property var _mood: App.Moods.humidity(hum)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: hum >= 80 ? App.Theme.rain
              : hum <= 30 ? App.Theme.warn
              : App.Theme.accent

    implicitHeight: 280

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: isNaN(root.hum) ? "—" : root.hum.toFixed(0)
                color: root.accentColor
                glowColor: root.accentColor
                glowOpacity: 0.85
                pixelSize: 92
            }
            Label {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 20
                text: "%"
                color: App.Theme.textDim
                font.pixelSize: 26
                font.family: App.Theme.displayFont
                font.weight: Font.Medium
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Label {
                text: "FROM YESTERDAY"
                color: App.Theme.textFaint
                font.pixelSize: 11
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }
            Label {
                visible: root.data.humidityFromYesterday !== undefined
                text: {
                    var d = root.data.humidityFromYesterday
                    if (d === undefined) return ""
                    return (d >= 0 ? "▲ " : "▼ ") + Math.abs(d).toFixed(0) + "%"
                }
                color: App.Theme.text
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        Item { Layout.fillHeight: true }
    }
}
