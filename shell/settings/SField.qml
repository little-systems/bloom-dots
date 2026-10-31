import QtQuick
import "../common/render"

// A text field in Settings' own style.
Rectangle {
	id: root
	property QtObject theme
	property alias text: input.text
	property string placeholder: ""
	property bool secret: false
	property string accessibleName: root.placeholder
	signal accepted()

	width: 240
	height: 28
	radius: 6
	color: root.theme.groupBg
	border.width: 1
	border.color: input.activeFocus ? "#0a84ff" : root.theme.border
	Accessible.role: Accessible.EditableText
	Accessible.name: root.accessibleName
	Accessible.passwordEdit: root.secret

	function focusField() { input.forceActiveFocus(); }

	TextInput {
		id: input
		objectName: "input"
		x: 10
		width: parent.width - 20
		height: parent.height
		verticalAlignment: TextInput.AlignVCenter
		activeFocusOnTab: true
		echoMode: root.secret ? TextInput.Password : TextInput.Normal
		inputMethodHints: root.secret ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
		color: root.theme.text
		clip: true
		font.family: Fonts.ui
		font.pixelSize: 12
		Keys.onReturnPressed: root.accepted()
		Text {
			visible: input.text === ""
			height: parent.height
			verticalAlignment: Text.AlignVCenter
			text: root.placeholder
			color: root.theme.textMuted
			font: input.font
		}
	}
}
