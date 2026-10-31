import QtTest
import "../../shell/services/performance.js" as Logic

TestCase {
	name: "PerformanceLogic"

	function test_modes() {
		compare(Logic.isLow("off", true), false);
		compare(Logic.isLow("on", false), true);
		compare(Logic.isLow("auto", true), true);
		compare(Logic.isLow("auto", false), false);
	}
}
