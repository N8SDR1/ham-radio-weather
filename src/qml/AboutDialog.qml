import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

Dialog {
    id: dialog
    title: "About"
    modal: true
    standardButtons: Dialog.Close
    width: 480
    anchors.centerIn: parent

    readonly property string donateUrl: App.DonateUrl.url

    background: Rectangle {
        color: App.Theme.surface
        border.color: App.Theme.border
        radius: 12
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            spacing: 12
            Item {
                width: 72; height: 72
                Rectangle {
                    anchors.fill: parent
                    visible: aboutLogo.status !== Image.Ready
                    radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: App.Theme.accent }
                        GradientStop { position: 1.0; color: App.Theme.accent2 }
                    }
                    Label { anchors.centerIn: parent; text: "☁"; color: "white"; font.pixelSize: 36 }
                }
                Image {
                    id: aboutLogo
                    anchors.fill: parent
                    source: appLogoUrl
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }
            }
            ColumnLayout {
                spacing: 0
                Label {
                    text: App.AppVersion.name
                    color: App.Theme.text
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }
                Label {
                    text: "v" + App.AppVersion.version + "  ·  " + App.AppVersion.tag
                    color: App.Theme.textDim
                    font.pixelSize: 13
                }
                Label {
                    text: "by N8SDR · Rick Langford"
                    color: App.Theme.accent
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: App.Theme.border; opacity: 0.5 }

        Label {
            Layout.fillWidth: true
            text: "A Qt6/PySide6 desktop weather dashboard for Ambient Weather stations, with ham-radio overlays (HF propagation, satellite passes, lightning alerts)."
            color: App.Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        GroupBox {
            Layout.fillWidth: true
            label: Label {
                text: "DATA SOURCES"
                color: App.Theme.textFaint
                font.pixelSize: 10
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }
            background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                Label { text: "• Ambient Weather REST + Socket.IO  (your station)"; color: App.Theme.text; font.pixelSize: 11 }
                Label { text: "• Open-Meteo  (forecast, sun/moon)";                 color: App.Theme.text; font.pixelSize: 11 }
                Label { text: "• HamQSL solar XML  (SFI, K/A, band conditions)";    color: App.Theme.text; font.pixelSize: 11 }
                Label { text: "• Celestrak amateur TLEs  (satellite passes)";       color: App.Theme.text; font.pixelSize: 11 }
            }
        }

        // Donation banner — bigger, warmer, with a subtle breathing glow so
        // it actually catches the eye when the dialog opens.
        Rectangle {
            id: donateBanner
            Layout.fillWidth: true
            Layout.preferredHeight: donateCol.implicitHeight + 28
            Layout.topMargin: 4
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(App.Theme.warn.r,    App.Theme.warn.g,    App.Theme.warn.b,    0.16) }
                GradientStop { position: 1.0; color: Qt.rgba(App.Theme.accent2.r, App.Theme.accent2.g, App.Theme.accent2.b, 0.14) }
            }
            border.color: Qt.rgba(App.Theme.warn.r, App.Theme.warn.g, App.Theme.warn.b, 0.7)
            border.width: 1

            // Soft breathing glow — subtle, doesn't shout
            SequentialAnimation on border.width {
                running: dialog.visible
                loops: Animation.Infinite
                NumberAnimation { to: 2; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 1600; easing.type: Easing.InOutSine }
            }

            ColumnLayout {
                id: donateCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        text: "☕"
                        color: App.Theme.warn
                        font.pixelSize: 28
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            text: "Support the project"
                            color: App.Theme.text
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                        Label {
                            text: "Free now, free forever — but coffee helps"
                            color: App.Theme.textDim
                            font.pixelSize: 11
                            font.italic: true
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Built by a fellow ham, for the community. Free to use, free to share. A small donation keeps the code flowing and the releases coming.  73 de N8SDR"
                    color: App.Theme.text
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Button {
                    Layout.alignment: Qt.AlignLeft
                    text: "☕  Buy me a coffee — PayPal"
                    highlighted: true
                    onClicked: Qt.openUrlExternally(dialog.donateUrl)
                    ToolTip.text: "Opens PayPal in your browser"
                    ToolTip.visible: hovered
                }
            }
        }

        // --- Update checker ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: updCol.implicitHeight + 16
            radius: 8
            color: "transparent"
            border.color: App.Theme.border

            ColumnLayout {
                id: updCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: "UPDATES"
                        color: App.Theme.textFaint
                        font.pixelSize: 10
                        font.letterSpacing: 1.0
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                    Label {
                        text: updateChecker.repoUrl
                        color: App.Theme.accent
                        font.pixelSize: 10
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(updateChecker.repoUrl)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: {
                        var s = updateChecker.status
                        if (s === "checking")          return "Checking GitHub…"
                        if (s === "up_to_date")        return updateChecker.message
                        if (s === "update_available")  return "🎉 " + updateChecker.message
                        if (s === "no_releases")       return updateChecker.message
                        if (s === "error")             return "⚠ " + updateChecker.message
                        return "Current version: v" + App.AppVersion.version
                    }
                    color: updateChecker.status === "update_available" ? App.Theme.good
                         : updateChecker.status === "error"            ? App.Theme.bad
                         : App.Theme.text
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Button {
                        text: "Check for Updates"
                        enabled: updateChecker.status !== "checking"
                        onClicked: updateChecker.check()
                    }
                    Button {
                        visible: updateChecker.status === "update_available"
                        text: "Open Release Page"
                        highlighted: true
                        onClicked: Qt.openUrlExternally(updateChecker.releaseUrl)
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "© " + App.AppVersion.year + " N8SDR · Rick Langford"
            color: App.Theme.textFaint
            font.pixelSize: 11
        }
    }
}
