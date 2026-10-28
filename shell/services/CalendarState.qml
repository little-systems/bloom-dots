pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/notch/calendar.js" as Logic

Singleton {
	id: root
	property var todos: []
	property int durationSec: 1500
	property real deadlineMs: 0
	property int pausedSec: 1500
	property string error: ""
	readonly property bool running: deadlineMs > 0
	function remaining() { return Logic.remaining(root.deadlineMs, root.pausedSec, Date.now()); }
	function _save() { state.save({ todos: root.todos, durationSec: root.durationSec, deadlineMs: root.deadlineMs, pausedSec: root.pausedSec }); }
	function _schedule() {
		deadlineTimer.stop();
		if (root.deadlineMs > 0) { deadlineTimer.interval = Math.max(1, root.deadlineMs - Date.now()); deadlineTimer.start(); }
	}
	function start() {
		if (root.pausedSec <= 0) root.pausedSec = root.durationSec;
		root.deadlineMs = Date.now() + root.pausedSec * 1000;
		root._save(); root._schedule();
	}
	function pause() {
		if (!root.running) return;
		root.pausedSec = root.remaining(); root.deadlineMs = 0;
		root._save(); root._schedule();
	}
	function reset() { root.deadlineMs = 0; root.pausedSec = root.durationSec; root._save(); root._schedule(); }
	function setDuration(seconds) {
		if (!Number.isInteger(seconds) || seconds < 1 || seconds > 180 * 60) return "invalid duration";
		root.durationSec = seconds; root.deadlineMs = 0; root.pausedSec = seconds; root._save(); root._schedule(); return "ok";
	}
	function addTodo(text) {
		const clean = (text || "").trim();
		if (!clean || clean.length > 240 || root.todos.length >= 100) return "invalid todo";
		root.todos = root.todos.concat([{ id: Date.now() * 1000 + Math.floor(Math.random() * 1000), text: clean, done: false }]);
		root._save(); return "ok";
	}
	function toggleTodo(id) { root.todos = root.todos.map(t => t.id === id ? Object.assign({}, t, { done: !t.done }) : t); root._save(); }
	function removeTodo(id) { root.todos = root.todos.filter(t => t.id !== id); root._save(); }
	StateFile {
		id: state; name: "calendar"; defaultValue: ({ todos: [], durationSec: 1500, deadlineMs: 0, pausedSec: 1500 })
		onLoadedChanged: if (loaded) {
			const s = Logic.restored(value, Date.now());
			root.todos = s.todos; root.durationSec = s.durationSec; root.deadlineMs = s.deadlineMs; root.pausedSec = s.pausedSec;
			root._schedule();
			if (s.expired) { root._save(); finished.running = true; }
		}
	}
	Timer {
		id: deadlineTimer
		onTriggered: {
			if (root.deadlineMs > Date.now()) { root._schedule(); return; }
			root.deadlineMs = 0; root.pausedSec = 0; root._save();
			finished.running = true;
		}
	}
	Process { id: finished; command: ["notify-send", "-a", "Bloom", "Pomodoro finished", "Time for a break"] }
}
