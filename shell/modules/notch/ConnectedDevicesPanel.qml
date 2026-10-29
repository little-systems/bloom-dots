import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	Component.onCompleted: Bluetooth.hold("devices-panel", true)
	Component.onDestruction: Bluetooth.hold("devices-panel", false)
	Flickable {
		anchors.fill: parent; clip: true; contentHeight: list.implicitHeight
		Column {
			id: list; width: parent.width; spacing: 5
			Repeater {
				model: Devices.audioDevices
				delegate: Rectangle {
					required property var modelData
					width: list.width; height: 36; radius: 9; color: Theme.groupBg
					SvgIcon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: modelData.kind === "input" ? "mic" : "volume-2"; color: Theme.text; size: 16 }
					Text { x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; elide: Text.ElideRight; text: modelData.name; color: Theme.text; font.family: "Inter"; font.pixelSize: 11 }
					Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.kind; color: Theme.textMuted; font.pixelSize: 10 }
				}
			}
			Repeater {
				model: Bluetooth.devices.filter(d => d.connected)
				delegate: Rectangle {
					required property var modelData
					width: list.width; height: 36; radius: 9; color: Theme.groupBg
					SvgIcon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "bluetooth"; color: Theme.text; size: 16 }
					Text { x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; elide: Text.ElideRight; text: modelData.name; color: Theme.text; font.family: "Inter"; font.pixelSize: 11 }
					Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.batteryLabel || "Connected"; color: Theme.textMuted; font.pixelSize: 10 }
				}
			}
			Text { visible: Devices.count === 0; text: "No connected devices"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11 }
		}
	}
}
