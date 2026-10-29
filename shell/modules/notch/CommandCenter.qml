import QtQuick
import qs.services
import "../../common"

Item {
	id: root
	signal subpanelRequested(string name)
	Component.onCompleted: { Network.hold("command-center", true); Bluetooth.hold("command-center", true); SessionControls.refresh(); }
	Component.onDestruction: { Network.hold("command-center", false); Bluetooth.hold("command-center", false); }

	Grid {
		id: tiles
		y: 12; width: parent.width
		columns: 2; columnSpacing: 10; rowSpacing: 10
		ControlTile {
			width: (tiles.width - 10) / 2
			title: "Wi-Fi"; icon: Network.wifiEnabled ? "wifi" : "wifi-off"
			detail: !Network.available ? "Unavailable" : !Network.wifiEnabled ? "Off" : Network.ssid || "Not connected"
			active: Network.wifiEnabled; available: Network.available; hasMore: true
			textColor: Theme.text; mutedColor: Theme.textMuted
			onClicked: Network.setWifi(!Network.wifiEnabled)
			onMoreClicked: root.subpanelRequested("wifi")
		}
		ControlTile {
			width: (tiles.width - 10) / 2
			title: "Dock Mode"; icon: "hard-drive"
			detail: Settings.values["bloom-dock-mode"]
			active: Settings.values["bloom-dock-mode"] === "fixed"
			textColor: Theme.text; mutedColor: Theme.textMuted
			onClicked: {
				const modes = ["fixed", "smart", "peek"];
				const current = Settings.values["bloom-dock-mode"];
				Settings.set("bloom-dock-mode", modes[(modes.indexOf(current) + 1) % modes.length]);
			}
		}
		ControlTile {
			width: (tiles.width - 10) / 2
			title: "Bluetooth"; icon: "bluetooth"
			detail: !Bluetooth.available ? "Unavailable" : !Bluetooth.powered ? "Off" : Bluetooth.devices.filter(d => d.connected).map(d => d.name).join(", ") || "On"
			active: Bluetooth.powered; available: Bluetooth.available; hasMore: true
			textColor: Theme.text; mutedColor: Theme.textMuted
			onClicked: Bluetooth.setPowered(!Bluetooth.powered)
			onMoreClicked: root.subpanelRequested("bluetooth")
		}
		ControlTile {
			width: (tiles.width - 10) / 2
			title: "Notch Mode"; icon: "calendar-days"
			detail: Settings.values["bloom-notch-mode"]
			active: Settings.values["bloom-notch-mode"] === "fixed"
			textColor: Theme.text; mutedColor: Theme.textMuted
			onClicked: {
				const modes = ["fixed", "smart", "peek"];
				const current = Settings.values["bloom-notch-mode"];
				Settings.set("bloom-notch-mode", modes[(modes.indexOf(current) + 1) % modes.length]);
			}
		}
	}

	Row {
		id: actions
		y: 100
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: (root.width - 8 - 6 * 32) / 5
		Repeater {
			model: [
				{ icon: "bell-off", label: "DND", active: Settings.values["bloom-notifications-dnd"] },
				{ icon: "moon", label: "Idle", active: SessionControls.idleActive },
				{ icon: "sun", label: "Night", active: SessionControls.nightActive },
				{ icon: "bell", label: "Notifications", active: false },
				{ icon: "wifi", label: "Wi-Fi", active: false },
				{ icon: "bluetooth", label: "Bluetooth", active: false }
			]
			delegate: Rectangle {
				required property var modelData
				width: 32; height: 32; radius: 16
				color: modelData.active ? Theme.text : Theme.groupBg
				border.width: 1; border.color: modelData.active ? Theme.text : Theme.border
				SvgIcon { anchors.centerIn: parent; name: modelData.icon; color: modelData.active ? Theme.bgExpanded : Theme.textMuted; size: 15 }
				MouseArea {
					anchors.fill: parent; cursorShape: Qt.PointingHandCursor
					onClicked: {
						if (modelData.label === "DND") Settings.set("bloom-notifications-dnd", !Settings.values["bloom-notifications-dnd"]);
						else if (modelData.label === "Idle") SessionControls.setIdle(!SessionControls.idleActive);
						else if (modelData.label === "Night") SessionControls.setNight(!SessionControls.nightActive);
						else if (modelData.label === "Notifications") root.subpanelRequested("notifications");
						else root.subpanelRequested(modelData.label === "Wi-Fi" ? "wifi" : "bluetooth");
					}
				}
			}
		}
	}

	Column {
		y: 142
		width: parent.width
		spacing: 8
		Repeater {
			model: ["volume", "brightness"]
			delegate: Item {
				required property string modelData
				readonly property bool volumeRow: modelData === "volume"
				readonly property real level: volumeRow ? Audio.volume : Brightness.percent / 100
				width: root.width; height: 18
				SvgIcon { x: 0; anchors.verticalCenter: parent.verticalCenter; name: volumeRow ? "volume-2" : "sun"; color: Theme.textMuted; size: 12 }
				Text { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 57; text: volumeRow ? "Volume" : "Brightness"; color: Theme.textMuted; font.pixelSize: 9; font.family: "Inter"; font.weight: Font.DemiBold }
				Rectangle {
					id: track
					x: 85; anchors.verticalCenter: parent.verticalCenter
					width: parent.width - 123; height: 6; radius: 3; color: Theme.groupBg
					Rectangle { width: parent.width * Math.max(0, Math.min(1, level)); height: parent.height; radius: parent.radius; color: Theme.text }
				}
				MouseArea {
					x: track.x; y: 0; width: track.width; height: parent.height
					enabled: volumeRow || Brightness.available; cursorShape: Qt.PointingHandCursor
					function apply(x) { const v = Math.max(0, Math.min(1, x / width)); if (volumeRow) Audio.setVolume(v); else Brightness.setPercent(v * 100); }
					onPressed: mouse => apply(mouse.x)
					onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
				}
				Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: volumeRow ? Math.round(Audio.volume * 100) + "%" : Brightness.available ? Brightness.percent + "%" : "—"; color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.DemiBold }
			}
		}
	}
}
