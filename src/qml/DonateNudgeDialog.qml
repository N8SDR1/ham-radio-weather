import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

// Shown ONCE, on the 7th launch, as a gentle reminder that development is
// hobbyist + unpaid. Dismissible; marks donateNudgeShown=true so it never
// reappears.
Dialog {
    id: dialog
    modal: true
    closePolicy: Popup.CloseOnEscape
    width: 480
    anchors.centerIn: parent

    background: Rectangle {
        color: App.Theme.surface
        border.color: App.Theme.warn
        border.width: 1
        radius: 12
    }

    header: Rectangle {
        color: "transparent"
        height: 48
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 12
            Label {
                text: "☕  A quick thank-you"
                color: App.Theme.text
                font.pixelSize: 17
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        Label {
            Layout.fillWidth: true
            text:
                "You've been using Ham Radio Weather Dashboard for a while now — " +
                "hope it's been useful around the shack!\n\n" +
                "This is a hobbyist project, built by a fellow ham and given away " +
                "free for the community. It will always stay free. But if you've " +
                "enjoyed it and would like to send a coffee, there's a PayPal " +
                "donate link below. Every bit helps keep the code flowing.\n\n" +
                "Either way — thanks for using it. 73 de N8SDR"
            color: App.Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Maybe later"
                onClicked: {
                    App.AppSettings.donateNudgeShown = true
                    dialog.close()
                }
            }
            Button {
                text: "☕  Buy me a coffee"
                highlighted: true
                onClicked: {
                    App.AppSettings.donateNudgeShown = true
                    Qt.openUrlExternally(App.DonateUrl.url)
                    dialog.close()
                }
            }
        }
    }
}
