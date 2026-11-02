import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch"
import "../notch/qp"
import "session.js" as Logic

// The session menu: common screen/sleep actions and session-ending actions
// on a compact card. Ending the session with work in progress asks first. Pure:
// SessionWindow.qml binds the Session service.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	// { pacman, downloads }
	property var busy: ({ pacman: false, downloads: 0 })
	property int selectedIndex: 0
	property color accent: "#007aff"
	readonly property var _actions: ["lock", "suspend", "hibernate", "logout", "reboot", "shutdown", "firmware"].map(id => Logic.ACTIONS.find(a => a.id === id))

	signal actionChosen(string id)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	property bool _open: false
	// The action waiting on "… anyway".
	property var _asking: null
	readonly property string _warning: root._asking ? Logic.warning(root._asking.id, root.busy) : ""

	function open() {
		root.selectedIndex = 0;
		root._asking = null;
		root._open = true;
		enter.jump(0);
		keys.forceActiveFocus();
	}
	function close() { root._open = false; }
	function _choose(action, confirmed) {
		if (!action) return;
		if (!confirmed && Logic.warning(action.id, root.busy)) { root._asking = action; return; }
		root._asking = null;
		root.actionChosen(action.id);
	}

	OpeningMotion {
		id: enter
		initial: 0
		target: root._open ? 1 : 0
	}

	// cursor: default — a click on the screen around the card dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	Item {
		id: keys
		objectName: "keys"
		focus: true
		Keys.onPressed: event => {
			const n = root._actions.length;
			if (event.key === Qt.Key_Escape) {
				if (root._asking) root._asking = null;
				else root.dismissed();
			} else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) root.selectedIndex = (root.selectedIndex + 1) % n;
			else if (event.key === Qt.Key_Down) root.selectedIndex = (root.selectedIndex + 1) % n;
			else if (event.key === Qt.Key_Up) root.selectedIndex = (root.selectedIndex - 1 + n) % n;
			else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) root.selectedIndex = (root.selectedIndex - 1 + n) % n;
			else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root._choose(root._asking ?? root._actions[root.selectedIndex], root._asking !== null);
			else return;
			event.accepted = true;
		}
	}

	RectangularShadow {
		anchors.fill: card
		visible: card.visible
		opacity: card.opacity
		scale: card.scale
		offset.y: 12
		blur: Tokens.dock.popup.shadow.blur
		radius: Tokens.launcher.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}

	readonly property real _morph: enter.extent
	Rectangle {
		id: card
		objectName: "card"
		scale: enter.zoom
		transform: Translate { y: enter.rise }
		anchors.centerIn: parent
		width: (content.width + 2 * Tokens.session.padding) * root._morph
		height: (content.height + 2 * Tokens.session.padding) * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		visible: opacity > 0
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Column {
			id: content
			anchors.centerIn: parent
			width: Math.min(520, root.width - 80)
			spacing: 15
			Item {
				width: parent.width; height: 45
				SvgIcon { x: 2; y: 2; name: root._asking ? root._asking.icon : "power"; size: 20; color: root.theme.text }
				Column {
					x: 32; y: 0; spacing: 2
					Text { text: root._asking ? root._asking.label + "?" : "Session"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(18); font.weight: Font.DemiBold }
					Text { text: root._asking ? "Check before continuing" : "Choose what to do with this computer"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(11) }
				}
				Rectangle {
					anchors.right: parent.right; width: 28; height: 28; radius: 8; color: closeHover.hovered ? root.theme.groupBg : "transparent"
					SvgIcon { anchors.centerIn: parent; name: "x"; size: 13; color: root.theme.textMuted }
					HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
					TapHandler { onTapped: root.dismissed() }
				}
			}
			Column {
				visible: !root._asking
				width: parent.width; spacing: 10
				Text { text: "SCREEN & SLEEP"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10); font.weight: Font.DemiBold }
				Row {
					width: parent.width; spacing: 8
					Repeater {
						model: root._actions.slice(0, 3)
						delegate: ActionTile {
							required property var modelData
							required property int index
							action: modelData; actionIndex: index; theme: root.theme
							selected: root.selectedIndex === index
							onPointed: root.selectedIndex = index
							onChosen: root._choose(modelData, false)
						}
					}
				}
				Item { width: 1; height: 4 }
				Text { text: "SESSION & POWER"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10); font.weight: Font.DemiBold }
				Row {
					width: parent.width; spacing: 8
					Repeater {
						model: root._actions.slice(3, 6)
						delegate: ActionTile {
							required property var modelData
							required property int index
							action: modelData; actionIndex: index + 3; theme: root.theme
							selected: root.selectedIndex === index + 3
							onPointed: root.selectedIndex = index + 3
							onChosen: root._choose(modelData, false)
						}
					}
				}
			}
			Rectangle {
				visible: !root._asking
				objectName: "action:firmware"
				width: parent.width; height: 39; radius: 10
				color: firmwareHover.hovered || root.selectedIndex === 6 ? root.theme.groupBg : "transparent"
				border.width: 1; border.color: root.theme.border
				Accessible.role: Accessible.Button; Accessible.name: "Firmware setup, restart into firmware settings"
				SvgIcon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "cpu"; size: 16; color: root.theme.textMuted }
				Text { x: 36; anchors.verticalCenter: parent.verticalCenter; text: "Firmware setup"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(12) }
				Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "Restart into firmware settings"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(11) }
				HoverHandler { id: firmwareHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selectedIndex = 6 }
				TapHandler { onTapped: root._choose(root._actions[6], false) }
			}
			Text {
				objectName: "warning"
				visible: root._warning !== ""; width: parent.width
				text: root._warning; wrapMode: Text.Wrap; color: root.theme.text
				font.family: Fonts.family; font.pixelSize: Fonts.px(13)
			}
			Row {
				visible: root._warning !== ""; anchors.right: parent.right; spacing: Tokens.qp.actions.gap
				QpButton { objectName: "cancel"; theme: root.theme; text: "Cancel"; onClicked: root._asking = null }
				QpButton { objectName: "confirm"; theme: root.theme; primary: true; text: root._asking ? root._asking.label + " anyway" : ""; onClicked: root._choose(root._asking, true) }
			}
			Text { anchors.right: parent.right; text: root._asking ? "Enter to continue · Esc to cancel" : "Arrow keys to choose · Enter to select · Esc to close"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10) }
		}
	}
}
