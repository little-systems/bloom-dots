import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	Component.onCompleted: Bluetooth.hold("bluetooth-panel", true)
	Component.onDestruction: Bluetooth.hold("bluetooth-panel", false)
	Text { x: 2; y: 0; text: !Bluetooth.available ? "Bluetooth adapter unavailable" : Bluetooth.powered ? "Bluetooth is on" : "Bluetooth is off"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11 }
	PressArea {
		anchors.right: parent.right; y: -4; width: 45; height: 24
		onClicked: Bluetooth.setPowered(!Bluetooth.powered)
		Text { anchors.centerIn: parent; text: Bluetooth.powered ? "Turn off" : "Turn on"; color: Theme.text; font.pixelSize: 9 }
	}
	Flickable {
		x: 0; y: 28; width: parent.width; height: parent.height - 28
		clip: true; contentHeight: list.implicitHeight
		Column {
			id: list
			width: parent.width; spacing: 5
			Repeater {
				model: Bluetooth.devices
				delegate: Rectangle {
					required property var modelData
					width: list.width; height: 39; radius: 9
					color: modelData.connected ? Theme.groupBg : "transparent"
					SvgIcon { x: 7; anchors.verticalCenter: parent.verticalCenter; name: "bluetooth"; color: Theme.text; size: 16 }
					Text { x: 32; y: 4; width: parent.width - 80; elide: Text.ElideRight; text: modelData.name; color: Theme.text; font.family: "Inter"; font.pixelSize: 11 }
					Text { x: 32; y: 22; text: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available"; color: Theme.textMuted; font.pixelSize: 9 }
					Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.batteryLabel; color: Theme.textMuted; font.pixelSize: 9 }
					MouseArea { anchors.fill: parent; enabled: Bluetooth.powered; cursorShape: Qt.PointingHandCursor; onClicked: Bluetooth.setConnected(modelData.path, !modelData.connected) }
				}
			}
			Text { visible: Bluetooth.devices.length === 0; text: Bluetooth.available ? "No paired devices" : "Start BlueZ to use Bluetooth"; color: Theme.textMuted; font.pixelSize: 11 }
		}
	}
	Text { anchors.bottom: parent.bottom; visible: Bluetooth.error !== ""; text: Bluetooth.error; color: Theme.textMuted; font.pixelSize: 9 }
}
