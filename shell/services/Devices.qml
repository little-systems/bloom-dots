pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "devices.js" as Logic

// Connected devices and Bloom's device alerts (Bloom bluetooth.rs, usb.rs,
// jack.rs and App.tsx showDeviceAlert):
// - Bluetooth: a paired device connecting or disconnecting.
// - USB: an external camera, audio device, drive or microphone plugged in or
//   removed (shell/scripts/usb-devices.sh; the computer's own never count).
// - The headphone jack.
// Devices present when watching starts are the baseline and never alert.
Singleton {
	id: root
	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0
	readonly property var privacy: Logic.privacy(Pipewire.nodes.values)
	property var alert: null
	property var _jackPorts: null
	// Headphones in the 3.5 mm jack (pactl's active port), while held.
	readonly property bool jackHeadphones: root._jackPorts ? Object.values(root._jackPorts).some(v => v) : false
	// External USB devices now, as usb-devices.sh lists them.
	property var usb: []
	// The panel's wired devices: the jack, then USB devices.
	readonly property var wired: Logic.wiredDevices(root.usb, root.jackHeadphones)
	readonly property var _looks: Logic.parseLooks(Settings.values["bloom-device-looks"])

	onActiveChanged: {
		Bluetooth.hold("device-alerts", root.active);
		if (root.active) {
			root._watchingSince = Date.now();
			root.refreshJacks();
			root.refreshUsb();
		} else {
			root._knownAll = null;
			root._knownUsb = null;
			root._jackPorts = null;
		}
	}

	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true; else delete next[key];
		root._holders = next;
	}

	// ---- Bluetooth ----

	// Bloom ignores changes in the first 5 s: the adapter's first reports
	// describe devices that were already connected.
	property real _watchingSince: 0
	property var _knownAll: null
	readonly property var _allBluetooth: Bluetooth.devices.filter(d => d.paired || d.connected)
	on_AllBluetoothChanged: {
		const current = root._allBluetooth;
		if (root._knownAll !== null && Date.now() - root._watchingSince >= 5000) {
			for (const change of Logic.connectionChanges(root._knownAll, current))
				root.showAlert(Object.assign({ id: change.device.path }, Logic.bluetoothAlert(change.device, change.connected, root._looks)));
		}
		root._knownAll = current;
		// A battery level often arrives a moment after the device connects:
		// fill it into the alert while that device is still showing.
		const showing = root.alert && root.alert.bluetooth && root.alert.connected
			? current.find(d => d.path === root.alert.id && d.connected) : null;
		if (showing) {
			const fresh = Logic.bluetoothAlert(showing, true, root._looks);
			if (fresh.battery !== root.alert.battery || JSON.stringify(fresh.buds) !== JSON.stringify(root.alert.buds))
				root.alert = Object.assign({}, root.alert, { battery: fresh.battery, buds: fresh.buds });
		}
	}

	// ---- USB ----

	property var _knownUsb: null
	function refreshUsb() {
		if (!root.active)
			return;
		if (usbQuery.running)
			usbQuery.again = true;
		else
			usbQuery.running = true;
	}
	Process {
		id: usbQuery
		property bool again: false
		command: ["timeout", "-k", "1s", "5s", "sh", Quickshell.shellPath("scripts/usb-devices.sh")]
		environment: ({ BLOOM_SYSFS: Quickshell.env("BLOOM_SYSFS") || "" })
		stdout: StdioCollector { id: usbOut }
		onExited: code => {
			if (code === 0) {
				const current = Logic.parseUsb(usbOut.text);
				if (root._knownUsb !== null) {
					for (const change of Logic.usbChanges(root._knownUsb, current))
						root.showAlert(Object.assign({ id: change.device.id }, Logic.usbAlert(change.device, change.connected, root._looks)));
				}
				root._knownUsb = current;
				root.usb = current;
			}
			if (again) {
				again = false;
				running = true;
			}
		}
	}
	// udev only says something changed; a device brings several events (its
	// interfaces), gathered for 0.7 s as Bloom does, then the list is read.
	SupervisedProcess {
		backend: "devices"
		wanted: root.active
		command: [Quickshell.env("BLOOM_UDEVADM") || "udevadm", "monitor", "--udev", "--subsystem-match=usb", "--subsystem-match=sound", "--subsystem-match=video4linux", "--subsystem-match=block"]
		stdout: SplitParser { onRead: line => { if (/^UDEV /.test(line)) usbGather.restart(); } }
	}
	Timer { id: usbGather; interval: 700; onTriggered: root.refreshUsb() }

	// ---- Headphone jack ----

	function refreshJacks() { if (root.active && !jackQuery.running) jackQuery.running = true; }
	SupervisedProcess {
		backend: "audio-events"
		wanted: root.active
		command: [Quickshell.env("BLOOM_PACTL") || "pactl", "subscribe"]
		stdout: SplitParser { onRead: line => { if (/on (sink|card) #/.test(line)) jackDebounce.restart(); } }
	}
	Timer { id: jackDebounce; interval: 200; onTriggered: root.refreshJacks() }
	Process {
		id: jackQuery
		command: ["timeout", "-k", "1s", "5s", Quickshell.env("BLOOM_PACTL") || "pactl", "list", "sinks"]
		stdout: StdioCollector { id: jackOutput }
		onExited: code => {
			if (code !== 0) return;
			const next = Logic.headphonePorts(jackOutput.text);
			const change = Logic.jackChange(root._jackPorts, next);
			root._jackPorts = next;
			if (change) root.showAlert(Object.assign({ id: "jack" }, Logic.wiredAlert("Headphones", "earbuds-jack", change === "connected", root._looks)));
		}
	}

	// ---- The alert ----

	// Bloom's showDeviceAlert: { id, name, art, status, connected, wired,
	// bluetooth, battery, buds } plus a runId that replays the art.
	property var _alertQueue: []
	function showAlert(alert) {
		const next = Logic.queueAlert(root.alert, root._alertQueue, alert);
		root._alertQueue = next.queue;
		if (next.show) root._present(next.show);
	}
	function _present(alert) {
		root.alert = Object.assign({ runId: Date.now() }, alert);
		clearAlert.interval = Logic.alertMs(alert.connected);
		clearAlert.restart();
	}
	// A click on the alert: it goes, and so does the queue.
	function dismissAlert() {
		root._alertQueue = [];
		root.alert = null;
		clearAlert.stop();
	}
	Timer {
		id: clearAlert
		onTriggered: {
			const next = root._alertQueue[0];
			root._alertQueue = root._alertQueue.slice(1);
			if (next) root._present(next);
			else root.alert = null;
		}
	}
}
