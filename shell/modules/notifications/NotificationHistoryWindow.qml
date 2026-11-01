pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "../../common/screens.js" as Screens
import "../../common/render"

// The small top-right bell replaces the notch entry point. Hovering it reveals
// recent notifications; leaving a hover-opened sheet closes it after a grace.
PanelWindow {
    id: win
    required property var modelData
    required property var hub
    property bool hoverOpened: false
    property bool suppressHoverUntilLeave: false
    readonly property real uiScale: Settings.values["bloom-scale"]
    readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
    readonly property bool sheetShown: hub.historyOpen || (Render.macMotion && entrance.progress > 0.001)
    function stateObject() {
        return { kind: "history", screen: modelData.name, visible: hub.historyOpen && targetScreen,
            hoverTargetVisible: handle.visible, x: sheet.x, y: sheet.y, count: hub.history.length };
    }

    screen: modelData
    anchors.top: true
    anchors.right: true
    implicitWidth: Math.min(Math.ceil(430 * uiScale), modelData.width)
    implicitHeight: Math.min(Math.ceil(650 * uiScale), modelData.height)
    color: "transparent"
    visible: targetScreen
    exclusiveZone: -1
    WlrLayershell.namespace: "bloom:notification-history"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: hub.historyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: handle.visible ? handle : null
        Region { item: win.sheetShown ? sheet : null }
    }

    OpeningMotion { id: entrance; initial: 0; target: hub.historyOpen ? 1 : 0 }
    Timer {
        id: hoverClose
        interval: 550
        onTriggered: {
            if (win.hoverOpened && !sheetHover.hovered) {
                win.hoverOpened = false;
                win.hub.closeHistory();
            }
        }
    }
    Timer {
        id: suppressReset
        interval: 600
        onTriggered: win.suppressHoverUntilLeave = false
    }
    Connections {
        target: win.hub
        function onHistoryOpenChanged() {
            if (!win.hub.historyOpen) {
                win.hoverOpened = false;
                win.suppressHoverUntilLeave = true;
                hoverClose.stop();
                suppressReset.restart();
            }
        }
    }

    Rectangle {
        id: handle
        objectName: "notificationHoverTarget"
        x: win.width - width - 14 * win.uiScale
        y: 12 * win.uiScale
        width: 38 * win.uiScale; height: 34 * win.uiScale
        radius: 12 * win.uiScale
        visible: !win.hub.historyOpen && win.hub.cards.length === 0
        color: Theme.bgExpanded
        border.color: Theme.border
        border.width: 1
        SvgIcon { anchors.centerIn: parent; name: "bell"; size: 16 * win.uiScale; color: Theme.text }
        Rectangle {
            visible: win.hub.unread > 0
            anchors.right: parent.right; anchors.rightMargin: -2 * win.uiScale
            anchors.top: parent.top; anchors.topMargin: -2 * win.uiScale
            width: 14 * win.uiScale; height: width; radius: width / 2
            color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: win.hub.unread > 9 ? "9+" : win.hub.unread
                color: Theme.bgExpanded
                font.family: Fonts.familyFor(Font.Bold)
                font.pixelSize: Fonts.px(8 * win.uiScale)
            }
        }
        HoverHandler {
            id: handleHover
            onHoveredChanged: {
                if (!hovered) { win.suppressHoverUntilLeave = false; return; }
                if (win.suppressHoverUntilLeave) return;
                win.hoverOpened = true;
                win.hub.openHistory();
                hoverClose.restart();
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.hoverOpened = false; win.hub.openHistory(); } }
    }

    Rectangle {
        id: sheet
        objectName: "notificationHistorySheet"
        x: win.width - width - 12 * win.uiScale
        y: 12 * win.uiScale
        width: Math.min(400 * win.uiScale, win.width - 24 * win.uiScale)
        height: Math.min(560 * win.uiScale, win.height - 24 * win.uiScale)
        radius: 19 * win.uiScale
        visible: win.sheetShown
        enabled: win.hub.historyOpen
        opacity: Render.macMotion ? entrance.progress : 1
        scale: entrance.zoom
        transformOrigin: Item.TopRight
        transform: Translate { y: entrance.rise }
        color: Theme.bgExpanded
        border.color: Theme.border
        border.width: 1
        focus: win.hub.historyOpen
        Keys.onEscapePressed: win.hub.closeHistory()
        HoverHandler {
            id: sheetHover
            onHoveredChanged: {
                if (hovered) hoverClose.stop();
                else if (win.hoverOpened) hoverClose.restart();
            }
        }
        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
            x: 18 * win.uiScale; y: 17 * win.uiScale
            text: "Notifications"
            color: Theme.text
            font.family: Fonts.familyFor(Font.Bold)
            font.pixelSize: Fonts.px(18 * win.uiScale)
        }
        Text {
            x: 18 * win.uiScale; y: 44 * win.uiScale
            text: win.hub.history.length + (win.hub.history.length === 1 ? " recent item" : " recent items")
            color: Theme.textMuted
            font.family: Fonts.family
            font.pixelSize: Fonts.px(11 * win.uiScale)
        }
        Rectangle {
            x: parent.width - width - 14 * win.uiScale; y: 16 * win.uiScale
            width: 26 * win.uiScale; height: width; radius: width / 2
            color: Theme.groupBg
            SvgIcon { anchors.centerIn: parent; name: "x"; size: 13 * win.uiScale; color: Theme.textMuted }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.suppressHoverUntilLeave = true; win.hub.closeHistory(); } }
        }
        Rectangle { x: 16 * win.uiScale; y: 73 * win.uiScale; width: parent.width - 32 * win.uiScale; height: 1; color: Theme.border }

        Row {
            x: 16 * win.uiScale; y: 86 * win.uiScale
            spacing: 7 * win.uiScale
            Rectangle {
                width: 82 * win.uiScale; height: 26 * win.uiScale; radius: 8 * win.uiScale; color: Theme.groupBg
                Text { anchors.centerIn: parent; text: "Mark read"; color: Theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(10 * win.uiScale) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.markRead() }
            }
            Rectangle {
                width: 80 * win.uiScale; height: 26 * win.uiScale; radius: 8 * win.uiScale; color: Theme.groupBg
                Text { anchors.centerIn: parent; text: "Clear all"; color: Theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(10 * win.uiScale) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.clear() }
            }
            Rectangle {
                width: 80 * win.uiScale; height: 26 * win.uiScale; radius: 8 * win.uiScale
                color: Settings.values["bloom-notifications-dnd"] ? Theme.text : Theme.groupBg
                Text { anchors.centerIn: parent; text: "Focus"; color: Settings.values["bloom-notifications-dnd"] ? Theme.bgExpanded : Theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(10 * win.uiScale) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("bloom-notifications-dnd", !Settings.values["bloom-notifications-dnd"]) }
            }
        }
        Text {
            anchors.centerIn: list
            visible: win.hub.history.length === 0
            text: "All caught up"
            color: Theme.textMuted
            font.family: Fonts.family
            font.pixelSize: Fonts.px(13 * win.uiScale)
        }
        ListView {
            id: list
            objectName: "notificationHistoryList"
            x: 12 * win.uiScale; y: 125 * win.uiScale
            width: parent.width - 24 * win.uiScale
            height: parent.height - 139 * win.uiScale
            model: win.hub.history
            spacing: 7 * win.uiScale
            clip: true
            ScrollGlide { flickable: list }
            delegate: Rectangle {
                id: entry
                required property var modelData
                readonly property var actions: win.hub.liveFor(modelData.key, modelData.id)?.actions ?? []
                width: list.width
                height: (modelData.body ? 98 : 78) * win.uiScale + (actions.length ? 25 * win.uiScale : 0)
                radius: 12 * win.uiScale
                color: Theme.groupBg
                border.color: Theme.border
                border.width: 1
                Rectangle {
                    x: 11 * win.uiScale; y: 12 * win.uiScale
                    width: 30 * win.uiScale; height: width; radius: 8 * win.uiScale
                    color: Theme.bgExpanded
                    Text { anchors.centerIn: parent; text: entry.modelData.app.slice(0, 1).toUpperCase(); textFormat: Text.PlainText; color: Theme.text; font.family: Fonts.familyFor(Font.Bold); font.pixelSize: Fonts.px(14 * win.uiScale) }
                }
                Text {
                    x: 50 * win.uiScale; y: 8 * win.uiScale; width: parent.width - 85 * win.uiScale
                    text: entry.modelData.app
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    font.family: Fonts.familyFor(Font.DemiBold)
                    font.pixelSize: Fonts.px(10 * win.uiScale)
                    elide: Text.ElideRight
                }
                Text {
                    x: 50 * win.uiScale; y: 28 * win.uiScale; width: parent.width - 66 * win.uiScale
                    text: entry.modelData.summary
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Fonts.familyFor(Font.DemiBold)
                    font.pixelSize: Fonts.px(13 * win.uiScale)
                    elide: Text.ElideRight
                }
                Text {
                    x: 50 * win.uiScale; y: 49 * win.uiScale; width: parent.width - 66 * win.uiScale
                    height: 34 * win.uiScale
                    visible: entry.modelData.body !== ""
                    text: entry.modelData.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.textMuted
                    font.family: Fonts.family
                    font.pixelSize: Fonts.px(10 * win.uiScale)
                }
                Rectangle {
                    visible: !entry.modelData.read
                    anchors.top: parent.top; anchors.topMargin: 13 * win.uiScale
                    anchors.right: parent.right; anchors.rightMargin: 12 * win.uiScale
                    width: 6 * win.uiScale; height: width; radius: width / 2
                    color: Theme.accent
                }
                Row {
                    x: 50 * win.uiScale; y: entry.height - 25 * win.uiScale
                    spacing: 5 * win.uiScale
                    visible: entry.actions.length > 0
                    Repeater {
                        model: entry.actions
                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData
                            width: Math.min(95 * win.uiScale, actionLabel.implicitWidth + 16 * win.uiScale)
                            height: 20 * win.uiScale; radius: 6 * win.uiScale
                            color: Theme.bgExpanded
                            Text { id: actionLabel; anchors.centerIn: parent; text: actionButton.modelData.text; textFormat: Text.PlainText; color: Theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(10 * win.uiScale) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.invokeHistory(entry.modelData.key, entry.modelData.id, actionButton.modelData.identifier) }
                        }
                    }
                }
            }
        }
    }
}
