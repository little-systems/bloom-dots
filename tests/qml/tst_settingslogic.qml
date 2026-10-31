import QtTest
import "../../shell/settings/logic.js" as Logic

TestCase {
	name: "SettingsLogic"

	readonly property var config: ({ left: ["weather", "cpu"], right: ["battery"] })

	function test_pool() {
		compare(Logic.pool(config), ["ram", "disk", "net"]);
	}
	function test_remove() {
		compare(Logic.remove(config, "cpu"), { left: ["weather"], right: ["battery"] });
	}
	function test_swap() {
		compare(Logic.swapSide(config, "cpu"), { left: ["weather"], right: ["battery", "cpu"] });
		compare(Logic.swapSide(config, "battery"), { left: ["weather", "cpu", "battery"], right: [] });
	}
	function test_moveInSide() {
		compare(Logic.moveInSide(config, "cpu", -1).left, ["cpu", "weather"]);
		compare(Logic.moveInSide(config, "weather", -1), config);
		compare(Logic.moveInSide(config, "battery", 1), config);
	}
	function test_place() {
		compare(Logic.place(config, "ram", "right"), { left: ["weather", "cpu"], right: ["battery", "ram"] });
		compare(Logic.place(config, "ram", "left", 0).left, ["ram", "weather", "cpu"]);
		compare(Logic.place(config, "cpu", "right"), { left: ["weather"], right: ["battery", "cpu"] });
	}
	function test_lists() {
		compare(Logic.parseList('["a"]'), ["a"]);
		compare(Logic.parseList("nope"), []);
		compare(Logic.parseList("{}"), []);
		compare(Logic.toggled(["a"], "b"), ["a", "b"]);
		compare(Logic.toggled(["a", "b"], "a"), ["b"]);
		compare(Logic.folderList("a,b"), ["a", "b"]);
		compare(Logic.folderList(""), []);
	}
	function test_enabledPanels() {
		compare(Logic.enabledPanels(true, false, true), 2);
	}
}
