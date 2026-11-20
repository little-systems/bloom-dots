pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../common/i18n"
import "taskmanager.js" as Logic

// The default task manager (owner: Mission Center, bundled), opened from the
// dock's menu, Ctrl+Shift+Esc and the Command Center.
Singleton {
	id: root

	readonly property var entries: (Apps.revision, DesktopEntries.applications.values.map(e => ({
		id: e.id, name: e.name, categories: e.categories, noDisplay: e.noDisplay })))
	readonly property string chosen: Logic.choose(Settings.values["bloom-task-manager"], root.entries)

	// "ok", or "none" (and a notification saying so) when nothing is installed.
	function open() {
		if (root.chosen === "") {
			notice.running = true;
			return "none";
		}
		Apps.launch(root.chosen);
		return "ok";
	}

	Process {
		id: notice
		command: ["timeout", "-k", "1s", "5s", "notify-send", "-a", "Bloom",
			I18n.t("linux.taskManager.noneTitle"), I18n.t("linux.taskManager.noneBody")]
	}
}
