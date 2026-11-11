pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/notch/calendar.js" as Logic

// The notch's Pomodoro timer with Bloom's states: running (a deadline, so it
// survives a restart), paused (pausedSec left), idle (pausedSec 0; the clock
// shows the last duration) and finished (until reset, a start or an edit).
Singleton {
	id: root

	// Bloom's lastDurationSeconds: what Start and an idle clock use.
	property int durationSec: 1500
	property real deadlineMs: 0
	property int pausedSec: 0
	property bool finished: false
	property string error: ""
	readonly property bool running: deadlineMs > 0

	function remaining() {
		return Logic.remaining(root.deadlineMs, root.pausedSec, Date.now());
	}

	function _save() {
		state.save({ durationSec: root.durationSec, deadlineMs: root.deadlineMs, pausedSec: root.pausedSec, finished: root.finished });
	}

	function _schedule() {
		deadlineTimer.stop();
		if (root.deadlineMs > 0) {
			deadlineTimer.interval = Math.max(1, root.deadlineMs - Date.now());
			deadlineTimer.start();
		}
	}

	// Bloom's startTimer: a new run of `seconds`, which becomes the duration.
	function startWith(seconds) {
		root.durationSec = seconds;
		root.pausedSec = 0;
		root.finished = false;
		root.deadlineMs = Date.now() + seconds * 1000;
		root._save();
		root._schedule();
	}

	// Play when not running: a paused timer resumes; idle or finished restarts
	// the last duration.
	function start() {
		if (root.running)
			return;
		if (root.pausedSec > 0) {
			root.deadlineMs = Date.now() + root.pausedSec * 1000;
			root.pausedSec = 0;
			root._save();
			root._schedule();
		} else {
			root.startWith(root.durationSec);
		}
	}

	function pause() {
		if (!root.running)
			return;
		root.pausedSec = root.remaining();
		root.deadlineMs = 0;
		root._save();
		root._schedule();
	}

	function reset() {
		root.deadlineMs = 0;
		root.pausedSec = 0;
		root.finished = false;
		root._save();
		root._schedule();
	}

	// An edited duration: starts it (Enter, Play) or leaves it idle (blur).
	function commit(seconds, startNow) {
		if (!Number.isInteger(seconds) || seconds < 1 || seconds > Logic.MAX_TIMER_SECONDS)
			return "invalid duration";
		if (startNow) {
			root.startWith(seconds);
		} else {
			root.durationSec = seconds;
			root.deadlineMs = 0;
			root.pausedSec = 0;
			root.finished = false;
			root._save();
			root._schedule();
		}
		return "ok";
	}

	function setDuration(seconds) {
		return root.commit(seconds, false);
	}

	StateFile {
		id: state
		name: "calendar"
		defaultValue: ({ durationSec: 1500, deadlineMs: 0, pausedSec: 0, finished: false })
		validate: v => v !== null && typeof v === "object" && !Array.isArray(v) ? v : undefined
		maxBytes: 4096
		onLoadedChanged: if (loaded) restore()
		onExternallyChanged: restore()
		function restore() {
			const s = Logic.restored(value, Date.now());
			root.durationSec = s.durationSec;
			root.deadlineMs = s.deadlineMs;
			root.pausedSec = s.pausedSec;
			root.finished = s.finished;
			root._schedule();
			if (s.expired) {
				root._save();
				finishedNote.running = true;
			}
		}
	}

	Timer {
		id: deadlineTimer
		onTriggered: {
			if (root.deadlineMs > Date.now()) {
				root._schedule();
				return;
			}
			root.deadlineMs = 0;
			root.pausedSec = 0;
			root.finished = true;
			root._save();
			finishedNote.running = true;
		}
	}

	Process {
		id: finishedNote
		command: ["timeout", "-k", "1s", "5s", "notify-send", "-a", "Bloom", "Pomodoro finished", "Time for a break"]
	}
}
