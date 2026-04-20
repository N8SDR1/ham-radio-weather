import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property var  current: data.current || ({})
    readonly property var  daily:   data.daily   || []
    readonly property bool hasData: daily.length > 0

    readonly property int  curCode: current.weather_code !== undefined ? current.weather_code : -1
    readonly property bool isDay:   current.is_day ? true : false

    title:       hasData ? "Forecast · " + App.WeatherCodes.label(curCode) : "Forecast"
    iconEmoji:   hasData ? App.WeatherCodes.icon(curCode, isDay) : "☀"
    accentColor: App.Theme.accent

    implicitHeight: 280

    Label {
        anchors.centerIn: parent
        visible: !root.hasData
        text: App.AppSettings.gridSquare
              ? "Loading forecast for " + App.AppSettings.gridSquare + "…"
              : "Set your Maidenhead grid square in Settings (⚙) to enable the forecast."
        color: App.Theme.textDim
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 40
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasData
        spacing: 8

        // today summary — bigger, more breathing room
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Label {
                text: root.hasData ? App.WeatherCodes.icon(root.curCode, root.isDay) : "☀"
                font.pixelSize: 62
                Layout.alignment: Qt.AlignVCenter
            }

            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: root.current.temp !== undefined
                      ? App.Units.fmt(App.Units.tempF(root.current.temp), 0)
                      : "—"
                color: App.Theme.text
                glowColor: root.accentColor
                glowOpacity: 0.75
                pixelSize: 58
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Label {
                    visible: root.daily.length > 0 && root.daily[0].hi !== null
                    text: "▲ " + (root.daily.length > 0 && root.daily[0].hi !== null
                          ? App.Units.fmt(App.Units.tempF(root.daily[0].hi), 0) + App.Units.tempUnit() : "")
                    color: App.Theme.hot
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
                Label {
                    visible: root.daily.length > 0 && root.daily[0].lo !== null
                    text: "▼ " + (root.daily.length > 0 && root.daily[0].lo !== null
                          ? App.Units.fmt(App.Units.tempF(root.daily[0].lo), 0) + App.Units.tempUnit() : "")
                    color: App.Theme.cold
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: App.Theme.border; opacity: 0.5; Layout.topMargin: 4 }

        // day strip — bigger icons, bigger text, more column padding
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 39

            Repeater {
                model: Math.min(7, root.daily.length)
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: 2
                    readonly property var d: root.daily[index]

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!d || !d.date) return ""
                            var dt = new Date(d.date)
                            if (index === 0) return "TODAY"
                            return Qt.formatDate(dt, "ddd").toUpperCase()
                        }
                        color: index === 0 ? root.accentColor : App.Theme.textFaint
                        font.pixelSize: 12
                        font.letterSpacing: 0.8
                        font.weight: Font.Bold
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: d ? App.WeatherCodes.icon(d.weather_code, true) : ""
                        font.pixelSize: 32
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: d && d.hi !== null
                              ? App.Units.fmt(App.Units.tempF(d.hi), 0) + "°"
                              : "—"
                        color: App.Theme.text
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        font.family: App.Theme.displayFont
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: d && d.lo !== null
                              ? App.Units.fmt(App.Units.tempF(d.lo), 0) + "°"
                              : "—"
                        color: App.Theme.textDim
                        font.pixelSize: 14
                        font.family: App.Theme.displayFont
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: d && d.pop_max !== null && d.pop_max > 0 ? "💧" + d.pop_max + "%" : ""
                        color: App.Theme.rain
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
