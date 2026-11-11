import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "state.js" as Logic

// One JSON document of UI state in $XDG_STATE_HOME/bloom/<name>.json (timer,
// dock order, notification history...), kept apart from settings so a
// settings reset never touches it. The shell is the only cooperating writer.
//
// A file that is too large, malformed or the wrong shape (`validate`) is moved
// to <name>.json.bak, keeping the three newest backups, and the default is used,
// so one bad file can't break a panel. A file another program replaces while
// Bloom runs is adopted: `value` follows it, `externallyChanged` fires, and a
// save not yet written is dropped rather than overwriting the newer file.
// errorKind: "" | "unreadable" | "malformed" | "invalid" | "too-large" |
// "unwritable" | "external" | "quarantine-failed".
Scope {
	id: root

	required property string name
	property var defaultValue: ({})
	// Returns the (possibly normalized) value, or undefined if it is invalid.
	property var validate: null
	property int maxBytes: 262144
	property var value: root.defaultValue
	property bool loaded: false
	property string error: ""
	property string errorKind: ""
	signal externallyChanged()
	property var _committedValue: root.defaultValue
	property bool _committedOnDisk: false
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

	function _fail(kind, message) {
		root.errorKind = kind;
		root.error = message;
	}

	function _clear() {
		root.errorKind = "";
		root.error = "";
	}

	function retry() {
		// FileView caches setText even on failure. Reload the real contents
		// before retrying, or an identical pending value may be skipped.
		if (root._readBlocked || (root.error !== "" && !root._quarantineNeeded && root.errorKind !== "too-large" && root.errorKind !== "invalid")) { file.reload(); return; }
		if (root._quarantineNeeded) {
			if (!backup.running) backup.running = true;
			return;
		}
		root._flush();
	}

	function save(v) {
		let snapshot;
		try {
			snapshot = JSON.parse(Logic.serialize(v));
		} catch (e) {
			root._fail("invalid", "State is not serializable; the last saved value was retained");
			console.warn("bloom state: invalid save request for " + root.name);
			return false;
		}
		if (root.maxBytes > 0 && Logic.utf8Bytes(Logic.serialize(snapshot)) > root.maxBytes) {
			root._fail("too-large", "State is larger than " + root.maxBytes + " bytes; the last saved value was retained");
			console.warn("bloom state: save for " + root.name + " exceeds its size budget");
			return false;
		}
		const shaped = Logic.accept(snapshot, root.validate);
		if (!shaped.ok) {
			root._fail("invalid", "State has an unexpected shape; the last saved value was retained");
			console.warn("bloom state: save for " + root.name + " has an unexpected shape");
			return false;
		}
		root.value = shaped.value;
		root._pendingValue = shaped.value;
		root._hasPending = true;
		if (root.error !== "") root.retry();
		else root._flush();
		return true;
	}

	function _flush() {
		if (!root._hasPending || !root.loaded || backup.running || root._writing || root._quarantineNeeded || root._readBlocked)
			return;
		root._writingValue = JSON.parse(Logic.serialize(root._pendingValue));
		if (root._committedOnDisk && Logic.serialize(root._writingValue) === Logic.serialize(root._committedValue)) {
			root._hasPending = false;
			root._clear();
			root.value = root._committedValue;
			return;
		}
		root._writing = true;
		root._hasPending = false;
		file.setText(Logic.serialize(root._writingValue));
	}

	// Called for the first load and every reload after the file changes.
	function _adopt(text) {
		const first = !root.loaded;
		const r = Logic.check(text, root.maxBytes, root.validate);
		if (!first && r.ok) {
			// Compare values, not text: formatting differences aren't changes.
			const seen = Logic.serialize(r.value);
			if (root._writing && seen === Logic.serialize(root._writingValue)) return;
			if (root._committedOnDisk && seen === Logic.serialize(root._committedValue)) {
				// Unchanged: our own write, or a retry's reload. Resume held writes.
				root._readBlocked = false;
				if (root.errorKind === "unwritable" || root.errorKind === "unreadable") root._clear();
				Qt.callLater(root._flush);
				return;
			}
		}
		root._readBlocked = false;
		root._clear();
		root._committedValue = r.ok ? r.value : root.defaultValue;
		root._committedOnDisk = r.ok;
		if (!r.ok) {
			root._quarantineNeeded = true;
			console.warn(`bloom state: ${root.name} is corrupt (${r.kind}: ${r.error}); preserving it before any writes`);
			if (!backup.running) backup.running = true;
		}
		if (!first && root._hasPending) {
			// The newer file wins over a local change that hasn't been written.
			root._hasPending = false;
			if (r.ok) root._fail("external", "State changed outside Bloom; the newer file was kept");
		}
		if (!root._hasPending)
			root.value = r.ok ? r.value : root.defaultValue;
		if (!r.ok) root._fail(r.kind, "State was " + r.kind + " and was set aside; the default is in use");
		root.loaded = true;
		if (!first) {
			console.info("bloom state: " + root.name + " changed outside Bloom; reloaded");
			root.externallyChanged();
		}
		Qt.callLater(root._flush);
	}

	FileView {
		id: file
		path: root.path
		atomicWrites: true
		printErrors: false
		watchChanges: true
		onFileChanged: reload()
		onSaved: {
			root._committedValue = root._writingValue;
			root._committedOnDisk = true;
			if (!root._hasPending) root.value = root._committedValue;
			root._writing = false;
			root._clear();
			Qt.callLater(root._flush);
		}
		onSaveFailed: code => {
			root._writing = false;
			root._fail("unwritable", "Couldn't save state (error " + code + "); retry after fixing storage");
			if (!root._hasPending) root._pendingValue = root._writingValue;
			root._hasPending = true;
			root.value = root._committedValue;
			console.warn("bloom state: save failed for " + root.name + " (error " + code + ")");
		}

		onLoaded: root._adopt(text())

		onLoadFailed: error => {
			const first = !root.loaded;
			root._committedOnDisk = false;
			root._readBlocked = error !== FileViewError.FileNotFound;
			if (root._readBlocked) {
				console.warn(`bloom state: cannot read ${root.path} (error ${error}); using the default`);
				root._fail("unreadable", "State could not be read; writes are blocked until it can be checked");
			}
			if (!root._hasPending)
				root.value = root.defaultValue;
			root.loaded = true;
			if (!first && !root._writing) root.externallyChanged();
			Qt.callLater(root._flush);
		}
	}

	Process {
		id: backup
		// Numbered backups keep any earlier .bak instead of replacing it; only
		// the newest .bak and two numbered ones are kept. Pruning can't fail it.
		command: ["sh", "-c", "mv -f -T --backup=numbered \"$1\" \"$1.bak\" || exit 1; "
			+ "ls -1d -- \"$1\".bak.~*~ 2>/dev/null | sort -t '~' -k 2 -n | head -n -2 | while IFS= read -r f; do rm -f -- \"$f\"; done; exit 0",
			"sh", root.path]
		onExited: code => {
			if (code !== 0) {
				root._fail("quarantine-failed", "Couldn't preserve damaged state; writes are blocked");
				console.warn("bloom state: quarantine failed for " + root.name + " (exit " + code + ")");
				return;
			}
			root._quarantineNeeded = false;
			console.warn("bloom state: " + root.name + " was set aside in its backup");
			root._flush();
		}
	}
}
