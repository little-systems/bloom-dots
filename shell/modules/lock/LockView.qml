import QtQuick
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "lock.js" as Lock

// The lock screen. Bloom has none, so this is its language: Bloom Inter, the
// launcher's field, the panels' error colour. Pure: LockSurface.qml drives it.
// The background is opaque on purpose: session_lock_xray shows anything behind
// a translucent surface.
Item {
	id: root

	property QtObject theme: QtObject {
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property string user: ""
	property date time: new Date()
	property bool clock24: true
	property bool busy: false
	property bool responseVisible: false
	property bool capsLock: false
	property string message: ""
	property bool messageIsError: false

	signal submitted(string response)

	property real _shake: 0

	function focusField() {
		field.forceActiveFocus();
	}
	function shake() {
		shakeAnimation.restart();
	}
	function _submit() {
		if (root.busy || field.text === "") return;
		const response = field.text;
		field.text = "";
		root.submitted(response);
	}

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		color: "black"
	}

	// cursor: default — a click anywhere puts the keyboard back on the field
	MouseArea {
		anchors.fill: parent
		onClicked: root.focusField()
	}

	Column {
		x: (root.width - width) / 2
		y: root.height * Tokens.lock.top
		width: Tokens.lock.field.width * 2
		spacing: Tokens.lock.gap

		Text {
			objectName: "clock"
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: Lock.clock(root.time, root.clock24)
			color: root.theme.text
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Tokens.lock.clock
			font.weight: Font.DemiBold
		}
		Text {
			objectName: "date"
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: Lock.date(root.time)
			color: root.theme.textMuted
			font.family: Fonts.familyFor(Font.Medium)
			font.pixelSize: Tokens.lock.date
			font.weight: Font.Medium
		}
		Item {
			width: 1
			height: Tokens.lock.gap * 2
		}
		Text {
			objectName: "user"
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: root.user
			textFormat: Text.PlainText
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.lock.user
		}
		Item {
			width: parent.width
			height: Tokens.lock.field.height

			Rectangle {
				id: fieldBox
				objectName: "fieldBox"
				x: (parent.width - width) / 2 + root._shake
				width: Tokens.lock.field.width
				height: Tokens.lock.field.height
				radius: Tokens.lock.field.radius
				color: root.theme.groupBg
				border.width: 1
				border.color: root.messageIsError ? "#ff8a80" : "transparent"

				TextInput {
					id: field
					objectName: "field"
					x: Tokens.lock.field.paddingH
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width - 2 * Tokens.lock.field.paddingH
					readOnly: root.busy
					opacity: root.busy ? 0.5 : 1
					echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
					passwordCharacter: "•"
					inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
					horizontalAlignment: TextInput.AlignHCenter
					color: root.theme.text
					selectionColor: root.accent
					clip: true
					font.family: Fonts.family
					font.pixelSize: Tokens.lock.field.size
					Keys.onReturnPressed: root._submit()
					Keys.onEnterPressed: root._submit()
					Keys.onEscapePressed: field.text = ""
				}
			}
		}
		Text {
			objectName: "message"
			visible: text !== ""
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: root.message
			textFormat: Text.PlainText
			color: root.messageIsError ? "#ff8a80" : root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.lock.message
		}
		Text {
			objectName: "caps"
			visible: root.capsLock
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			text: "Caps Lock is on"
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.lock.message
		}
	}

	SequentialAnimation {
		id: shakeAnimation
		NumberAnimation { target: root; property: "_shake"; to: Tokens.lock.shake.steps[0]; duration: Tokens.lock.shake.ms }
		NumberAnimation { target: root; property: "_shake"; to: Tokens.lock.shake.steps[1]; duration: Tokens.lock.shake.ms }
		NumberAnimation { target: root; property: "_shake"; to: Tokens.lock.shake.steps[2]; duration: Tokens.lock.shake.ms }
		NumberAnimation { target: root; property: "_shake"; to: Tokens.lock.shake.steps[3]; duration: Tokens.lock.shake.ms }
	}
}
