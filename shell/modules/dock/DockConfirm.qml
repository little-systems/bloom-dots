import QtQuick
import "../../common/render"

Item {
	id: root
	property bool opened: false
	property color background: Qt.rgba(0.1, 0.1, 0.12, 0.96)
	property color foreground: "white"
	readonly property Item boxItem: box
	signal confirmed()
	width: 260; height: 130
	visible: opened

	Rectangle {
		id: box
		anchors.fill: parent
		radius: 12
		color: root.background
		border.width: 1
		border.color: Qt.rgba(1, 1, 1, 0.1)
		Text {
			font.family: Fonts.familyFor(Font.Bold)
			x: 16; y: 16
			text: "Empty Trash?"
			color: root.foreground
			font.pixelSize: 16
			font.bold: true
		}
		Text {
			font.family: Fonts.family
			x: 16; y: 44
			text: "This permanently removes the items."
			color: root.foreground
			opacity: 0.7
			font.pixelSize: 11
		}
		Rectangle {
			id: cancel
			objectName: "confirm-cancel"
			x: 16; y: 80; width: 105; height: 34; radius: 7
			color: Qt.rgba(1, 1, 1, 0.12)
			Text { font.family: Fonts.family; anchors.centerIn: parent; text: "Cancel"; color: root.foreground; font.pixelSize: 12 }
			MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.opened = false }
		}
		Rectangle {
			id: empty
			objectName: "confirm-empty"
			x: 139; y: 80; width: 105; height: 34; radius: 7
			color: "#d94343"
			Text { font.family: Fonts.family; anchors.centerIn: parent; text: "Empty Trash"; color: "white"; font.pixelSize: 12 }
			MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.opened = false; root.confirmed(); } }
		}
	}
}
