import QtQuick
import QtTest
import "../../shell/modules/notch/panels.js" as Panels

TestCase {
	name: "PanelRules"
	function test_openingAndMemory() {
		const enabled = ({ calendar: true, "command-center": true, devices: false });
		compare(Panels.opening("command-center", "calendar", true, enabled), "command-center");
		compare(Panels.opening("devices", "calendar", true, enabled), "calendar");
		compare(Panels.opening("command-center", "calendar", false, enabled), "calendar");
		compare(Panels.opening("calendar", "devices", false, { calendar: false, "command-center": false, devices: false }), "");
	}
	function test_cycleSkipsDisabledPanels() {
		const enabled = ({ calendar: true, "command-center": false, devices: true });
		compare(Panels.cycle("calendar", 1, enabled), "devices");
		compare(Panels.cycle("calendar", -1, enabled), "devices");
		compare(Panels.cycle("devices", 1, enabled), "calendar");
	}
	function test_sizes() {
		compare(Panels.size("calendar", 5, 0), { width: 480, height: 273 });
		compare(Panels.size("calendar", 6, 0), { width: 480, height: 305 });
		compare(Panels.size("command-center", 0, 0), { width: 350, height: 230 });
		compare(Panels.size("wifi", 0, 0), { width: 350, height: 300 });
		compare(Panels.size("devices", 0, 99), { width: 350, height: 300 });
		compare(Panels.size("shelf", 0, 0, 0), { width: 380, height: 130 });
		compare(Panels.size("shelf", 0, 0, 1), { width: 380, height: 176 });
		compare(Panels.size("shelf", 0, 0, 2), { width: 380, height: 190 });
	}
}
