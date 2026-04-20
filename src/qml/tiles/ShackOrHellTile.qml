import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real tempIn: data.tempinf !== undefined ? data.tempinf : NaN

    // dynamic personality: the hotter the shack, the more "hell" it becomes
    readonly property int mood: {
        if (isNaN(tempIn)) return 1
        if (tempIn >= 85)  return 3   // HELL
        if (tempIn >= 78)  return 2   // hot
        if (tempIn <= 55)  return 0   // frozen shack
        return 1                       // normal shack
    }

    title: ["Frozen Shack", "Shack", "Shack's Heating", "Hell Mode"][mood]
    iconEmoji: ["🧊", "🏠", "🔥", "😈"][mood]
    accentColor: ["#4fc3f7", "#b388ff", "#ff8a65", "#ff3d00"][mood]

    RowLayout {
        anchors.fill: parent
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                text: "TEMP"
                color: App.Theme.textFaint
                font.pixelSize: 11
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }
            Text {
                id: bigTemp
                text: App.Units.fmt(App.Units.tempF(root.tempIn), 1)
                color: root.accentColor
                font.family: App.Theme.displayFont
                font.pixelSize: 58
                font.weight: Font.Bold
                font.styleName: "SemiBold SemiCondensed"
                style: Text.Outline
                styleColor: Qt.rgba(1, 1, 1, 0.15)
                renderType: Text.NativeRendering
            }
            Label {
                text: App.Units.tempUnit()
                color: App.Theme.textDim
                font.pixelSize: 13
            }
        }

        Rectangle {
            width: 1; Layout.fillHeight: true
            color: App.Theme.border
            Layout.topMargin: 18
            Layout.bottomMargin: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                text: "HUMIDITY"
                color: App.Theme.textFaint
                font.pixelSize: 11
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }
            Text {
                text: (root.data.humidityin !== undefined ? root.data.humidityin : "—")
                color: App.Theme.text
                font.family: App.Theme.displayFont
                font.pixelSize: 58
                font.weight: Font.Bold
                font.styleName: "SemiBold SemiCondensed"
                style: Text.Outline
                styleColor: Qt.rgba(1, 1, 1, 0.15)
                renderType: Text.NativeRendering
            }
            Label {
                text: "%"
                color: App.Theme.textDim
                font.pixelSize: 13
            }
        }
    }

    // subtle flicker when hellish — just enough to sell the joke
    SequentialAnimation on iconEmoji {
        running: root.mood === 3
        loops: Animation.Infinite
        PropertyAction { value: "😈" }
        PauseAnimation { duration: 2400 }
        PropertyAction { value: "🔥" }
        PauseAnimation { duration: 600 }
    }
}
