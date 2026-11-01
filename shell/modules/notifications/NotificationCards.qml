pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "../../common/screens.js" as Screens
import "../../common/render"

// A single stack slides from the physical top-right corner. At rest only an
// invisible corner target takes input; there is no separate history window.
PanelWindow {
	id: win
	required property var modelData
	required property var hub
	property bool previewOpen: false
	property bool hoverOpen: false
	property bool footerHovered: false
	property bool expanded: false
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
	readonly property bool showHistory: (hoverOpen || expanded || hub.historyOpen) && hub.history.length > 0
	readonly property var displayed: showHistory ? hub.history : hub.cards
	readonly property int itemCount: displayed.length
	readonly property real compactHeight: itemCount > 0 ? cardHeight(displayed[0], 0) : 0
	readonly property bool stackShown: ((previewOpen || hoverOpen) && hub.cards.length > 0) || showHistory || (expanded && itemCount > 0)
	function cardHeight(item, index) {
		const actions = hub.liveFor(item.key, item.id)?.actions ?? [];
		return ((item.body ? 112 : 94) + (actions.length ? 27 : 0) + (index === 0 && itemCount > 1 ? 30 : 0)) * uiScale;
	}
	function stateObject() {
		return { kind: "stack", screen: modelData.name, visible: stackShown && targetScreen,
			mode: showHistory ? "history" : "arrival", expanded: expanded, shown: itemCount,
			expansionProgress: Math.max(0, Math.min(1, expansion.value)),
			clearVisible: clearButton.visible,
			clearX: modelData.width - win.width + clearButton.x + clearButton.width / 2,
			clearY: clearButton.y + clearButton.height / 2,
			cards: hub.cards.length, history: hub.history.length,
			hovered: stackHover.hovered, cornerHovered: cornerHover.hovered, cornerAvailable: true,
			x: stack.x, y: stack.y, progress: Math.max(0, Math.min(1, slide.value)) };
	}
	function revealArrival() {
		if (win.hoverOpen || win.hub.historyOpen) return;
		win.previewOpen = true;
		hideTimer.restart();
	}
	onExpandedChanged: if (!expanded) stack.contentY = 0
	Component.onCompleted: if (hub.cards.length > 0) revealArrival()

	screen: modelData
	anchors.top: true
	anchors.right: true
	implicitWidth: Math.min(Math.ceil(396 * uiScale), modelData.width)
	implicitHeight: Math.min(Math.ceil(610 * uiScale), modelData.height)
	color: "transparent"
	visible: targetScreen
	exclusiveZone: -1
	WlrLayershell.namespace: "bloom:notification-stack"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region {
		item: corner
		Region { item: win.stackShown || slide.value > 0.01 ? stack : null }
		Region { item: clearButton.visible ? clearButton : null }
	}

	Connections {
		target: win.hub
		function onCardsChanged() {
			if (win.hub.cards.length > 0) win.revealArrival();
			else if (!win.hoverOpen && !win.hub.historyOpen) win.previewOpen = false;
		}
		function onHistoryOpenChanged() {
			if (win.hub.historyOpen) win.expanded = true;
			else if (!win.hoverOpen) win.expanded = false;
		}
	}
	Timer {
		id: hideTimer
		interval: Settings.values["bloom-notifications-timeout"]
		onTriggered: win.previewOpen = false
	}
	Timer {
		id: hoverClose
		interval: win.expanded ? 3000 : 350
		onTriggered: {
			if (!cornerHover.hovered && !stackHover.hovered && !win.footerHovered && !clearHover.hovered && !win.hub.historyOpen) {
				win.hoverOpen = false;
				win.expanded = false;
				win.hub.setCardsHovered(false);
			}
		}
	}
	Spring {
		id: slide
		initial: 0
		target: win.stackShown ? 1 : 0
		stiffness: 520
		damping: 48
	}
	Spring {
		id: expansion
		initial: 0
		target: win.expanded && win.itemCount > 1 ? 1 : 0
		stiffness: 500
		damping: 48
	}

	Item {
		id: corner
		objectName: "notificationCornerTarget"
		x: win.width - width
		y: 0
		width: 48 * win.uiScale
		height: 48 * win.uiScale
		HoverHandler {
			id: cornerHover
			onHoveredChanged: {
				if (hovered) {
					win.hoverOpen = true;
					win.previewOpen = false;
					hideTimer.stop();
					hoverClose.stop();
					win.hub.setCardsHovered(true);
				} else if (win.hoverOpen) hoverClose.restart();
			}
		}
	}

	Repeater {
		model: Math.min(2, Math.max(0, win.itemCount - 1))
		delegate: Rectangle {
			required property int index
			x: stack.x + (index + 1) * 8 * win.uiScale
			y: stack.y + win.compactHeight - 3 * win.uiScale + index * 8 * win.uiScale
			width: stack.width - (index + 1) * 16 * win.uiScale
			height: 18 * win.uiScale
			radius: 12 * win.uiScale
			color: Theme.bgExpanded
			border.color: Theme.border
			border.width: 1
			opacity: (1 - Math.max(0, Math.min(1, expansion.value))) * Math.max(0, Math.min(1, slide.value))
		}
	}

	ListView {
		id: stack
		objectName: "notificationStack"
		x: 12 * win.uiScale + (1 - Math.max(0, Math.min(1, slide.value))) * win.width
		y: 12 * win.uiScale
		width: win.width - 24 * win.uiScale
		readonly property real expandedHeight: Math.max(win.compactHeight, Math.min(contentHeight, 360 * win.uiScale, win.height - 90 * win.uiScale))
		height: win.compactHeight + (expandedHeight - win.compactHeight) * Math.max(0, Math.min(1, expansion.value))
		model: win.displayed
		spacing: 8 * win.uiScale
		clip: true
		opacity: Math.max(0, Math.min(1, slide.value))
		interactive: win.expanded && contentHeight > height
		ScrollGlide { flickable: stack }
		HoverHandler {
			id: stackHover
			onHoveredChanged: {
				if (hovered) {
					hideTimer.stop();
					hoverClose.stop();
					win.hub.setCardsHovered(true);
				} else {
					win.hub.setCardsHovered(false);
					if (win.hoverOpen) hoverClose.restart();
					else if (win.previewOpen) hideTimer.restart();
				}
			}
		}

		delegate: Rectangle {
			id: card
			objectName: "notificationCard"
			required property var modelData
			required property int index
			readonly property var actions: win.hub.liveFor(modelData.key, modelData.id)?.actions ?? []
			width: stack.width
			height: win.cardHeight(modelData, index)
			radius: 16 * win.uiScale
			color: Theme.bgExpanded
			border.color: Theme.border
			border.width: 1
			opacity: index === 0 ? 1 : Math.max(0, Math.min(1, expansion.value))
			scale: index === 0 ? 1 : 0.97 + 0.03 * Math.max(0, Math.min(1, expansion.value))

			Rectangle {
				visible: card.modelData.urgency === "critical"
				x: 0; y: 19 * win.uiScale
				width: 3 * win.uiScale; height: card.height - 38 * win.uiScale
				radius: width / 2
				color: Theme.accent
			}

			Rectangle {
				x: 13 * win.uiScale; y: 13 * win.uiScale
				width: 36 * win.uiScale; height: width; radius: 9 * win.uiScale
				color: Theme.groupBg
				clip: true
				Image {
					id: appImage
					anchors.fill: parent
					source: card.modelData.image || ""
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
				x: 59 * win.uiScale; y: 12 * win.uiScale
				width: parent.width - 104 * win.uiScale
				text: card.modelData.app
				textFormat: Text.PlainText
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Fonts.px(11 * win.uiScale)
				color: Theme.textMuted
				elide: Text.ElideRight
			}
			Text {
				x: 59 * win.uiScale; y: 33 * win.uiScale
				width: parent.width - 105 * win.uiScale
				text: card.modelData.summary
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
				visible: card.modelData.body !== ""
				text: card.modelData.body
				textFormat: Text.PlainText
				wrapMode: Text.Wrap
				elide: Text.ElideRight
				maximumLineCount: 2
				font.family: Fonts.family
				font.pixelSize: Fonts.px(11 * win.uiScale)
				color: Theme.textMuted
			}
			Rectangle {
				anchors.right: parent.right; anchors.rightMargin: 10 * win.uiScale
				y: 10 * win.uiScale
				width: 23 * win.uiScale; height: width; radius: width / 2
				color: Theme.groupBg
				opacity: stackHover.hovered ? 1 : 0.65
				SvgIcon { anchors.centerIn: parent; name: "x"; size: 12 * win.uiScale; color: Theme.textMuted }
				MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.remove(card.modelData.key, card.modelData.id) }
			}
			Row {
				x: 59 * win.uiScale
				y: card.height - (card.index === 0 && win.itemCount > 1 ? 60 : 30) * win.uiScale
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
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.invoke(card.modelData.id, actionButton.modelData.identifier) }
					}
				}
			}
			Item {
				visible: card.index === 0 && win.itemCount > 1
				x: 13 * win.uiScale
				y: card.height - 31 * win.uiScale
				width: card.width - 26 * win.uiScale
				height: 28 * win.uiScale
				Rectangle {
					anchors.top: parent.top
					width: parent.width; height: 1
					color: Theme.border
				}
				SvgIcon {
					x: 3 * win.uiScale; anchors.verticalCenter: parent.verticalCenter
					name: "layers"; size: 14 * win.uiScale; color: Theme.textMuted
				}
				Text {
					x: 25 * win.uiScale; anchors.verticalCenter: parent.verticalCenter
					text: win.expanded ? "Collapse notifications" : (win.itemCount - 1) + " more notification" + (win.itemCount === 2 ? "" : "s")
					textFormat: Text.PlainText
					font.family: Fonts.familyFor(Font.Medium)
					font.pixelSize: Fonts.px(11 * win.uiScale)
					color: Theme.textMuted
				}
				SvgIcon {
					anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
					name: win.expanded ? "chevron-up" : "chevron-down"
					size: 16 * win.uiScale; color: Theme.textMuted
				}
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onEntered: { win.footerHovered = true; win.hoverOpen = true; hoverClose.stop(); }
					onExited: { win.footerHovered = false; if (win.hoverOpen) hoverClose.restart(); }
					onClicked: { win.hoverOpen = true; win.expanded = !win.expanded; hoverClose.stop(); }
				}
			}
		}
	}
	Rectangle {
		id: clearButton
		objectName: "notificationClearAll"
		x: stack.x + stack.width - width
		y: stack.y + stack.height + 10 * win.uiScale
		width: 42 * win.uiScale; height: width; radius: width / 2
		color: Theme.bgExpanded
		border.color: Theme.border
		border.width: 1
		visible: win.itemCount > 0 && expansion.value > 0.05 && win.stackShown
		opacity: Math.max(0, Math.min(1, expansion.value)) * Math.max(0, Math.min(1, slide.value))
		scale: 0.88 + 0.12 * Math.max(0, Math.min(1, expansion.value))
		SvgIcon { anchors.centerIn: parent; name: "trash-2"; size: 18 * win.uiScale; color: Theme.text }
		HoverHandler { id: clearHover; onHoveredChanged: if (hovered) hoverClose.stop(); else if (win.hoverOpen) hoverClose.restart() }
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: { win.hub.clear(); win.expanded = false; win.hoverOpen = false; win.previewOpen = false; }
		}
	}
}
