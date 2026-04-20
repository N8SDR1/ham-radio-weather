import QtQuick
import QtQuick.Effects
import "../" as App

// Reusable "display" number with the Outdoor-tile dazzle treatment:
// Bahnschrift SemiBold SemiCondensed, deep accent, thin outline, soft glow.
Item {
    id: root
    property string text: ""
    property color color: App.Theme.text
    property color glowColor: color
    property int pixelSize: 72
    property real glowOpacity: 0.85
    property bool glow: true

    implicitWidth:  numText.implicitWidth + 12
    implicitHeight: numText.implicitHeight + 12

    Text {
        id: numText
        anchors.centerIn: parent
        text: root.text
        color: root.color
        font.family: App.Theme.displayFont
        font.pixelSize: root.pixelSize
        font.weight: Font.Bold
        font.styleName: "SemiBold SemiCondensed"
        style: Text.Outline
        styleColor: Qt.rgba(1, 1, 1, 0.18)
        renderType: Text.NativeRendering
    }

    MultiEffect {
        source: numText
        anchors.fill: numText
        visible: root.glow
        shadowEnabled: root.glow
        shadowBlur: 1.0
        shadowColor: root.glowColor
        shadowOpacity: root.glowOpacity
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }
}
