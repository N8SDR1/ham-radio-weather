import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    // Collect all probes present in data
    readonly property var probes: {
        var out = []
        if (!data) return out
        for (var i = 1; i <= 10; i++) {
            var m = data["soilmoisture" + i]
            var t = data["soiltemp" + i]
            var has = (m !== undefined && m !== null) || (t !== undefined && t !== null)
            if (has) out.push({ n: i, moisture: m, temp: t })
        }
        return out
    }
    readonly property bool hasAny: probes.length > 0

    title:       hasAny ? "Soil Probes  ·  " + probes.length : "Soil Probes"
    iconEmoji:   "🌱"
    accentColor: App.Theme.good

    implicitHeight: 300

    Label {
        anchors.centerIn: parent
        visible: !root.hasAny
        text: "No soil probes detected.\nAdd an Ambient WH51 (moisture) or WH34 (temperature) probe — it'll show up here automatically."
        color: App.Theme.textDim
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width - 40
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasAny
        spacing: 4

        Repeater {
            model: root.probes
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.08)
                border.color: Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.3)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Label {
                        text: "Probe " + modelData.n
                        color: App.Theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.preferredWidth: 70
                    }
                    Label {
                        visible: modelData.moisture !== undefined && modelData.moisture !== null
                        text: "💧 " + modelData.moisture + "%"
                        color: App.Theme.rain
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.family: App.Theme.displayFont
                        Layout.preferredWidth: 90
                    }
                    Label {
                        visible: modelData.temp !== undefined && modelData.temp !== null
                        text: "🌡 " + App.Units.fmt(App.Units.tempF(modelData.temp), 1) + App.Units.tempUnit()
                        color: App.Theme.text
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: App.Theme.displayFont
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
