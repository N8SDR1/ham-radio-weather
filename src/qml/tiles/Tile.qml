import QtQuick
import QtQuick.Controls
import "../" as App

Item {
    id: tile
    property string title: ""
    property string iconEmoji: ""
    property color accentColor: App.Theme.accent
    default property alias content: body.data

    property string tileId: ""
    property string tileSize: "M"
    property string minSize: "S"

    readonly property bool _canS:  App.TileCatalog.sizeOrder(minSize) <= 0
    readonly property bool _canM:  App.TileCatalog.sizeOrder(minSize) <= 1
    readonly property bool _canL:  App.TileCatalog.sizeOrder(minSize) <= 2
    readonly property bool _canXL: App.TileCatalog.sizeOrder(minSize) <= 3

    signal hideRequested()
    signal sizeRequested(string newSize)
    signal dragStarted()
    signal dragEnded()
    signal droppedHere(bool insertBefore)   // passes left/right half of target

    implicitHeight: 200
    implicitWidth: 320

    Rectangle {
        visible: App.Theme.dark
        anchors.fill: card
        anchors.margins: -2
        radius: App.Theme.tileRadius + 2
        color: "transparent"
        border.color: Qt.rgba(tile.accentColor.r, tile.accentColor.g,
                              tile.accentColor.b, 0.08)
        border.width: 1
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: App.Theme.tileRadius
        border.color: dropArea.containsDrag ? tile.accentColor : App.Theme.border
        border.width: dropArea.containsDrag ? 2 : 1
        Behavior on border.color { ColorAnimation { duration: 150 } }
        opacity: dragGhost.visible ? 0.55 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: App.Theme.surfaceTop }
            GradientStop { position: 1.0; color: App.Theme.surfaceBot }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            radius: App.Theme.tileRadius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.0) }
                GradientStop { position: 0.5; color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.9) }
                GradientStop { position: 1.0; color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.0) }
            }
            opacity: App.Theme.dark ? 1.0 : 0.6
        }

        // header
        Item {
            id: header
            x: App.Theme.tilePad
            y: App.Theme.tilePad - 2
            width: parent.width - 2 * App.Theme.tilePad
            height: 38

            // Canonical panel name — centered between left (icon + mood) and
            // right (drag handle + menu). Thin / medium-bright so it reads as
            // subtle metadata, not as the primary title.
            Label {
                id: canonicalName
                visible: App.AppSettings.showCanonicalNames && text.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Leave room so we never collide with the left/right rows:
                // ~130 px absorbed by icon (36) + mood title + spacing on the
                // left, ~80 px by drag + menu on the right. Width is capped.
                width: Math.max(0, parent.width - 240)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: {
                    var meta = App.TileCatalog.get(tile.tileId)
                    return meta ? meta.name : ""
                }
                color: App.Theme.dark ? "#d0d5df" : "#5a6272"
                font.pixelSize: 12
                font.weight: Font.Thin
                font.letterSpacing: 0.4
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    id: iconBadge
                    width: 36; height: 36; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(tile.accentColor.r, tile.accentColor.g,
                                   tile.accentColor.b, App.Theme.dark ? 0.20 : 0.24)
                    border.color: Qt.rgba(tile.accentColor.r, tile.accentColor.g,
                                          tile.accentColor.b, 0.4)
                    border.width: 1
                    Label {
                        anchors.centerIn: parent
                        text: tile.iconEmoji
                        font.pixelSize: 22
                    }
                    // Hover tooltip shows the tile's canonical name (since the
                    // title above it shows the dynamic mood which can obscure
                    // what the panel actually is).
                    MouseArea {
                        id: iconHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: {
                            var meta = App.TileCatalog.get(tile.tileId)
                            return meta ? meta.name : tile.title
                        }
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.title.toUpperCase()
                    color: App.Theme.textDim
                    font.pixelSize: 13
                    font.letterSpacing: 1.6
                    font.weight: Font.Bold
                    font.family: App.Theme.fontFamily
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // drag handle — STATIC. Ghost below does the actual moving.
                Rectangle {
                    id: dragHandle
                    width: 32; height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: dragArea.containsMouse || dragArea.drag.active
                           ? Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.2)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Label {
                        anchors.centerIn: parent
                        text: "⋮⋮"
                        color: dragArea.containsMouse || dragArea.drag.active
                               ? tile.accentColor : App.Theme.textFaint
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        rotation: 90
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: dragGhost
                        drag.threshold: 3

                        // Only show tooltip on idle hover, not while dragging
                        ToolTip.visible: containsMouse && !drag.active
                        ToolTip.delay: 500
                        ToolTip.text: "Drag to reorder  —  drop on the left half "
                                    + "of another tile to insert BEFORE, right half to insert AFTER. "
                                    + "Drop in an empty grid slot to snap next to the nearest tile."

                        onPressed: function(mouse) {
                            var p = dragHandle.mapToItem(tile, mouse.x, mouse.y)
                            dragGhost.x = p.x - dragGhost.width / 2
                            dragGhost.y = p.y - dragGhost.height / 2
                            dragGhost.visible = true
                            dragGhost.Drag.active = true
                            tile.dragStarted()
                        }
                        onReleased: {
                            if (dragGhost.Drag.active) {
                                dragGhost.Drag.drop()
                                dragGhost.Drag.active = false
                            }
                            dragGhost.visible = false
                            dragGhost.x = 0
                            dragGhost.y = 0
                            tile.dragEnded()
                        }
                    }
                }

                ToolButton {
                    width: 32; height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⋯"
                    font.pixelSize: 18
                    flat: true
                    onClicked: tileMenu.open()

                    Menu {
                        id: tileMenu
                        y: parent.height
                        MenuItem { text: "Hide Panel"; onTriggered: tile.hideRequested() }
                        MenuSeparator {}
                        MenuItem {
                            text: "Small";       checkable: true
                            checked: tile.tileSize === "S"
                            height: visible ? implicitHeight : 0
                            visible: tile._canS
                            onTriggered: tile.sizeRequested("S")
                        }
                        MenuItem {
                            text: "Medium";      checkable: true
                            checked: tile.tileSize === "M"
                            height: visible ? implicitHeight : 0
                            visible: tile._canM
                            onTriggered: tile.sizeRequested("M")
                        }
                        MenuItem {
                            text: "Large";       checkable: true
                            checked: tile.tileSize === "L"
                            height: visible ? implicitHeight : 0
                            visible: tile._canL
                            onTriggered: tile.sizeRequested("L")
                        }
                        MenuItem {
                            text: "Extra Large"; checkable: true
                            checked: tile.tileSize === "XL"
                            height: visible ? implicitHeight : 0
                            visible: tile._canXL
                            onTriggered: tile.sizeRequested("XL")
                        }
                    }
                }
            }
        }

        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: header.bottom
            anchors.margins: App.Theme.tilePad
            anchors.topMargin: 4
        }
    }

    // Free-floating drag ghost — parented directly to the tile (outside card / any layout)
    // so it can be moved anywhere on screen. Drag.active tracks the MouseArea automatically.
    Rectangle {
        id: dragGhost
        width: 180; height: 46
        visible: false
        z: 1000
        radius: 10
        color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.95)
        opacity: 0.95

        // Drag.active is controlled manually from the MouseArea handlers below
        // so Drag.drop() can fire on release before the binding deactivates.
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.keys: ["wx-tile"]

        border.color: Qt.lighter(tile.accentColor, 1.4)
        border.width: 2

        Row {
            anchors.centerIn: parent
            spacing: 10
            Label { text: tile.iconEmoji; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: tile.title
                color: "white"
                font.pixelSize: 14
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["wx-tile"]
        onDropped: function(drop) {
            tile.droppedHere(drop.x < width / 2)
        }
    }
}
