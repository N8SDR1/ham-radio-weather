import QtQuick
import QtQuick.Controls
import "." as App

TextField {
    id: field

    color: App.Theme.text
    placeholderTextColor: App.Theme.textFaint
    selectionColor: App.Theme.accent
    selectedTextColor: App.Theme.dark ? "#0b0f18" : "#ffffff"
    font.pixelSize: 13
    leftPadding: 10
    rightPadding: 10
    topPadding: 8
    bottomPadding: 8

    background: Rectangle {
        radius: 6
        color: App.Theme.dark ? "#0b0f18" : "#f0f3f7"
        border.color: field.activeFocus ? App.Theme.accent : App.Theme.border
        border.width: field.activeFocus ? 2 : 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}
