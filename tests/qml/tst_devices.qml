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


	// Bloom's deviceAlertStatus: wired devices plug in, cards insert,
	// everything else connects.
	function test_alertStatus() {
		compare(Devices.alertStatus("round-buds", true, false), "Connected");
		compare(Devices.alertStatus("mouse", false, false), "Disconnected");
		compare(Devices.alertStatus("flash-drive", true, false), "Plugged in");
		compare(Devices.alertStatus("headphones", false, true), "Unplugged", "wired whatever it looks like");
		compare(Devices.alertStatus("sd-card", true, true), "Inserted");
		compare(Devices.alertStatus("sd-card", false, true), "Removed");
	}
	// The alert a Bluetooth change raises: the art by kind (or the user's pick).
	function test_bluetoothAlert() {
		const a = Devices.bluetoothAlert({ path: "/m", name: "MX Master 3", kind: "mouse", battery: 15, buds: {} }, true, {});
		compare(a.name, "MX Master 3");
		compare(a.art, "mouse");
		compare(a.connected, true);
		compare(a.status, "Connected");
		compare(a.battery, 15);
		compare(a.wired, false);
		compare(a.bluetooth, true);
		const off = Devices.bluetoothAlert({ path: "/a", name: "AirPods Pro", kind: "audio", battery: null, buds: {} }, false, { "AirPods Pro": "round-buds" });
		compare(off.art, "round-buds");
		compare(off.status, "Disconnected");
		compare(off.battery, null);
	}
	function test_connectionChanges() {
		const before = [{ path: "/a", name: "A", connected: true }, { path: "/b", name: "B", connected: false }];
		const after = [{ path: "/a", name: "A", connected: false }, { path: "/b", name: "B", connected: true }];
		compare(Devices.connectionChanges(before, after).map(c => [c.device.path, c.connected]), [["/a", false], ["/b", true]]);
		compare(Devices.connectionChanges(after, after), []);
	}
	function test_alertDurations() {
		// Bloom DEVICE_ALERT_MS.
		compare(Devices.alertMs(true), 4200);
		compare(Devices.alertMs(false), 2600);
	}

	// Bloom's showDeviceAlert: the same device replaces its alert; another
	// waits behind it, at most 3, newest last.
	function test_alertQueue() {
		const a = { id: "a" }, b = { id: "b" }, c = { id: "c" }, d = { id: "d" }, e = { id: "e" };
		compare(Devices.queueAlert(null, [], a), { show: a, queue: [] });
		compare(Devices.queueAlert(a, [], { id: "a", v: 2 }), { show: { id: "a", v: 2 }, queue: [] });
		compare(Devices.queueAlert(a, [], b), { show: null, queue: [b] });
		compare(Devices.queueAlert(a, [b, c], { id: "b", v: 2 }).queue, [c, { id: "b", v: 2 }]);
		compare(Devices.queueAlert(a, [b, c, d], e).queue, [c, d, e]);
	}

	// USB devices from shell/scripts/usb-devices.sh (Bloom usb.rs, usbArtFor.ts).
	function test_parseUsb() {
		compare(Devices.parseUsb("1-2\taudio-out\tAB13X USB Audio\n1-5\tdisk\tSanDisk Cruzer Blade\n\nbad line\n"),
			[{ id: "usb:1-2", class: "audio-out", name: "AB13X USB Audio" }, { id: "usb:1-5", class: "disk", name: "SanDisk Cruzer Blade" }]);
		compare(Devices.parseUsb(""), []);
	}
	function test_usbArtAndName() {
		compare(Devices.usbArtFor({ class: "camera", name: "C920" }), "webcam");
		compare(Devices.usbArtFor({ class: "audio-in", name: "Yeti" }), "microphone");
		compare(Devices.usbArtFor({ class: "audio-out", name: "USB-C Earbuds" }), "earbuds-usbc");
		compare(Devices.usbArtFor({ class: "audio-out", name: "AB13X USB Audio" }), "headphones-wired");
		compare(Devices.usbArtFor({ class: "disk", name: "Samsung Portable SSD T7" }), "ssd");
		compare(Devices.usbArtFor({ class: "disk", name: "SD Card Reader" }), "sd-card");
		compare(Devices.usbArtFor({ class: "disk", name: "SanDisk Cruzer Blade" }), "flash-drive");
		compare(Devices.usbDisplayName({ class: "disk", name: "Mass Storage" }), "USB drive");
		compare(Devices.usbDisplayName({ class: "camera", name: "" }), "USB camera");
		compare(Devices.usbDisplayName({ class: "disk", name: "Kingston DataTraveler" }), "Kingston DataTraveler");
	}
	function test_usbChanges() {
		const a = { id: "usb:1-2", class: "audio-out", name: "Dongle" }, b = { id: "usb:1-5", class: "disk", name: "Stick" };
		compare(Devices.usbChanges([a], [a, b]), [{ device: b, connected: true }]);
		compare(Devices.usbChanges([a, b], [a]), [{ device: b, connected: false }]);
		compare(Devices.usbChanges([a], [a]), []);
	}
	function test_usbAlert() {
		const alert = Devices.usbAlert({ id: "usb:1-5", class: "disk", name: "SanDisk Cruzer Blade" }, true, {});
		compare(alert.name, "SanDisk Cruzer Blade");
		compare(alert.art, "flash-drive");
		compare(alert.status, "Plugged in");
		compare(alert.wired, true);
		compare(Devices.usbAlert({ id: "usb:1-9", class: "disk", name: "SD Card Reader" }, false, {}).status, "Removed");
		// An audio device's look can be picked; a drive's can't.
		compare(Devices.usbAlert({ id: "usb:1-2", class: "audio-out", name: "Dongle" }, true, { Dongle: "earbuds-usbc" }).art, "earbuds-usbc");
	}
	function test_usbInThePanel() {
		const usb = [{ id: "usb:1-2", class: "audio-out", name: "AB13X USB Audio" }, { id: "usb:1-5", class: "disk", name: "Mass Storage" }];
		const wired = Devices.wiredDevices(usb, true);
		compare(wired.map(d => [d.id, d.kind, d.name, d.art]), [
			["jack", "audio", "Headphones", "earbuds-jack"],
			["usb:1-2", "audio", "AB13X USB Audio", "headphones-wired"],
			["usb:1-5", "usb", "USB drive", "flash-drive"]
		]);
		const groups = Devices.groupDevices(Devices.entries(null, [], wired, {}), 20);
		compare(groups.map(g => g.key), ["audio", "usb"]);
		compare(Devices.wiredSub(wired[2]), "USB");
	}
}
