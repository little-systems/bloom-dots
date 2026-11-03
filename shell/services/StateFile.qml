import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "state.js" as Logic

// One JSON document of UI state in $XDG_STATE_HOME/bloom/<name>.json (timer,
// dock order, notification history...), kept apart from settings so a
// settings reset never touches it. A corrupt file is moved to
// <name>.json.bak and the default is used, so one bad file can't break a panel.
Scope {
	id: root

	required property string name
	property var defaultValue: ({})
	property var value: root.defaultValue
	property bool loaded: false
	property string error: ""
	property var _committedValue: root.defaultValue
	property var _writingValue
	property bool _writing: false
	property bool _quarantineNeeded: false
	property bool _readBlocked: false
	readonly property string path: Paths.stateFile(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), root.name)

	// A save is held until the file has loaded (so a stale file can't
	// overwrite it) and until a corrupt file has been moved aside (so the
	// move can't take the new file with it).
	property var _pendingValue
	property bool _hasPending: false

	function retry() {
		// FileView caches setText even on failure. Reload the real contents
		// before retrying, or an identical pending value may be skipped.
		if (root._readBlocked || (root.error !== "" && !root._quarantineNeeded)) { file.reload(); return; }
		if (root._quarantineNeeded) {
			if (!backup.running) backup.running = true;
			return;
		}
		root._flush();
	}

	function save(v) {
		root.value = v;
		root._pendingValue = v;
		root._hasPending = true;
		if (root.error !== "") root.retry();
		else root._flush();
	}

	function _flush() {
		if (!root._hasPending || !root.loaded || backup.running || root._writing || root._quarantineNeeded || root._readBlocked)
			return;
		root._writingValue = JSON.parse(Logic.serialize(root._pendingValue));
		root._writing = true;
		root._hasPending = false;
		file.setText(Logic.serialize(root._writingValue));
	}

	FileView {
		id: file
		path: root.path
		atomicWrites: true
		printErrors: false
		onSaved: {
			root._committedValue = root._writingValue;
			if (!root._hasPending) root.value = root._committedValue;
			root._writing = false;
			root.error = "";
			Qt.callLater(root._flush);
		}
		onSaveFailed: code => {
			root._writing = false;
			root.error = "Couldn't save state (error " + code + "); retry after fixing storage";
			if (!root._hasPending) root._pendingValue = root._writingValue;
			root._hasPending = true;
			root.value = root._committedValue;
			console.warn("bloom state: save failed for " + root.name + " (error " + code + ")");
		}

		onLoaded: {
			root._readBlocked = false;
			root.error = "";
			const r = Logic.parse(text());
			root._committedValue = r.ok ? r.value : root.defaultValue;
			if (!r.ok) {
				root._quarantineNeeded = true;
				console.warn("bloom state: " + root.name + " is corrupt; preserving it before any writes");
				backup.running = true;
			}
			if (!root._hasPending)
				root.value = r.ok ? r.value : root.defaultValue;
			root.loaded = true;
			Qt.callLater(root._flush);
		}

		onLoadFailed: error => {
			root._readBlocked = error !== FileViewError.FileNotFound;
			if (root._readBlocked) {
				console.warn(`bloom state: cannot read ${root.path} (error ${error}); using the default`);
				root.error = "State could not be read; writes are blocked until it can be checked";
			}
			if (!root._hasPending)
				root.value = root.defaultValue;
			root.loaded = true;
			Qt.callLater(root._flush);
		}
	}

	Process {
		id: backup
		// Numbered backups keep any earlier .bak instead of replacing it.
		command: ["mv", "-f", "-T", "--backup=numbered", root.path, root.path + ".bak"]
		onExited: code => {
			if (code !== 0) {
				root.error = "Couldn't preserve corrupt state; writes are blocked";
				console.warn("bloom state: quarantine failed for " + root.name + " (exit " + code + ")");
				return;
			}
			root._quarantineNeeded = false;
			root.error = "";
			console.warn("bloom state: " + root.name + " is corrupt; moved to its backup");
			root._flush();
		}
	}
}
