import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real rate:  data.hourlyrainin !== undefined ? data.hourlyrainin : 0
    readonly property real day:   data.dailyrainin  !== undefined ? data.dailyrainin  : 0
    readonly property real event: data.eventrainin  !== undefined ? data.eventrainin  : 0

    readonly property var _mood: App.Moods.rain(day)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: App.Theme.rain

    implicitHeight: 280

    // EVENT (since-rain-started) is a station-stateful value — Open-Meteo
    // has no equivalent, so the column is hidden in None mode.
    readonly property bool _showEvent: !App.StationSource.isOnlineOnly(App.AppSettings.stationType)

    RowLayout {
        anchors.fill: parent
        spacing: 8

        RainStat { label: "RATE";  valueIn: root.rate;  suffix: "/hr"; Layout.fillWidth: true; Layout.fillHeight: true }
        Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 10; Layout.bottomMargin: 10 }
        RainStat { label: "DAY";   valueIn: root.day;   Layout.fillWidth: true; Layout.fillHeight: true }
        Rectangle {
            visible: root._showEvent
            width: 1; Layout.fillHeight: true; color: App.Theme.border
            Layout.topMargin: 10; Layout.bottomMargin: 10
        }
        RainStat {
            visible: root._showEvent
            label: "EVENT"; valueIn: root.event
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }

    component RainStat: ColumnLayout {
        property string label: ""
        property real valueIn: 0
        property string suffix: ""
        spacing: 2

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: parent.label
            color: App.Theme.textFaint
            font.pixelSize: 11
            font.letterSpacing: 1.0
            font.weight: Font.Bold
        }
        Item { Layout.fillHeight: true }
        BigNumber {
            Layout.alignment: Qt.AlignHCenter
            text: App.Units.fmt(App.Units.rainIn(parent.valueIn), 2)
            color: parent.valueIn > 0 ? root.accentColor : App.Theme.text
            glowColor: root.accentColor
            glowOpacity: parent.valueIn > 0 ? 0.85 : 0.3
            pixelSize: 40
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: App.Units.rainUnit() + parent.suffix
            color: App.Theme.textDim
            font.pixelSize: 12
        }
        Item { Layout.fillHeight: true }
    }
}
