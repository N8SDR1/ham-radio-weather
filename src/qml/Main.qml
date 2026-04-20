import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "." as App
import "tiles"

ApplicationWindow {
    id: root
    width: 1440
    height: 900
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: App.AppVersion.name + " v" + App.AppVersion.version
    color: App.Theme.bg

    property var latest:     ({})
    property var hfData:     ({})
    property var forecast:   ({})
    property var satellites: ({})

    // tile currently being dragged (set by a tile's dragStarted, cleared on dragEnded)
    property string draggingTileId: ""

    // layout state derived from AppSettings, with a tick property to force
    // recomputation when we write back to settings
    readonly property var _order: {
        var _dep = App.AppSettings.panelOrderJson
        var saved = App.AppSettings.getPanelOrder().filter(function(id) {
            return App.TileCatalog.get(id) !== null   // drop orphaned ids
        })
        var allIds = App.TileCatalog.defaultOrder()
        if (!saved.length) return allIds
        var merged = saved.slice()
        for (var i = 0; i < allIds.length; i++)
            if (merged.indexOf(allIds[i]) === -1) merged.push(allIds[i])
        return merged
    }
    readonly property var _hidden: {
        var _dep = App.AppSettings.panelHiddenJson
        return App.AppSettings.getPanelHidden()
    }
    readonly property var _sizes: {
        var _dep = App.AppSettings.panelSizesJson
        return App.AppSettings.getPanelSizes()
    }
    readonly property var activeTiles: {
        var st = App.AppSettings.stationType
        var onlineOnly = App.StationSource.isOnlineOnly(st)
        return _order.filter(function(id) {
            if (_hidden.indexOf(id) !== -1) return false
            var meta = App.TileCatalog.get(id)
            // Tiles flagged requiresLocalStation auto-hide in None mode (no
            // way to populate indoor temp/humidity from online sources).
            if (onlineOnly && meta && meta.requiresLocalStation) return false
            return true
        })
    }

    function _bump() { /* kept for backward compat, bindings now auto-refresh */ }

    function reorderTiles(sourceId, targetId, insertBefore) {
        // Use the merged order (_order) that already includes any tiles added
        // after the saved panelOrderJson was written.
        var order = _order.slice()
        var from = order.indexOf(sourceId)
        if (from === -1) return
        if (sourceId === targetId) return
        order.splice(from, 1)
        var to = order.indexOf(targetId)
        if (to === -1) { order.splice(from, 0, sourceId); return }
        var newIndex = insertBefore ? to : to + 1
        order.splice(newIndex, 0, sourceId)
        App.AppSettings.setPanelOrder(order)
        _bump()
    }

    function hideTile(id) { App.AppSettings.hidePanel(id); _bump() }
    function showTile(id) { App.AppSettings.showPanel(id); _bump() }
    function setTileSize(id, sz) {
        var clamped = App.TileCatalog.clampSize(id, sz)
        App.AppSettings.setPanelSize(id, clamped)
        _bump()
    }

    function sizeFor(id) {
        var s = _sizes[id]
        if (!s) {
            var meta = App.TileCatalog.get(id)
            s = meta ? meta.defaultSize : "M"
        }
        return App.TileCatalog.clampSize(id, s)
    }

    Connections {
        target: weatherClient
        function onDataUpdated(data) { root.latest = data || {} }
    }
    Connections {
        target: hamqslClient
        function onDataUpdated(data) { root.hfData = data || {} }
    }
    Connections {
        target: forecastClient
        function onDataUpdated(data) { root.forecast = data || {} }
    }
    Connections {
        target: satellitesClient
        function onDataUpdated(data) { root.satellites = data || {} }
    }
    // Push the "effective" location (override takes priority over grid square)
    // to every location-aware client in one place.
    function _pushLocation() {
        if (App.AppSettings.overrideLocationEnabled) {
            var lat = App.AppSettings.overrideLat
            var lon = App.AppSettings.overrideLon
            forecastClient.setLocation(lat, lon)
            satellitesClient.setLocation(lat, lon)
            if (typeof weatherClient.setLocation === "function")
                weatherClient.setLocation(lat, lon)
        } else if (App.AppSettings.gridSquare) {
            forecastClient.setGridSquare(App.AppSettings.gridSquare)
            satellitesClient.setGridSquare(App.AppSettings.gridSquare)
            if (typeof weatherClient.setGridSquare === "function")
                weatherClient.setGridSquare(App.AppSettings.gridSquare)
        }
    }

    Connections {
        target: App.AppSettings
        function onGridSquareChanged()             { root._pushLocation() }
        function onOverrideLocationEnabledChanged(){ root._pushLocation() }
        function onOverrideLatChanged()            { if (App.AppSettings.overrideLocationEnabled) root._pushLocation() }
        function onOverrideLonChanged()            { if (App.AppSettings.overrideLocationEnabled) root._pushLocation() }
        function onTrackedSatsJsonChanged() {
            var list = App.AppSettings.getTrackedSats()
            if (list.length === 0) list = App.SatelliteCatalog.defaultEnabledIds()
            satellitesClient.setTrackedList(list)
        }
    }

    Component.onCompleted: {
        App.Units.system  = App.AppSettings.unitSystem
        App.Theme.mode    = App.AppSettings.themeMode
        App.Theme.uiScale = App.AppSettings.uiScale || 1.0
        // First-run: auto-hide tiles flagged defaultHidden (sensor add-ons the user may not own).
        if (App.AppSettings.panelHiddenJson === "")
            App.AppSettings.setPanelHidden(App.TileCatalog.defaultHiddenIds())
        // Gate the app behind the disclaimer until the user has accepted it.
        if (!App.AppSettings.disclaimerAccepted) {
            disclaimerDialog.open()
        } else {
            // Increment launch counter once per run; show the one-time donate
            // nudge on the 7th launch.
            App.AppSettings.launchCount = App.AppSettings.launchCount + 1
            if (!App.AppSettings.donateNudgeShown && App.AppSettings.launchCount >= 7)
                Qt.callLater(function() { donateNudgeDialog.open() })
        }
        root._pushLocation()
        // Seed tracked satellites from defaults on first run
        if (App.AppSettings.trackedSatsJson === "")
            App.AppSettings.setTrackedSats(App.SatelliteCatalog.defaultEnabledIds())
        var sats = App.AppSettings.getTrackedSats()
        if (sats.length === 0) sats = App.SatelliteCatalog.defaultEnabledIds()
        satellitesClient.setTrackedList(sats)
    }
    Connections {
        target: App.Units
        function onSystemChanged() { App.AppSettings.unitSystem = App.Units.system }
    }
    Connections {
        target: App.Theme
        function onModeChanged()    { App.AppSettings.themeMode = App.Theme.mode }
        function onUiScaleChanged() { App.AppSettings.uiScale   = App.Theme.uiScale }
    }

    SettingsDialog    { id: settingsDialog }
    DisclaimerDialog  { id: disclaimerDialog }
    DonateNudgeDialog { id: donateNudgeDialog }

    Shortcut {
        sequence: "F11"
        onActivated: root.visibility = (root.visibility === Window.FullScreen
                                        ? Window.Windowed : Window.FullScreen)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: App.Theme.bgAccent }
            GradientStop { position: 1.0; color: App.Theme.bg }
        }
    }

    header: ToolBar {
        padding: 8
        background: Rectangle {
            color: App.Theme.bg
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: App.Theme.border
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 18
            spacing: 14

            RowLayout {
                spacing: 10

                // App logo — falls back to gradient square if image missing
                Item {
                    width: 40; height: 40
                    Rectangle {
                        id: logoFallback
                        anchors.fill: parent
                        radius: 8
                        visible: headerLogo.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: App.Theme.accent }
                            GradientStop { position: 1.0; color: App.Theme.accent2 }
                        }
                        Label {
                            anchors.centerIn: parent
                            text: "☁"
                            color: "white"
                            font.pixelSize: 20
                        }
                    }
                    Image {
                        id: headerLogo
                        anchors.fill: parent
                        source: appLogoUrl
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                    }
                }
                Label {
                    text: App.AppVersion.name
                    color: App.Theme.text
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Label {
                    text: "v" + App.AppVersion.version
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    text: App.AppSettings.callsign
                          ? "— " + App.AppSettings.callsign
                              + (App.AppSettings.gridSquare ? " · " + App.AppSettings.gridSquare : "")
                          : "— configure in Settings"
                    color: App.Theme.textDim
                    font.pixelSize: 13
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 10; height: 10; radius: 5
                color: weatherClient.connected ? App.Theme.good : App.Theme.bad
                Behavior on color { ColorAnimation { duration: 200 } }
                SequentialAnimation on opacity {
                    running: weatherClient.connected
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Label {
                text: weatherClient.connected ? "Live" : "Offline"
                color: App.Theme.textDim
                font.pixelSize: 12
            }

            Rectangle {
                width: 1; height: 18
                color: App.Theme.border
                opacity: 0.6
            }

            // Active source badge — shows which data source is live
            Rectangle {
                id: sourceBadge
                readonly property var info: App.StationSource.info(App.AppSettings.stationType)
                Layout.preferredWidth: Math.max(72, sourceRow.implicitWidth + 16)
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: 6
                color: "transparent"
                border.color: info.color
                border.width: 1

                Row {
                    id: sourceRow
                    anchors.centerIn: parent
                    spacing: 5
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sourceBadge.info.icon
                        font.pixelSize: 14
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sourceBadge.info.label
                        color: sourceBadge.info.color
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsDialog.open()
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: "Active data source: " + sourceBadge.info.label
                                + "  —  click to open Weather Station settings"
                }
            }

            // Alert badge — mirrors battery indicator style
            Rectangle {
                id: alertBadge
                readonly property var _active: {
                    var _d = App.AppSettings.alertsJson
                    return App.AlertRules.evaluate(root.latest, App.AppSettings.getAlertSettings())
                }
                readonly property bool _hasWarning: {
                    for (var i = 0; i < _active.length; i++)
                        if (_active[i].severity === "warning") return true
                    return false
                }
                readonly property int _count: _active.length

                Layout.preferredWidth: Math.max(68, alertRow.implicitWidth + 16)
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: 6
                color: alertMouse.containsMouse
                       ? Qt.rgba(App.Theme.accent.r, App.Theme.accent.g, App.Theme.accent.b, 0.15)
                       : "transparent"
                border.color: _count === 0    ? App.Theme.border
                            : _hasWarning     ? App.Theme.bad
                                              : App.Theme.warn
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                SequentialAnimation on opacity {
                    running: alertBadge._hasWarning
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 700; easing.type: Easing.InOutSine }
                }

                Row {
                    id: alertRow
                    anchors.centerIn: parent
                    spacing: 5

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: alertBadge._count === 0 ? "✅"
                            : alertBadge._hasWarning  ? "⚠"
                                                      : "🔔"
                        color: alertBadge._count === 0 ? App.Theme.good
                             : alertBadge._hasWarning  ? App.Theme.bad
                                                       : App.Theme.warn
                        font.pixelSize: 15
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: alertBadge._count === 0 ? "CLEAR"
                                                      : alertBadge._count + " ACTIVE"
                        color: alertBadge._count === 0 ? App.Theme.textDim
                             : alertBadge._hasWarning  ? App.Theme.bad
                                                       : App.Theme.warn
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }
                }

                MouseArea {
                    id: alertMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsDialog.open()
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: {
                        if (alertBadge._count === 0) return "No alerts — click to configure thresholds"
                        var list = alertBadge._active.map(function(a) { return a.icon + " " + a.label }).join("\n")
                        return list + "\n\nClick to configure in Settings"
                    }
                }
            }

            // Inline battery indicator — eliminates component-loading as a cause
            Rectangle {
                id: batteryIndicator
                // Hidden when user is in "None" (online-only) mode — no
                // physical sensors means no batteries to monitor.
                visible: !App.StationSource.isOnlineOnly(App.AppSettings.stationType)
                readonly property var _state: App.Batteries.detect(root.latest)
                Layout.preferredWidth: visible ? Math.max(70, batRow.implicitWidth + 16) : 0
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: 6
                color: batMouse.containsMouse
                       ? Qt.rgba(App.Theme.accent.r, App.Theme.accent.g, App.Theme.accent.b, 0.15)
                       : "transparent"
                border.color: !_state.hasAny ? App.Theme.border
                            : _state.allOk   ? Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.4)
                                             : App.Theme.bad
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 5

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !batteryIndicator._state.hasAny ? "🔋"
                            : batteryIndicator._state.allOk   ? "🔋"
                                                              : "🪫"
                        color: !batteryIndicator._state.hasAny ? App.Theme.textFaint
                             : batteryIndicator._state.allOk   ? App.Theme.good
                                                               : App.Theme.bad
                        font.pixelSize: 16

                        SequentialAnimation on opacity {
                            running: batteryIndicator._state.hasAny && !batteryIndicator._state.allOk
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.30; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !batteryIndicator._state.hasAny ? "—"
                            : batteryIndicator._state.allOk   ? "OK"
                                                              : batteryIndicator._state.lowList.length + " LOW"
                        color: !batteryIndicator._state.hasAny ? App.Theme.textFaint
                             : batteryIndicator._state.allOk   ? App.Theme.textDim
                                                               : App.Theme.bad
                        font.pixelSize: 11
                        font.weight: (batteryIndicator._state.hasAny && !batteryIndicator._state.allOk) ? Font.Bold : Font.Medium
                        font.letterSpacing: 0.5
                    }
                }

                MouseArea {
                    id: batMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsDialog.open()
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: {
                        var s = batteryIndicator._state
                        if (!s.hasAny) return "No battery data in this station's feed — click to open Settings"
                        if (s.allOk)   return "All batteries OK — click for details"
                        var names = s.lowList.map(function(k) { return App.Batteries.prettyName(k) })
                        return "Low: " + names.join(", ") + " — click for details"
                    }
                }
            }

            ToolButton {
                text: App.Units.metric ? "°C" : "°F"
                onClicked: App.Units.system = App.Units.metric ? "imperial" : "metric"
                ToolTip.text: "Toggle units"
                ToolTip.visible: hovered
            }
            ToolButton {
                text: App.Theme.mode === "auto" ? "Auto"
                    : App.Theme.mode === "dark" ? "Dark" : "Light"
                onClicked: {
                    App.Theme.mode = App.Theme.mode === "auto" ? "dark"
                                   : App.Theme.mode === "dark" ? "light" : "auto"
                }
                ToolTip.text: "Theme: auto / dark / light"
                ToolTip.visible: hovered
            }
            // Subtle "buy me a coffee" button — always visible, never obstructive.
            ToolButton {
                id: donateBtn
                text: "☕"
                font.pixelSize: 17
                onClicked: Qt.openUrlExternally(App.DonateUrl.url)
                ToolTip.text: "Support this project — 73 de N8SDR"
                ToolTip.visible: hovered
                ToolTip.delay: 300
                contentItem: Label {
                    text: donateBtn.text
                    color: App.Theme.warn   // warm amber, not red/pink
                    font.pixelSize: donateBtn.font.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    opacity: donateBtn.hovered ? 1.0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            ToolButton {
                text: "⚙"
                font.pixelSize: 16
                onClicked: settingsDialog.open()
                ToolTip.text: "Settings — callsign, grid, panels, keys"
                ToolTip.visible: hovered
            }
        }
    }

    ScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth:  availableWidth
        contentHeight: grid.implicitHeight * App.Theme.uiScale + 2*(App.Theme.gap + 4)
        clip: true

        Item {
            id: scrollContent
            anchors.fill: parent

            // Catches drops that land outside any tile (e.g. the empty space in a
            // partially-filled row). Finds the nearest tile by distance and
            // inserts the dragged tile adjacent to it.
            DropArea {
                id: gridDropArea
                anchors.fill: parent
                keys: ["wx-tile"]
                onDropped: function(drop) {
                    if (!root.draggingTileId) return
                    var nearestId = ""
                    var nearestDist = Number.POSITIVE_INFINITY
                    var beforeTarget = true
                    var s = App.Theme.uiScale
                    for (var i = 0; i < tileRepeater.count; i++) {
                        var d = tileRepeater.itemAt(i)
                        if (!d) continue
                        var cx = grid.x + (d.x + d.width  / 2) * s
                        var cy = grid.y + (d.y + d.height / 2) * s
                        var dx = drop.x - cx
                        var dy = drop.y - cy
                        var dist = Math.sqrt(dx * dx + dy * dy)
                        if (dist < nearestDist) {
                            nearestDist = dist
                            nearestId = d.tileId
                            beforeTarget = dx < 0
                        }
                    }
                    if (nearestId && nearestId !== root.draggingTileId)
                        root.reorderTiles(root.draggingTileId, nearestId, beforeTarget)
                }
            }

            GridLayout {
                id: grid
                x: App.Theme.gap + 4
                y: App.Theme.gap + 4
                width: (scroller.availableWidth - 2*(App.Theme.gap + 4)) / App.Theme.uiScale
                transformOrigin: Item.TopLeft
                scale: App.Theme.uiScale
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                columns: Math.max(1, Math.floor((width - 2*App.Theme.gap) / 360))
                columnSpacing: App.Theme.gap
                rowSpacing: App.Theme.gap

                Repeater {
                    id: tileRepeater
                    model: root.activeTiles
                    delegate: TileLoader {
                        tileId: modelData
                        tileSize: root.sizeFor(modelData)
                        weatherData:   root.latest
                        hfData:        root.hfData
                        forecastData:  root.forecast
                        satelliteData: root.satellites
                        gridColumnCount: grid.columns

                        onHideRequested: function(id)      { root.hideTile(id) }
                        onSizeRequested: function(id, sz)  { root.setTileSize(id, sz) }
                        onDragStarted:   function(id)      { root.draggingTileId = id }
                        onDragEnded:     function(id)      { root.draggingTileId = "" }
                        onDroppedHere:   function(tgt, before) {
                            if (root.draggingTileId && root.draggingTileId !== tgt)
                                root.reorderTiles(root.draggingTileId, tgt, before)
                        }
                    }
                }
            }
        }
    }

    // empty-state prompt when user has hidden everything
    Label {
        anchors.centerIn: parent
        visible: root.activeTiles.length === 0
        text: "All panels hidden — open Settings (⚙) to re-enable"
        color: App.Theme.textDim
        font.pixelSize: 14
    }
}
