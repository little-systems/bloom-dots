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
	function _choose(action) {
		if (root._asking === null && Logic.warning(action.id, root.busy)) root._asking = action;
		else {
			root._asking = null;
			root.actionChosen(action.id);
		}
	}

	Spring {
		id: enter
		stiffness: Tokens.launcher.enter.stiffness
		damping: Tokens.launcher.enter.damping
		mass: Tokens.launcher.enter.mass
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
			const n = Logic.ACTIONS.length;
			if (event.key === Qt.Key_Escape) {
				if (root._asking) root._asking = null;
				else root.dismissed();
			} else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) root.selectedIndex = (root.selectedIndex + 1) % n;
			else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) root.selectedIndex = (root.selectedIndex - 1 + n) % n;
			else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root._choose(root._asking ?? Logic.ACTIONS[root.selectedIndex]);
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

	Rectangle {
		id: card
		objectName: "card"
		anchors.centerIn: parent
		width: content.width + 2 * Tokens.session.padding
		height: content.height + 2 * Tokens.session.padding
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		visible: opacity > 0
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		scale: Tokens.launcher.enter.scale + (1 - Tokens.launcher.enter.scale) * enter.value
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Column {
			id: content
			anchors.centerIn: parent
			spacing: Tokens.session.gap

			Row {
				id: actions
				Repeater {
					model: Logic.ACTIONS

					Item {
						id: cell
						required property var modelData
						required property int index
						objectName: "action:" + cell.modelData.id
						width: Tokens.session.cell
						height: button.height + Tokens.session.labelGap + label.height

						CcRoundButton {
							id: button
							anchors.horizontalCenter: parent.horizontalCenter
							theme: root.theme
							icon: cell.modelData.icon
							active: cell.index === root.selectedIndex
							onClicked: root._choose(cell.modelData)
						}
						Text {
							id: label
							objectName: "label"
							y: button.height + Tokens.session.labelGap
							width: parent.width
							horizontalAlignment: Text.AlignHCenter
							text: cell.modelData.label
							color: root.theme.textMuted
							font.family: Fonts.family
							font.pixelSize: Tokens.session.label
						}
					}
				}
			}

			Text {
				objectName: "warning"
				visible: root._warning !== ""
				anchors.horizontalCenter: parent.horizontalCenter
				text: root._warning
				color: root.theme.text
				font.family: Fonts.family
				font.pixelSize: Tokens.session.note
			}
			Row {
				visible: root._warning !== ""
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: Tokens.qp.actions.gap

				QpButton {
					objectName: "confirm"
					theme: root.theme
					primary: true
					text: root._asking ? root._asking.label + " anyway" : ""
					onClicked: root._choose(root._asking)
				}
				QpButton {
					objectName: "cancel"
					theme: root.theme
					text: "Cancel"
					onClicked: root._asking = null
				}
			}
		}
	}
}
