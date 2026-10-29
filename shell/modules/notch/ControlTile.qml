import QtQuick
import qs.services
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
	height: 34
	radius: 10
	color: active ? root.textColor : Theme.groupBg
	border.width: 1
	border.color: active ? root.textColor : Theme.border
	opacity: available ? 1 : 0.5
	Behavior on color { ColorAnimation { duration: 180 } }
	Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10; color: active ? Qt.rgba(Theme.bgExpanded.r, Theme.bgExpanded.g, Theme.bgExpanded.b, 0.08) : Theme.groupBg
		SvgIcon { anchors.centerIn: parent; name: root.icon; color: active ? Theme.bgExpanded : root.textColor; size: 12 }
	}
	Text {
		x: 36; y: 6; width: parent.width - (root.hasMore ? 60 : 42)
		text: root.title; color: active ? Theme.bgExpanded : root.textColor; elide: Text.ElideRight
		font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold
	}
	Text {
		x: 36; y: 18; width: parent.width - (root.hasMore ? 60 : 42)
		text: root.detail; color: active ? Qt.rgba(Theme.bgExpanded.r, Theme.bgExpanded.g, Theme.bgExpanded.b, 0.55) : root.mutedColor; elide: Text.ElideRight
		font.family: "Inter"; font.pixelSize: 8
	}
	MouseArea { anchors.fill: parent; enabled: root.available; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
	PressArea {
		anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
		anchors.rightMargin: 5; width: 18; height: 18
		visible: root.hasMore; hoverScale: 1.1
		onClicked: root.moreClicked()
		SvgIcon { anchors.centerIn: parent; name: "chevron-right"; color: active ? Theme.bgExpanded : root.textColor; size: 12 }
	}
}
