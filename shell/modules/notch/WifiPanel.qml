import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	signal subpanelRequested(string name)
	property bool pinned: false
	property string selected: ""
	Component.onCompleted: Network.hold("wifi-panel", true)
	Component.onDestruction: Network.hold("wifi-panel", false)

	Item {
		x: 12; y: 4; width: parent.width - 24; height: 24
		PressArea { x: 0; width: 24; height: 24; onClicked: root.subpanelRequested("command-center"); SvgIcon { anchors.centerIn: parent; name: "chevron-left"; color: Theme.textMuted; size: 14 } }
		Text { x: 28; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; color: Theme.text; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold }
		PressArea { anchors.right: toggle.left; anchors.rightMargin: 7; width: 24; height: 24; enabled: Network.wifiEnabled; onClicked: Network.refresh(true); SvgIcon { anchors.centerIn: parent; name: "search"; color: Theme.textMuted; size: 14 } }
		Rectangle {
			id: toggle; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 17; radius: 9
			color: Network.wifiEnabled ? Theme.text : Theme.groupBg
			Rectangle { x: Network.wifiEnabled ? 15 : 2; y: 2; width: 13; height: 13; radius: 7; color: Network.wifiEnabled ? Theme.bgExpanded : Theme.textMuted; Behavior on x { NumberAnimation { duration: 150 } } }
			MouseArea { anchors.fill: parent; enabled: Network.available; cursorShape: Qt.PointingHandCursor; onClicked: Network.setWifi(!Network.wifiEnabled) }
		}
	}
	Flickable {
		x: 12; y: 34; width: parent.width - 24; height: parent.height - 44
		contentHeight: list.implicitHeight; clip: true
		Column {
			id: list; width: parent.width; spacing: 2
			Repeater {
				model: Network.wifiEnabled ? Network.networks : []
				delegate: Rectangle {
					id: row
					required property var modelData
					width: list.width; height: root.selected === modelData.ssid ? (modelData.secured && !modelData.active ? 112 : 76) : 36; radius: 10
					color: root.selected === modelData.ssid ? Theme.groupBg : "transparent"
					Rectangle { x: 8; y: 6; width: 24; height: 24; radius: 12; color: modelData.active ? Theme.text : Theme.groupBg
						SvgIcon { anchors.centerIn: parent; name: "wifi"; color: modelData.active ? Theme.bgExpanded : Theme.text; size: 13 }
					}
					Text { x: 41; y: 5; width: parent.width - 68; text: modelData.ssid; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
					Text { x: 41; y: 21; text: modelData.active ? "Connected" : modelData.secured ? "Secured" : "Open"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9 }
					SvgIcon { anchors.right: parent.right; anchors.rightMargin: 8; y: 12; visible: modelData.secured; name: "lock-keyhole"; color: Theme.textMuted; size: 11 }
					MouseArea { x: 0; y: 0; width: parent.width; height: 36; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = root.selected === modelData.ssid ? "" : modelData.ssid }
					Rectangle {
						x: 41; y: 43; width: parent.width - 50; height: 26; radius: 8
						visible: root.selected === modelData.ssid && modelData.secured && !modelData.active
						color: Theme.groupBg; border.width: 1; border.color: Theme.border
						TextInput {
							id: passwordField; anchors.fill: parent; onActiveFocusChanged: root.pinned = activeFocus; anchors.leftMargin: 9; anchors.rightMargin: 9
							verticalAlignment: TextInput.AlignVCenter; echoMode: TextInput.Password
							color: Theme.text; font.family: "Inter"; font.pixelSize: 10
							onAccepted: { if (Network.connect(modelData.ssid, text) === "ok") text = ""; }
						}
						Text { x: 9; anchors.verticalCenter: parent.verticalCenter; visible: !passwordField.text && !passwordField.activeFocus; text: "Password (if needed)"; color: Theme.textMuted; font.pixelSize: 10 }
					}
					Rectangle {
						x: 41; y: modelData.secured && !modelData.active ? 78 : 43; width: 80; height: 24; radius: 8
						visible: root.selected === modelData.ssid
						color: modelData.active ? Theme.groupBg : Theme.text
						Text { anchors.centerIn: parent; text: modelData.active ? "Disconnect" : "Connect"; color: modelData.active ? Theme.text : Theme.bgExpanded; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold }
						MouseArea {
							anchors.fill: parent; cursorShape: Qt.PointingHandCursor
							onClicked: {
								if (modelData.active) Network.disconnect(modelData.ssid);
								else if (Network.connect(modelData.ssid, passwordField.text) === "ok") passwordField.text = "";
							}
						}
					}
				}
			}
			Text {
				visible: !Network.wifiEnabled || Network.networks.length === 0
				width: parent.width; height: 65; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
				text: !Network.available ? "NetworkManager unavailable" : !Network.wifiEnabled ? "Wi-Fi is off" : "No networks found"
				color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11
			}
		}
	}
	Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; visible: Network.error !== ""; text: Network.error; color: Theme.textMuted; font.pixelSize: 9 }
}
