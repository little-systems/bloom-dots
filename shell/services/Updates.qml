pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "updates.js" as Logic
import "../common/tokens.js" as Tokens

// Pending pacman updates (spec §4.2, §5.1) for the notch's dot and pulse.
// Checks once a minute after something holds it, then hourly, and on demand
// (`bloom ipc updates check`). A failed check keeps the last good count so
// the dot doesn't flicker while offline.
Singleton {
	id: root

	property int count: 0
	property bool installed: true
	readonly property bool available: root.installed && root.count > 0
	readonly property bool checking: proc.running
	// A check found more updates than the last good one (the pulse).
	signal arrived()

	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function check() {
		if (!proc.running)
			proc.running = true;
	}

	function _finish(code, text) {
		const r = Logic.parse(code, text);
		if (r.missing) {
			if (root.installed)
				console.log("bloom updates: checkupdates is not installed (pacman-contrib); the update indicator is off");
			root.installed = false;
			root.count = 0;
			return;
		}
		root.installed = true;
		if (!r.ok)
			return;
		const rose = Logic.rose(root.count, r.count);
		root.count = r.count;
		if (rose)
			root.arrived();
	}

	onActiveChanged: {
		if (root.active)
			first.restart();
		else
			first.stop();
	}

	Timer {
		id: first
		interval: Tokens.updates.firstCheckMs
		onTriggered: root.check()
	}

	Timer {
		interval: Tokens.updates.intervalMs
		repeat: true
		running: root.active
		onTriggered: root.check()
	}

	Timer {
		id: watchdog
		interval: Tokens.updates.timeoutMs
		onTriggered: proc.running = false
	}

	Process {
		id: proc
		// Through sh so a missing checkupdates exits 127; a missing binary
		// started directly never reports an exit.
		// BLOOM_CHECKUPDATES points tests at a fake, so they never sync the real databases.
		command: ["sh", "-c", 'c="${BLOOM_CHECKUPDATES:-checkupdates}"; command -v "$c" >/dev/null || exit 127; exec "$c"']
		onRunningChanged: {
			if (proc.running)
				watchdog.restart();
			else
				watchdog.stop();
		}
		stdout: StdioCollector { id: out }
		onExited: code => root._finish(code, out.text)
	}
}
