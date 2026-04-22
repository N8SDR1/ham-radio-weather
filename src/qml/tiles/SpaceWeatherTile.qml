import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

// 3-day space-weather / planetary-K forecast from NOAA SWPC. Pairs with the
// HF Propagation tile: that one shows "now", this one shows the 72 h outlook
// so operators can plan DX sessions around upcoming geomagnetic storms.
Tile {
    id: root
    property var data: ({})

    readonly property var forecast:  data.forecast || []
    readonly property var observed:  data.observed || []
    readonly property real currentKp: data.current_kp !== undefined ? data.current_kp : NaN
    readonly property real peakKp:    data.peak_kp    !== undefined ? data.peak_kp    : NaN
    readonly property int  peakG:     data.peak_g     !== undefined ? data.peak_g     : 0
    readonly property string peakTime: data.peak_time || ""
    readonly property bool hasData: forecast.length > 0

    readonly property var _mood: App.Moods.spaceWeather(hasData ? peakKp : NaN)
    title:       _mood.title
    iconEmoji:   _mood.icon
    accentColor: {
        if (!hasData || isNaN(peakKp)) return App.Theme.accent
        if (peakKp >= 7) return App.Theme.bad
        if (peakKp >= 5) return App.Theme.warn
        if (peakKp >= 4) return App.Theme.lightning
        return App.Theme.good
    }

    implicitHeight: 300

    // G4/G5 geomagnetic storms (peak Kp >= 8) are rare enough that when
    // they actually happen, the tile earns some extra drama: slow
    // aurora-green/violet waves undulating in the background.
    readonly property bool _aurora:
        App.AppSettings.effectForceAurora || peakKp >= 8

    Item {
        id: auroraLayer
        anchors.fill: parent
        z: -1
        visible: root._aurora
        clip: true
        opacity: 0.35

        // Two slow-drifting color bands give a convincing undulating
        // aurora ribbon without needing shaders. Different speeds +
        // offsets so they never align the same way twice.
        Rectangle {
            id: auroraBand1
            width:  parent.width * 1.4
            height: 120
            radius: 60
            y: parent.height * 0.15
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "#55ff9c" }   // aurora green
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                running: auroraLayer.visible
                loops:   Animation.Infinite
                from: -auroraBand1.width + auroraLayer.width
                to:   auroraLayer.width
                duration: 9000
                easing.type: Easing.InOutSine
            }
            NumberAnimation on y {
                running: auroraLayer.visible
                loops:   Animation.Infinite
                from: auroraLayer.height * 0.10
                to:   auroraLayer.height * 0.40
                duration: 7000
                easing.type: Easing.InOutSine
            }
        }
        Rectangle {
            id: auroraBand2
            width:  parent.width * 1.6
            height: 100
            radius: 50
            y: parent.height * 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "#8b5cf6" }   // aurora violet
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                running: auroraLayer.visible
                loops:   Animation.Infinite
                from: auroraLayer.width
                to:   -auroraBand2.width + auroraLayer.width
                duration: 11000
                easing.type: Easing.InOutSine
            }
            NumberAnimation on y {
                running: auroraLayer.visible
                loops:   Animation.Infinite
                from: auroraLayer.height * 0.70
                to:   auroraLayer.height * 0.35
                duration: 8500
                easing.type: Easing.InOutSine
            }
        }
    }

    function _kpColor(kp) {
        if (kp >= 7) return App.Theme.bad
        if (kp >= 5) return App.Theme.warn
        if (kp >= 4) return App.Theme.lightning
        if (kp >= 3) return Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.75)
        return App.Theme.good
    }

    function _fmtPeakTime(iso) {
        if (!iso) return ""
        var t = new Date(iso)
        if (isNaN(t.getTime())) return ""
        var ms = t.getTime() - Date.now()
        var hrs = Math.round(ms / 3600000)
        if (hrs < 0) return "recent"
        if (hrs < 1) return "within the hour"
        if (hrs < 48) return "in " + hrs + " h"
        return "in " + Math.round(hrs / 24) + " d"
    }

    // Loading state
    Label {
        anchors.centerIn: parent
        visible: !root.hasData
        text: "Waiting for NOAA SWPC planetary-K forecast…"
        color: App.Theme.textDim
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasData
        spacing: 8

        // Top row: current + peak
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Label {
                    text: "NOW"
                    color: App.Theme.textFaint
                    font.pixelSize: 10
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: 6
                    BigNumber {
                        Layout.alignment: Qt.AlignVCenter
                        text: isNaN(root.currentKp) ? "—" : root.currentKp.toFixed(1)
                        color: root._kpColor(root.currentKp)
                        glowColor: root._kpColor(root.currentKp)
                        glowOpacity: 0.7
                        pixelSize: 44
                    }
                    Label {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 8
                        text: "Kp"
                        color: App.Theme.textDim
                        font.pixelSize: 14
                        font.family: App.Theme.displayFont
                        font.weight: Font.Medium
                    }
                }
            }

            Rectangle {
                width: 1
                Layout.preferredHeight: 48
                color: App.Theme.border
                opacity: 0.5
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: "72 H PEAK"
                    color: App.Theme.textFaint
                    font.pixelSize: 10
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: 8
                    Label {
                        text: isNaN(root.peakKp) ? "—" : root.peakKp.toFixed(1) + " Kp"
                        color: root._kpColor(root.peakKp)
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.family: App.Theme.displayFont
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        visible: root.peakG > 0
                        implicitWidth: gBadge.implicitWidth + 10
                        implicitHeight: gBadge.implicitHeight + 4
                        radius: 4
                        color: Qt.rgba(root._kpColor(root.peakKp).r,
                                       root._kpColor(root.peakKp).g,
                                       root._kpColor(root.peakKp).b, 0.2)
                        border.color: root._kpColor(root.peakKp)
                        border.width: 1
                        Label {
                            id: gBadge
                            anchors.centerIn: parent
                            text: "G" + root.peakG
                            color: root._kpColor(root.peakKp)
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.5
                        }
                    }
                }
                Label {
                    text: root._fmtPeakTime(root.peakTime)
                    color: App.Theme.textDim
                    font.pixelSize: 11
                }
            }
        }

        // 72-hour forecast bars (8 × 3-hour slots per day, 3 days)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 4

            Label {
                text: "72-HOUR KP FORECAST"
                color: App.Theme.textFaint
                font.pixelSize: 10
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }

            // Bar chart
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 50

                // Kp scale lines (reference: 4 = unsettled, 5 = storm)
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: parent.height - (parent.height * 5 / 9)
                    height: 1
                    color: App.Theme.warn
                    opacity: 0.25
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: parent.height - (parent.height * 7 / 9)
                    height: 1
                    color: App.Theme.bad
                    opacity: 0.25
                }

                Row {
                    anchors.fill: parent
                    spacing: 2
                    Repeater {
                        model: Math.min(24, root.forecast.length)
                        delegate: Item {
                            width: Math.max(1, (parent.width - (Math.min(24, root.forecast.length) - 1) * 2)
                                            / Math.min(24, root.forecast.length))
                            height: parent.height
                            readonly property var slot: root.forecast[index]
                            readonly property real kp: slot ? slot.kp : 0
                            // Bars grow from bottom
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: parent.height * Math.min(1, kp / 9)
                                radius: 2
                                color: root._kpColor(kp)
                                opacity: 0.85
                                Behavior on height { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                }
            }

            // Day labels underneath
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: "Today →"
                    color: App.Theme.textDim
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                }
                Label {
                    Layout.fillWidth: true
                    text: "+1 day"
                    color: App.Theme.textDim
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    Layout.fillWidth: true
                    text: "+2 days"
                    color: App.Theme.textDim
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Legend: what the bar colors mean
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Rectangle { width: 14; height: 10; radius: 2; color: App.Theme.good; opacity: 0.9 }
                Label { text: "Quiet (<4)"; color: App.Theme.textDim; font.pixelSize: 12 }

                Rectangle { width: 14; height: 10; radius: 2; color: App.Theme.lightning; opacity: 0.9 }
                Label { text: "Unsettled (4)"; color: App.Theme.textDim; font.pixelSize: 12 }

                Rectangle { width: 14; height: 10; radius: 2; color: App.Theme.warn; opacity: 0.9 }
                Label { text: "Storm (5-6)"; color: App.Theme.textDim; font.pixelSize: 12 }

                Rectangle { width: 14; height: 10; radius: 2; color: App.Theme.bad; opacity: 0.9 }
                Label { text: "Severe (7+)"; color: App.Theme.textDim; font.pixelSize: 12 }

                Item { Layout.fillWidth: true }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
