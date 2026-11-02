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
	property bool controlsHovered: false
	property bool expanded: false
	property var visualItems: []
	property real firstCardHeight: 108 * uiScale
	property real secondCardHeight: 108 * uiScale
	property real penultimateCardHeight: 108 * uiScale
	property real lastCardHeight: 108 * uiScale
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
	readonly property bool showHistory: (hoverOpen || expanded || hub.historyOpen) && hub.history.length > 0
	readonly property bool closing: !previewOpen && !hoverOpen && !expanded && !hub.historyOpen
	readonly property var activeItems: showHistory ? hub.history : hub.cards
	readonly property var displayed: closing ? visualItems : (activeItems.length > 0 ? activeItems : visualItems)
	readonly property int itemCount: displayed.length
	readonly property real compactHeight: itemCount > 0 ? firstCardHeight : 0
	readonly property bool stackShown: ((previewOpen || hoverOpen) && hub.cards.length > 0) || showHistory || (expanded && itemCount > 0)
	function stateObject() {
		return { kind: "stack", screen: modelData.name, visible: stackShown && targetScreen,
			mode: showHistory ? "history" : "arrival", expanded: expanded, shown: itemCount,
			expansionProgress: Math.max(0, Math.min(1, expansion.value)),
			clearVisible: clearButton.visible,
			expandX: modelData.width - win.width + stack.x + stack.width - 54 * uiScale,
			expandY: stack.y + 26 * uiScale,
			clearX: modelData.width - win.width + clearButton.x + clearButton.width / 2,
			clearY: clearButton.y + clearButton.height / 2,
			cards: hub.cards.length, history: hub.history.length,
			hovered: stackHover.hovered, cornerHovered: cornerHover.hovered, cornerAvailable: true,
			x: stack.x, y: stack.y, viewportHeight: stack.height,
			renderedCardHeight: stack.itemAtIndex(0)?.height ?? 0,
			secondCardHeight: stack.itemAtIndex(1)?.height ?? 0,
			scrollbarVisible: scrollHit.visible,
			scrollX: modelData.width - win.width + scrollHit.x + scrollHit.width / 2,
			scrollTopY: scrollHit.y + 12 * uiScale,
			scrollBottomY: scrollHit.y + scrollHit.height - 12 * uiScale,
			contentY: stack.contentY, contentHeight: stack.contentHeight,
			progress: Math.max(0, Math.min(1, slide.value)) };
	}
	function revealArrival() {
		if (win.hoverOpen || win.hub.historyOpen) return;
		win.previewOpen = true;
		hideTimer.restart();
	}
	onShowHistoryChanged: if (showHistory) visualItems = hub.history
	onExpandedChanged: if (!expanded) stack.contentY = 0
	Component.onCompleted: {
		if (hub.cards.length > 0) {
			visualItems = hub.cards;
			revealArrival();
		}
	}

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
		Region { item: scrollHit.visible ? scrollHit : null }
		Region { item: clearButton.visible ? clearButton : null }
	}

	Connections {
		target: win.hub
		function onCardsChanged() {
			if (win.hub.cards.length > 0) {
				win.visualItems = win.hub.cards;
				win.revealArrival();
			}
			else if (!win.hoverOpen && !win.hub.historyOpen) win.previewOpen = false;
		}
		function onHistoryChanged() {
			if (win.showHistory && win.hub.history.length > 0) win.visualItems = win.hub.history;
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
			if (!cornerHover.hovered && !stackHover.hovered && !win.controlsHovered && !clearHover.hovered && !win.hub.historyOpen) {
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
		stiffness: 300
		damping: 36
		onSettledChanged: if (settled && target === 0) win.visualItems = []
	}
	Spring {
		id: expansion
		initial: 0
		target: win.expanded && win.itemCount > 1 ? 1 : 0
		stiffness: 380
		damping: 42
	}

	Item {
		id: corner
		objectName: "notificationCornerTarget"
		x: win.width - width
		y: 0
		width: 48 * win.uiScale
		height: 4 * win.uiScale
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

	ListView {
		id: stack
		objectName: "notificationStack"
		x: 12 * win.uiScale + (1 - Math.max(0, Math.min(1, slide.value))) * win.width
		y: 12 * win.uiScale
		width: win.width - 42 * win.uiScale
		readonly property real expandedHeight: Math.max(win.compactHeight, Math.min(
			Math.max(win.firstCardHeight + spacing + win.secondCardHeight,
				win.penultimateCardHeight + spacing + win.lastCardHeight), win.height - 90 * win.uiScale))
		height: win.compactHeight + (expandedHeight - win.compactHeight) * Math.max(0, Math.min(1, expansion.value))
		model: win.displayed
		spacing: 8 * win.uiScale
		clip: true
		opacity: 1
		interactive: win.expanded && contentHeight > height
		snapMode: ListView.SnapToItem
		boundsBehavior: Flickable.StopAtBounds
		remove: Transition { NumberAnimation { properties: "x"; to: stack.width; duration: 150; easing.type: Easing.OutCubic } }
		displaced: Transition { NumberAnimation { properties: "y"; duration: 190; easing.type: Easing.OutCubic } }
		footer: Item {
			width: stack.width
			height: win.expanded ? Math.max(0, stack.height - win.penultimateCardHeight - stack.spacing - win.lastCardHeight) : 0
		}
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
			readonly property string appIconSource: {
				Apps.revision;
				const icon = modelData.icon || "";
				if (icon.startsWith("file:///") || icon.startsWith("image://")) return icon;
				if (icon.startsWith("/")) return "file://" + icon;
				const entry = (modelData.desktopEntry ? DesktopEntries.byId(modelData.desktopEntry) : null)
					|| DesktopEntries.heuristicLookup(modelData.app);
				return (icon ? Quickshell.iconPath(icon, true) : "")
					|| (entry?.icon ? Quickshell.iconPath(entry.icon, true) : "")
					|| Quickshell.iconPath(modelData.app.toLowerCase(), true)
					|| modelData.image || "";
			}
			readonly property real contentBottom: bodyText.visible
				? bodyText.y + bodyText.implicitHeight : summaryText.y + summaryText.implicitHeight
			width: stack.width
			height: Math.ceil(contentBottom + (actions.length > 0 ? 42 : 14) * win.uiScale)
			function reportHeight() {
				if (index === 0) win.firstCardHeight = height;
				else if (index === 1) win.secondCardHeight = height;
				if (index === win.itemCount - 2) win.penultimateCardHeight = height;
				if (index === win.itemCount - 1) win.lastCardHeight = height;
			}
			onHeightChanged: reportHeight()
			onIndexChanged: reportHeight()
			Component.onCompleted: reportHeight()
			radius: 15 * win.uiScale
			color: Theme.bgExpanded
			border.color: Theme.border
			border.width: 1
			opacity: index === 0 ? 1 : Math.max(0, Math.min(1, expansion.value))
			transform: Translate { y: index === 0 ? 0 : -10 * win.uiScale * (1 - Math.max(0, Math.min(1, expansion.value))) }

			Rectangle {
				visible: card.modelData.urgency === "critical"
				x: 0; y: 16 * win.uiScale
				width: 3 * win.uiScale; height: card.height - 32 * win.uiScale
				radius: width / 2; color: Theme.accent
			}
			Rectangle {
				x: 14 * win.uiScale; y: 12 * win.uiScale
				width: 30 * win.uiScale; height: width; radius: 8 * win.uiScale
				color: Theme.groupBg; clip: true
				Image {
					id: appImage
					anchors.fill: parent
					source: card.appIconSource
					fillMode: Image.PreserveAspectCrop
					asynchronous: false
					visible: status === Image.Ready
				}
				Text {
					anchors.centerIn: parent
					visible: !appImage.visible
					text: card.modelData.app.slice(0, 1).toUpperCase()
					textFormat: Text.PlainText
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Fonts.px(15 * win.uiScale)
					color: Theme.text
				}
			}
			Text {
				x: 53 * win.uiScale; y: 17 * win.uiScale
				width: card.width - (card.index === 0 && win.itemCount > 1 ? 136 : 96) * win.uiScale
				text: card.modelData.app
				textFormat: Text.PlainText
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Fonts.px(11 * win.uiScale)
				color: Theme.textMuted
				elide: Text.ElideRight
			}
			Text {
				id: summaryText
				x: 14 * win.uiScale; y: 49 * win.uiScale
				width: card.width - 28 * win.uiScale
				text: card.modelData.summary
				textFormat: Text.PlainText
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Fonts.px(15 * win.uiScale)
				color: Theme.text
				elide: Text.ElideRight
			}
			Text {
				id: bodyText
				x: 14 * win.uiScale
				y: summaryText.y + summaryText.implicitHeight + 3 * win.uiScale
				width: card.width - 28 * win.uiScale
				visible: card.modelData.body !== ""
				text: card.modelData.body
				textFormat: Text.PlainText
				wrapMode: Text.Wrap
				elide: Text.ElideRight
				maximumLineCount: 3
				font.family: Fonts.family
				font.pixelSize: Fonts.px(13 * win.uiScale)
				color: Theme.text
				opacity: 0.84
			}
			Rectangle {
				visible: card.index === 0 && win.itemCount > 1
				x: card.width - 73 * win.uiScale; y: 13 * win.uiScale
				width: 38 * win.uiScale; height: 26 * win.uiScale
				radius: 9 * win.uiScale; color: Theme.groupBg
				Text {
					x: 6 * win.uiScale; anchors.verticalCenter: parent.verticalCenter
					text: String(Math.min(99, win.itemCount - 1))
					textFormat: Text.PlainText
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Fonts.px(10 * win.uiScale)
					color: Theme.text
				}
				SvgIcon {
					anchors.right: parent.right; anchors.rightMargin: 3 * win.uiScale
					anchors.verticalCenter: parent.verticalCenter
					name: win.expanded ? "chevron-up" : "chevron-down"
					size: 14 * win.uiScale; color: Theme.textMuted
				}
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onEntered: { win.controlsHovered = true; win.hoverOpen = true; hoverClose.stop(); }
					onExited: { win.controlsHovered = false; if (win.hoverOpen) hoverClose.restart(); }
					onClicked: { win.hoverOpen = true; win.expanded = !win.expanded; hoverClose.stop(); }
				}
			}
			Rectangle {
				x: card.width - 31 * win.uiScale; y: 13 * win.uiScale
				width: 25 * win.uiScale; height: width; radius: width / 2
				color: Theme.groupBg
				SvgIcon { anchors.centerIn: parent; name: "x"; size: 13 * win.uiScale; color: Theme.textMuted }
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					hoverEnabled: true
					onEntered: { win.controlsHovered = true; hoverClose.stop(); }
					onExited: { win.controlsHovered = false; if (win.hoverOpen) hoverClose.restart(); }
					onClicked: win.hub.remove(card.modelData.key, card.modelData.id)
				}
			}
			Row {
				x: 14 * win.uiScale
				y: card.contentBottom + 8 * win.uiScale
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
		}
	}
	Item {
		id: scrollHit
		x: stack.x + stack.width + 5 * win.uiScale
		y: stack.y
		width: 15 * win.uiScale
		height: stack.height
		visible: win.expanded && expansion.value > 0.95 && stack.contentHeight > stack.height + 1
		Rectangle {
			x: (parent.width - width) / 2; y: 3 * win.uiScale
			width: 4 * win.uiScale; height: parent.height - 6 * win.uiScale
			radius: width / 2; color: Theme.border
		}
		Rectangle {
			id: scrollThumb
			x: (parent.width - width) / 2
			width: 4 * win.uiScale
			height: Math.max(28 * win.uiScale, stack.visibleArea.heightRatio * parent.height)
			y: Math.max(0, Math.min(parent.height - height, stack.visibleArea.yPosition * parent.height))
			radius: width / 2
			color: Theme.text
			opacity: 0.7
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			property real grab: 0
			function moveThumb(y) {
				const travel = scrollHit.height - scrollThumb.height;
				if (travel <= 0) return;
				stack.contentY = Math.max(0, Math.min(stack.contentHeight - stack.height,
					(y - grab) / travel * (stack.contentHeight - stack.height)));
			}
			onPressed: mouse => {
				grab = mouse.y >= scrollThumb.y && mouse.y <= scrollThumb.y + scrollThumb.height
					? mouse.y - scrollThumb.y : scrollThumb.height / 2;
				moveThumb(mouse.y);
			}
			onPositionChanged: mouse => { if (pressed) moveThumb(mouse.y); }
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
		opacity: Math.max(0, Math.min(1, expansion.value))
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
