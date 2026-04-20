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

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        BigNumber {
            Layout.alignment: Qt.AlignHCenter
            text: isNaN(root.uv) ? "—" : root.uv.toFixed(0)
            color: root.accentColor
            glowColor: root.accentColor
            glowOpacity: 0.85
            pixelSize: 90
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
