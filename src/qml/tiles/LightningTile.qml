import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "../" as App

Tile {
    id: root
    property var data: ({})

    readonly property int  strikesToday: data.lightning_day !== undefined ? data.lightning_day : 0
    readonly property int  strikesHour:  data.lightning_hour !== undefined ? data.lightning_hour : 0
    readonly property var  lastStrike:   data.lightning_time
    readonly property real distance:     data.lightning_distance !== undefined ? data.lightning_distance : NaN

    readonly property var _mood: App.Moods.lightning(distance, strikesToday)
    // Panic threshold is user-configurable via Settings → Tile Personality.
    // Dev-test toggle forces panic mode regardless of distance/strike count
    // so the strobe + title rotation can be previewed on a calm day.
    readonly property bool _panicking:
        App.AppSettings.effectForceStrobe ||
        (strikesToday > 0 && !isNaN(distance) && distance < App.AppSettings.moodLightningPanicMi)

    // Escalating panic title rotation when strikes are within 5 mi —
    // cycles through progressively more frantic captions so the tile
    // actually feels like it's yelling at you. Falls back to the
    // calm mood title as soon as the threat distance opens up again.
    readonly property var _panicTitles: [
        "Unplug the Rig!",
        "NO SERIOUSLY UNPLUG",
        "⚡ THE RIG! ⚡",
        "SAVE YOURSELF",
        "The antenna! THE ANTENNA!"
    ]
    property int _panicIdx: 0

    title:     _panicking ? _panicTitles[_panicIdx] : _mood.title
    iconEmoji: _mood.icon
    accentColor: _panicking ? App.Theme.bad : App.Theme.lightning

    // Step the panic index every ~2.2 s while the panic is active — slow
    // enough that each caption has time to read and land, fast enough
    // that the escalation still feels urgent.
    Timer {
        running: root._panicking
        interval: 2200
        repeat: true
        onTriggered: root._panicIdx = (root._panicIdx + 1) % root._panicTitles.length
    }

    // age of last strike in human terms
    function lastStrikeLabel() {
        if (!lastStrike) return "—"
        var t = new Date(lastStrike)
        if (isNaN(t.getTime())) return "—"
        var diffMs = Date.now() - t.getTime()
        var min = Math.floor(diffMs / 60000)
        if (min < 1)   return "just now"
        if (min < 60)  return min + "m ago"
        var hr = Math.floor(min / 60)
        if (hr < 24)   return hr + "h ago"
        var d = Math.floor(hr / 24)
        return d + "d ago"
    }

    implicitHeight: 280

    // Zigzag lightning bolts flashing in the background when panicking.
    // THREE paths at different cycle lengths so they naturally phase in
    // and out of alignment — sometimes a lone bolt, sometimes two
    // overlap, sometimes the stage is quiet. Electric violet stroke
    // with indigo halo for that "purple thunder" vibe that reads great
    // against the dark theme (and doesn't fight the amber strobe up
    // front on the BigNumber).
    Item {
        id: boltLayer
        anchors.fill: parent
        anchors.margins: 14
        z: -1                 // sits behind the content
        visible: root._panicking
        clip: true

        // Shared color palette — tweak these two to retune the vibe.
        readonly property color _boltStroke: "#b8a7ff"   // pale lavender
        readonly property color _boltHalo:   "#6366f1"   // indigo glow

        // ----- Bolt 1 (left-biased, tall trunk w/ right branch) ----
        Item {
            id: bolt1
            anchors.fill: parent
            opacity: 0

            Shape {
                id: bolt1Shape
                anchors.fill: parent
                antialiasing: true
                layer.enabled: true
                layer.samples: 8

                ShapePath {
                    strokeColor: boltLayer._boltStroke
                    strokeWidth: 2.5
                    fillColor:  "transparent"
                    capStyle:   ShapePath.RoundCap
                    joinStyle:  ShapePath.BevelJoin
                    startX: bolt1.width * 0.28
                    startY: 0
                    PathLine { x: bolt1.width * 0.36; y: bolt1.height * 0.20 }
                    PathLine { x: bolt1.width * 0.22; y: bolt1.height * 0.38 }
                    PathLine { x: bolt1.width * 0.34; y: bolt1.height * 0.50 }
                    PathLine { x: bolt1.width * 0.20; y: bolt1.height * 0.68 }
                    PathLine { x: bolt1.width * 0.32; y: bolt1.height * 0.82 }
                    PathLine { x: bolt1.width * 0.24; y: bolt1.height }
                }
                ShapePath {
                    strokeColor: boltLayer._boltStroke
                    strokeWidth: 1.8
                    fillColor:  "transparent"
                    capStyle:   ShapePath.RoundCap
                    joinStyle:  ShapePath.BevelJoin
                    startX: bolt1.width * 0.34; startY: bolt1.height * 0.50
                    PathLine { x: bolt1.width * 0.48; y: bolt1.height * 0.58 }
                    PathLine { x: bolt1.width * 0.42; y: bolt1.height * 0.70 }
                }
            }

            MultiEffect {
                source: bolt1Shape
                anchors.fill: bolt1Shape
                shadowEnabled: true
                shadowBlur:    1.0
                shadowColor:   boltLayer._boltHalo
                shadowOpacity: 0.95
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   0
                autoPaddingEnabled: true
            }

            // Cycle ~10 s — long stretches of dark so the strikes feel
            // like events, not a metronome. Each bolt has its own period
            // so they phase in and out of alignment naturally.
            SequentialAnimation on opacity {
                running: boltLayer.visible
                loops:   Animation.Infinite
                PauseAnimation  { duration: 8000 }
                NumberAnimation { to: 0.55; duration: 70 }
                PauseAnimation  { duration: 180 }
                NumberAnimation { to: 0.0;  duration: 1750; easing.type: Easing.OutCubic }
            }
        }

        // ----- Bolt 2 (right-biased, mirrored branching) -----------
        Item {
            id: bolt2
            anchors.fill: parent
            opacity: 0

            Shape {
                id: bolt2Shape
                anchors.fill: parent
                antialiasing: true
                layer.enabled: true
                layer.samples: 8

                ShapePath {
                    strokeColor: boltLayer._boltStroke
                    strokeWidth: 2.5
                    fillColor:  "transparent"
                    capStyle:   ShapePath.RoundCap
                    joinStyle:  ShapePath.BevelJoin
                    startX: bolt2.width * 0.72
                    startY: 0
                    PathLine { x: bolt2.width * 0.65; y: bolt2.height * 0.18 }
                    PathLine { x: bolt2.width * 0.78; y: bolt2.height * 0.34 }
                    PathLine { x: bolt2.width * 0.66; y: bolt2.height * 0.48 }
                    PathLine { x: bolt2.width * 0.80; y: bolt2.height * 0.64 }
                    PathLine { x: bolt2.width * 0.70; y: bolt2.height * 0.80 }
                    PathLine { x: bolt2.width * 0.78; y: bolt2.height }
                }
                ShapePath {
                    strokeColor: boltLayer._boltStroke
                    strokeWidth: 1.8
                    fillColor:  "transparent"
                    capStyle:   ShapePath.RoundCap
                    joinStyle:  ShapePath.BevelJoin
                    startX: bolt2.width * 0.66; startY: bolt2.height * 0.48
                    PathLine { x: bolt2.width * 0.54; y: bolt2.height * 0.55 }
                    PathLine { x: bolt2.width * 0.58; y: bolt2.height * 0.66 }
                }
            }

            MultiEffect {
                source: bolt2Shape
                anchors.fill: bolt2Shape
                shadowEnabled: true
                shadowBlur:    1.0
                shadowColor:   boltLayer._boltHalo
                shadowOpacity: 0.95
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   0
                autoPaddingEnabled: true
            }

            // Cycle ~12 s — different period from Bolt 1 so they phase
            // in and out of alignment.
            SequentialAnimation on opacity {
                running: boltLayer.visible
                loops:   Animation.Infinite
                PauseAnimation  { duration: 10000 }
                NumberAnimation { to: 0.50; duration: 80 }
                PauseAnimation  { duration: 160 }
                NumberAnimation { to: 0.0;  duration: 2000; easing.type: Easing.OutCubic }
            }
        }

        // ----- Bolt 3 (center, short stout trunk, no branch) -------
        Item {
            id: bolt3
            anchors.fill: parent
            opacity: 0

            Shape {
                id: bolt3Shape
                anchors.fill: parent
                antialiasing: true
                layer.enabled: true
                layer.samples: 8

                ShapePath {
                    strokeColor: boltLayer._boltStroke
                    strokeWidth: 2.0
                    fillColor:  "transparent"
                    capStyle:   ShapePath.RoundCap
                    joinStyle:  ShapePath.BevelJoin
                    // Starts partway down so it looks like a closer/smaller strike
                    startX: bolt3.width * 0.50
                    startY: bolt3.height * 0.08
                    PathLine { x: bolt3.width * 0.54; y: bolt3.height * 0.22 }
                    PathLine { x: bolt3.width * 0.46; y: bolt3.height * 0.38 }
                    PathLine { x: bolt3.width * 0.56; y: bolt3.height * 0.54 }
                    PathLine { x: bolt3.width * 0.48; y: bolt3.height * 0.70 }
                    PathLine { x: bolt3.width * 0.52; y: bolt3.height * 0.88 }
                }
            }

            MultiEffect {
                source: bolt3Shape
                anchors.fill: bolt3Shape
                shadowEnabled: true
                shadowBlur:    1.0
                shadowColor:   boltLayer._boltHalo
                shadowOpacity: 0.9
                shadowHorizontalOffset: 0
                shadowVerticalOffset:   0
                autoPaddingEnabled: true
            }

            // Cycle ~15 s — longest of the three, rarest bolt.
            SequentialAnimation on opacity {
                running: boltLayer.visible
                loops:   Animation.Infinite
                PauseAnimation  { duration: 13000 }
                NumberAnimation { to: 0.45; duration: 75 }
                PauseAnimation  { duration: 150 }
                NumberAnimation { to: 0.0;  duration: 1775; easing.type: Easing.OutCubic }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item { Layout.fillHeight: true }

        // Wrapper hosts the pulse-scale animation centered on the number.
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  numberRow.implicitWidth  + 20
            implicitHeight: numberRow.implicitHeight + 8

            RowLayout {
                id: numberRow
                anchors.centerIn: parent
                spacing: 6

                BigNumber {
                    id: bigN
                    Layout.alignment: Qt.AlignVCenter
                    text: root.strikesToday.toString()
                    color: root.strikesToday > 0 ? App.Theme.lightning : App.Theme.text
                    glowColor: App.Theme.lightning
                    glowOpacity: root.strikesToday > 0 ? 0.9 : 0.4
                    pixelSize: 86
                    // Strobe when strikes are within panic distance — the
                    // number flashes white like a bolt landing in the yard.
                    moodEffect: root._panicking ? "strobe" : ""
                    transformOrigin: Item.Center

                    // Scale punch on each strike — briefly grows ~8% like
                    // the number got slapped by the bolt, then glides back.
                    // Synced to the strobe rhythm so the halo flash, the
                    // radial bloom, and the scale punch all land together.
                    SequentialAnimation on scale {
                        running: root._panicking
                        loops:   Animation.Infinite
                        PauseAnimation  { duration: 1400 }
                        NumberAnimation { to: 1.09; duration: 35 }
                        NumberAnimation { to: 1.04; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 1.00; duration: 700; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 1.04; duration: 40 }
                        NumberAnimation { to: 1.00; duration: 550; easing.type: Easing.OutCubic }
                    }

                    // Tiny horizontal jitter — "getting zapped" micro-shake.
                    // Offset by a few ms from the scale so it feels physical
                    // rather than mechanical.
                    SequentialAnimation on x {
                        running: root._panicking
                        loops:   Animation.Infinite
                        PauseAnimation  { duration: 1435 }   // flash + 35
                        NumberAnimation { to:  2; duration: 30 }
                        NumberAnimation { to: -2; duration: 30 }
                        NumberAnimation { to:  1; duration: 30 }
                        NumberAnimation { to:  0; duration: 60 }
                        PauseAnimation  { duration: 1150 }   // settle until next cycle
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 18
                    text: "today"
                    color: App.Theme.textDim
                    font.pixelSize: 16
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            ColumnLayout {
                spacing: 2
                Label { text: "HOURLY"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: root.strikesHour + " ⚡"
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            ColumnLayout {
                spacing: 2
                Label { text: "LAST STRIKE"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: root.lastStrikeLabel()
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: App.Theme.border; Layout.topMargin: 4; Layout.bottomMargin: 4 }
            ColumnLayout {
                spacing: 2
                Label { text: "DISTANCE"; color: App.Theme.textFaint; font.pixelSize: 11; font.letterSpacing: 1.0; font.weight: Font.Bold }
                Label {
                    text: !isNaN(root.distance)
                        ? App.Units.fmt(App.Units.distMi(root.distance), 0) + " " + App.Units.distUnit()
                        : "—"
                    color: App.Theme.text
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
