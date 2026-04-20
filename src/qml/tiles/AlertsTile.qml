import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

// Threshold-based alerts driven by the local weather data (station or None
// mode). NOAA/NWS official alerts live in the separate NwsAlertsTile so they
// can render with full wrapped text.
Tile {
    id: root
    property var data: ({})

    readonly property var active: {
        var _dep = App.AppSettings.alertsJson
        return App.AlertRules.evaluate(data, App.AppSettings.getAlertSettings())
    }
    readonly property int activeCount: active.length
    readonly property bool hasWarning: {
        for (var i = 0; i < active.length; i++)
            if (active[i].severity === "warning") return true
        return false
    }

    title:       activeCount === 0 ? "All Clear"
               : hasWarning         ? activeCount + " Active · Warning"
                                    : activeCount + " Active"
    iconEmoji:   activeCount === 0 ? "✅"
               : hasWarning         ? "⚠"
                                    : "🔔"
    accentColor: activeCount === 0 ? App.Theme.good
               : hasWarning         ? App.Theme.bad
                                    : App.Theme.warn

    implicitHeight: 300

    // === Empty state ===
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.activeCount === 0
        spacing: 8

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "✅"
            font.pixelSize: 56
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "All Clear"
            color: App.Theme.good
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.family: App.Theme.displayFont
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "No thresholds exceeded. Configure in Settings."
            color: App.Theme.textDim
            font.pixelSize: 12
        }
    }

    // === Active alerts list ===
    ColumnLayout {
        anchors.fill: parent
        visible: root.activeCount > 0
        spacing: 6

        Repeater {
            model: root.active
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: Qt.rgba(App.AlertRules.severityColor(modelData.severity).r,
                               App.AlertRules.severityColor(modelData.severity).g,
                               App.AlertRules.severityColor(modelData.severity).b, 0.12)
                border.color: App.AlertRules.severityColor(modelData.severity)
                border.width: 1

                SequentialAnimation on opacity {
                    running: modelData.severity === "warning"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.65; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 700; easing.type: Easing.InOutSine }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Label {
                        text: modelData.icon
                        font.pixelSize: 20
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            text: modelData.label
                            color: App.Theme.text
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Label {
                            text: "Now " + modelData.value.toFixed(1) + modelData.unit
                                + "  ·  threshold " + modelData.comparator
                                + " " + modelData.threshold + modelData.unit
                            color: App.Theme.textDim
                            font.pixelSize: 11
                        }
                    }
                    Label {
                        text: modelData.severity.toUpperCase()
                        color: App.AlertRules.severityColor(modelData.severity)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
