import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	signal subpanelRequested(string name)
	property string selected: ""
	Component.onCompleted: Bluetooth.hold("bluetooth-panel", true)
	Component.onDestruction: Bluetooth.hold("bluetooth-panel", false)

	Item {
		x: 12; y: 4; width: parent.width - 24; height: 24
		PressArea { x: 0; width: 24; height: 24; onClicked: root.subpanelRequested("command-center"); SvgIcon { anchors.centerIn: parent; name: "chevron-left"; color: Theme.textMuted; size: 14 } }
		Text { x: 28; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth"; color: Theme.text; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold }
		Rectangle {
			id: toggle; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 17; radius: 9
			color: Bluetooth.powered ? Theme.text : Theme.groupBg
			Rectangle { x: Bluetooth.powered ? 15 : 2; y: 2; width: 13; height: 13; radius: 7; color: Bluetooth.powered ? Theme.bgExpanded : Theme.textMuted; Behavior on x { NumberAnimation { duration: 150 } } }
			MouseArea { anchors.fill: parent; enabled: Bluetooth.available; cursorShape: Qt.PointingHandCursor; onClicked: Bluetooth.setPowered(!Bluetooth.powered) }
		}
	}
	Flickable {
		x: 12; y: 34; width: parent.width - 24; height: parent.height - 44
		contentHeight: list.implicitHeight; clip: true
		Column {
			id: list; width: parent.width; spacing: 2
			Repeater {
				model: Bluetooth.powered ? Bluetooth.devices : []
				delegate: Rectangle {
					id: row
					required property var modelData
					width: list.width; height: root.selected === modelData.path ? 76 : 36; radius: 10
					color: root.selected === modelData.path ? Theme.groupBg : "transparent"
					Rectangle { x: 8; y: 6; width: 24; height: 24; radius: 12; color: modelData.connected ? Theme.text : Theme.groupBg
						SvgIcon { anchors.centerIn: parent; name: "bluetooth"; color: modelData.connected ? Theme.bgExpanded : Theme.text; size: 13 }
					}
					Text { x: 41; y: 5; width: parent.width - 90; text: modelData.name; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
					Text { x: 41; y: 21; text: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9 }
					Text { anchors.right: parent.right; anchors.rightMargin: 8; y: 12; text: modelData.batteryLabel; color: Theme.textMuted; font.pixelSize: 9 }
					MouseArea { x: 0; y: 0; width: parent.width; height: 36; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = root.selected === modelData.path ? "" : modelData.path }
					Rectangle {
						x: 41; y: 43; width: 84; height: 24; radius: 8
						visible: root.selected === modelData.path
						color: modelData.connected ? Theme.groupBg : Theme.text
						Text { anchors.centerIn: parent; text: modelData.connected ? "Disconnect" : "Connect"; color: modelData.connected ? Theme.text : Theme.bgExpanded; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold }
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bluetooth.setConnected(modelData.path, !modelData.connected) }
					}
				}
			}
			Text {
				visible: !Bluetooth.powered || Bluetooth.devices.length === 0
				width: parent.width; height: 70; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
				text: !Bluetooth.available ? "Bluetooth adapter unavailable" : !Bluetooth.powered ? "Bluetooth is off" : "No paired devices"
				color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11
			}
		}
	}
	Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; visible: Bluetooth.error !== ""; text: Bluetooth.error; color: Theme.textMuted; font.pixelSize: 9 }
}
