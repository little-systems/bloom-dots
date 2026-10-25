import QtQuick
import QtTest
import "../../shell/common/paths.js" as Paths

TestCase {
	name: "Paths"

	function test_settingsFile() {
		compare(Paths.settingsFile(undefined, "/home/u"), "/home/u/.config/bloom/settings.json");
		compare(Paths.settingsFile("", "/home/u"), "/home/u/.config/bloom/settings.json");
		compare(Paths.settingsFile("/x/cfg", "/home/u"), "/x/cfg/bloom/settings.json");
	}

	function test_stateFile() {
		compare(Paths.stateFile(undefined, "/home/u", "todo"), "/home/u/.local/state/bloom/todo.json");
		compare(Paths.stateFile("/x/st", "/home/u", "dock-order"), "/x/st/bloom/dock-order.json");
	}

	function test_stateFileRejectsPathTricks() {
		let threw = false;
		try { Paths.stateFile(undefined, "/home/u", "../evil"); } catch (e) { threw = true; }
		verify(threw);
	}
}
