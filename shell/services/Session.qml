pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/session/session.js" as Logic

// The session menu: what's running (checked each time it opens) and the
// actions. Commands are argv only, with systemctl, loginctl and hyprctl on PATH.
Singleton {
	id: root

	property bool opened: false
	property var busy: ({ pacman: false, downloads: 0 })

	function show() {
		root.opened = true;
		if (!busyCheck.running) busyCheck.running = true;
	}
	function hide() { root.opened = false; }
	function toggle() { if (root.opened) root.hide(); else root.show(); }

	function run(id) {
		root.hide();
		// Lock through logind: whatever the session's idle daemon runs.
		const argv = id === "lock" ? ["loginctl", "lock-session"] : Logic.command(id);
		if (!argv) return "unknown action";
		Quickshell.execDetached(argv);
		return "ok";
	}

	Process {
		id: busyCheck
		command: ["timeout", "-k", "1s", "3s", "sh", Quickshell.shellPath("scripts/session-busy.sh")]
		stdout: StdioCollector { id: busyOut }
		onExited: root.busy = Logic.parseBusy(busyOut.text)
	}
}
