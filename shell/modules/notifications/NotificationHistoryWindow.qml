pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.services

// The history sheet opens below Bloom's notch. Old entries remain text-only;
// action buttons exist solely while their source notification is live.
PanelWindow {
	id: win
	required property var modelData
	required property var hub
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: {
		const focused = HyprState.monitors.find(m => m.focused)?.name;
		return focused ? modelData.name === focused : modelData.name === Quickshell.screens[0]?.name;
	}
	function stateObject() { return { kind: "history", screen: modelData.name, visible: visible, count: hub.history.length }; }

	screen: modelData
	anchors.top: true
	anchors.left: true
	anchors.right: true
	implicitHeight: Math.min(Math.ceil(620 * uiScale), modelData.height)
	color: "transparent"
	visible: hub.historyOpen && targetScreen
	exclusiveZone: 0
	WlrLayershell.namespace: "bloom:notification-history"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
	mask: Region { item: win.visible ? sheet : null }

	Rectangle {
		id: sheet
		focus: win.visible
		Keys.onEscapePressed: win.hub.closeHistory()
		width: Math.min(420 * win.uiScale, win.width - 16 * win.uiScale)
		height: Math.min(500 * win.uiScale, win.height - 68 * win.uiScale)
		x: (win.width - width) / 2
		y: 58 * win.uiScale
		radius: 18 * win.uiScale
		color: Theme.bgExpanded
		border.color: Theme.border
		border.width: 1
		Text {
			x: 16 * win.uiScale; y: 12 * win.uiScale
			text: "Notifications"; color: Theme.text; font.bold: true; font.pixelSize: 16 * win.uiScale
		}
		Button {
			id: closeButton
			anchors.right: parent.right; anchors.rightMargin: 12 * win.uiScale; y: 8 * win.uiScale
			width: 62 * win.uiScale; height: 28 * win.uiScale
			text: "Close"
			focus: win.visible
			background: Rectangle { color: closeButton.activeFocus ? Theme.groupBg : "transparent"; radius: 5 }
			contentItem: Text { text: closeButton.text; color: Theme.textMuted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 * win.uiScale }
			onClicked: win.hub.closeHistory()
		}
		Button {
			id: readButton
			x: 12 * win.uiScale; y: 37 * win.uiScale
			width: 88 * win.uiScale; height: 26 * win.uiScale
			text: "Mark read"
			background: Rectangle { color: readButton.activeFocus ? Theme.groupBg : "transparent"; radius: 5 }
			contentItem: Text { text: readButton.text; color: Theme.accent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 * win.uiScale }
			onClicked: win.hub.markRead()
		}
		Button {
			id: clearButton
			x: 101 * win.uiScale; y: 37 * win.uiScale
			width: 94 * win.uiScale; height: 26 * win.uiScale
			text: "Clear history"
			background: Rectangle { color: clearButton.activeFocus ? Theme.groupBg : "transparent"; radius: 5 }
			contentItem: Text { text: clearButton.text; color: Theme.accent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 * win.uiScale }
			onClicked: win.hub.clear()
		}
		Button {
			id: dndButton
			x: 198 * win.uiScale; y: 37 * win.uiScale
			width: 94 * win.uiScale; height: 26 * win.uiScale
			text: Settings.values["bloom-notifications-dnd"] ? "DND on" : "DND off"
			background: Rectangle { color: dndButton.activeFocus ? Theme.groupBg : "transparent"; radius: 5 }
			contentItem: Text { text: dndButton.text; color: Theme.accent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11 * win.uiScale }
			onClicked: Settings.set("bloom-notifications-dnd", !Settings.values["bloom-notifications-dnd"])
		}
		ListView {
			id: list
			x: 10 * win.uiScale; y: 68 * win.uiScale
			width: parent.width - 20 * win.uiScale
			height: parent.height - 78 * win.uiScale
			clip: true
			model: win.hub.history
			spacing: 6 * win.uiScale
			delegate: Rectangle {
				id: item
				required property var modelData
				width: list.width
				height: 84 * win.uiScale
				radius: 9 * win.uiScale
				color: Theme.groupBg
				Rectangle { width: 5 * win.uiScale; height: parent.height; radius: 2; color: item.modelData.read ? "transparent" : Theme.accent }
				Text { x: 14 * win.uiScale; y: 7 * win.uiScale; width: parent.width - 28 * win.uiScale; text: item.modelData.app + " · " + item.modelData.summary; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.text; font.bold: true; font.pixelSize: 12 * win.uiScale }
				Text { x: 14 * win.uiScale; y: 28 * win.uiScale; width: parent.width - 28 * win.uiScale; height: 32 * win.uiScale; text: item.modelData.body; textFormat: Text.PlainText; wrapMode: Text.Wrap; elide: Text.ElideRight; color: Theme.textMuted; font.pixelSize: 11 * win.uiScale }
				Row {
					x: 14 * win.uiScale; y: 61 * win.uiScale; spacing: 8 * win.uiScale
					Repeater {
						model: win.hub.liveFor(item.modelData.key, item.modelData.id)?.actions ?? []
						delegate: Button {
							id: actionLabel
							required property var modelData
							text: modelData.text
							width: Math.min(100 * win.uiScale, implicitWidth)
							height: 18 * win.uiScale
							background: Rectangle { color: actionLabel.activeFocus ? Theme.bgExpanded : "transparent"; radius: 4 }
							contentItem: Text { text: actionLabel.text; textFormat: Text.PlainText; color: Theme.accent; font.pixelSize: 10 * win.uiScale }
							onClicked: win.hub.invokeHistory(item.modelData.key, item.modelData.id, actionLabel.modelData.identifier)
						}
					}
				}
			}
		}
	}
}
