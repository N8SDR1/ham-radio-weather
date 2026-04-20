import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

// Compact battery status for the header. Always visible.
Item {
    id: root
    property var data: ({})
    signal clicked()

    readonly property var state: App.Batteries.detect(data)

    implicitWidth:  Math.max(60, inner.implicitWidth + 8)
    implicitHeight: 24

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 5

        Label {
            id: iconLabel
            anchors.verticalCenter: parent.verticalCenter
            text: !root.state.hasAny ? "🔋"
                : root.state.allOk   ? "🔋"
                                     : "🪫"
            color: !root.state.hasAny ? App.Theme.textFaint
                 : root.state.allOk   ? App.Theme.good
                                      : App.Theme.bad
            font.pixelSize: 16

            SequentialAnimation on opacity {
                running: root.state.hasAny && !root.state.allOk
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        Label {
            id: countLabel
            anchors.verticalCenter: parent.verticalCenter
            text: !root.state.hasAny ? "—"
                : root.state.allOk   ? "OK"
                                     : root.state.lowList.length + " low"
            color: !root.state.hasAny ? App.Theme.textFaint
                 : root.state.allOk   ? App.Theme.textDim
                                      : App.Theme.bad
            font.pixelSize: 11
            font.weight: (root.state.hasAny && !root.state.allOk) ? Font.Bold : Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        ToolTip.visible: containsMouse
        ToolTip.delay: 300
        ToolTip.text: {
            if (!root.state.hasAny) return "No battery data in this station's feed — click to open Settings"
            if (root.state.allOk)   return "All batteries OK — click for details"
            var names = root.state.lowList.map(function(k) { return App.Batteries.prettyName(k) })
            return "Low: " + names.join(", ") + " — click for details"
        }
    }
}
