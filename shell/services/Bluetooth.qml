pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "bluetooth.js" as Logic

// BlueZ ObjectManager snapshot plus signals while a visible panel holds it.
// busctl calls are bounded and argv-only; UI never runs a shell command.
// Discovery and pairing run in one bluetoothctl session, which is also the
// pairing agent: BlueZ stops a discovery when the client that started it
// leaves, and the agent must stay up while a device pairs. The session runs
// only while the panel's "Add a device" view looks or a device pairs.
Singleton {
	id: root
	property var _holders: ({})
	readonly property bool active: Object.keys(_holders).length > 0
	property bool available: false
	property bool powered: false
	property string adapter: ""
	property var devices: []
	property string error: ""
	property bool discovering: false
	// Bloom's panel lists.
	readonly property var paired: Logic.paired(root.devices)
	readonly property var nearby: Logic.nearby(root.devices)
	// A connect, disconnect or remove in progress, by device path.
	property string busy: ""
	// The device being paired, and the agent's request for it:
	// { id, kind: "confirm" | "display" | "provide", pin }.
	property string pairing: ""
	property var prompt: null
	// The last failure as { id, code } (bluetooth.js errorText codes).
	property var lastError: null
	signal pairedDevice(string path)
	property bool _looking: false
	// After a pairing, the session stays a while to trust and connect it.
	property bool _settling: false
	readonly property bool _sessionWanted: root.active && root.powered && (root._looking || root.pairing !== "" || root._settling)
	function hold(key, wanted) {
		const next = Object.assign({}, root._holders);
		if (wanted) next[key] = true;
		else delete next[key];
		root._holders = next;
		if (wanted) root.refresh();
	}
	// A change that arrives while a snapshot runs reads again after it, so a
	// connect is never missed until the next signal.
	function refresh() {
		if (!root.active) return;
		if (snapshot.running) snapshot.again = true;
		else snapshot.running = true;
	}
	function setPowered(powered) {
		if (!root.adapter) return "Bluetooth adapter unavailable";
		if (change.running) return "Bluetooth change in progress";
		change.command = ["timeout", "-k", "1s", "8s", "busctl", "--system", "set-property", "org.bluez", root.adapter, "org.bluez.Adapter1", "Powered", "b", powered ? "true" : "false"];
		change.running = true;
		return "ok";
	}
	function setConnected(path, wanted) {
		if (!root.devices.some(d => d.path === path)) return "unknown device";
		if (change.running) return "Bluetooth change in progress";
		root._change(path, ["timeout", "-k", "1s", "15s", "busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", wanted ? "Connect" : "Disconnect"]);
		return "ok";
	}
	// Bloom's Remove: forgets the pairing.
	function unpair(path) {
		if (!root.devices.some(d => d.path === path)) return "unknown device";
		if (change.running) return "Bluetooth change in progress";
		root._change(path, ["timeout", "-k", "1s", "10s", "busctl", "--system", "call", "org.bluez", root.adapter, "org.bluez.Adapter1", "RemoveDevice", "o", path]);
		return "ok";
	}
	function _change(path, command) {
		root.busy = path;
		root.lastError = null;
		change.command = command;
		change.running = true;
	}
	// Look for devices to pair while the "Add a device" view shows.
	function discover(wanted) {
		root._looking = wanted;
		if (session.running) session.send(wanted ? "scan on" : "scan off");
		return "ok";
	}
	function pair(path) {
		const d = root.devices.find(x => x.path === path);
		if (!d) return "unknown device";
		if (root.pairing !== "") return "already pairing";
		root.lastError = null;
		root.prompt = null;
		root.pairing = path;
		session.queue("pair " + d.address);
		pairTimeout.restart();
		return "ok";
	}
	// The person's answer to a confirm or provide request.
	function respond(accept, pin) {
		if (!root.prompt) return "nothing to answer";
		const kind = root.prompt.kind;
		root.prompt = null;
		if (kind === "confirm") session.send(accept ? "yes" : "no");
		else if (kind === "provide") session.send(accept && /^[0-9A-Za-z]{1,16}$/.test(pin || "") ? pin : "");
		return "ok";
	}
	function clearError() { root.lastError = null; }
	function _finishPairing(code) {
		const path = root.pairing;
		const d = root.devices.find(x => x.path === path);
		pairTimeout.stop();
		root.prompt = null;
		root.pairing = "";
		if (code === "ok") {
			// Paired as Bloom leaves it on Windows: trusted and connected.
			if (d) {
				root._settling = true;
				settle.restart();
				session.send("trust " + d.address);
				session.send("connect " + d.address);
			}
			root.pairedDevice(path);
		} else {
			root.lastError = { id: path, code: code };
		}
		root.refresh();
	}
	onActiveChanged: if (!active) { root.devices = []; root._looking = false; root.pairing = ""; root.prompt = null; }
	Process {
		id: monitor
		running: root.active
		command: ["dbus-monitor", "--system", "type='signal',sender='org.bluez'"]
		stdout: SplitParser { onRead: line => { if (line.indexOf("signal ") >= 0) debounce.restart(); } }
	}
	Timer { id: debounce; interval: 200; onTriggered: root.refresh() }
	Process {
		id: snapshot
		property bool again: false
		command: ["timeout", "-k", "1s", "5s", "busctl", "--system", "--json=short", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
		stdout: StdioCollector { id: snapshotOut }
		onExited: code => {
			const s = code === 0 ? Logic.managed(snapshotOut.text) : Logic.managed("");
			root.available = s.available; root.powered = s.powered; root.adapter = s.adapter; root.devices = s.devices; root.discovering = s.discovering;
			if (!s.available) root.error = "Bluetooth adapter unavailable";
			else root.error = "";
			if (again) {
				again = false;
				running = true;
			}
		}
	}
	Process {
		id: change
		onExited: code => {
			root.error = code === 0 ? "" : "Bluetooth change failed";
			if (code !== 0) root.lastError = { id: root.busy, code: code === 124 ? "timeout" : "failed" };
			root.busy = "";
			root.refresh();
		}
	}

	// bluetoothctl: discovery and the pairing agent. Commands sent before it
	// has started wait in a queue.
	Process {
		id: session
		property var _queue: []
		running: root._sessionWanted
		command: [Quickshell.env("BLOOM_BLUETOOTHCTL") || "bluetoothctl"]
		stdinEnabled: true
		function send(line) { if (running) write(line + "\n"); }
		function queue(line) {
			if (running) send(line);
			else _queue = _queue.concat([line]);
		}
		onStarted: {
			send("agent KeyboardDisplay");
			send("default-agent");
			if (root._looking) send("scan on");
			for (const line of _queue) send(line);
			_queue = [];
		}
		onExited: {
			_queue = [];
			if (root.pairing !== "") root._finishPairing("failed");
		}
		stdout: SplitParser {
			onRead: line => {
				if (root.pairing === "") return;
				const got = Logic.agentLine(line);
				if (!got) return;
				if (got.answer) session.send(got.answer);
				else if (got.prompt) root.prompt = { id: root.pairing, kind: got.prompt, pin: got.pin };
				else if (got.result) root._finishPairing(got.result);
			}
		}
	}
	Timer { id: settle; interval: 15000; onTriggered: root._settling = false }
	// BlueZ gives up on its own; this only covers a session that stops talking.
	Timer { id: pairTimeout; interval: 60000; onTriggered: if (root.pairing !== "") { session.send("cancel-pairing"); root._finishPairing("timeout"); } }
}
