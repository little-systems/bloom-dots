import QtQuick
import "../../../common/tokens.js" as Tokens
import "../../../common/render"

// .qp-input: a password or PIN field. Focusing the input focuses its field.
FocusScope {
	id: root

	property QtObject theme: QpTheme {}
	property alias text: field.text
	property alias echoMode: field.echoMode
	property string placeholder: ""
	readonly property bool focused: field.activeFocus

	signal accepted()
	signal escaped()

	function focusField() {
		field.forceActiveFocus();
	}

	height: Tokens.qp.input.height

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.qp.input.radius
		border.width: 1
		// .qp-input:focus has no transition.
		border.color: field.activeFocus ? root.theme.textMuted : root.theme.border
		color: root.theme.groupBg
	}

	Text {
		objectName: "placeholder"
		visible: field.text === ""
		anchors.fill: field
		verticalAlignment: Text.AlignVCenter
		text: root.placeholder
		color: root.theme.textMuted
		elide: Text.ElideRight
		font: field.font
	}

	TextInput {
		id: field
		objectName: "field"
		focus: true
		anchors.fill: parent
		anchors.leftMargin: Tokens.qp.input.padH
		anchors.rightMargin: Tokens.qp.input.padH
		verticalAlignment: TextInput.AlignVCenter
		clip: true
		selectByMouse: true
		color: root.theme.text
		selectionColor: root.theme.textMuted
		font.family: Fonts.family
		font.pixelSize: Tokens.qp.text
		onAccepted: root.accepted()
		Keys.onEscapePressed: root.escaped()
	}

	HoverHandler {
		objectName: "pointer"
		cursorShape: Qt.IBeamCursor
	}
}
