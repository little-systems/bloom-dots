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
	readonly property var connectedBluetooth: Bluetooth.devices.filter(d => d.connected)
	readonly property int count: root.audioDevices.length + root.connectedBluetooth.length
	onActiveChanged: {
		Bluetooth.hold("device-alerts", root.active);
		if (!root.active) { root._knownBluetooth = null; root._knownAudio = null; }
	}
	onConnectedBluetoothChanged: {
		const current = root.connectedBluetooth;
		if (root._knownBluetooth !== null) {
			const added = current.find(d => !root._knownBluetooth.some(old => old.path === d.path));
			if (added) root.showAlert("Bluetooth connected", added.name, "bluetooth");
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
	function showAlert(title, detail, kind) {
		root.alert = { title, detail, kind };
		clearAlert.restart();
	}
	Timer { id: clearAlert; interval: 4300; onTriggered: root.alert = null }
	Process {
		running: root.active
		command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb", "--subsystem-match=sound"]
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
