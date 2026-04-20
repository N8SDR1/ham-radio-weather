import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real pm25:    data.pm25        !== undefined ? data.pm25        : NaN
    readonly property real pm25_24: data.pm25_24h    !== undefined ? data.pm25_24h    : NaN
    readonly property real aqi:     data.aqi_pm25    !== undefined ? data.aqi_pm25    : NaN
    readonly property real co2:     data.co2         !== undefined ? data.co2         : NaN
    readonly property real co2In:   data.co2_in_aqin !== undefined ? data.co2_in_aqin : NaN

    readonly property bool hasAny: !isNaN(pm25) || !isNaN(aqi) || !isNaN(co2) || !isNaN(co2In)

    function aqiInfo(v) {
        if (isNaN(v)) return { label: "—",        color: App.Theme.textDim }
        if (v <= 50)  return { label: "GOOD",      color: App.Theme.good }
        if (v <= 100) return { label: "MODERATE",  color: App.Theme.lightning }
        if (v <= 150) return { label: "UNHEALTHY (SENSITIVE)", color: App.Theme.warn }
        if (v <= 200) return { label: "UNHEALTHY", color: App.Theme.bad }
        if (v <= 300) return { label: "VERY UNHEALTHY", color: "#8e24aa" }
        return              { label: "HAZARDOUS", color: "#5d1f1f" }
    }
    readonly property var aqiBand: aqiInfo(aqi)

    title:       hasAny ? "Air Quality  ·  " + aqiBand.label : "Air Quality"
    iconEmoji:   hasAny ? "🫁" : "🌫"
    accentColor: hasAny ? aqiBand.color : App.Theme.accent

    implicitHeight: 300

    Label {
        anchors.centerIn: parent
        visible: !root.hasAny
        text: "No AQIN sensor detected in the Ambient feed.\nAdd an Ambient PM2.5/CO₂ sensor and it'll appear here."
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

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                BigNumber {
                    Layout.alignment: Qt.AlignHCenter
                    text: isNaN(root.aqi) ? "—" : root.aqi.toFixed(0)
                    color: root.aqiBand.color
                    glowColor: root.aqiBand.color
                    pixelSize: 64
                    glowOpacity: 0.85
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "AQI (PM2.5)"
                    color: App.Theme.textDim
                    font.pixelSize: 11
                    font.letterSpacing: 0.8
                    font.weight: Font.Bold
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; opacity: 0.5; Layout.topMargin: 12; Layout.bottomMargin: 12 }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                RowLayout {
                    spacing: 12
                    ColumnLayout {
                        spacing: 0
                        Label { text: "PM2.5 NOW"; color: App.Theme.textFaint; font.pixelSize: 10; font.letterSpacing: 1.0; font.weight: Font.Bold }
                        Label {
                            text: isNaN(root.pm25) ? "—" : root.pm25.toFixed(1) + " µg/m³"
                            color: App.Theme.text
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: App.Theme.displayFont
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Label { text: "24-HR AVG"; color: App.Theme.textFaint; font.pixelSize: 10; font.letterSpacing: 1.0; font.weight: Font.Bold }
                        Label {
                            text: isNaN(root.pm25_24) ? "—" : root.pm25_24.toFixed(1) + " µg/m³"
                            color: App.Theme.text
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: App.Theme.displayFont
                        }
                    }
                }

                RowLayout {
                    spacing: 12
                    visible: !isNaN(root.co2) || !isNaN(root.co2In)
                    ColumnLayout {
                        spacing: 0
                        visible: !isNaN(root.co2In)
                        Label { text: "CO₂ INDOOR"; color: App.Theme.textFaint; font.pixelSize: 10; font.letterSpacing: 1.0; font.weight: Font.Bold }
                        Label {
                            text: isNaN(root.co2In) ? "—" : root.co2In.toFixed(0) + " ppm"
                            color: root.co2In > 1000 ? App.Theme.warn
                                 : root.co2In > 1500 ? App.Theme.bad
                                 : App.Theme.text
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: App.Theme.displayFont
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        visible: !isNaN(root.co2)
                        Label { text: "CO₂ OUTDOOR"; color: App.Theme.textFaint; font.pixelSize: 10; font.letterSpacing: 1.0; font.weight: Font.Bold }
                        Label {
                            text: isNaN(root.co2) ? "—" : root.co2.toFixed(0) + " ppm"
                            color: App.Theme.text
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            font.family: App.Theme.displayFont
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
