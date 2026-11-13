import QtTest
import "../../shell/common/motion.js" as Motion

TestCase {
	name: "Motion"

	// Hyprland reloads only when Reduce Motion really changes, never when the
	// shell starts or the settings file first loads.
	function test_reloadNeeded() {
		compare(Motion.reloadNeeded(undefined, false), false);
		compare(Motion.reloadNeeded(undefined, true), false);
		compare(Motion.reloadNeeded(false, false), false);
		compare(Motion.reloadNeeded(false, true), true);
		compare(Motion.reloadNeeded(true, false), true);
	}
}
