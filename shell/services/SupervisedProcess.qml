import QtQuick
import Quickshell
import Quickshell.Io
import "capability.js" as Logic

// A long-running backend process (monitors, agents, helpers) that should run
// while `wanted`. If it exits or can't start while still wanted, it restarts
// after a bounded exponential backoff (1 s ... 60 s), resetting once it has run
// for 30 s. `retry()` is the user-visible "try again". Its capability is
// reported to Capabilities under `backend`: available, degraded (exited),
// missing (the program couldn't start) or stopped (not wanted).
Process {
	id: proc

	property bool wanted: false
	required property string backend
	property int baseDelayMs: 1000
	property int maxDelayMs: 60000
	property int stableMs: 30000
	property int attempt: 0
	property string capability: "stopped"
	property string reason: ""
	property bool _started: false
	property bool _restarting: false
	property real _startedAt: 0

	function retry() {
		proc.attempt = 0;
		proc._backoff.stop();
		if (proc.wanted && !proc.running) proc.running = true;
	}

	// Apply a new command or arguments now; not counted as a failure.
	function restart() {
		if (!proc.running) { proc.retry(); return; }
		proc._restarting = true;
		proc.running = false;
	}

	function _set(state, why) {
		proc.capability = state;
		proc.reason = why;
		Capabilities.report(proc.backend, state, why, proc.attempt);
	}

	function _lost(state, why) {
		if (!proc.wanted) { proc._set("stopped", ""); return; }
		if (proc._started && Date.now() - proc._startedAt >= proc.stableMs) proc.attempt = 0;
		proc.attempt++;
		proc._set(state, why);
		proc._backoff.interval = Logic.backoffMs(proc.attempt, proc.baseDelayMs, proc.maxDelayMs);
		proc._backoff.restart();
	}

	onWantedChanged: {
		if (proc.wanted) {
			proc.attempt = 0;
			if (!proc.running && !proc._backoff.running) proc.running = true;
		} else {
			proc._backoff.stop();
			proc.running = false;
			proc._set("stopped", "");
		}
	}
	Component.onCompleted: if (proc.wanted) proc.running = true
	onStarted: {
		proc._started = true;
		proc._startedAt = Date.now();
		proc._set("available", "");
	}
	onExited: (code, status) => {
		proc._started = false;
		if (proc._restarting) {
			proc._restarting = false;
			if (proc.wanted) proc.running = true;
			return;
		}
		if (proc.wanted) proc._lost("degraded", "exited with " + (status === 0 ? "status " + code : "a crash"));
	}
	// A program that can't be found never starts or exits; running just drops.
	onRunningChanged: {
		if (proc.running) return;
		if (!proc._started && proc.wanted && !proc._backoff.running && proc.capability !== "degraded")
			proc._lost("missing", proc.command.length ? proc.command[0] + " couldn't start" : "no command");
	}

	property Timer _backoff: Timer {
		onTriggered: if (proc.wanted && !proc.running) { proc.capability = "unknown"; proc.running = true; }
	}
}
