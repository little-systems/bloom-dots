pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/cheatsheet/cheatsheet.js" as Logic

// The keybind cheatsheet: the compositor's binds, read each time it opens so
// it never goes stale.
Singleton {
	id: root

	property bool opened: false
	property var groups: []

	function show() {
		root.opened = true;
		if (!binds.running) binds.running = true;
	}
	function hide() { root.opened = false; }
	function toggle() { if (root.opened) root.hide(); else root.show(); }

	Process {
		id: binds
		command: ["hyprctl", "binds", "-j"]
		stdout: StdioCollector {
			onStreamFinished: root.groups = Logic.parse(text)
		}
	}
}
