import QtQuick
import "../../common"
import "../../common/render"
import "../notch"

Rectangle {
	id: root
	required property var action
	required property int actionIndex
	required property QtObject theme
	property bool selected: false
	signal chosen()
	signal pointed()

	readonly property string detail: ({
		lock: "Keep apps open",
		suspend: "Quick resume",
		hibernate: "Save to disk",
		logout: "Close your session",
		reboot: "Start fresh",
		shutdown: "Turn off the PC"
	})[action.id] ?? ""

	objectName: "action:" + action.id
	width: Math.floor((parent.width - 16) / 3)
	height: Math.max(94, Fonts.px(14) * 1.4 + Fonts.px(11) * 1.4 + 52)
	radius: 13
	color: selected || hover.hovered ? theme.groupBg : Qt.rgba(1, 1, 1, 0.035)
	border.width: 1
	border.color: selected ? theme.textMuted : theme.border
	Behavior on color { ColorAnimation { duration: 150 } }
	Behavior on border.color { ColorAnimation { duration: 150 } }
	Accessible.role: Accessible.Button
	Accessible.name: action.label + ", " + detail

	SvgIcon {
		x: 13; y: 12; size: 20
		name: root.action.icon
		color: root.action.id === "shutdown" ? "#ff453a" : root.theme.text
	}
	Column {
		x: 13; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
		width: parent.width - 26; spacing: 2
		Text { objectName: "label"; text: root.action.label; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(14); font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
		Text { text: root.detail; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(11); elide: Text.ElideRight; width: parent.width }
	}
	HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.pointed() }
	TapHandler { onTapped: root.chosen() }
}
