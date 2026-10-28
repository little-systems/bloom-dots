import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	Component.onCompleted: Network.hold("wifi-panel", true)
	Component.onDestruction: Network.hold("wifi-panel", false)
	Text { x: 2; y: 0; text: !Network.available ? "NetworkManager unavailable" : Network.wifiEnabled ? (Network.ssid || "Not connected") : "Wi-Fi is off"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11 }
	PressArea {
		anchors.right: parent.right; y: -4; width: 27; height: 24
		onClicked: Network.refresh(true)
		SvgIcon { anchors.centerIn: parent; name: "search"; color: Theme.text; size: 15 }
	}
	Flickable {
		x: 0; y: 28; width: parent.width; height: parent.height - 28
		clip: true; contentHeight: list.implicitHeight
		Column {
			id: list
			width: parent.width; spacing: 5
			Repeater {
				model: Network.networks
				delegate: Rectangle {
					required property var modelData
					width: list.width; height: 35; radius: 9
					color: modelData.active ? Theme.groupBg : "transparent"
					SvgIcon { x: 7; anchors.verticalCenter: parent.verticalCenter; name: "wifi"; color: Theme.text; size: 15 }
					Text { x: 30; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 95; elide: Text.ElideRight; text: modelData.ssid; color: Theme.text; font.family: "Inter"; font.pixelSize: 11 }
					Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.active ? "Connected" : modelData.secured ? "Secured" : modelData.signal + "%"; color: Theme.textMuted; font.pixelSize: 9 }
					MouseArea { anchors.fill: parent; enabled: !modelData.active; cursorShape: Qt.PointingHandCursor; onClicked: Network.connect(modelData.ssid) }
				}
			}
			Text { visible: Network.networks.length === 0; text: Network.available ? "No Wi-Fi networks found" : "Install or start NetworkManager"; color: Theme.textMuted; font.pixelSize: 11 }
		}
	}
	Text { anchors.bottom: parent.bottom; visible: Network.error !== ""; text: Network.error; color: Theme.textMuted; font.pixelSize: 9 }
}
