pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// hypridle and hyprsunset are user services on supported installs. Query on
// demand; don't stop an unrelated process launched outside those units.
Singleton {
	id: root
	property bool idleActive: false
	property bool nightActive: false
	property string error: ""
	function refresh() { if (!query.running) query.running = true; }
	function setIdle(enabled) { return root._set("hypridle.service", enabled); }
	function setNight(enabled) { return root._set("hyprsunset.service", enabled); }
	function _set(unit, enabled) {
		if (change.running) return "service change in progress";
		change.command = ["timeout", "-k", "1s", "8s", "systemctl", "--user", enabled ? "start" : "stop", unit];
		change.running = true;
		return "ok";
	}
	Process {
		id: query
		command: ["timeout", "-k", "1s", "5s", "systemctl", "--user", "is-active", "hypridle.service", "hyprsunset.service"]
		stdout: StdioCollector { id: output }
		onExited: {
			const lines = output.text.trim().split("\n");
			root.idleActive = lines[0] === "active";
			root.nightActive = lines[1] === "active";
		}
	}
	Process { id: change; onExited: code => { root.error = code === 0 ? "" : "service change failed"; root.refresh(); } }
}
