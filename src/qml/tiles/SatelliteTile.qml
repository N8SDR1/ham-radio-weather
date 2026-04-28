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

    // Ticks are referenced as a dependency inside any binding that
    // depends on Date.now(). Without this, QML only re-evaluates the
    // countdown text when `passes` changes — "in 15m" would stay stuck
    // on "in 15m" until the next TLE poll lands a new pass.
    //
    // Adaptive cadence: tick once per second when a pass is imminent
    // (≤ 2 min out) for smooth seconds countdown, otherwise every 30 s
    // to keep CPU quiet.
    property int _tick: 0
    readonly property bool _imminentCountdown: {
        if (!hasData || nextIsNow) return false
        var m = minsUntil(nextPass ? nextPass.aos : null)
        return m !== null && m >= 0 && m <= 2
    }
    Timer {
        interval: root._imminentCountdown ? 1000 : 30 * 1000
        running:  true
        repeat:   true
        onTriggered: root._tick++
    }

    function minsUntil(iso) {
        if (!iso) return null
        var t = new Date(iso)
        if (isNaN(t.getTime())) return null
        return Math.round((t.getTime() - Date.now()) / 60000)
    }
    // Returns seconds-until-AOS for sub-minute granularity. Used when
    // the pass is close enough that "in 1m" would be misleading.
    function secsUntil(iso) {
        if (!iso) return null
        var t = new Date(iso)
        if (isNaN(t.getTime())) return null
        return Math.max(0, Math.round((t.getTime() - Date.now()) / 1000))
    }
    function fmtMinutes(m) {
        if (m === null) return "—"
        if (m <= 0)    return "now"
        if (m < 60)    return "in " + m + "m"
        var h = Math.floor(m / 60)
        var mm = m % 60
        return "in " + h + "h " + mm + "m"
    }
    // Rich countdown that shows seconds when ≤ 90 s out, minutes above
    // that. Takes the raw ISO so it can always compute fresh against
    // the current clock.
    function fmtCountdown(iso) {
        var _dep = root._tick      // re-evaluate on every tick
        if (!iso) return "—"
        var secs = root.secsUntil(iso)
        if (secs === null) return "—"
        if (secs <= 0) return "now"
        if (secs < 90) return "in " + secs + "s"
        // Fall through to minute display for anything >= 90 s
        return root.fmtMinutes(root.minsUntil(iso))
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
                    id: countdownLabel
                    // Rich countdown — shows seconds when the pass is
                    // imminent (< 90 s out), minutes above that. Depends
                    // on root._tick so it actually ticks down over time.
                    // During a live pass, shows current elevation + time
                    // remaining until LOS instead of an AOS countdown.
                    text: {
                        var _dep = root._tick
                        if (!root.nextPass) return "—"
                        if (root.nextIsNow) {
                            var el   = root.nextPass.current_el || 0
                            var secs = root.secsUntil(root.nextPass.los)
                            if (secs === null || secs <= 0)
                                return "At " + el + "°"
                            if (secs < 90)
                                return "At " + el + "° · " + secs + "s left"
                            var mins = Math.round(secs / 60)
                            return "At " + el + "° · " + mins + "m left"
                        }
                        return root.fmtCountdown(root.nextPass.aos)
                    }
                    color: root.nextIsNow ? App.Theme.good : App.Theme.accent2
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.family: App.Theme.displayFont

                    // Imminent-pass pulse: when the next bird is within
                    // 10 minutes, the countdown gently breathes green
                    // so it catches your eye across the room. Falls
                    // back to static display otherwise.
                    readonly property int _minsLeft: {
                        var _dep = root._tick      // re-evaluate on every tick
                        if (root.nextIsNow) return -1
                        var m = root.minsUntil(root.nextPass ? root.nextPass.aos : null)
                        return (m === null) ? 999 : m
                    }
                    readonly property bool _imminent:
                        App.AppSettings.effectForceCountdown ||
                        (_minsLeft >= 0 && _minsLeft <= 10)

                    SequentialAnimation on opacity {
                        running: countdownLabel._imminent
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on scale {
                        running: countdownLabel._imminent
                        loops:   Animation.Infinite
                        NumberAnimation { to: 1.05; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 900; easing.type: Easing.InOutSine }
                    }
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
                // "Pass length" — this is how long AO-27 (or whichever
                // bird) will be above the horizon when it arrives.
                // Label it explicitly so it doesn't read as a countdown.
                text: root.nextPass ? "⏱ Pass " + root.fmtDuration(root.nextPass.duration_s) : ""
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
                        // Tick-dependent so each row refreshes as time
                        // passes, not just when TLE data updates.
                        text: {
                            var _dep = root._tick
                            return p ? root.fmtMinutes(root.minsUntil(p.aos)) : ""
                        }
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
