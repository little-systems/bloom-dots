pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "notifications.js" as Logic
import "../../common/screens.js" as Screens
import "../../common/render"

// One top-right stack on the focused screen. No surface is mapped at rest.
PanelWindow {
	id: win
	required property var modelData
	required property var hub
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
	function stateObject() { return { kind: "cards", screen: modelData.name, visible: visible,
		groups: Logic.groups(hub.cards).map(g => ({ app: g.app, count: g.items.length })), viewportHeight: stack.height }; }

	screen: modelData
	anchors.top: true
	anchors.right: true
	implicitWidth: Math.min(Math.ceil(380 * uiScale), modelData.width)
	implicitHeight: Math.min(Math.ceil(640 * uiScale), modelData.height)
	color: "transparent"
	visible: targetScreen && hub.cards.length > 0
	exclusiveZone: 0
	WlrLayershell.namespace: "bloom:notification-cards"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region { item: win.visible ? stack : null }

	Flickable {
		id: stack
		x: 8 * win.uiScale
		y: 64 * win.uiScale
		width: win.width - 16 * win.uiScale
		height: Logic.cardViewport(win.height, win.uiScale, contentHeight)
		contentHeight: groupColumn.height
		clip: true
		flickableDirection: Flickable.VerticalFlick
		Column {
			id: groupColumn
			width: stack.width
			spacing: 8 * win.uiScale
			Repeater {
			model: Logic.groups(win.hub.cards)
			delegate: Rectangle {
				id: card
				required property var modelData
				readonly property var latest: modelData.items[0]
				width: stack.width
				height: 108 * win.uiScale
				radius: 14 * win.uiScale
				color: Theme.bgExpanded
				border.color: Theme.border
				border.width: 1
				Text {
					font.family: Fonts.family
					x: 14 * win.uiScale
					y: 8 * win.uiScale
					width: parent.width - 48 * win.uiScale
						text: card.modelData.app + (card.modelData.items.length > 1 ? " · " + card.modelData.items.length : "")
					textFormat: Text.PlainText
					elide: Text.ElideRight
					color: Theme.textMuted
					font.pixelSize: 11 * win.uiScale
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: card.modelData.items.length > 1; onClicked: win.hub.openHistory() }
				}
				Text {
					font.family: Fonts.familyFor(Font.Bold)
					x: 14 * win.uiScale
					y: 30 * win.uiScale
						width: parent.width - 88 * win.uiScale
						text: card.latest.summary
					textFormat: Text.PlainText
					elide: Text.ElideRight
					color: Theme.text
					font.bold: true
					font.pixelSize: 13 * win.uiScale
				}
				Text {
					font.family: Fonts.family
					x: 14 * win.uiScale
					y: 50 * win.uiScale
						width: parent.width - 88 * win.uiScale
					height: 32 * win.uiScale
						text: card.latest.body
					textFormat: Text.PlainText
					wrapMode: Text.Wrap
					elide: Text.ElideRight
					color: Theme.textMuted
					font.pixelSize: 11 * win.uiScale
				}
				Rectangle {
					x: parent.width - 66 * win.uiScale
					y: 34 * win.uiScale
					width: 50 * win.uiScale; height: width; radius: 7 * win.uiScale
					clip: true; color: Theme.groupBg
					Image {
						id: cardImage
						anchors.fill: parent
							source: card.latest.image || ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						visible: status === Image.Ready
					}
					Text {
						font.family: Fonts.family
						anchors.centerIn: parent
						visible: !cardImage.visible
						text: card.modelData.app.slice(0, 1).toUpperCase()
						textFormat: Text.PlainText
						color: Theme.text; font.pixelSize: 20 * win.uiScale
					}
				}
				Text {
					font.family: Fonts.family
					anchors.right: parent.right
					anchors.rightMargin: 12 * win.uiScale
					anchors.top: parent.top
					anchors.topMargin: 7 * win.uiScale
					text: "×"
					color: Theme.text
					font.pixelSize: 17 * win.uiScale
					MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.dismiss(card.latest.id) }
				}
				Row {
					x: 14 * win.uiScale
					y: 84 * win.uiScale
					spacing: 8 * win.uiScale
					Repeater {
						model: win.hub.live[card.latest.id]?.actions ?? []
						delegate: Rectangle {
							id: actionButton
							required property var modelData
							width: Math.min(92 * win.uiScale, label.implicitWidth + 16 * win.uiScale)
							height: 19 * win.uiScale
							radius: 5 * win.uiScale
							color: Theme.groupBg
							Text { font.family: Fonts.family; id: label; anchors.centerIn: parent; text: actionButton.modelData.text; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.text; font.pixelSize: 10 * win.uiScale }
							MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.hub.invoke(card.latest.id, actionButton.modelData.identifier) }
						}
					}
				}
			}
		}
		}
	}
}
