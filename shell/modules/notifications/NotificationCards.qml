pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// One top-right stack on the focused screen. No surface is mapped at rest.
PanelWindow {
	id: win
	required property var modelData
	required property var hub
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: {
		const focused = HyprState.monitors.find(m => m.focused)?.name;
		return focused ? modelData.name === focused : modelData.name === Quickshell.screens[0]?.name;
	}
	function stateObject() { return { kind: "cards", screen: modelData.name, visible: visible, count: hub.cards.length }; }

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

	Column {
		id: stack
		x: 8 * win.uiScale
		y: 64 * win.uiScale
		width: win.width - 16 * win.uiScale
		spacing: 8 * win.uiScale
		Repeater {
			model: win.hub.cards
			delegate: Rectangle {
				id: card
				required property var modelData
				width: stack.width
				height: 108 * win.uiScale
				radius: 14 * win.uiScale
				color: Theme.bgExpanded
				border.color: Theme.border
				border.width: 1
				Text {
					x: 14 * win.uiScale
					y: 8 * win.uiScale
					width: parent.width - 48 * win.uiScale
					text: card.modelData.app + (win.hub.cards.filter(c => c.app === card.modelData.app).length > 1
						? " · " + win.hub.cards.filter(c => c.app === card.modelData.app).length : "")
					textFormat: Text.PlainText
					elide: Text.ElideRight
					color: Theme.textMuted
					font.pixelSize: 11 * win.uiScale
				}
				Text {
					x: 14 * win.uiScale
					y: 30 * win.uiScale
						width: parent.width - 88 * win.uiScale
					text: card.modelData.summary
					textFormat: Text.PlainText
					elide: Text.ElideRight
					color: Theme.text
					font.bold: true
					font.pixelSize: 13 * win.uiScale
				}
				Text {
					x: 14 * win.uiScale
					y: 50 * win.uiScale
						width: parent.width - 88 * win.uiScale
					height: 32 * win.uiScale
					text: card.modelData.body
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
						source: card.modelData.image || ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						visible: status === Image.Ready
					}
					Text {
						anchors.centerIn: parent
						visible: !cardImage.visible
						text: card.modelData.app.slice(0, 1).toUpperCase()
						textFormat: Text.PlainText
						color: Theme.text; font.pixelSize: 20 * win.uiScale
					}
				}
				Text {
					anchors.right: parent.right
					anchors.rightMargin: 12 * win.uiScale
					anchors.top: parent.top
					anchors.topMargin: 7 * win.uiScale
					text: "×"
					color: Theme.text
					font.pixelSize: 17 * win.uiScale
					MouseArea { anchors.fill: parent; onClicked: win.hub.dismiss(card.modelData.id) }
				}
				Row {
					x: 14 * win.uiScale
					y: 84 * win.uiScale
					spacing: 8 * win.uiScale
					Repeater {
						model: win.hub.live[card.modelData.id]?.actions ?? []
						delegate: Rectangle {
							id: actionButton
							required property var modelData
							width: Math.min(92 * win.uiScale, label.implicitWidth + 16 * win.uiScale)
							height: 19 * win.uiScale
							radius: 5 * win.uiScale
							color: Theme.groupBg
							Text { id: label; anchors.centerIn: parent; text: actionButton.modelData.text; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.text; font.pixelSize: 10 * win.uiScale }
							MouseArea { anchors.fill: parent; onClicked: win.hub.invoke(card.modelData.id, actionButton.modelData.identifier) }
						}
					}
				}
			}
		}
	}
}
