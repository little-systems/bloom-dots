import QtTest
import "../../shell/services/taskmanager.js" as TaskManager

// Owner: a default task manager (Mission Center unless changed), opened from
// the dock, Ctrl+Shift+Esc and the Command Center.
TestCase {
	name: "TaskManager"

	readonly property var entries: [
		{ id: "org.gnome.Calculator", name: "Calculator", categories: ["Utility"], noDisplay: false },
		{ id: "htop", name: "Htop", categories: ["System", "Monitor", "ConsoleOnly"], noDisplay: false },
		{ id: "io.missioncenter.MissionCenter", name: "Mission Center", categories: ["GTK", "System", "Monitor"], noDisplay: false },
		{ id: "hidden-monitor", name: "Hidden", categories: ["Monitor"], noDisplay: true }
	]

	function test_theChosenAppWhenInstalled() {
		compare(TaskManager.choose("htop", entries), "htop");
		compare(TaskManager.choose("io.missioncenter.MissionCenter", entries), "io.missioncenter.MissionCenter");
	}

	function test_aMissingChoiceFallsBackToAnInstalledMonitor() {
		compare(TaskManager.choose("gone.app", entries), "htop", "the first by name");
		compare(TaskManager.choose("", entries), "htop");
	}

	function test_noTaskManagerInstalled() {
		compare(TaskManager.choose("io.missioncenter.MissionCenter", [entries[0], entries[3]]), "");
	}

	function test_choicesAreVisibleMonitors() {
		compare(TaskManager.choices(entries, "htop"), [{ value: "htop", label: "Htop" }, { value: "io.missioncenter.MissionCenter", label: "Mission Center" }]);
		compare(TaskManager.choices(entries, "custom.app"), [{ value: "htop", label: "Htop" }, { value: "io.missioncenter.MissionCenter", label: "Mission Center" }, { value: "custom.app", label: "custom.app" }],
			"a current value outside the list is kept");
		compare(TaskManager.choices(entries, ""), [{ value: "htop", label: "Htop" }, { value: "io.missioncenter.MissionCenter", label: "Mission Center" }]);
	}
}
