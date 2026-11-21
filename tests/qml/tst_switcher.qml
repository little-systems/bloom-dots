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

	// Each `bloom ipc` is its own process, so messages can land out of order.
	function test_olderMessagesAreDropped() {
		verify(Logic.fresh(1, 0, 0));
		verify(Logic.fresh(5, 4, 10));
		verify(!Logic.fresh(4, 5, 10));
		verify(!Logic.fresh(5, 5, 10));
	}

	// Hyprland's reload restarts the count; by then the last message is old.
	function test_aRestartedCountIsTakenOnceTheLastMessageIsOld() {
		verify(!Logic.fresh(1, 40, Logic.restartAfterMs - 1));
		verify(Logic.fresh(1, 40, Logic.restartAfterMs + 1));
	}
}
