import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "state.js" as Logic

// One JSON document of UI state in $XDG_STATE_HOME/bloom/<name>.json (todos,
// dock order, notification history...), kept apart from settings so a
// settings reset never touches it. A corrupt file is moved to
// <name>.json.bak and the default is used, so one bad file can't break a panel.
Scope {
	id: root

	required property string name
	property var defaultValue: ({})
	property var value: root.defaultValue
	property bool loaded: false
	readonly property string path: Paths.stateFile(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), root.name)

	// A save is held until the file has loaded (so a stale file can't
	// overwrite it) and until a corrupt file has been moved aside (so the
	// move can't take the new file with it).
	property var _pendingValue
	property bool _hasPending: false

	function save(v) {
		root.value = v;
		root._pendingValue = v;
		root._hasPending = true;
		root._flush();
	}

	function _flush() {
		if (!root._hasPending || !root.loaded || backup.running)
			return;
		root._hasPending = false;
		file.setText(Logic.serialize(root._pendingValue));
	}

	FileView {
		id: file
		path: root.path
		atomicWrites: true
		printErrors: false

		onLoaded: {
			const r = Logic.parse(text());
			if (!r.ok) {
				console.warn(`bloom state: ${root.path} is corrupt (${r.error}); moved to ${root.path}.bak`);
				backup.running = true;
			}
			if (!root._hasPending)
				root.value = r.ok ? r.value : root.defaultValue;
			root.loaded = true;
			root._flush();
		}

		onLoadFailed: error => {
			if (error !== FileViewError.FileNotFound)
				console.warn(`bloom state: cannot read ${root.path} (error ${error}); using the default`);
			if (!root._hasPending)
				root.value = root.defaultValue;
			root.loaded = true;
			root._flush();
		}
	}

	Process {
		id: backup
		// Numbered backups keep any earlier .bak instead of replacing it.
		command: ["mv", "-f", "--backup=numbered", root.path, root.path + ".bak"]
		onExited: root._flush()
	}
}
