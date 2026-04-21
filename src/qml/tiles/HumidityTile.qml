import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})
    property var history: []

    readonly property real hum: data.humidity !== undefined ? data.humidity : NaN
    readonly property var _mood: App.Moods.humidity(hum)

    readonly property var _humSeries: {
        if (!history || history.length === 0) return []
        var r = []
        for (var i = 0; i < history.length; i++) {
            var v = history[i].humidity
            if (typeof v === "number") r.push(v)
        }
        return r
    }
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

        // Yesterday-delta block. Only shows when:
        //   1. We have a station (None mode has no history), AND
        //   2. A humidityFromYesterday value has actually been computed
        //      (populated once Batch 2 history plumbing lands).
        // Hidden cleanly until both conditions are met.
        RowLayout {
            visible: !App.StationSource.isOnlineOnly(App.AppSettings.stationType)
                     && root.data.humidityFromYesterday !== undefined
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

        // 24 h humidity sparkline, centered below the big value.
        Sparkline {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            Layout.preferredWidth: Math.min(root.width * 0.7, 220)
            Layout.preferredHeight: 24
            values: root._humSeries
            lineColor: App.AppSettings.sparklineColor === "red"
                       ? App.Theme.bad : root.accentColor
            dotColor:  lineColor
        }

        Item { Layout.fillHeight: true }
    }
}
