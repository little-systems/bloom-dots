import QtQuick
import "../../common"

Rectangle {
	id: root
	property string title: ""
	property string detail: ""
	property string icon: ""
	property bool active: false
	property bool available: true
	property bool hasMore: false
	property color textColor: "white"
	property color mutedColor: Qt.rgba(1, 1, 1, 0.6)
	signal clicked()
	signal moreClicked()
	height: 46
	radius: 12
	color: active ? Qt.rgba(0, 0.48, 1, 0.28) : Qt.rgba(textColor.r, textColor.g, textColor.b, 0.06)
	opacity: available ? 1 : 0.5
	Behavior on color { ColorAnimation { duration: 180 } }
	SvgIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: root.icon; color: root.textColor; size: 18 }
	Text {
		x: 37; y: 7; width: parent.width - (root.hasMore ? 64 : 45)
		text: root.title; color: root.textColor; elide: Text.ElideRight
		font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold
	}
	Text {
		x: 37; y: 24; width: parent.width - (root.hasMore ? 64 : 45)
		text: root.detail; color: root.mutedColor; elide: Text.ElideRight
		font.family: "Inter"; font.pixelSize: 9
	}
	MouseArea { anchors.fill: parent; enabled: root.available; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
	PressArea {
		anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
		anchors.rightMargin: 5; width: 25; height: 30
		visible: root.hasMore; hoverScale: 1.1
		onClicked: root.moreClicked()
		SvgIcon { anchors.centerIn: parent; name: "chevron-right"; color: root.textColor; size: 14 }
	}
}
