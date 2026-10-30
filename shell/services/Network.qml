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
	// Bloom's panel state: a scan running, the network a change is for, and
	// the last failure as { ssid, code } (network.js connectError codes).
	readonly property bool scanning: listQuery.running && listQuery.rescan
	property string busy: ""
	property var lastError: null
	property var _saved: []
	property string _listText: ""

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
		if (!savedQuery.running) savedQuery.running = true;
		if (listQuery.running) {
			// A scan asked for during a plain listing runs after it.
			if (rescan && !listQuery.rescan) listQuery.pendingRescan = true;
		} else {
			listQuery.rescan = rescan;
			listQuery.command = ["timeout", "-k", "1s", "15s", "nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", rescan ? "yes" : "no"];
			listQuery.running = true;
		}
	}
	function setWifi(enabled) {
		if (change.running) return "network change in progress";
		change.command = ["timeout", "-k", "1s", "10s", "nmcli", "radio", "wifi", enabled ? "on" : "off"];
		change.running = true;
		return "ok";
	}
	function connect(ssid, password) {
		if (change.running) return "network change in progress";
		if (!root.networks.some(n => n.ssid === ssid)) return "unknown network";
		if (password && (password.length < 8 || password.length > 63 || /[\r\n\0]/.test(password))) {
			root.lastError = { ssid: ssid, code: "password-length" };
			return "invalid password";
		}
		change.pendingPassword = password || "";
		// --ask reads the secret from stdin; it must never appear in argv.
		root._start(ssid, "connect", Logic.connectCommand(ssid, password), !!password);
		return "ok";
	}
	function disconnect(ssid) {
		if (change.running) return "network change in progress";
		if (!root.networks.some(n => n.ssid === ssid && n.connected)) return "not connected";
		root._start(ssid, "disconnect", ["timeout", "-k", "1s", "10s", "nmcli", "connection", "down", "id", ssid], false);
		return "ok";
	}
	// Bloom's Forget: the saved profile goes.
	function forget(ssid) {
		if (change.running) return "network change in progress";
		if (!root._saved.includes(ssid)) return "not saved";
		root._start(ssid, "forget", ["timeout", "-k", "1s", "10s", "nmcli", "connection", "delete", "id", ssid], false);
		return "ok";
	}
	function clearError() { root.lastError = null; }
	function _start(ssid, action, command, withPassword) {
		root.busy = ssid;
		root.lastError = null;
		change.action = action;
		change.withPassword = withPassword;
		change.command = command;
		change.running = true;
	}
	function _networks() { root.networks = Logic.wifiList(root._listText, root._saved); }
	onActiveChanged: if (!active) { root.networks = []; root.ssid = ""; root._listText = ""; }

	Process {
		id: monitor
		running: root.active
		command: ["nmcli", "monitor"]
		stdout: SplitParser { onRead: line => { if (line.trim()) debounce.restart(); } }
	}
	Timer { id: debounce; interval: 200; onTriggered: root.refresh(false) }
	Process {
		id: statusQuery
		command: ["timeout", "-k", "1s", "5s", "nmcli", "-t", "-f", "WIFI,STATE", "general", "status"]
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
		id: savedQuery
		command: ["timeout", "-k", "1s", "5s", "nmcli", "-t", "--escape", "yes", "-f", "NAME,TYPE", "connection", "show"]
		stdout: StdioCollector { id: savedOut }
		onExited: code => {
			root._saved = code === 0 ? Logic.savedNames(savedOut.text) : [];
			root._networks();
		}
	}
	Process {
		id: listQuery
		property bool rescan: false
		property bool pendingRescan: false
		stdout: StdioCollector { id: listOut }
		onExited: code => {
			root._listText = code === 0 ? listOut.text : "";
			root._networks();
			root.ssid = root.networks.find(n => n.connected)?.ssid ?? "";
			if (pendingRescan) {
				pendingRescan = false;
				root.refresh(true);
			}
		}
	}
	Process {
		id: change
		property string pendingPassword: ""
		property string action: ""
		property bool withPassword: false
		stdinEnabled: true
		stdout: StdioCollector { id: changeOut }
		stderr: StdioCollector { id: changeErr }
		onStarted: {
			if (pendingPassword) {
				change.write(pendingPassword + "\n");
				pendingPassword = "";
			}
		}
		onExited: code => {
			pendingPassword = "";
			root.error = code === 0 ? "" : "Wi-Fi change failed; check NetworkManager or credentials";
			if (code !== 0)
				root.lastError = { ssid: root.busy, code: action === "connect" ? Logic.connectError(changeErr.text + changeOut.text, code, withPassword) : "failed" };
			root.busy = "";
			root.refresh(false);
		}
	}
}
