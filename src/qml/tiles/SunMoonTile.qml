import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property var daily: data.daily || []
    readonly property var today: daily.length > 0 ? daily[0] : null
    readonly property bool hasData: today !== null && today.sunrise && today.sunset

    readonly property date sunriseDt: hasData ? new Date(today.sunrise) : new Date(NaN)
    readonly property date sunsetDt:  hasData ? new Date(today.sunset)  : new Date(NaN)

    // time-of-day mood for the title
    readonly property int  _hourNow: (new Date()).getHours()
    readonly property string _moodTitle: {
        if (_hourNow >= 5 && _hourNow < 7)   return "Golden Hour"
        if (_hourNow >= 7 && _hourNow < 19)  return "Daytime"
        if (_hourNow >= 19 && _hourNow < 21) return "Sunset"
        if (_hourNow >= 21 || _hourNow < 3)  return "Night Watch"
        return "Pre-Dawn"
    }

    // --- moon phase (Conway-style) ---
    function moonPhase(date) {
        var ms = date.getTime() - Date.UTC(2000, 0, 6, 18, 14, 0)
        var days = ms / 86400000
        var cycle = 29.53058867
        var p = (days / cycle) - Math.floor(days / cycle)
        if (p < 0) p += 1
        return p
    }
    function moonIcon(p) {
        if (p < 0.03 || p > 0.97) return "🌑"
        if (p < 0.22) return "🌒"
        if (p < 0.28) return "🌓"
        if (p < 0.47) return "🌔"
        if (p < 0.53) return "🌕"
        if (p < 0.72) return "🌖"
        if (p < 0.78) return "🌗"
        return "🌘"
    }
    function moonLabel(p) {
        if (p < 0.03 || p > 0.97) return "New Moon"
        if (p < 0.22) return "Waxing Crescent"
        if (p < 0.28) return "First Quarter"
        if (p < 0.47) return "Waxing Gibbous"
        if (p < 0.53) return "Full Moon"
        if (p < 0.72) return "Waning Gibbous"
        if (p < 0.78) return "Last Quarter"
        return "Waning Crescent"
    }

    readonly property real _phase: moonPhase(new Date())

    title:       _moodTitle
    iconEmoji:   (_hourNow >= 7 && _hourNow < 19) ? "☀" : moonIcon(_phase)
    accentColor: (_hourNow >= 7 && _hourNow < 19) ? App.Theme.lightning : App.Theme.accent2

    implicitHeight: 280

    function fmtTime(dt) {
        if (isNaN(dt.getTime())) return "—"
        return Qt.formatTime(dt, "h:mm ap")
    }

    function dayLengthLabel() {
        if (!hasData) return "—"
        var mins = Math.round((sunsetDt.getTime() - sunriseDt.getTime()) / 60000)
        var h = Math.floor(mins / 60), m = mins % 60
        return h + "h " + m + "m"
    }

    Label {
        anchors.centerIn: parent
        visible: !root.hasData
        text: App.AppSettings.gridSquare
              ? "Loading sun/moon data…"
              : "Set your Maidenhead grid square in Settings (⚙)."
        color: App.Theme.textDim
        font.pixelSize: 13
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 40
    }

    RowLayout {
        anchors.fill: parent
        visible: root.hasData
        spacing: 14

        // sun rise/set
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            ColumnLayout {
                spacing: 2
                Label {
                    text: "SUNRISE"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: 6
                    Label { text: "🌅"; font.pixelSize: 18 }
                    Label {
                        text: root.fmtTime(root.sunriseDt)
                        color: App.Theme.text
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        font.family: App.Theme.displayFont
                    }
                }
            }
            ColumnLayout {
                spacing: 2
                Label {
                    text: "SUNSET"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: 6
                    Label { text: "🌇"; font.pixelSize: 18 }
                    Label {
                        text: root.fmtTime(root.sunsetDt)
                        color: App.Theme.text
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        font.family: App.Theme.displayFont
                    }
                }
            }
            ColumnLayout {
                spacing: 2
                Label {
                    text: "DAY LENGTH"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.0
                    font.weight: Font.Bold
                }
                Label {
                    text: root.dayLengthLabel()
                    color: App.Theme.text
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    font.family: App.Theme.displayFont
                }
            }
        }

        Rectangle {
            width: 1; Layout.fillHeight: true
            color: App.Theme.border
            opacity: 0.5
            Layout.topMargin: 10
            Layout.bottomMargin: 10
        }

        // moon block
        ColumnLayout {
            Layout.preferredWidth: 140
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.moonIcon(root._phase)
                font.pixelSize: 58
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.moonLabel(root._phase)
                color: App.Theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round(root._phase * 100) + "% cycle"
                color: App.Theme.textFaint
                font.pixelSize: 10
            }
        }
    }
}
