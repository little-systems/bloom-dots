import QtQuick
import QtTest
import "../../shell/settings"

Item {
	id: host; width: 300; height: 100
	QtObject { id: fakeTheme; property color text: "white"; property color textMuted: "gray"; property color groupBg: "#222"; property color border: "#555" }
	Component { id: number; SNumber { theme: fakeTheme; from: 0.1; to: 1; factor: 100; suffix: "%"; value: 0.9 } }
	TestCase {
		name: "ExactNumber"; when: windowShown
		function make() { return createTemporaryObject(number, host); }
		function edited(v) { const s = createTemporaryQmlObject('import QtTest; SignalSpy {}', host); s.target = v; s.signalName = "edited"; return s; }
		function test_exactValuesDoNotSnapToSliderSteps() {
			const v = make(), s = edited(v), field = findChild(v, "numberInput");
			field.forceActiveFocus(); field.text = "97.5"; keyClick(Qt.Key_Return);
			compare(s.count, 1); fuzzyCompare(s.signalArguments[0][0], 0.975, 0.000001);
		}
		function test_outOfRangeAndInvalidTextDoNotWrite() {
			const v = make(), s = edited(v), field = findChild(v, "numberInput");
			field.forceActiveFocus(); field.text = "110"; keyClick(Qt.Key_Return); compare(s.count, 0);
			field.text = "NaN"; verify(!v.commit()); compare(s.count, 0);
			v.cancel(); compare(field.text, "90");
		}
		function test_escapeCancels() {
			const v = make(), s = edited(v), field = findChild(v, "numberInput");
			field.forceActiveFocus(); field.text = "45"; keyClick(Qt.Key_Escape);
			compare(s.count, 0); compare(field.text, "90");
		}
	}
}
