pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "devices.js" as Logic

Singleton {
	id: root
	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0
	readonly property var audioDevices: Logic.audioDevices(Pipewire.nodes.values)
	readonly property var privacy: Logic.privacy(Pipewire.nodes.values)
	property var alert: null
	property var _eventLines: []
	property var _knownAudio: null
	property var _jackPorts: null
	readonly property var connectedBluetooth: Bluetooth.devices.filter(d => d.connected)
	// Headphones in the 3.5 mm jack (pactl's active port), while held.
	readonly property bool jackHeadphones: root._jackPorts ? Object.values(root._jackPorts).some(v => v) : false
	readonly property var wiredAudio: Logic.wiredAudio(Pipewire.nodes.values, root.jackHeadphones)
	readonly property int count: (Battery.available && Battery.ready ? 1 : 0) + root.audioDevices.length + root.connectedBluetooth.length
	onActiveChanged: {
		Bluetooth.hold("device-alerts", root.active);
		if (root.active) root.refreshJacks();
		else { root._knownAll = null; root._knownAudio = null; root._jackPorts = null; }
	}
	// Bloom alerts when a Bluetooth device connects or disconnects.
	property var _knownAll: null
	readonly property var _allBluetooth: Bluetooth.devices.filter(d => d.paired || d.connected)
	on_AllBluetoothChanged: {
		const current = root._allBluetooth;
		if (root._knownAll !== null) {
			for (const change of Logic.connectionChanges(root._knownAll, current))
				root.showAlert(Object.assign({ id: change.device.path }, Logic.bluetoothAlert(change.device, change.connected, root._looks)));
		}
		root._knownAll = current;
	}
	readonly property var _looks: Logic.parseLooks(Settings.values["bloom-device-looks"])
	// Only USB audio alerts (Bloom's wired audio); the built-in sound card and
	// a display's HDMI audio coming and going never do.
	readonly property var _audioNodes: Pipewire.nodes.values.filter(n => n && !n.isStream)
	on_AudioNodesChanged: {
		const current = root._audioNodes.map(n => ({ id: n.id, isStream: false, description: n.description, nickname: n.nickname, name: n.name, properties: n.properties }));
		if (root._knownAudio !== null) {
			const added = Logic.audioAlert(root._knownAudio, current);
			if (added) root.showAlert(Object.assign({ id: added.id }, Logic.wiredAlert(added.name, added.art, true, root._looks)));
		}
		root._knownAudio = current;
	}
	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true; else delete next[key];
		root._holders = next;
	}
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
	// A click on the alert, or a panel opening: it goes, and so does the queue.
	function dismissAlert() {
		root._alertQueue = [];
		root.alert = null;
		clearAlert.stop();
	}
	function refreshJacks() { if (root.active && !jackQuery.running) jackQuery.running = true; }
	Timer {
		id: clearAlert
		onTriggered: {
			const next = root._alertQueue[0];
			root._alertQueue = root._alertQueue.slice(1);
			if (next) root._present(next);
			else root.alert = null;
		}
	}
	Process {
		running: root.active
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
	Process {
		running: root.active
		command: [Quickshell.env("BLOOM_UDEVADM") || "udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb", "--subsystem-match=sound"]
		stdout: SplitParser {
			onRead: line => {
				if (line.trim()) { root._eventLines.push(line.trim()); return; }
				const event = Logic.udevEvent(root._eventLines);
				root._eventLines = [];
				if (event) root.showAlert(Object.assign({ id: "usb:" + event.detail }, Logic.usbAlert(event.detail, true)));
			}
		}
	}
}
