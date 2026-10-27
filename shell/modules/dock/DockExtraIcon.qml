import QtQuick
import "../../common/tokens.js" as Tokens

Item {
	id: root
	property string name: ""
	property string iconSource: ""
	property string kind: ""
	property int count: 0
	property bool present: true
	property bool iconOnly: false
	property bool light: false
	property color textColor: "white"
	property color tooltipBg: "black"
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"
	signal clicked()
	readonly property bool hovered: icon.hovered
	implicitWidth: Tokens.dock.extras.tile
	implicitHeight: Tokens.dock.extras.tile

	DockIcon {
		id: icon
		anchors.fill: parent
		name: root.name
		iconSource: root.iconSource
		present: root.present
		iconOnly: root.iconOnly
		light: root.light
		textColor: root.textColor
		tooltipBg: root.tooltipBg
		tooltipText: root.tooltipText
		tooltipBorder: root.tooltipBorder
		onClicked: root.clicked()
	}
	Rectangle {
		visible: root.kind === "trash" && root.count > 0
		anchors.right: parent.right
		anchors.top: parent.top
		width: 14; height: 14; radius: 7
		color: "#e05050"
		Text { anchors.centerIn: parent; text: root.count > 9 ? "9+" : String(root.count); color: "white"; font.pixelSize: 9 }
	}
}
