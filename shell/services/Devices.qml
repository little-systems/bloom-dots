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
	property var _knownBluetooth: null
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
		else { root._knownBluetooth = null; root._knownAudio = null; root._jackPorts = null; }
	}
	onConnectedBluetoothChanged: {
		const current = root.connectedBluetooth;
		if (root._knownBluetooth !== null) {
			const added = current.find(d => !root._knownBluetooth.some(old => old.path === d.path));
			if (added) root.showAlert("Bluetooth connected", added.name, "bluetooth", added.battery, added.buds);
		}
		root._knownBluetooth = current;
	}
	onAudioDevicesChanged: {
		const current = root.audioDevices;
		if (root._knownAudio !== null) {
			const added = current.find(d => !root._knownAudio.some(old => old.id === d.id));
			if (added) root.showAlert("Audio device connected", added.name, "audio");
		}
		root._knownAudio = current;
	}
	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true; else delete next[key];
		root._holders = next;
	}
	function showAlert(title, detail, kind, battery, buds) {
		root.alert = { title, detail, kind, battery: Number.isInteger(battery) ? battery : null, buds: buds || null };
		clearAlert.restart();
	}
	function refreshJacks() { if (root.active && !jackQuery.running) jackQuery.running = true; }
	Timer { id: clearAlert; interval: 4300; onTriggered: root.alert = null }
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
			if (change) root.showAlert("Headphones " + change, "Audio output changed", "audio");
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
				if (event) root.showAlert(event.title, event.detail, event.kind);
			}
		}
	}
}
