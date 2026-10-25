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
	// FileView only watches a file that existed when it was first read.
	property bool _seenFile: false

	signal settingChanged(string key)

	function get(key) {
		return root.values[key];
	}

	function inputType(key) {
		return Logic.SCHEMA[key]?.type ?? "";
	}

	// Validates and saves one setting. Returns "" on success, else the error.
	function set(key, value) {
		if (!root._fileValid)
			return "settings.json is invalid; fix it before changing settings";
		const r = Logic.validateOne(key, value);
		if (!r.ok)
			return `${key}: ${r.error}`;
		const next = Object.assign({}, root._raw);
		next[key] = r.value;
		file.setText(Logic.serialize(next));
		root._apply(next);
		return "";
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
		atomicWrites: true
		printErrors: false

		onFileChanged: reload()

		onLoaded: {
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
			if (error !== FileViewError.FileNotFound) {
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
