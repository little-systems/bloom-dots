pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "capability.js" as Logic

// What each backend can do right now, separate from configured intent and
// observed device state. Backends report; the shell IPC `capabilities
// snapshot` and `bloom doctor` read. Changes are logged once per transition.
Singleton {
	id: root

	property var entries: ({})

	function report(backend, state, reason, attempts) {
		const old = root.entries[backend];
		const next = Logic.entry(state, reason, attempts, old && old.state === state ? old.since : Date.now());
		if (old && old.state === next.state && old.reason === next.reason && old.attempts === next.attempts) return;
		const copy = Object.assign({}, root.entries);
		copy[backend] = next;
		root.entries = copy;
		if (!old || old.state !== next.state) {
			const text = `bloom capability: ${backend} ${next.state}${next.reason ? " (" + next.reason + ")" : ""}`;
			if (next.state === "degraded" || next.state === "missing") console.warn(text);
			else console.info(text);
		}
	}

	function state(backend) {
		return root.entries[backend]?.state ?? "unknown";
	}

	IpcHandler {
		target: "capabilities"

		function snapshot(): string {
			return JSON.stringify({ version: 1, backends: root.entries });
		}
	}
}
