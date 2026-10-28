pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "network.js" as Logic

// NetworkManager through nmcli. The monitor and scans exist only while a
// Command Center or Wi-Fi panel holds this service.
Singleton {
	id: root
	property var _holders: ({})
	readonly property bool active: Object.keys(_holders).length > 0
	property bool available: false
	property bool wifiEnabled: false
	property bool connected: false
	property string ssid: ""
	property var networks: []
	property string error: ""

	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true;
		else delete next[key];
		root._holders = next;
		if (wanted) root.refresh(false);
	}
	function refresh(rescan) {
		if (!root.active) return;
		if (!statusQuery.running) statusQuery.running = true;
		if (!listQuery.running) {
			listQuery.command = ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", rescan ? "yes" : "no"];
			listQuery.running = true;
		}
	}
	function setWifi(enabled) {
		if (change.running) return "network change in progress";
		change.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"];
		change.running = true;
		return "ok";
	}
	function connect(ssid) {
		if (change.running) return "network change in progress";
		if (!root.networks.some(n => n.ssid === ssid)) return "unknown network";
		change.command = ["nmcli", "-w", "12", "device", "wifi", "connect", ssid];
		change.running = true;
		return "ok";
	}
	onActiveChanged: if (!active) { root.networks = []; root.ssid = ""; }

	Process {
		id: monitor
		running: root.active
		command: ["nmcli", "monitor"]
		stdout: SplitParser { onRead: line => { if (line.trim()) debounce.restart(); } }
	}
	Timer { id: debounce; interval: 200; onTriggered: root.refresh(false) }
	Process {
		id: statusQuery
		command: ["nmcli", "-t", "-f", "WIFI,STATE", "general", "status"]
		stdout: StdioCollector { id: statusOut }
		onExited: code => {
			root.available = code === 0;
			if (code === 0) {
				const s = Logic.status(statusOut.text);
				root.wifiEnabled = s.wifiEnabled;
				root.connected = s.connected;
				root.error = "";
			} else root.error = "NetworkManager unavailable";
		}
	}
	Process {
		id: listQuery
		stdout: StdioCollector { id: listOut }
		onExited: code => {
			root.networks = code === 0 ? Logic.wifiList(listOut.text) : [];
			root.ssid = root.networks.find(n => n.active)?.ssid ?? "";
		}
	}
	Process {
		id: change
		onExited: code => {
			root.error = code === 0 ? "" : "Wi-Fi change failed; check NetworkManager or credentials";
			root.refresh(false);
		}
	}
}
