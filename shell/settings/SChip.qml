import QtQuick
import "../common"
import "../common/render"

// Bloom's .folder-chip.
Rectangle {
	id: root
	property QtObject theme
	property color accent: "#007aff"
	property string text: ""
	property string icon: ""
	property bool active: false
	signal clicked()

	width: row.implicitWidth + 26
	height: chipText.implicitHeight + 10
	radius: height / 2
	border.width: 1
	border.color: root.active ? root.accent : root.theme.border
	color: root.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : hover.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

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
			color: root.theme.text
			font.family: Fonts.ui
			font.pixelSize: 12
		}
	}
	HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
	TapHandler { onTapped: root.clicked() }
}
