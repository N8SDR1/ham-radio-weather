import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as App

Dialog {
    id: dialog
    title: "Settings"
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 560
    height: Math.min(parent ? parent.height * 0.9 : 720, 720)
    anchors.centerIn: parent

    HelpDialog  { id: helpDialog }
    AboutDialog { id: aboutDialog }

    property string callsign:      App.AppSettings.callsign
    property string gridSquare:    App.AppSettings.gridSquare
    property string ambientAppKey: App.AppSettings.ambientAppKey
    property string ambientApiKey: App.AppSettings.ambientApiKey

    background: Rectangle {
        color: App.Theme.surface
        border.color: App.Theme.border
        radius: 12
    }

    header: Rectangle {
        color: "transparent"
        height: 48
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            spacing: 8
            Label {
                text: "Settings"
                color: App.Theme.text
                font.pixelSize: 18
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            ToolButton {
                text: "? Help"
                font.pixelSize: 12
                onClicked: helpDialog.open()
                ToolTip.text: "Open the user guide"
                ToolTip.visible: hovered
            }
            ToolButton {
                text: "About"
                font.pixelSize: 12
                onClicked: aboutDialog.open()
                ToolTip.text: "Version info and credits"
                ToolTip.visible: hovered
            }
        }
    }

    contentItem: ScrollView {
        clip: true
        ColumnLayout {
            width: dialog.availableWidth
            spacing: 18

            // Operator
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "OPERATOR"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Callsign"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                        App.ThemedTextField {
                            Layout.fillWidth: true
                            text: dialog.callsign
                            placeholderText: "N8SDR"
                            onTextChanged: dialog.callsign = text
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Grid Square"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                        App.ThemedTextField {
                            Layout.fillWidth: true
                            text: dialog.gridSquare
                            placeholderText: "EN80 or EN80pb"
                            onTextChanged: dialog.gridSquare = text
                            ToolTip.text: "Maidenhead locator — default source of location for forecast, satellites, and online-only mode"
                            ToolTip.visible: hovered
                        }
                    }

                    // Optional lat/lon override
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        height: 1
                        color: App.Theme.border
                        opacity: 0.4
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        CheckBox {
                            id: overrideToggle
                            checked: App.AppSettings.overrideLocationEnabled
                            text: ""
                            onToggled: App.AppSettings.overrideLocationEnabled = checked
                        }
                        Label {
                            text: "Override with explicit latitude / longitude"
                            color: App.Theme.text
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overrideToggle.checked = !overrideToggle.checked
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Use this when grid square is too coarse (6-char grid is ~5 km). Applies to forecast, satellites, and online-only mode."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        visible: overrideToggle.checked
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: overrideToggle.checked
                        Label { text: "Latitude";  color: App.Theme.textDim; Layout.preferredWidth: 110 }
                        App.ThemedTextField {
                            Layout.fillWidth: true
                            text: App.AppSettings.overrideLat.toFixed(4)
                            placeholderText: "40.2845  (+ = N, − = S)"
                            onEditingFinished: {
                                var v = parseFloat(text)
                                if (!isNaN(v) && v >= -90 && v <= 90)
                                    App.AppSettings.overrideLat = v
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: overrideToggle.checked
                        Label { text: "Longitude"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                        App.ThemedTextField {
                            Layout.fillWidth: true
                            text: App.AppSettings.overrideLon.toFixed(4)
                            placeholderText: "-84.5614  (+ = E, − = W)"
                            onEditingFinished: {
                                var v = parseFloat(text)
                                if (!isNaN(v) && v >= -180 && v <= 180)
                                    App.AppSettings.overrideLon = v
                            }
                        }
                    }
                }
            }

            // Alerts
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "ALERTS"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    Label {
                        text: "Trigger an alert on the Alerts tile when the threshold is met."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: App.AlertRules.catalog
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            readonly property var _saved: {
                                var _d = App.AppSettings.alertsJson
                                return App.AppSettings.getAlertSettings()[modelData.id] || {}
                            }
                            readonly property bool _enabled: _saved.enabled !== undefined
                                                             ? _saved.enabled : modelData.defaultEnabled
                            readonly property real _threshold: _saved.threshold !== undefined
                                                               ? Number(_saved.threshold) : modelData.defaultThreshold

                            CheckBox {
                                checked: parent._enabled
                                onToggled: App.AppSettings.setAlertRule(
                                    modelData.id, checked, parent._threshold)
                                Layout.preferredWidth: 30
                            }
                            Label {
                                text: modelData.icon + "  " + modelData.label
                                color: App.Theme.text
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.comparator
                                color: App.Theme.textDim
                                font.pixelSize: 11
                                font.family: "Consolas"
                            }
                            App.ThemedTextField {
                                Layout.preferredWidth: 70
                                text: parent._threshold.toString()
                                onEditingFinished: {
                                    var v = parseFloat(text)
                                    if (!isNaN(v))
                                        App.AppSettings.setAlertRule(
                                            modelData.id, parent._enabled, v)
                                }
                            }
                            Label {
                                text: modelData.unit
                                color: App.Theme.textFaint
                                font.pixelSize: 11
                                Layout.preferredWidth: 45
                            }
                        }
                    }

                    Button {
                        text: "Reset Alert Defaults"
                        Layout.alignment: Qt.AlignRight
                        onClicked: App.AppSettings.resetAlerts()
                    }
                }
            }

            // Satellites — pick which amateur birds to track
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "SATELLITES"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    Label {
                        text: "Choose which amateur-radio satellites the Satellites tile predicts passes for. Unchecked birds are ignored."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                    }

                    Repeater {
                        model: App.SatelliteCatalog.catalog
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            readonly property bool _checked: {
                                var _d = App.AppSettings.trackedSatsJson
                                return App.AppSettings.isSatTracked(modelData.id)
                            }

                            CheckBox {
                                checked: parent._checked
                                onToggled: App.AppSettings.toggleSat(modelData.id, checked)
                                Layout.preferredWidth: 30
                            }
                            Label {
                                text: "🛰  " + modelData.label
                                color: App.Theme.text
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.id
                                color: App.Theme.textFaint
                                font.pixelSize: 10
                                font.family: "Consolas"
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Reset Defaults"
                            onClicked: App.AppSettings.setTrackedSats(
                                App.SatelliteCatalog.defaultEnabledIds())
                        }
                    }
                }
            }

            // UI Size
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "UI SIZE"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    Label {
                        text: "Scale the dashboard's fonts, spacing, and icons. Affects every tile."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "Small",    value: 0.85 },
                                { label: "Normal",   value: 1.00 },
                                { label: "Medium",   value: 1.15 },
                                { label: "Large",    value: 1.30 }
                            ]
                            delegate: Button {
                                Layout.fillWidth: true
                                text: modelData.label + "  " + Math.round(modelData.value * 100) + "%"
                                checkable: true
                                checked: Math.abs(App.Theme.uiScale - modelData.value) < 0.01
                                onClicked: App.Theme.uiScale = modelData.value
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        height: 1
                        color: App.Theme.border
                        opacity: 0.4
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        CheckBox {
                            id: canonicalToggle
                            checked: App.AppSettings.showCanonicalNames
                            text: ""
                            onToggled: App.AppSettings.showCanonicalNames = checked
                        }
                        Label {
                            text: "Show panel names in tile headers"
                            color: App.Theme.text
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: canonicalToggle.checked = !canonicalToggle.checked
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "When on, each tile shows its canonical name (Outdoor, Wind, Lightning, etc.) centered in the header next to the dynamic mood title. Elides with \u2026 on narrow tiles."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Battery Status
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "BATTERY STATUS"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    id: battCol
                    anchors.fill: parent
                    spacing: 4

                    property var battState: App.Batteries.detect(weatherClient.latest)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label {
                            text: battCol.battState.allOk ? "🔋" : "🪫"
                            font.pixelSize: 18
                        }
                        Label {
                            text: !battCol.battState.hasAny ? "No battery sensors reported"
                                : battCol.battState.allOk  ? "All batteries OK"
                                                           : battCol.battState.lowList.length + " sensor(s) low"
                            color: battCol.battState.allOk ? App.Theme.text : App.Theme.bad
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: battCol.battState.hasAny
                        Layout.fillWidth: true
                        height: 1
                        color: App.Theme.border
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                    }

                    Repeater {
                        model: battCol.battState.items
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Label {
                                text: modelData.ok ? "✓" : "⚠"
                                color: modelData.ok ? App.Theme.good : App.Theme.bad
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                Layout.preferredWidth: 20
                            }
                            Label {
                                text: App.Batteries.prettyName(modelData.key)
                                color: App.Theme.text
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.key
                                color: App.Theme.textFaint
                                font.pixelSize: 10
                                font.family: "Consolas"
                            }
                            Label {
                                text: modelData.ok ? "OK" : "LOW"
                                color: modelData.ok ? App.Theme.good : App.Theme.bad
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            // Panels
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "PANELS"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    Label {
                        text: "Toggle panels on/off. Drag tiles by the ⋮⋮ handle in their header to reorder. Right-click a tile's ⋯ menu to resize."
                        color: App.Theme.textFaint
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: App.TileCatalog.tiles
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            CheckBox {
                                checked: {
                                    var _d = App.AppSettings.panelHiddenJson
                                    return App.AppSettings.getPanelHidden().indexOf(modelData.id) === -1
                                }
                                onToggled: App.AppSettings.togglePanel(modelData.id, checked)
                                Layout.preferredWidth: 30
                            }
                            Label {
                                text: modelData.name
                                color: App.Theme.text
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                Layout.preferredWidth: 120
                                model: App.TileCatalog.allowedSizes(modelData.id)
                                currentIndex: {
                                    var _d = App.AppSettings.panelSizesJson
                                    var sizes = App.AppSettings.getPanelSizes()
                                    var cur = App.TileCatalog.clampSize(modelData.id,
                                                sizes[modelData.id] || modelData.defaultSize)
                                    return model.indexOf(cur)
                                }
                                onActivated: App.AppSettings.setPanelSize(modelData.id,
                                                App.TileCatalog.clampSize(modelData.id, currentText))
                            }
                        }
                    }

                    Button {
                        text: "Reset Layout to Defaults"
                        Layout.alignment: Qt.AlignRight
                        onClicked: App.AppSettings.resetLayout()
                    }
                }
            }

            // Ambient keys
            // Weather Station — brand picker + per-brand credential fields
            GroupBox {
                Layout.fillWidth: true
                label: Label {
                    text: "WEATHER STATION"
                    color: App.Theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                }
                background: Rectangle { color: "transparent"; border.color: App.Theme.border; radius: 8 }

                ColumnLayout {
                    id: stationCol
                    anchors.fill: parent
                    spacing: 10

                    // Catalog of supported brands. `wired` = fully implemented today.
                    readonly property var brands: [
                        { id: "none",    label: "None  —  no local station (use online sources)",
                          wired: true,  notes: "Pulls current weather from Open-Meteo using your grid square. Lightning / NWS alerts come in a later update." },
                        { id: "ambient", label: "Ambient Weather  (WS-2000, WS-2902, WS-5000, WS-1965)",
                          wired: true,  notes: "REST + Socket.IO realtime." },
                        { id: "ecowitt", label: "Ecowitt  (Wittboy, GW1100, HP2551, HP2564)",
                          wired: true,  notes: "REST Cloud API. Requires API key + App key + station MAC. Local LAN polling coming next." },
                        { id: "tempest", label: "WeatherFlow Tempest",
                          wired: false, notes: "REST + WebSocket + UDP local (3-sec updates). Coming v1.0.9." },
                        { id: "davis",   label: "Davis Instruments  (Vantage Pro2 / Vue + WeatherLink Live)",
                          wired: false, notes: "WeatherLink v2 REST (HMAC-signed) + local HTTP. Coming v1.1.0." },
                        { id: "netatmo", label: "Netatmo Smart Weather Station",
                          wired: false, notes: "REST + OAuth 2.0. Coming v1.1.1." }
                    ]

                    readonly property string currentBrand: {
                        var _d = App.AppSettings.stationType
                        return _d || "ambient"
                    }
                    readonly property var currentMeta: {
                        for (var i = 0; i < brands.length; i++)
                            if (brands[i].id === currentBrand) return brands[i]
                        return brands[0]
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label { text: "Station"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                        ComboBox {
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "id"
                            model: stationCol.brands
                            currentIndex: {
                                for (var i = 0; i < stationCol.brands.length; i++)
                                    if (stationCol.brands[i].id === stationCol.currentBrand) return i
                                return 0
                            }
                            onActivated: App.AppSettings.stationType = stationCol.brands[currentIndex].id
                        }
                    }

                    // Status banner per brand
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 6
                        color: stationCol.currentMeta.wired
                               ? Qt.rgba(App.Theme.good.r, App.Theme.good.g, App.Theme.good.b, 0.15)
                               : Qt.rgba(App.Theme.warn.r, App.Theme.warn.g, App.Theme.warn.b, 0.15)
                        border.color: stationCol.currentMeta.wired ? App.Theme.good : App.Theme.warn
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            Label {
                                text: stationCol.currentMeta.wired ? "✓" : "⏳"
                                color: stationCol.currentMeta.wired ? App.Theme.good : App.Theme.warn
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: stationCol.currentMeta.notes
                                color: App.Theme.text
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // === AMBIENT fields ===
                    ColumnLayout {
                        visible: stationCol.currentBrand === "ambient"
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "App Key"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: dialog.ambientAppKey
                                placeholderText: "Developer / application key"
                                echoMode: TextInput.Password
                                onTextChanged: dialog.ambientAppKey = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "API Key"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: dialog.ambientApiKey
                                placeholderText: "User API key"
                                echoMode: TextInput.Password
                                onTextChanged: dialog.ambientApiKey = text
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Leave blank to use the keys from .env. Requires restart."
                            color: App.Theme.textFaint
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    // === ECOWITT fields ===
                    ColumnLayout {
                        visible: stationCol.currentBrand === "ecowitt"
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "API Key"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.ecowittApiKey
                                placeholderText: "From ecowitt.net account"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.ecowittApiKey = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "App Key"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.ecowittAppKey
                                placeholderText: "Application key"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.ecowittAppKey = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Station MAC"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.ecowittMac
                                placeholderText: "AA:BB:CC:DD:EE:FF"
                                onTextChanged: App.AppSettings.ecowittMac = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "LAN IP (opt.)"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.ecowittLocalIp
                                placeholderText: "192.168.1.x — for local polling"
                                onTextChanged: App.AppSettings.ecowittLocalIp = text
                            }
                        }
                    }

                    // === TEMPEST fields ===
                    ColumnLayout {
                        visible: stationCol.currentBrand === "tempest"
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Token"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.tempestToken
                                placeholderText: "Personal access token"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.tempestToken = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Station ID"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.tempestStationId
                                placeholderText: "Numeric station id"
                                onTextChanged: App.AppSettings.tempestStationId = text
                            }
                        }
                    }

                    // === DAVIS fields ===
                    ColumnLayout {
                        visible: stationCol.currentBrand === "davis"
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "API Key"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.davisApiKey
                                placeholderText: "WeatherLink v2 key"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.davisApiKey = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "API Secret"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.davisApiSecret
                                placeholderText: "WeatherLink v2 secret"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.davisApiSecret = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Station ID"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.davisStationId
                                placeholderText: "Numeric station id"
                                onTextChanged: App.AppSettings.davisStationId = text
                            }
                        }
                    }

                    // === NETATMO fields ===
                    ColumnLayout {
                        visible: stationCol.currentBrand === "netatmo"
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Client ID"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.netatmoClientId
                                placeholderText: "From dev.netatmo.com"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.netatmoClientId = text
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Client Secret"; color: App.Theme.textDim; Layout.preferredWidth: 110 }
                            App.ThemedTextField {
                                Layout.fillWidth: true
                                text: App.AppSettings.netatmoClientSecret
                                placeholderText: "From dev.netatmo.com"
                                echoMode: TextInput.Password
                                onTextChanged: App.AppSettings.netatmoClientSecret = text
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Note: OAuth 2.0 — access/refresh tokens will be negotiated on first auth."
                            color: App.Theme.textFaint
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Reset row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Clear Credentials for " + stationCol.currentMeta.label.split("  ")[0]
                            onClicked: {
                                var b = stationCol.currentBrand
                                if (b === "ambient") {
                                    App.AppSettings.ambientAppKey = ""
                                    App.AppSettings.ambientApiKey = ""
                                    dialog.ambientAppKey = ""
                                    dialog.ambientApiKey = ""
                                } else if (b === "ecowitt") {
                                    App.AppSettings.ecowittApiKey = ""
                                    App.AppSettings.ecowittAppKey = ""
                                    App.AppSettings.ecowittMac    = ""
                                    App.AppSettings.ecowittLocalIp= ""
                                } else if (b === "tempest") {
                                    App.AppSettings.tempestToken     = ""
                                    App.AppSettings.tempestStationId = ""
                                } else if (b === "davis") {
                                    App.AppSettings.davisApiKey    = ""
                                    App.AppSettings.davisApiSecret = ""
                                    App.AppSettings.davisStationId = ""
                                } else if (b === "netatmo") {
                                    App.AppSettings.netatmoClientId     = ""
                                    App.AppSettings.netatmoClientSecret = ""
                                    App.AppSettings.netatmoAccessToken  = ""
                                    App.AppSettings.netatmoRefreshToken = ""
                                }
                            }
                        }
                    }

                    // --- Debug / diagnostics ---
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        height: 1
                        color: App.Theme.border
                        opacity: 0.5
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        CheckBox {
                            id: debugToggle
                            checked: false
                            text: ""   // we provide the label separately below
                        }
                        Label {
                            text: "Show debug / diagnostic info"
                            color: App.Theme.text
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: debugToggle.checked = !debugToggle.checked
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            visible: debugToggle.checked
                            text: weatherClient.connected ? "● connected" : "● offline"
                            color: weatherClient.connected ? App.Theme.good : App.Theme.bad
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        visible: debugToggle.checked
                        Layout.fillWidth: true
                        spacing: 6

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 3
                            Label { text: "Last poll"; color: App.Theme.textDim; font.pixelSize: 11 }
                            Label {
                                text: weatherClient.lastPollIso || "—"
                                color: App.Theme.text
                                font.pixelSize: 11
                                font.family: "Consolas"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Label { text: "HTTP status"; color: App.Theme.textDim; font.pixelSize: 11 }
                            Label {
                                text: weatherClient.httpStatus ? weatherClient.httpStatus.toString() : "—"
                                color: weatherClient.httpStatus === 200 ? App.Theme.good
                                     : weatherClient.httpStatus >= 400   ? App.Theme.bad
                                                                         : App.Theme.text
                                font.pixelSize: 11
                                font.family: "Consolas"
                            }
                            Label { text: "Last error"; color: App.Theme.textDim; font.pixelSize: 11 }
                            Label {
                                text: weatherClient.lastError || "(none)"
                                color: weatherClient.lastError ? App.Theme.bad : App.Theme.textFaint
                                font.pixelSize: 11
                                font.family: "Consolas"
                                Layout.fillWidth: true
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        Label {
                            text: "RAW API RESPONSE"
                            color: App.Theme.textFaint
                            font.pixelSize: 10
                            font.letterSpacing: 1.0
                            font.weight: Font.Bold
                            Layout.topMargin: 4
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: App.Theme.dark ? "#0b0f18" : "#f0f3f7"
                            border.color: App.Theme.border
                            radius: 6
                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                TextArea {
                                    id: rawArea
                                    readOnly: true
                                    wrapMode: TextArea.Wrap
                                    text: weatherClient.rawResponse || "(no response received yet)"
                                    color: App.Theme.text
                                    font.pixelSize: 10
                                    font.family: "Consolas"
                                    background: Rectangle { color: "transparent" }
                                }
                            }
                        }

                        Label {
                            text: "FLATTENED (what the tiles see)"
                            color: App.Theme.textFaint
                            font.pixelSize: 10
                            font.letterSpacing: 1.0
                            font.weight: Font.Bold
                            Layout.topMargin: 4
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: App.Theme.dark ? "#0b0f18" : "#f0f3f7"
                            border.color: App.Theme.border
                            radius: 6
                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                TextArea {
                                    id: flatArea
                                    readOnly: true
                                    wrapMode: TextArea.Wrap
                                    text: weatherClient.flattenedJson || "(empty)"
                                    color: App.Theme.text
                                    font.pixelSize: 10
                                    font.family: "Consolas"
                                    background: Rectangle { color: "transparent" }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Label {
                                text: "Paste one of these into an email/issue if you hit problems."
                                color: App.Theme.textFaint
                                font.pixelSize: 10
                                Layout.fillWidth: true
                            }
                            Button {
                                text: "Copy Raw"
                                onClicked: clipboard.setText(weatherClient.rawResponse || "")
                            }
                            Button {
                                text: "Copy Flattened"
                                onClicked: clipboard.setText(weatherClient.flattenedJson || "")
                            }
                            Button {
                                text: "Copy All"
                                onClicked: clipboard.setText(
                                    "=== " + stationCol.currentMeta.label + " ===\n" +
                                    "Last poll: " + (weatherClient.lastPollIso || "—") + "\n" +
                                    "HTTP:      " + (weatherClient.httpStatus || "—") + "\n" +
                                    "Error:     " + (weatherClient.lastError || "(none)") + "\n" +
                                    "Connected: " + weatherClient.connected + "\n\n" +
                                    "--- raw response ---\n" + (weatherClient.rawResponse || "") + "\n\n" +
                                    "--- flattened ---\n" + (weatherClient.flattenedJson || "")
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    onAccepted: {
        App.AppSettings.callsign      = callsign
        App.AppSettings.gridSquare    = gridSquare
        App.AppSettings.ambientAppKey = ambientAppKey
        App.AppSettings.ambientApiKey = ambientApiKey
    }
    onRejected: {
        callsign      = App.AppSettings.callsign
        gridSquare    = App.AppSettings.gridSquare
        ambientAppKey = App.AppSettings.ambientAppKey
        ambientApiKey = App.AppSettings.ambientApiKey
    }
}
