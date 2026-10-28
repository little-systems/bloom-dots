pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "bluetooth.js" as Logic

// BlueZ ObjectManager snapshot plus signals while a visible panel holds it.
// busctl calls are bounded and argv-only; UI never runs a shell command.
Singleton {
	id: root
	property var _holders: ({})
	readonly property bool active: Object.keys(_holders).length > 0
	property bool available: false
	property bool powered: false
	property string adapter: ""
	property var devices: []
	property string error: ""
	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true;
		else delete next[key];
		root._holders = next;
		if (wanted) root.refresh();
	}
	function refresh() { if (root.active && !snapshot.running) snapshot.running = true; }
	function setPowered(powered) {
		if (!root.adapter) return "Bluetooth adapter unavailable";
		if (change.running) return "Bluetooth change in progress";
		change.command = ["busctl", "--system", "set-property", "org.bluez", root.adapter, "org.bluez.Adapter1", "Powered", "b", powered ? "true" : "false"];
		change.running = true;
		return "ok";
	}
	function setConnected(path, wanted) {
		if (!root.devices.some(d => d.path === path)) return "unknown device";
		if (change.running) return "Bluetooth change in progress";
		change.command = ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", wanted ? "Connect" : "Disconnect"];
		change.running = true;
		return "ok";
	}
	onActiveChanged: if (!active) root.devices = []
	Process {
		id: monitor
		running: root.active
		command: ["dbus-monitor", "--system", "type='signal',sender='org.bluez'"]
		stdout: SplitParser { onRead: line => { if (line.indexOf("signal ") >= 0) debounce.restart(); } }
	}
	Timer { id: debounce; interval: 200; onTriggered: root.refresh() }
	Process {
		id: snapshot
		command: ["busctl", "--system", "--json=short", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
		stdout: StdioCollector { id: snapshotOut }
		onExited: code => {
			const s = code === 0 ? Logic.managed(snapshotOut.text) : Logic.managed("");
			root.available = s.available; root.powered = s.powered; root.adapter = s.adapter; root.devices = s.devices;
			if (!s.available) root.error = "Bluetooth adapter unavailable";
			else root.error = "";
		}
	}
	Process {
		id: change
		onExited: code => {
			root.error = code === 0 ? "" : "Bluetooth change failed";
			root.refresh();
		}
	}
}
