pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "settings.js" as Logic

// Live settings from $XDG_CONFIG_HOME/bloom/settings.json. `values` always
// holds every schema key (invalid or missing ones take defaults), and hand
// edits apply immediately. A file with a syntax error is ignored, keeping the
// last good settings, and is never overwritten.
Singleton {
	id: root

	readonly property string path: Paths.settingsFile(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"))
	property var values: Logic.defaults()
	property var warnings: []

	// Last parsed file contents, unknown keys included, so a write never drops
	// keys this version doesn't know.
	property var _raw: ({})
	property bool _fileValid: true
	property bool _loaded: false
	// FileView only watches a file that existed when it was first read.
	property bool _seenFile: false
	property string saveError: ""

	signal settingChanged(string key)

	function get(key) {
		return root.values[key];
	}

	function inputType(key) {
		return Logic.SCHEMA[key]?.type ?? "";
	}

	// Accepted requests return a pending ticket, never a durability claim.
	readonly property string _writerId: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
	property int _sequence: 0
	property var _queue: []
	property var _results: ({})
	property var _current: null
	property string _reply: ""
	property string revision: ""
	signal writeFinished(string ticket, string error)
	function set(key, value, completed) { return root.setMany({ [key]: value }, completed); }
	function _complete(callback, error) {
		if (typeof callback !== "function") return;
		try { callback(error); } catch (e) { console.warn("bloom settings: completion listener unavailable"); }
	}
	function result(ticket) { return root._results[ticket] || { state: "unknown", error: "unknown settings operation" }; }
	function setMany(changes, completed) {
		if (!root._loaded) file.waitForJob();
		let error = root._loaded ? "" : "Settings are still loading; retry";
		const patch = {};
		if (error === "" && (changes === null || typeof changes !== "object" || Array.isArray(changes))) error = "settings changes must be an object";
		else if (error === "") for (const key of Object.keys(changes)) {
			const checked = Logic.validateOne(key, changes[key]);
			if (!checked.ok) { error = key + ": " + checked.error; break; }
			patch[key] = checked.value;
		}
		if (error !== "") { root.saveError = error; root._complete(completed, error); return error; }
		if (root._queue.length >= 32) {
			error = "Settings writer is busy; wait for pending saves before retrying";
			root.saveError = error; root._complete(completed, error); return error;
		}
		const base = JSON.parse(JSON.stringify(root._raw));
		// Scalar controls express a new absolute value, so later local intents
		// can follow earlier queued values. Composite read/modify/write values
		// keep their original base and must conflict instead of losing edits.
		for (const pending of [root._current].concat(root._queue)) {
			if (!pending) continue;
			for (const key of Object.keys(patch)) {
				if (["number", "bool", "enum", "color"].indexOf(root.inputType(key)) >= 0 && key in pending.changes)
					base[key] = pending.changes[key];
			}
		}
		const ticket = "settings-" + root._writerId + "-" + (++root._sequence);
		root._results[ticket] = { state: "pending", error: "" };
		root._queue = root._queue.concat([{ ticket: ticket, changes: patch, base: base, completed: completed }]);
		root._startNext();
		return "pending:" + ticket;
	}
	function _startNext() {
		if (root._current || writer.running || root._queue.length === 0) return;
		root._current = root._queue[0]; root._queue = root._queue.slice(1);
		root._reply = ""; root.saveError = "";
		writer.stdinEnabled = true; writer.running = true; writeDeadline.restart();
	}
	function _finish(error, reply) {
		const operation = root._current;
		if (!operation) return;
		writeDeadline.stop(); root.saveError = error;
		if (error !== "") console.warn("bloom settings: commit not confirmed; reloading storage");
		if (reply && reply.ok) { root.revision = reply.revision; root._apply(reply.value); }
		root._results[operation.ticket] = { state: error === "" ? "succeeded" : "failed", error: error, revision: root.revision };
		const keys = Object.keys(root._results);
		keys.slice(0, Math.max(0, keys.length - 64)).forEach(key => delete root._results[key]);
		root._current = null;
		file.reload();
		Qt.callLater(root._startNext);
		root.writeFinished(operation.ticket, error);
		root._complete(operation.completed, error);
	}
	Process {
		id: writer
		command: ["python3", decodeURIComponent(Qt.resolvedUrl("settings-store.py").toString().replace("file://", "")), root.path]
		stdinEnabled: true
		onStarted: { if (!root._current) { writer.kill(); return; } writer.write(JSON.stringify({ changes: root._current.changes, base: root._current.base }) + "\n"); writer.stdinEnabled = false; }
		stdout: StdioCollector { onStreamFinished: root._reply = text }
		onExited: code => Qt.callLater(() => {
			let reply;
			try { reply = JSON.parse(root._reply); } catch (e) {}
			root._finish(reply?.ok === true && code === 0 ? "" : (reply?.error || "Settings write was not confirmed; reload before retrying"), reply?.ok === true && code === 0 ? reply : null);
			Qt.callLater(root._startNext);
		})
	}
	Timer {
		id: writeDeadline
		interval: 3000
		onTriggered: { writer.kill(); root._finish("Settings write timed out; reload before retrying", null); }
	}

	function nonDefaults() {
		return Logic.nonDefaults(root.values);
	}

	function _apply(obj) {
		const res = Logic.validate(obj);
		const old = root.values;
		root._raw = obj;
		root.values = res.values;
		root.warnings = res.warnings;
		res.warnings.forEach(w => console.warn("bloom settings:", w));
		Logic.changedKeys(old, res.values).forEach(k => root.settingChanged(k));
	}

	FileView {
		id: file
		path: root.path
		watchChanges: true
		printErrors: false

		onFileChanged: reload()

		onLoaded: {
			root._loaded = true;
			root._seenFile = true;
			const r = Logic.parse(text());
			// Valid JSON that isn't an object (a string, a list) is treated like a
			// syntax error, so a write never builds on it or replaces it.
			const isObject = r.ok && r.value !== null && typeof r.value === "object" && !Array.isArray(r.value);
			root._fileValid = isObject;
			if (isObject)
				root._apply(r.value);
			else if (r.ok)
				console.warn(`bloom settings: ${root.path} is not a JSON object; keeping the last good settings`);
			else
				console.warn(`bloom settings: ${root.path} is not valid JSON (${r.error}); keeping the last good settings`);
		}

		onLoadFailed: error => {
			root._loaded = true;
			if (error !== FileViewError.FileNotFound) {
				root._fileValid = false;
				console.warn(`bloom settings: cannot read ${root.path} (error ${error}); keeping the last good settings`);
				return;
			}
			root._fileValid = true;
			// Deleting the file resets to defaults; a file that never existed
			// already has them.
			if (root._seenFile)
				root._apply({});
		}
	}

	// First run: poll until settings.json appears, then the watch takes over.
	Timer {
		interval: 2000
		repeat: true
		running: !root._seenFile
		onTriggered: file.reload()
	}
}
