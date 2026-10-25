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

	function save(v) {
		root.value = v;
		file.setText(Logic.serialize(v));
	}

	FileView {
		id: file
		path: root.path
		atomicWrites: true
		printErrors: false

		onLoaded: {
			const r = Logic.parse(text());
			if (r.ok) {
				root.value = r.value;
			} else {
				console.warn(`bloom state: ${root.path} is corrupt (${r.error}); moved to ${root.path}.bak`);
				backup.running = true;
				root.value = root.defaultValue;
			}
			root.loaded = true;
		}

		onLoadFailed: error => {
			if (error !== FileViewError.FileNotFound)
				console.warn(`bloom state: cannot read ${root.path} (error ${error}); using the default`);
			root.value = root.defaultValue;
			root.loaded = true;
		}
	}

	Process {
		id: backup
		command: ["mv", "-f", root.path, root.path + ".bak"]
	}
}
