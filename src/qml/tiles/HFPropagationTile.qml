import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property real sfi:   data.sfi    !== null && data.sfi    !== undefined ? data.sfi    : NaN
    readonly property real kidx:  data.kindex !== null && data.kindex !== undefined ? data.kindex : NaN
    readonly property real aidx:  data.aindex !== null && data.aindex !== undefined ? data.aindex : NaN
    readonly property var  bands: data.bands || ({})

    readonly property bool hasData: !isNaN(sfi)
    readonly property var _mood: App.Moods.hfProp(sfi)
    readonly property var _storm: App.Moods.geoStorm(kidx)

    // Geomagnetic storms at G3+ (K-index ≥ 7) cause HF blackouts. When
    // that's happening, overlay a drifting horizontal-line "static"
    // pattern across the tile — subtle interference to match the mood
    // without blocking the data.
    readonly property bool _blackout:
        App.AppSettings.effectForceStatic || kidx >= 7

    title:       hasData ? _mood.title : "HF Propagation"
    iconEmoji:   hasData ? _mood.icon  : "📡"
    accentColor: App.Theme.accent2

    implicitHeight: 280

    // Static overlay — thin horizontal lines drifting vertically across
    // the tile. Low opacity so it reads as interference, not obstruction.
    Item {
        id: staticLayer
        anchors.fill: parent
        z: 9
        visible: root._blackout
        clip: true

        Repeater {
            model: 9
            delegate: Rectangle {
                readonly property int _dur: 1100 + (index * 170)
                width:  parent.width
                height: (index % 3 === 0) ? 2 : 1
                color:  App.Theme.bad
                opacity: 0.22
                y: parent.height
                SequentialAnimation on y {
                    running: staticLayer.visible
                    loops:   Animation.Infinite
                    PauseAnimation  { duration: index * 150 }
                    NumberAnimation {
                        from: staticLayer.height + 4
                        to: -4
                        duration: _dur
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    readonly property var _bandOrder: ["80m-40m", "30m-20m", "17m-15m", "12m-10m"]

    function _stormColor(sev) {
        if (sev >= 4) return App.Theme.bad
        if (sev >= 2) return App.Theme.warn
        if (sev >= 1) return App.Theme.lightning
        return App.Theme.good
    }

    Label {
        anchors.centerIn: parent
        visible: !root.hasData
        text: "Waiting for hamqsl.com data…\n(first poll within ~15s of startup)"
        color: App.Theme.textDim
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        anchors.fill: parent
        visible: root.hasData
        spacing: 18

        // left column: SFI big, plus K/A indexes + geomagnetic storm
        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            BigNumber {
                Layout.alignment: Qt.AlignLeft
                text: isNaN(root.sfi) ? "—" : root.sfi.toFixed(0)
                color: App.Theme.text
                glowColor: root.accentColor
                glowOpacity: 0.85
                pixelSize: 68
            }
            Label {
                text: "SFI  ·  SOLAR FLUX"
                color: App.Theme.textDim
                font.pixelSize: 11
                font.letterSpacing: 1.0
                font.weight: Font.Bold
            }

            RowLayout {
                Layout.topMargin: 4
                spacing: 18
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "K-INDEX"
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        font.letterSpacing: 1.0
                        font.weight: Font.Bold
                    }
                    Label {
                        text: isNaN(root.kidx) ? "—" : root.kidx.toFixed(0)
                        color: root.kidx >= 5 ? App.Theme.bad
                             : root.kidx >= 3 ? App.Theme.warn
                             : App.Theme.good
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        font.family: App.Theme.displayFont
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "A-INDEX"
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        font.letterSpacing: 1.0
                        font.weight: Font.Bold
                    }
                    Label {
                        text: isNaN(root.aidx) ? "—" : root.aidx.toFixed(0)
                        color: root.aidx >= 30 ? App.Theme.bad
                             : root.aidx >= 15 ? App.Theme.warn
                             : App.Theme.good
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        font.family: App.Theme.displayFont
                    }
                }
            }

            // geomagnetic storm badge
            Rectangle {
                Layout.topMargin: 4
                Layout.preferredHeight: 30
                Layout.preferredWidth: stormRow.implicitWidth + 18
                radius: 7
                color: Qt.rgba(root._stormColor(root._storm.severity).r,
                               root._stormColor(root._storm.severity).g,
                               root._stormColor(root._storm.severity).b, 0.18)
                border.color: root._stormColor(root._storm.severity)
                border.width: 1

                SequentialAnimation on opacity {
                    running: root._storm.severity >= 3
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 700; easing.type: Easing.InOutSine }
                }

                Row {
                    id: stormRow
                    anchors.centerIn: parent
                    spacing: 9
                    Label {
                        text: root._storm.severity >= 3 ? "⚠" : "🧲"
                        color: root._stormColor(root._storm.severity)
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: root._storm.level
                        color: root._stormColor(root._storm.severity)
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        font.family: App.Theme.displayFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: "·"
                        color: root._stormColor(root._storm.severity)
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: root._storm.title.toUpperCase() + " STORM"
                        color: root._stormColor(root._storm.severity)
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        anchors.verticalCenter: parent.verticalCenter
                    }
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

        // right column: band grid
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Label { text: "";      Layout.preferredWidth: 80 }
                Label { text: "DAY";   color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                Label { text: "NIGHT"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            }

            Repeater {
                model: root._bandOrder
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label {
                        text: modelData
                        color: App.Theme.text
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.family: App.Theme.displayFont
                        Layout.preferredWidth: 80
                    }
                    BandCell {
                        Layout.fillWidth: true
                        cond: (root.bands && root.bands[modelData]) ? (root.bands[modelData].day   || "") : ""
                    }
                    BandCell {
                        Layout.fillWidth: true
                        cond: (root.bands && root.bands[modelData]) ? (root.bands[modelData].night || "") : ""
                    }
                }
            }
        }
    }

    component BandCell: Rectangle {
        property string cond: ""
        implicitHeight: 34
        radius: 6
        color: App.Theme.bandColor(cond)
        border.color: Qt.rgba(1, 1, 1, App.Theme.dark ? 0.08 : 0.12)
        border.width: 1
        Label {
            anchors.centerIn: parent
            text: parent.cond || "—"
            color: App.Theme.dark ? "#0d1118" : "#f5f5f5"
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 0.4
        }
    }
}
