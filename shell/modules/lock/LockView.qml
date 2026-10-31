import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens

// The lock screen over its backdrop: the clock, then three islands along the
// bottom. In the middle the password, to its left who and which keyboard, to
// its right the battery and power. Bloom's surfaces, type and springs. Pure:
// LockSurface.qml drives it, and every screen shares its text.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property string user: ""
	property string layout: ""
	property date time: new Date()
	property bool clockTurning: true
	property string text: ""
	property bool busy: false
	property bool responseVisible: false
	property bool capsLock: false
	property string message: ""
	property bool messageIsError: false
	property bool batteryAvailable: false
	property int batteryLevel: 0
	property bool batteryCharging: false
	property bool batteryLow: false

	signal textEdited(string text)
	signal submitted(string response)
	signal suspendRequested()
	signal shutdownRequested()
	signal rebootRequested()

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
	onTextChanged: if (field.text !== root.text) field.text = root.text

	// cursor: default — any click or movement puts the keyboard back on the field
	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onPressed: root.focusField()
		onPositionChanged: root.focusField()
	}

	LockClock {
		objectName: "clock"
		x: (root.width - width) / 2
		y: root.height * Tokens.lock.clock.top
		theme: root.theme
		accent: root.accent
		time: root.time
		turning: root.clockTurning
	}

	Spring {
		id: enter
		stiffness: Tokens.lock.island.enter.stiffness
		damping: Tokens.lock.island.enter.damping
		mass: Tokens.lock.island.enter.mass
		initial: 0
		target: 1
	}

	component Island: Rectangle {
		height: Tokens.lock.island.height
		radius: Tokens.lock.island.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		opacity: Math.min(1, Math.max(0, enter.value))
		scale: Tokens.lock.island.enter.scale + (1 - Tokens.lock.island.enter.scale) * enter.value
	}
	component Label: Text {
		color: root.theme.textMuted
		font.family: Fonts.family
		font.pixelSize: Tokens.lock.island.text
		anchors.verticalCenter: parent.verticalCenter
	}
	component Glyph: SvgIcon {
		size: Tokens.lock.island.icon
		color: root.theme.textMuted
		anchors.verticalCenter: parent.verticalCenter
	}
	component Button: Rectangle {
		id: button
		required property string icon
		signal clicked()
		width: Tokens.lock.island.button
		height: width
		radius: width / 2
		color: hover.hovered ? root.theme.groupBg : "transparent"
		anchors.verticalCenter: parent.verticalCenter

		SvgIcon {
			anchors.centerIn: parent
			name: button.icon
			size: Tokens.lock.island.icon
			color: root.theme.text
		}
		HoverHandler {
			id: hover
			cursorShape: Qt.PointingHandCursor
		}
		TapHandler { onTapped: button.clicked() }
	}

	Text {
		objectName: "caps"
		visible: root.capsLock
		x: (root.width - width) / 2
		y: main.y - height - Tokens.lock.island.gap
		text: "Caps Lock is on"
		color: root.theme.text
		font.family: Fonts.family
		font.pixelSize: Tokens.lock.message
	}

	Island {
		id: main
		objectName: "fieldBox"
		x: (root.width - width) / 2 + root._shake
		y: root.height - height - Tokens.lock.island.bottom
		width: Tokens.lock.island.field + Tokens.lock.island.button + 3 * Tokens.lock.island.gap / 2
		border.color: root.messageIsError ? "#ff8a80" : root.theme.border

		TextInput {
			id: field
			objectName: "field"
			x: Tokens.lock.island.paddingH + 4
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.lock.island.field - Tokens.lock.island.paddingH
			readOnly: root.busy
			opacity: root.busy ? 0.5 : 1
			echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
			passwordCharacter: "•"
			inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
			color: root.theme.text
			selectionColor: root.accent
			clip: true
			font.family: Fonts.family
			font.pixelSize: Tokens.lock.island.fieldSize
			onTextChanged: if (text !== root.text) root.textEdited(text)
			Keys.onReturnPressed: root._submit()
			Keys.onEnterPressed: root._submit()
			Keys.onEscapePressed: field.text = ""

			Text {
				objectName: "message"
				visible: field.text === ""
				width: parent.width
				anchors.verticalCenter: parent.verticalCenter
				text: root.message || "Enter password"
				textFormat: Text.PlainText
				elide: Text.ElideRight
				color: root.messageIsError ? "#ff8a80" : root.theme.textMuted
				font: field.font
			}
		}

		Rectangle {
			objectName: "confirm"
			x: parent.width - width - (parent.height - height) / 2
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.lock.island.button
			height: width
			radius: width / 2
			color: root.accent
			opacity: root.busy ? 0.5 : 1

			SvgIcon {
				anchors.centerIn: parent
				name: "arrow-right"
				size: Tokens.lock.island.icon
				color: "white"
			}
			HoverHandler { cursorShape: Qt.PointingHandCursor }
			TapHandler { onTapped: root._submit() }
		}
	}

	Island {
		objectName: "leftIsland"
		x: main.x - width - Tokens.lock.island.gap
		y: main.y
		width: leftRow.width + 2 * Tokens.lock.island.paddingH

		Row {
			id: leftRow
			x: Tokens.lock.island.paddingH
			height: parent.height
			spacing: Tokens.lock.island.itemGap

			Glyph { name: "user" }
			Label {
				objectName: "user"
				text: root.user
				textFormat: Text.PlainText
			}
			Item { visible: root.layout !== ""; width: Tokens.lock.island.itemGap; height: 1 }
			Glyph { name: "keyboard"; visible: root.layout !== "" }
			Label {
				objectName: "layout"
				visible: root.layout !== ""
				text: root.layout
			}
		}
	}

	Island {
		objectName: "rightIsland"
		x: main.x + main.width + Tokens.lock.island.gap
		y: main.y
		width: rightRow.width + Tokens.lock.island.paddingH + (Tokens.lock.island.height - Tokens.lock.island.button) / 2

		Row {
			id: rightRow
			x: Tokens.lock.island.paddingH
			height: parent.height
			spacing: Tokens.lock.island.itemGap / 2

			Glyph {
				visible: root.batteryAvailable
				name: root.batteryCharging ? "zap" : "battery-full"
				color: root.batteryLow && !root.batteryCharging ? "#ff8a80" : root.theme.textMuted
			}
			Label {
				objectName: "battery"
				visible: root.batteryAvailable
				text: root.batteryLevel
				color: root.batteryLow && !root.batteryCharging ? "#ff8a80" : root.theme.textMuted
			}
			Item { visible: root.batteryAvailable; width: Tokens.lock.island.itemGap / 2; height: 1 }
			Button { objectName: "suspend"; icon: "moon"; onClicked: root.suspendRequested() }
			Button { objectName: "shutdown"; icon: "power"; onClicked: root.shutdownRequested() }
			Button { objectName: "reboot"; icon: "rotate-ccw"; onClicked: root.rebootRequested() }
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
