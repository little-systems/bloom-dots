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
	property var _retries: ({})

	// Supervised processes register a retry for their backend.
	function register(backend, retry) {
		const list = (root._retries[backend] || []).concat([retry]);
		root._retries = Object.assign({}, root._retries, { [backend]: list });
	}

	// A controlled repair: restart this Bloom-owned backend process now. It
	// never restarts shared system daemons.
	function retry(backend) {
		const list = root._retries[backend];
		if (!list || list.length === 0) return "unknown backend";
		for (const fn of list) fn();
		return "ok";
	}

	function report(backend, state, reason, attempts) {
		const old = root.entries[backend];
		const next = Logic.entry(state, reason, attempts, old && old.state === state ? old.since : Date.now());
		if (old && old.state === next.state && old.reason === next.reason && old.attempts === next.attempts) return;
		const copy = Object.assign({}, root.entries);
		copy[backend] = next;
		root.entries = copy;
		if (!old || old.state !== next.state) {
			const text = `bloom capability: ${backend} ${next.state}${next.reason ? " (" + next.reason + ")" : ""}`;
			// Absent services and tools are normal on many machines (no
			// Bluetooth, no PulseAudio): note them; a backend that broke warns.
			if (next.state === "degraded") console.warn(text);
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
		function retry(backend: string): string {
			return root.retry(backend);
		}
	}
}
