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

	// Bloom's battery hub (connectedDevices.ts groupDevices).
	function entry(id, kind, level, extra) {
		return Object.assign({ id: id, name: id, kind: kind, wired: false, art: null, level: level, charging: false, buds: null }, extra || {});
	}
	function test_groupsInBloomsOrder() {
		const groups = Devices.groupDevices([
			entry("mouse", "mouse", 50),
			entry("pc", "pc", 80),
			entry("buds", "audio", 60),
			entry("phone", "phone", 90),
			entry("keyboard", "keyboard", 10),
			entry("thing", "other", null)
		], 20);
		compare(groups.map(g => g.key), ["low", "pc", "audio", "phone", "accessories", "other"]);
		compare(groups.map(g => g.title), ["Needs charging", "This PC", "Audio", "Phone & watch", "Accessories", "Other"]);
		compare(groups[0].entries[0].id, "keyboard");
	}
	function test_chargingIsNeverLow() {
		const groups = Devices.groupDevices([entry("pc", "pc", 5, { charging: true })], 20);
		compare(groups[0].key, "pc");
	}
	function test_lowestBudDecides() {
		const buds = { left: { level: 90, charging: false }, right: { level: 12, charging: false }, case: null };
		const groups = Devices.groupDevices([entry("buds", "audio", null, { buds: buds })], 20);
		compare(groups[0].key, "low");
	}
	function test_sortsByLevelThenName() {
		const groups = Devices.groupDevices([entry("b", "mouse", 70), entry("a", "keyboard", 70), entry("c", "mouse", 30), entry("d", "mouse", null)], 20);
		compare(groups[0].entries.map(e => e.id), ["c", "a", "b", "d"]);
	}
	function test_pcStatus() {
		compare(Devices.pcStatus({ charging: true, secondsToFull: 4800 }), "Charging · 1 h 20 min to full");
		compare(Devices.pcStatus({ charging: true, secondsToFull: 0 }), "Charging");
		compare(Devices.pcStatus({ charging: false, pluggedIn: true }), "Plugged in");
		compare(Devices.pcStatus({ charging: false, pluggedIn: false, secondsLeft: 2700 }), "45 min left");
		compare(Devices.pcStatus({ charging: false, pluggedIn: false, secondsLeft: 7200 }), "2 h left");
		compare(Devices.pcStatus({ charging: false, pluggedIn: false, secondsLeft: 0 }), "On battery");
	}
	function test_bluetoothKinds() {
		compare(Devices.bluetoothKind("audio-headset"), "audio");
		compare(Devices.bluetoothKind("audio-card"), "audio");
		compare(Devices.bluetoothKind("input-mouse"), "mouse");
		compare(Devices.bluetoothKind("input-keyboard"), "keyboard");
		compare(Devices.bluetoothKind("input-gaming"), "gamepad");
		compare(Devices.bluetoothKind("phone"), "phone");
		compare(Devices.bluetoothKind(""), "other");
	}
	function test_wiredAudioSkipsTheBuiltInCard() {
		const nodes = [
			{ id: 1, isStream: false, description: "Built-in Audio Analog Stereo", name: "alsa_output.pci-0000_00_1f.3.analog-stereo", properties: { "media.class": "Audio/Sink" } },
			{ id: 2, isStream: false, description: "USB Headset", name: "alsa_output.usb-Logi_Headset-00.analog-stereo", properties: { "media.class": "Audio/Sink" } },
			{ id: 3, isStream: false, description: "USB Headset", name: "alsa_input.usb-Logi_Headset-00.mono-fallback", properties: { "media.class": "Audio/Source" } },
			{ id: 4, isStream: false, description: "AirPods", name: "bluez_output.AA_BB", properties: { "media.class": "Audio/Sink" } }
		];
		const wired = Devices.wiredAudio(nodes, false);
		compare(wired.length, 1, "one USB headset, no built-in card, no Bluetooth");
		compare(wired[0].name, "USB Headset");
		compare(wired[0].wired, true);
		const withJack = Devices.wiredAudio(nodes, true);
		compare(withJack.map(d => d.id), ["jack", "usb:USB Headset"]);
		compare(Devices.wiredSub(withJack[0]), "Headphone jack");
		compare(Devices.wiredSub(withJack[1]), "USB");
	}
	function test_entriesFromSources() {
		const entries = Devices.entries(
			{ present: true, level: 73, charging: true },
			[{ path: "/a", name: "AirPods Pro", connected: true, kind: "audio", battery: null, buds: { left: 80, right: 70 } },
			 { path: "/b", name: "Mouse", connected: false, kind: "mouse", battery: 50, buds: {} }],
			[], { "AirPods Pro": "stem-buds" });
		compare(entries.map(e => e.id), ["pc", "/a"]);
		compare(entries[0].name, "This PC");
		compare(entries[1].art, "stem-buds");
		compare(entries[1].buds.left, { level: 80, charging: false });
		compare(entries[1].buds.case, null);
	}

	// Bloom alerts for Bluetooth, USB devices and the jack, never for the
	// built-in sound card or a display's HDMI/DisplayPort audio.
	function test_audioAlertsOnlyForUsbAudio() {
		const builtIn = { id: 1, isStream: false, description: "Built-in Audio Analog Stereo", name: "alsa_output.pci-0000_00_1f.3.analog-stereo", properties: { "media.class": "Audio/Sink" } };
		const hdmi = { id: 2, isStream: false, description: "HDMI / DisplayPort 1 Output", name: "alsa_output.pci-0000_00_1f.3.hdmi-stereo", properties: { "media.class": "Audio/Sink" } };
		const usb = { id: 3, isStream: false, description: "USB Headset", name: "alsa_output.usb-Logi_Headset-00.analog-stereo", properties: { "media.class": "Audio/Sink" } };
		compare(Devices.audioAlert([], [builtIn]), null);
		compare(Devices.audioAlert([builtIn], [builtIn, hdmi]), null);
		compare(Devices.audioAlert([builtIn], [builtIn, usb]).name, "USB Headset");
		compare(Devices.audioAlert([usb], [usb]), null);
	}
	function test_udevSkipsUsbAudio() {
		// A USB headset alerts once, as audio (above), not also as a USB device.
		compare(Devices.udevEvent(["ACTION=add", "DEVTYPE=usb_device", "ID_MODEL=Headset", "ID_USB_INTERFACES=:010100:010200:030000:"]), null);
		verify(Devices.udevEvent(["ACTION=add", "DEVTYPE=usb_device", "ID_MODEL=Drive", "ID_USB_INTERFACES=:080650:"]) !== null);
	}
}
