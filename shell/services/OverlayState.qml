pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The overlay's state: opened, the crosshair (which stays on after closing, for
// games) and notes, kept in a plain file under Bloom's state folder.
Singleton {
	id: root

	property bool opened: false
	property bool crosshair: false
	property string notes: ""
	readonly property string _file: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/bloom/overlay-notes.txt"

	function toggle() { root.opened = !root.opened; }
	function hide() { root.opened = false; }
	function setNotes(text) {
		root.notes = text;
		saveTimer.restart();
	}

	Timer {
		id: saveTimer
		interval: 500
		onTriggered: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "sh", root._file, root.notes])
	}
	Process {
		running: true
		command: ["cat", root._file]
		stdout: StdioCollector { onStreamFinished: root.notes = text }
	}
}
