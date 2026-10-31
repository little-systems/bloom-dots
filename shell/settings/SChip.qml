import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's .folder-chip.
Rectangle {
	id: root
	activeFocusOnTab: true
	Accessible.role: Accessible.CheckBox
	Accessible.name: root.text
	Accessible.checked: root.active
	Keys.onSpacePressed: root.clicked()
	Keys.onReturnPressed: root.clicked()
	SFocusRing {}
	property QtObject theme
	property color accent: "#007aff"
	property string text: ""
	property string icon: ""
	property bool active: false
	signal clicked()

	width: row.implicitWidth + 28
	height: Tokens.settings.control
	radius: Tokens.settings.controlRadius
	border.width: 1
	border.color: root.active ? "transparent" : root.theme.border
	color: root.active ? root.accent : hover.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 5
		SvgIcon {
			visible: root.icon !== ""
			name: root.icon || "plus"
			size: 13
			color: root.theme.text
			anchors.verticalCenter: parent.verticalCenter
		}
		Text {
			id: chipText
			text: root.text
			textFormat: Text.PlainText
			color: root.active ? "white" : root.theme.text
			font.family: Fonts.ui
			font.pixelSize: Tokens.settings.controlText
		}
	}
	HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
	TapHandler { onTapped: root.clicked() }
}
