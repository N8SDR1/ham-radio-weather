import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

// Dedicated NOAA / NWS active-alerts tile. Shows full headlines, area
// descriptions, urgency / certainty, expiration, and the first ~600 chars of
// the description text — all word-wrapped.  Scrolls when multiple alerts are
// active.
Tile {
    id: root
    property var data: ({})   // unused (tile pulls from alertsClient)

    readonly property var alerts: alertsClient.alerts || []
    readonly property int alertCount: alerts.length
    readonly property bool hasSevere: alertsClient.hasExtremeOrSevere
    readonly property bool enabled: alertsClient.enabled
    readonly property string providerName: alertsClient.providerName
    readonly property bool hasGrid: App.AppSettings.gridSquare.length > 0
                                    || App.AppSettings.overrideLocationEnabled

    function _severityColor(sev) {
        var s = (sev || "").toLowerCase()
        if (s === "extreme")  return App.Theme.bad
        if (s === "severe")   return App.Theme.bad
        if (s === "moderate") return App.Theme.warn
        if (s === "minor")    return App.Theme.accent
        return App.Theme.textDim
    }

    function _severityIcon(sev) {
        var s = (sev || "").toLowerCase()
        if (s === "extreme" || s === "severe") return "⚠"
        if (s === "moderate")                  return "🟠"
        return "ℹ"
    }

    function _fmtExpires(iso) {
        if (!iso) return ""
        var t = new Date(iso)
        if (isNaN(t.getTime())) return ""
        return Qt.formatDateTime(t, "MMM d · h:mm ap")
    }

    title:       !enabled          ? "Alerts · Off"
               : alertCount === 0  ? "All Clear"
               : hasSevere         ? alertCount + " · Severe"
                                   : alertCount + " Active"
    iconEmoji:   !enabled          ? "🚫"
               : alertCount === 0  ? "✅"
               : hasSevere         ? "⚠"
                                   : "🔔"
    accentColor: !enabled          ? App.Theme.textFaint
               : alertCount === 0  ? App.Theme.good
               : hasSevere         ? App.Theme.bad
                                   : App.Theme.warn

    // Always-on centered header label showing which provider is feeding this
    // tile. Keeps the accent color distinct from the toggleable canonical-
    // names setting so the provider label is immediately legible.
    centerLabelText: (enabled && hasGrid) ? "via " + providerName : ""
    centerLabelColor: App.Theme.accent
    centerLabelSize: 14

    implicitHeight: 300

    // === Needs grid square ===
    Label {
        anchors.centerIn: parent
        visible: root.enabled && !root.hasGrid
        text: "Set your Maidenhead grid square in Settings (⚙)\nto enable NWS alert monitoring."
        color: App.Theme.textDim
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 40
        wrapMode: Text.WordWrap
    }

    // === Polling disabled state ===
    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.enabled
        spacing: 8

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "🚫"
            font.pixelSize: 56
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "NWS polling is off"
            color: App.Theme.textDim
            font.pixelSize: 18
            font.weight: Font.DemiBold
            font.family: App.Theme.displayFont
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Enable in Settings → Alerts → active-alerts check"
            color: App.Theme.textFaint
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // === Empty state ===
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.enabled && root.hasGrid && root.alertCount === 0
        spacing: 8

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "✅"
            font.pixelSize: 56
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "No active alerts"
            color: App.Theme.good
            font.pixelSize: 18
            font.weight: Font.DemiBold
            font.family: App.Theme.displayFont
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Checked every " + App.AppSettings.nwsPollMinutes
                + " min via " + root.providerName
            color: App.Theme.textFaint
            font.pixelSize: 11
        }
    }

    // === Active alerts — scrollable list of cards with full wrapped text ===
    ScrollView {
        anchors.fill: parent
        visible: root.enabled && root.hasGrid && root.alertCount > 0
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: parent.width
            spacing: 8

            Repeater {
                model: root.alerts
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cardCol.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(root._severityColor(modelData.severity).r,
                                   root._severityColor(modelData.severity).g,
                                   root._severityColor(modelData.severity).b, 0.10)
                    border.color: root._severityColor(modelData.severity)
                    border.width: 1

                    // Pulse only for extreme/severe
                    SequentialAnimation on opacity {
                        running: (modelData.severity === "extreme"
                               || modelData.severity === "severe")
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.70; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutSine }
                    }

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        // Header row: icon + event + severity pill + expiration
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Label {
                                text: root._severityIcon(modelData.severity)
                                color: root._severityColor(modelData.severity)
                                font.pixelSize: 18
                            }
                            Label {
                                text: modelData.event
                                color: App.Theme.text
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                radius: 4
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: sevBadge.implicitWidth + 12
                                color: Qt.rgba(root._severityColor(modelData.severity).r,
                                               root._severityColor(modelData.severity).g,
                                               root._severityColor(modelData.severity).b, 0.25)
                                border.color: root._severityColor(modelData.severity)
                                border.width: 1
                                Label {
                                    id: sevBadge
                                    anchors.centerIn: parent
                                    text: modelData.severity.toUpperCase()
                                    color: root._severityColor(modelData.severity)
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        // Headline — the one-liner NWS publishes
                        Label {
                            Layout.fillWidth: true
                            visible: modelData.headline && modelData.headline !== modelData.event
                            text: modelData.headline
                            color: App.Theme.text
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        // Area + expiration
                        Label {
                            Layout.fillWidth: true
                            visible: modelData.areaDesc || modelData.expires
                            text: {
                                var parts = []
                                if (modelData.areaDesc) parts.push("📍 " + modelData.areaDesc)
                                if (modelData.expires)  parts.push("until " + root._fmtExpires(modelData.expires))
                                return parts.join("  ·  ")
                            }
                            color: App.Theme.textDim
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }

                        // Description — longest form text, expandable
                        Label {
                            id: descLabel
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            visible: modelData.desc && modelData.desc.length > 0
                            text: modelData.desc
                            color: App.Theme.textDim
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: descExpanded ? 50 : 3
                            elide: Text.ElideRight
                            property bool descExpanded: false

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: descLabel.descExpanded = !descLabel.descExpanded
                                ToolTip.visible: containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: descLabel.descExpanded
                                    ? "Click to collapse"
                                    : "Click to show full description"
                            }
                        }

                        // Footer row: sender + urgency/certainty
                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            text: {
                                var bits = []
                                if (modelData.sender)     bits.push(modelData.sender)
                                if (modelData.urgency)    bits.push("urgency: " + modelData.urgency)
                                if (modelData.certainty)  bits.push("certainty: " + modelData.certainty)
                                return bits.join("  ·  ")
                            }
                            color: App.Theme.textFaint
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
