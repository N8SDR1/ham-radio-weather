import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

// First-run disclaimer. Must be accepted before the app is operational.
// If the user declines (or closes without accepting), the app exits.
Dialog {
    id: dialog
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 640
    height: Math.min(parent ? parent.height * 0.85 : 560, 560)
    anchors.centerIn: parent

    signal declined()

    background: Rectangle {
        color: App.Theme.surface
        border.color: App.Theme.warn
        border.width: 2
        radius: 12
    }

    header: Rectangle {
        color: "transparent"
        height: 52
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 12
            spacing: 10
            Label {
                text: "⚠"
                color: App.Theme.warn
                font.pixelSize: 28
            }
            Label {
                text: "Disclaimer — please read before using"
                color: App.Theme.text
                font.pixelSize: 17
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            background: Rectangle {
                color: App.Theme.dark ? "#0b0f18" : "#f0f3f7"
                border.color: App.Theme.border
                radius: 6
            }
            TextArea {
                readOnly: true
                wrapMode: TextArea.Wrap
                color: App.Theme.text
                font.pixelSize: 12
                leftPadding: 12
                rightPadding: 12
                topPadding: 10
                bottomPadding: 10
                background: Rectangle { color: "transparent" }
                text:
                    "Ham Radio Weather Dashboard is a hobbyist tool built by an amateur radio operator " +
                    "for the amateur radio community. All data it displays is informational only.\n\n" +

                    "Weather, lightning, satellite-pass, and propagation information are provided as-is " +
                    "and come from third-party public data sources, including but not limited to:\n" +
                    "    • Ambient Weather Network / Ecowitt Cloud  (your personal station data)\n" +
                    "    • Open-Meteo  (current conditions + forecast)\n" +
                    "    • HamQSL.com  (solar flux, K / A index, band conditions)\n" +
                    "    • Celestrak  (satellite orbital elements)\n" +
                    "    • Blitzortung.org  (lightning strike network, if enabled)\n" +
                    "    • US National Weather Service  (active alerts, if enabled)\n\n" +

                    "These feeds may be delayed, incomplete, or inaccurate. Sensor readings from personal " +
                    "stations may drift, lose battery, or fail. Satellite predictions use TLE data that " +
                    "ages and degrades over time. HF propagation forecasts are statistical estimates.\n\n" +

                    "DO NOT RELY on this application as a primary safety system. For weather emergencies, " +
                    "lightning avoidance, or any situation involving personal safety or equipment " +
                    "protection, consult official government weather services (NWS in the US, your " +
                    "national meteorological service elsewhere) and use your own judgment.\n\n" +

                    "For amateur radio operators specifically: the \"Unplug the Rig!\" lightning warning " +
                    "is a convenience indicator, not a substitute for proper station grounding, surge " +
                    "protection, or your own observation of approaching storms.\n\n" +

                    "By clicking \"I Accept\" you acknowledge the above limitations, agree that the " +
                    "author and contributors make no warranties of any kind, and accept full " +
                    "responsibility for how you use the information this app displays. This includes " +
                    "station-and-antenna safety during weather events.\n\n" +

                    "If you decline, the application will exit. You can revisit this dialog any time " +
                    "from the About screen."
            }
        }

        Label {
            text: "73 de N8SDR — Rick Langford"
            color: App.Theme.textFaint
            font.pixelSize: 11
            Layout.alignment: Qt.AlignRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Decline & Exit"
                Layout.preferredWidth: 140
                onClicked: {
                    dialog.declined()
                    Qt.quit()
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "I Accept"
                highlighted: true
                Layout.preferredWidth: 160
                onClicked: {
                    App.AppSettings.disclaimerAccepted = true
                    dialog.close()
                }
            }
        }
    }
}
