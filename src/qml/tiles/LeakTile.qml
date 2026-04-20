import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    // 1 = leak detected, 0 = dry. Any non-empty leak* key present = sensor configured.
    readonly property var detectors: {
        var out = []
        if (!data) return out
        for (var i = 1; i <= 4; i++) {
            var v = data["leak" + i]
            if (v === undefined || v === null) continue
            var n = Number(v)
            if (isNaN(n)) continue
            out.push({ n: i, wet: n === 1 })
        }
        return out
    }
    readonly property bool hasAny: detectors.length > 0
    readonly property int  wetCount: {
        var c = 0
        for (var i = 0; i < detectors.length; i++) if (detectors[i].wet) c++
        return c
    }

    title:       !hasAny        ? "Leak Detectors"
               : wetCount > 0   ? "LEAK DETECTED · " + wetCount + " wet"
                                : "All Dry"
    iconEmoji:   wetCount > 0 ? "🚨" : "💧"
    accentColor: !hasAny      ? App.Theme.accent
               : wetCount > 0 ? App.Theme.bad
                              : App.Theme.good

    implicitHeight: 300

    Label {
        anchors.centerIn: parent
        visible: !root.hasAny
        text: "No leak detectors paired.\nAdd an Ambient WH53 (leak sensor) and they'll appear here."
        color: App.Theme.textDim
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width - 40
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasAny
        spacing: 6

        Repeater {
            model: root.detectors
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: modelData.wet
                       ? Qt.rgba(App.Theme.bad.r, App.Theme.bad.g, App.Theme.bad.b, 0.15)
                       : Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.08)
                border.color: modelData.wet ? App.Theme.bad : Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.3)
                border.width: 1

                SequentialAnimation on opacity {
                    running: modelData.wet
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 600; easing.type: Easing.InOutSine }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Label {
                        text: modelData.wet ? "💦" : "✓"
                        color: modelData.wet ? App.Theme.bad : App.Theme.good
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Label {
                        text: "Leak Sensor " + modelData.n
                        color: App.Theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Label {
                        text: modelData.wet ? "WATER DETECTED" : "DRY"
                        color: modelData.wet ? App.Theme.bad : App.Theme.textDim
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
