pragma Singleton

import QtQuick
import Quickshell
import "launch.js" as Launch

// Installed apps (desktop entries) for the dock: names, icons and launching.
// Quickshell fills the entry list gradually after start, so `revision` grows
// as it loads; bind to it to re-resolve names and icons.
Singleton {
	id: root

	readonly property int revision: DesktopEntries.applications.values.length

	function idForClass(cls) {
		const e = DesktopEntries.heuristicLookup(cls);
		return e ? e.id : "";
	}

	function exists(id) {
		return !!DesktopEntries.byId(id);
	}

	function info(id) {
		if (id.startsWith("class:")) {
			const cls = id.slice(6);
			return { name: cls, icon: Quickshell.iconPath(cls, true) };
		}
		const e = DesktopEntries.byId(id);
		return e ? { name: e.name, icon: Quickshell.iconPath(e.icon, true) } : { name: id, icon: "" };
	}

	function launch(id) {
		const e = DesktopEntries.byId(id);
		if (!e || e.command.length === 0)
			return false;
		root.run(e.command, id, e.runInTerminal, e.workingDirectory);
		return true;
	}

	function run(command, name, terminal, workingDirectory) {
		const context = { command: Launch.argv(command, Launch.unitName(name, Date.now()), !!terminal) };
		if (workingDirectory)
			context.workingDirectory = workingDirectory;
		Quickshell.execDetached(context);
	}
}
