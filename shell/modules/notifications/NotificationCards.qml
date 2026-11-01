pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "../../common/screens.js" as Screens
import "../../common/render"
import "notifications.js" as Logic

// Brief macOS-style banners at the physical top-right edge. The input region
// follows the cards, so the rest of the overlay never blocks applications.
PanelWindow {
    id: win
    required property var modelData
    required property var hub
    readonly property real uiScale: Settings.values["bloom-scale"]
    readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
    function stateObject() {
        return { kind: "cards", screen: modelData.name, visible: visible,
            groups: Logic.groups(hub.cards).map(g => ({ app: g.app, count: g.items.length })),
            viewportHeight: stack.height, x: stack.x, y: stack.y, hovered: cardHover.hovered };
    }

    screen: modelData
    anchors.top: true
    anchors.right: true
    implicitWidth: Math.min(Math.ceil(396 * uiScale), modelData.width)
    implicitHeight: Math.min(Math.ceil(610 * uiScale), modelData.height)
    color: "transparent"
    visible: targetScreen && hub.cards.length > 0 && !hub.historyOpen
    onVisibleChanged: if (!visible) hub.setCardsHovered(false)
    exclusiveZone: -1
    WlrLayershell.namespace: "bloom:notification-cards"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: win.visible ? stack : null }

    Flickable {
        id: stack
        objectName: "notificationStack"
        x: 12 * win.uiScale
        y: 12 * win.uiScale
        width: win.width - 24 * win.uiScale
        height: Math.max(0, Math.min(contentHeight, win.height - 24 * win.uiScale))
        contentHeight: groupColumn.height
        clip: true
        interactive: contentHeight > height
        ScrollGlide { flickable: stack }
        HoverHandler {
            id: cardHover
            onHoveredChanged: win.hub.setCardsHovered(hovered)
        }

        Column {
            id: groupColumn
            width: stack.width
            spacing: 8 * win.uiScale
            Repeater {
                model: Logic.groups(win.hub.cards)
                delegate: Rectangle {
                    id: card
                    objectName: "notificationCard"
                    required property var modelData
                    readonly property var latest: modelData.items[0]
                    readonly property var actions: win.hub.live[latest.id]?.actions ?? []
                    OpeningMotion { id: arrival; initial: Render.macMotion ? 0 : 1; target: 1 }
                    width: stack.width
                    height: (latest.body ? 112 : 94) * win.uiScale + (actions.length ? 27 * win.uiScale : 0)
                    radius: 16 * win.uiScale
                    color: Theme.bgExpanded
                    border.color: Theme.border
                    border.width: 1
                    opacity: arrival.progress
                    scale: arrival.zoom
                    transform: Translate { y: arrival.rise }

                    Rectangle {
                        x: 13 * win.uiScale; y: 13 * win.uiScale
                        width: 36 * win.uiScale; height: width; radius: 9 * win.uiScale
                        color: Theme.groupBg
                        clip: true
                        Image {
                            id: appImage
                            anchors.fill: parent
                            source: card.latest.image || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !appImage.visible
                            text: card.modelData.app.slice(0, 1).toUpperCase()
                            textFormat: Text.PlainText
                            font.family: Fonts.familyFor(Font.DemiBold)
                            font.pixelSize: Fonts.px(17 * win.uiScale)
                            color: Theme.text
                        }
                    }
                    Text {
                        id: appLabel
                        x: 59 * win.uiScale; y: 12 * win.uiScale
                        width: parent.width - 104 * win.uiScale
                        text: card.modelData.app + (card.modelData.items.length > 1 ? " · " + card.modelData.items.length : "")
                        textFormat: Text.PlainText
                        font.family: Fonts.familyFor(Font.DemiBold)
                        font.pixelSize: Fonts.px(11 * win.uiScale)
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        x: appLabel.x; y: appLabel.y
                        width: appLabel.width; height: appLabel.height
                        enabled: card.modelData.items.length > 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.hub.openHistory()
                    }
                    Text {
                        x: 59 * win.uiScale; y: 33 * win.uiScale
                        width: parent.width - 105 * win.uiScale
                        text: card.latest.summary
                        textFormat: Text.PlainText
                        font.family: Fonts.familyFor(Font.DemiBold)
                        font.pixelSize: Fonts.px(14 * win.uiScale)
                        color: Theme.text
                        elide: Text.ElideRight
                    }
                    Text {
                        x: 59 * win.uiScale; y: 55 * win.uiScale
                        width: parent.width - 76 * win.uiScale
                        height: 37 * win.uiScale
                        visible: card.latest.body !== ""
                        text: card.latest.body
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        font.family: Fonts.family
                        font.pixelSize: Fonts.px(11 * win.uiScale)
                        color: Theme.textMuted
                    }
                    Rectangle {
                        id: dismissButton
                        anchors.right: parent.right; anchors.rightMargin: 10 * win.uiScale
                        y: 10 * win.uiScale
                        width: 23 * win.uiScale; height: width; radius: width / 2
                        color: Theme.groupBg
                        opacity: cardHover.hovered ? 1 : 0.65
                        SvgIcon { anchors.centerIn: parent; name: "x"; size: 12 * win.uiScale; color: Theme.textMuted }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.dismiss(card.latest.id) }
                    }
                    Row {
                        x: 59 * win.uiScale
                        y: card.height - 30 * win.uiScale
                        spacing: 6 * win.uiScale
                        visible: card.actions.length > 0
                        Repeater {
                            model: card.actions
                            delegate: Rectangle {
                                id: actionButton
                                required property var modelData
                                width: Math.min(110 * win.uiScale, actionLabel.implicitWidth + 20 * win.uiScale)
                                height: 22 * win.uiScale
                                radius: 7 * win.uiScale
                                color: Theme.groupBg
                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionButton.modelData.text
                                    textFormat: Text.PlainText
                                    color: Theme.text
                                    font.family: Fonts.familyFor(Font.Medium)
                                    font.pixelSize: Fonts.px(10 * win.uiScale)
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.invoke(card.latest.id, actionButton.modelData.identifier) }
                            }
                        }
                    }
                }
            }
        }
    }
}
