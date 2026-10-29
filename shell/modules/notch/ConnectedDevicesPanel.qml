import QtQuick
import qs.services
import "../../common"
import "device-art.js" as DeviceArtLogic

// Linux device sources differ, but the battery hub keeps Bloom's grouped
// header, quiet rows and percentage meter where a device reports one.
Item {
	id: root
	Component.onCompleted: Bluetooth.hold("devices-panel", true)
	Component.onDestruction: Bluetooth.hold("devices-panel", false)
	Row {
		x: 0; y: 4; spacing: 7; height: 24
		Rectangle { width: 22; height: 22; radius: 11; color: Theme.groupBg
			SvgIcon { anchors.centerIn: parent; name: "monitor-smartphone"; color: Theme.text; size: 13 }
		}
		Text { anchors.verticalCenter: parent.verticalCenter; text: "Connected devices"; color: Theme.text; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold }
	}
	Flickable {
		x: 0; y: 34; width: parent.width; height: parent.height - 39
		contentHeight: groups.implicitHeight; clip: true
		Column {
			id: groups; width: parent.width; spacing: 7
			Item {
				visible: Battery.available && Battery.ready
				width: parent.width; height: visible ? 60 : 0
				Text { x: 8; text: "THIS PC"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold }
				Row {
					y: 17; width: parent.width; spacing: 9
					SvgIcon { width: 30; height: 30; name: "laptop"; color: Theme.text; size: 18 }
					Column { width: 195; spacing: 2
						Text { text: "This PC"; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
						Text { text: Battery.charging ? "Charging" : Battery.pluggedIn ? "Plugged in" : "On battery"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9 }
					}
					Column { width: 40; spacing: 3
						Text { anchors.right: parent.right; text: Battery.level + "%"; color: Battery.level <= Battery.threshold ? "#ff453a" : Theme.text; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold }
						Rectangle { width: 40; height: 3; radius: 2; color: Theme.groupBg
							Rectangle { width: parent.width * Math.max(0, Math.min(1, Battery.level / 100)); height: parent.height; radius: 2; color: Battery.level <= Battery.threshold ? "#ff453a" : "#5bd78d" }
						}
					}
				}
			}
			Item {
				visible: Bluetooth.devices.some(d => d.connected)
				width: parent.width; height: visible ? 18 + btRows.implicitHeight : 0
				Text { x: 8; text: "BLUETOOTH"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold }
				Column { id: btRows; y: 17; width: parent.width; spacing: 2
					Repeater { model: Bluetooth.devices.filter(d => d.connected)
						delegate: Row { required property var modelData; width: btRows.width; height: 39; spacing: 9
							DeviceArt { width: 30; height: 30; still: true; art: DeviceArtLogic.artFor(modelData.name, "bluetooth") }
							Column { width: 195; spacing: 2
								Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
								Text { text: "Connected"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9 }
							}
							Text { text: modelData.batteryLabel; color: Theme.text; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold }
						}
					}
				}
			}
			Item {
				visible: Devices.audioDevices.length > 0
				width: parent.width; height: visible ? 18 + audioRows.implicitHeight : 0
				Text { x: 8; text: "AUDIO"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold }
				Column { id: audioRows; y: 17; width: parent.width; spacing: 2
					Repeater { model: Devices.audioDevices
						delegate: Row { required property var modelData; width: audioRows.width; height: 39; spacing: 9
							DeviceArt { width: 30; height: 30; still: true; art: modelData.kind === "input" ? "microphone" : DeviceArtLogic.artFor(modelData.name, "audio") }
							Column { width: 195; spacing: 2
								Text { width: parent.width; text: modelData.name; elide: Text.ElideRight; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
								Text { text: modelData.kind === "input" ? "Input" : "Output"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 9 }
							}
						}
					}
				}
			}
			Text {
				visible: Devices.count === 0
				width: parent.width; height: 65; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
				text: "No devices connected"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 11
			}
		}
	}
}
