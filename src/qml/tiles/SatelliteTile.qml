import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property var passes:  data.passes || []
    readonly property bool hasData: passes.length > 0
    readonly property var nextPass: hasData ? passes[0] : null
    readonly property bool nextIsNow: nextPass !== null && nextPass.currently_up === true

    readonly property string _title: {
        if (!App.AppSettings.gridSquare) return "Satellites"
        if (!hasData)                    return "Satellites"
        if (nextIsNow)                   return nextPass.name + " Overhead!"
        return "Next Pass · " + nextPass.name
    }
    readonly property string _icon: {
        if (nextIsNow) return "📡"
        if (hasData)   return "🛰"
        return "🛰"
    }

    title:       _title
    iconEmoji:   _icon
    accentColor: nextIsNow ? App.Theme.good : App.Theme.accent2

    implicitHeight: 280

    function minsUntil(iso) {
        if (!iso) return null
        var t = new Date(iso)
        if (isNaN(t.getTime())) return null
        return Math.round((t.getTime() - Date.now()) / 60000)
    }
    function fmtMinutes(m) {
        if (m === null) return "—"
        if (m <= 0)    return "now"
        if (m < 60)    return "in " + m + "m"
        var h = Math.floor(m / 60)
        var mm = m % 60
        return "in " + h + "h " + mm + "m"
    }
    function fmtDuration(s) {
        if (s === undefined || s === null) return "—"
        var m = Math.floor(s / 60)
        var ss = s % 60
        return m + "m " + (ss < 10 ? "0" : "") + ss + "s"
    }

    Label {
        anchors.centerIn: parent
        visible: !App.AppSettings.gridSquare
        text: "Set your Maidenhead grid square in Settings (⚙) to enable pass prediction."
        color: App.Theme.textDim
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 40
    }

    Label {
        anchors.centerIn: parent
        visible: App.AppSettings.gridSquare && !root.hasData
        text: "Fetching amateur satellite TLEs from celestrak.org…"
        color: App.Theme.textDim
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width - 40
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasData
        spacing: 6

        // hero: next pass
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: root.nextPass ? root.nextPass.name : "—"
                    color: App.Theme.text
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: root.nextIsNow
                        ? "Now at " + (root.nextPass ? root.nextPass.current_el : 0) + "°"
                        : root.fmtMinutes(root.minsUntil(root.nextPass ? root.nextPass.aos : null))
                    color: root.nextIsNow ? App.Theme.good : App.Theme.accent2
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.family: App.Theme.displayFont
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Label { text: "MAX EL"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold; Layout.alignment: Qt.AlignRight }
                Label {
                    text: root.nextPass ? root.nextPass.max_el + "°" : "—"
                    color: root.nextPass && root.nextPass.max_el >= 30
                           ? App.Theme.good
                           : root.nextPass && root.nextPass.max_el >= 10
                             ? App.Theme.warn
                             : App.Theme.textDim
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    font.family: App.Theme.displayFont
                    Layout.alignment: Qt.AlignRight
                }
            }
        }

        // secondary row: direction + duration
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: root.nextPass
                    ? "🧭 " + root.nextPass.aos_dir + " → " + root.nextPass.max_el_dir + " → " + root.nextPass.los_dir
                    : ""
                color: App.Theme.textDim
                font.pixelSize: 12
                font.family: App.Theme.displayFont
            }
            Item { Layout.fillWidth: true }
            Label {
                text: root.nextPass ? "⏱ " + root.fmtDuration(root.nextPass.duration_s) : ""
                color: App.Theme.textDim
                font.pixelSize: 12
                font.family: App.Theme.displayFont
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: App.Theme.border; opacity: 0.5 }

        // upcoming passes list
        Label {
            text: "UPCOMING"
            color: App.Theme.textFaint
            font.pixelSize: 10
            font.letterSpacing: 1.0
            font.weight: Font.Bold
            Layout.topMargin: 2
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: Math.min(4, Math.max(0, root.passes.length - 1))
                delegate: RowLayout {
                    Layout.fillWidth: true
                    readonly property var p: root.passes[index + 1]
                    spacing: 8

                    Label {
                        text: p ? p.name : ""
                        color: App.Theme.text
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        Layout.preferredWidth: 110
                        elide: Text.ElideRight
                    }
                    Label {
                        text: p ? root.fmtMinutes(root.minsUntil(p.aos)) : ""
                        color: App.Theme.textDim
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                    Label {
                        text: p ? p.max_el + "° " + p.max_el_dir : ""
                        color: p && p.max_el >= 30 ? App.Theme.good
                             : p && p.max_el >= 10 ? App.Theme.warn
                             : App.Theme.textDim
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: App.Theme.displayFont
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
