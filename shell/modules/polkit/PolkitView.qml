import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch/qp"

// The password dialog for polkit: the launcher's card with quick-panel parts.
// The password stays in the field: it leaves through `submitted`, and the
// field empties at once, and again whenever the dialog closes. Pure:
// PolkitWindow.qml binds the agent. Nothing here logs or stores what's typed.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	// What the system says is being asked for.
	property string message: ""
	property string prompt: ""
	property bool responseVisible: false
	property string supplementary: ""
	property bool supplementaryIsError: false
	// Checking the answer.
	property bool busy: false

	signal submitted(string response)
	signal cancelled()

	readonly property bool shown: root._open || card.opacity > 0
	property bool _open: false

	function open() {
		field.text = "";
		root._open = true;
		enter.jump(0);
		field.focusField();
	}
	function close() {
		field.text = "";
		root._open = false;
	}
	onBusyChanged: if (!root.busy && root._open) field.focusField()
	function _submit() {
		if (!field.text || root.busy) return;
		const response = field.text;
		field.text = "";
		root.submitted(response);
	}
	function _cancel() {
		field.text = "";
		root.cancelled();
	}

	Spring {
		id: enter
		stiffness: Tokens.morph.stiffness
		damping: Tokens.morph.damping
		mass: Tokens.morph.mass
		initial: 0
		target: root._open ? 1 : 0
	}

	// cursor: default — the screen around it; a stray click doesn't cancel
	MouseArea { anchors.fill: parent; enabled: root._open }

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

	readonly property real _morph: Tokens.morph.from + (1 - Tokens.morph.from) * Math.max(0, Math.min(1.02, enter.value))
	Rectangle {
		id: card
		objectName: "card"
		anchors.centerIn: parent
		width: Tokens.polkit.width * root._morph
		height: (content.height + 2 * Tokens.polkit.padding) * root._morph
		clip: true
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

		Column {
			id: content
			x: Tokens.polkit.padding
			y: Tokens.polkit.padding
			width: parent.width - 2 * Tokens.polkit.padding
			spacing: Tokens.polkit.gap

			Rectangle {
				anchors.horizontalCenter: parent.horizontalCenter
				width: Tokens.polkit.icon
				height: width
				radius: width / 2
				color: root.theme.groupBg

				SvgIcon {
					anchors.centerIn: parent
					name: "lock"
					size: Tokens.polkit.iconGlyph
					color: root.theme.text
				}
			}
			Text {
				objectName: "title"
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				text: "Authentication required"
				color: root.theme.text
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Tokens.polkit.title
				font.weight: Font.DemiBold
			}
			Text {
				objectName: "message"
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				textFormat: Text.PlainText
				text: root.message
				color: root.theme.textMuted
				font.family: Fonts.family
				font.pixelSize: Tokens.polkit.message
			}
			QpInput {
				id: field
				objectName: "password"
				width: parent.width
				theme: root.theme
				enabled: !root.busy
				placeholder: root.prompt.replace(/:\s*$/, "") || "Password"
				echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
				onAccepted: root._submit()
				onEscaped: root._cancel()
			}
			Text {
				objectName: "supplementary"
				visible: root.supplementary !== ""
				width: parent.width
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.Wrap
				textFormat: Text.PlainText
				text: root.supplementary
				color: root.supplementaryIsError ? Tokens.qp.error.color : root.theme.textMuted
				font.family: Fonts.family
				font.pixelSize: Tokens.polkit.message
			}
			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: Tokens.qp.actions.gap

				QpButton {
					objectName: "cancel"
					theme: root.theme
					text: "Cancel"
					onClicked: root._cancel()
				}
				QpButton {
					objectName: "authenticate"
					theme: root.theme
					text: "Authenticate"
					primary: true
					busy: root.busy
					enabled: !root.busy && field.text !== ""
					onClicked: root._submit()
				}
			}
		}
	}
}
