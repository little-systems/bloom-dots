import QtQuick
import QtTest
import "../../shell/modules/switcher/switcher.js" as Logic

// What Hyprland's Alt + Tab sends the shell: window addresses, most recent first.
TestCase {
	name: "SwitcherLogic"

	function test_parsesAddressesAndDropsAnythingElse() {
		compare(Logic.parse("0xa1,0xb2,0xc3"), ["0xa1", "0xb2", "0xc3"]);
		compare(Logic.parse("0xa1,,nope,0xZZ,0xb2"), ["0xa1", "0xb2"]);
		compare(Logic.parse(""), []);
	}

	function test_indexStaysInRange() {
		compare(Logic.clamp(1, 3), 1);
		compare(Logic.clamp(7, 3), 2);
		compare(Logic.clamp(-1, 3), 0);
		compare(Logic.clamp(0, 0), 0);
	}

	function test_columnsStopAtTheLimit() {
		compare(Logic.columns(2, 5), 2);
		compare(Logic.columns(5, 5), 5);
		compare(Logic.columns(9, 5), 5);
		compare(Logic.columns(0, 5), 1);
	}
}
