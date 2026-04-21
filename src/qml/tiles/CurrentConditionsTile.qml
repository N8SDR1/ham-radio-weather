import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})
    // Rolling station history (newest-first), injected by TileLoader when
    // the weather adapter exposes one. Empty on Ecowitt/None until their
    // history endpoints land — sparkline simply hides in that case.
    property var history: []

    readonly property real tempVal: data.tempf !== undefined ? data.tempf : NaN
    readonly property var _mood: App.Moods.outdoor(tempVal)

    // Extract the numeric series for the sparkline. Non-numeric entries
    // are dropped so the stroke doesn't jump to 0 for gaps.
    readonly property var _tempSeries: {
        if (!history || history.length === 0) return []
        var r = []
        for (var i = 0; i < history.length; i++) {
            var v = history[i].tempf
            if (typeof v === "number") r.push(v)
        }
        return r
    }

    title:     _mood.title
    iconEmoji: _mood.icon

    accentColor: {
        if (isNaN(tempVal)) return App.Theme.accent
        if (tempVal >= 75) return App.Theme.hot
        if (tempVal <= 40) return App.Theme.cold
        return App.Theme.accent
    }

    readonly property color glowColor: {
        if (isNaN(tempVal)) return App.Theme.accentGlow
        if (tempVal >= 75) return App.Theme.hotGlow
        if (tempVal <= 40) return App.Theme.coldGlow
        return App.Theme.accentGlow
    }

    implicitHeight: 280

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: App.Units.fmt(App.Units.tempF(root.tempVal), 1)
                color: root.accentColor
                glowColor: root.glowColor
                pixelSize: 92
                glowOpacity: 0.9
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 16
                spacing: 2
                Label {
                    text: App.Units.tempUnit()
                    color: root.accentColor
                    font.pixelSize: 24
                    font.family: App.Theme.displayFont
                    font.weight: Font.DemiBold
                }
                RowLayout {
                    spacing: 4
                    visible: !isNaN(root.tempVal) && root.data.tempfFromYesterday !== undefined
                    Label {
                        text: (root.data.tempfFromYesterday >= 0 ? "▲" : "▼")
                        color: root.data.tempfFromYesterday >= 0 ? App.Theme.hot : App.Theme.cold
                        font.pixelSize: 11
                    }
                    Label {
                        text: Math.abs(root.data.tempfFromYesterday || 0).toFixed(1) + "°"
                        color: App.Theme.textDim
                        font.pixelSize: 11
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }

        // 24 h temperature sparkline. Auto-hides when history is empty.
        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            Layout.bottomMargin: 4
            values: root._tempSeries
            lineColor: App.AppSettings.sparklineColor === "red"
                       ? App.Theme.bad : root.accentColor
            dotColor:  lineColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            StatPair {
                label: "Feels Like"
                value: App.Units.fmt(App.Units.tempF(root.data.feelsLike), 0) + App.Units.tempUnit()
            }
            Rectangle {
                width: 1; Layout.fillHeight: true
                color: App.Theme.border
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }
            StatPair {
                label: "Dew Point"
                value: App.Units.fmt(App.Units.tempF(root.data.dewPoint), 0) + App.Units.tempUnit()
            }
            Rectangle {
                width: 1; Layout.fillHeight: true
                color: App.Theme.border
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }
            StatPair {
                label: "Humidity"
                value: (root.data.humidity !== undefined ? root.data.humidity : "—") + "%"
            }
            Item { Layout.fillWidth: true }
        }
    }

    component StatPair: ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: 2
        Label {
            text: parent.label
            color: App.Theme.textFaint
            font.pixelSize: 11
            font.letterSpacing: 1.0
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
        }
        Label {
            text: parent.value
            color: App.Theme.text
            font.pixelSize: 18
            font.weight: Font.Medium
        }
    }
}
