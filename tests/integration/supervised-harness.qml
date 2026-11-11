import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// SupervisedProcess restart pacing and capability reporting, run by
// tests/integration/test_supervised.sh. Prints RESULT lines.
ShellRoot {
	id: root
	property int flakyStarts: 0

	SupervisedProcess {
		id: flaky
		backend: "flaky"
		wanted: true
		baseDelayMs: 50
		maxDelayMs: 200
		command: ["sh", "-c", "exit 1"]
		onStarted: root.flakyStarts++
	}

	SupervisedProcess {
		id: missing
		backend: "missing"
		wanted: true
		baseDelayMs: 50
		maxDelayMs: 100
		command: ["bloom-no-such-binary"]
	}

	SupervisedProcess {
		id: steady
		backend: "steady"
		wanted: true
		command: ["sleep", "30"]
	}

	SupervisedProcess {
		id: idle
		backend: "idle"
		wanted: false
		command: ["sleep", "30"]
	}

	Timer {
		interval: 1200
		running: true
		onTriggered: {
			const snap = JSON.parse(Capabilities.entries ? JSON.stringify({ backends: Capabilities.entries }) : "{}").backends;
			console.log(`RESULT flaky-restarts=${root.flakyStarts >= 4 && root.flakyStarts <= 12} flaky-degraded=${snap.flaky?.state === "degraded" || snap.flaky?.state === "unknown"} missing=${snap.missing?.state === "missing"} missing-retries=${missing.attempt >= 2} steady=${snap.steady?.state === "available"} idle-not-running=${!idle.running}`);
			steady.wanted = false;
			flaky.wanted = false;
			stopped.start();
		}
	}

	Timer {
		id: stopped
		interval: 400
		onTriggered: {
			const starts = root.flakyStarts;
			console.log(`RESULT steady-stopped=${Capabilities.state("steady") === "stopped" && !steady.running} flaky-stopped=${Capabilities.state("flaky") === "stopped"}`);
			later.starts = starts;
			later.start();
		}
	}

	Timer {
		id: later
		property int starts: 0
		interval: 500
		onTriggered: {
			console.log(`RESULT no-restart-when-unwanted=${root.flakyStarts === later.starts}`);
			missing.command = ["sleep", "30"];
			missing.retry();
			recovered.start();
		}
	}

	Timer {
		id: recovered
		interval: 400
		onTriggered: {
			console.log(`RESULT retry-recovers=${Capabilities.state("missing") === "available" && missing.attempt === 0}`);
			missing.restart();
			restarted.start();
		}
	}

	Timer {
		id: restarted
		interval: 400
		onTriggered: {
			console.log(`RESULT restart-not-a-failure=${missing.running && missing.attempt === 0 && Capabilities.state("missing") === "available"}`);
			Qt.exit(0);
		}
	}
}
