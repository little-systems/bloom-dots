import QtQuick
import QtTest
import "../../shell/services/devices.js" as Devices

TestCase {
	name: "DeviceRules"
	function test_audioAndPrivacy() {
		const nodes = [
			{ id: 1, isStream: false, description: "Headphones", properties: { "media.class": "Audio/Sink" } },
			{ id: 2, isStream: true, properties: { "media.class": "Stream/Input/Audio" } },
			{ id: 3, isStream: true, properties: { "media.class": "Stream/Input/Video", "node.name": "xdg-desktop-portal screencast" } }
		];
		compare(Devices.audioDevices(nodes).length, 1);
		compare(Devices.privacy(nodes).microphone, true);
		compare(Devices.privacy(nodes).screen, true);
		compare(Devices.privacy(nodes.slice(0, 1)).microphone, false);
	}
	function test_udevFiltering() {
		compare(Devices.udevEvent(["ACTION=add", "DEVTYPE=usb_device", "ID_MODEL=USB_Camera"]).detail, "USB Camera");
		compare(Devices.udevEvent(["ACTION=remove", "DEVTYPE=usb_device"]), null);
		compare(Devices.udevEvent(["ACTION=add", "DEVTYPE=usb_interface"]), null);
	}
	function test_headphoneJackChanges() {
		const before = Devices.headphonePorts("Sink #53\n  Active Port: analog-output-speaker\n");
		const after = Devices.headphonePorts("Sink #53\n  Active Port: analog-output-headphones\n");
		compare(Devices.jackChange(before, after), "connected");
		compare(Devices.jackChange(after, before), "disconnected");
		compare(Devices.jackChange(null, after), "");
	}
}
