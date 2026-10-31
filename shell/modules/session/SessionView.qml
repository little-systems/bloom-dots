import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch"
import "../notch/qp"
import "session.js" as Logic

// The session menu: lock, log out, suspend, hibernate, restart, shut down and
// firmware setup on the launcher's card, as Command Center's round buttons.
// Ending the session with pacman or a download running asks first. Pure:
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
			width: Math.min(324, root.width - 80)
			spacing: 12
			Item {
				width: parent.width; height: Math.max(34, Fonts.px(18) * 1.4)
				SvgIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: root._asking ? root._asking.icon : "power"; size: 18; color: root.theme.textMuted }
				Text { x: 38; anchors.verticalCenter: parent.verticalCenter; text: root._asking ? root._asking.label + "?" : "Session"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(16); font.weight: Font.DemiBold }
				Rectangle {
					anchors.right: parent.right; width: 28; height: 28; radius: 8; color: closeHover.hovered ? root.theme.groupBg : "transparent"
					SvgIcon { anchors.centerIn: parent; name: "x"; size: 13; color: root.theme.textMuted }
					HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
					TapHandler { onTapped: root.dismissed() }
				}
			}
			Rectangle { width: parent.width; height: 1; color: root.theme.border }
			Column {
				visible: !root._asking
				width: parent.width; spacing: 2
				Repeater {
					model: root._actions
					delegate: Column {
						id: group
						required property var modelData
						required property int index
						width: content.width
						Rectangle {
							id: actionRow
							objectName: "action:" + group.modelData.id
							width: parent.width; height: Math.max(40, Fonts.px(14) * 1.4 + 18); radius: 9
							color: rowHover.hovered || root.selectedIndex === group.index ? root.theme.groupBg : "transparent"
							Behavior on color { ColorAnimation { duration: 120 } }
							Accessible.role: Accessible.Button; Accessible.name: group.modelData.label
							SvgIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: group.modelData.icon; color: group.modelData.id === "shutdown" ? "#ff453a" : root.theme.textMuted; size: 17 }
							Text { objectName: "label"; x: 38; anchors.verticalCenter: parent.verticalCenter; text: group.modelData.label; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(14) }
							SvgIcon { visible: group.modelData.id === "firmware"; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; size: 13; color: root.theme.textMuted }
							HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selectedIndex = group.index }
							TapHandler { onTapped: root._choose(group.modelData, false) }
						}
						Item { width: parent.width; height: group.index === 2 || group.index === 5 ? 11 : 0; Rectangle { x: 8; y: 5; width: parent.width - 16; height: 1; visible: parent.height > 0; color: root.theme.border } }
					}
				}
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
			Text { anchors.right: parent.right; text: root._asking ? "Enter to continue · Esc to cancel" : "↑ ↓ to choose · Esc to close"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10) }
		}
	}
}
