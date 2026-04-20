import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property int  strikesToday: data.lightning_day !== undefined ? data.lightning_day : 0
    readonly property int  strikesHour:  data.lightning_hour !== undefined ? data.lightning_hour : 0
    readonly property var  lastStrike:   data.lightning_time
    readonly property real distance:     data.lightning_distance !== undefined ? data.lightning_distance : NaN

    readonly property var _mood: App.Moods.lightning(distance, strikesToday)
    title:     _mood.title
    iconEmoji: _mood.icon
    accentColor: (strikesToday > 0 && !isNaN(distance) && distance < 5)
                 ? App.Theme.bad
                 : App.Theme.lightning

    // age of last strike in human terms
    function lastStrikeLabel() {
        if (!lastStrike) return "—"
        var t = new Date(lastStrike)
        if (isNaN(t.getTime())) return "—"
        var diffMs = Date.now() - t.getTime()
        var min = Math.floor(diffMs / 60000)
        if (min < 1)   return "just now"
        if (min < 60)  return min + "m ago"
        var hr = Math.floor(min / 60)
        if (hr < 24)   return hr + "h ago"
        var d = Math.floor(hr / 24)
        return d + "d ago"
    }

    implicitHeight: 280

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            BigNumber {
                Layout.alignment: Qt.AlignVCenter
                text: root.strikesToday.toString()
                color: root.strikesToday > 0 ? App.Theme.lightning : App.Theme.text
                glowColor: App.Theme.lightning
                glowOpacity: root.strikesToday > 0 ? 0.9 : 0.4
                pixelSize: 86
            }
            Label {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 18
                text: "today"
                color: App.Theme.textDim
                font.pixelSize: 16
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            ColumnLayout {
                spacing: 2
                Label { text: "HOURLY"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: root.strikesHour + " ⚡"
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            ColumnLayout {
                spacing: 2
                Label { text: "LAST STRIKE"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: root.lastStrikeLabel()
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            ColumnLayout {
                spacing: 2
                Label { text: "DISTANCE"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: !isNaN(root.distance)
                        ? App.Units.fmt(App.Units.distMi(root.distance), 0) + " " + App.Units.distUnit()
                        : "—"
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
