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
		compare(Panels.opening("calendar", "devices", false, { calendar: false, "command-center": false, devices: false }), "command-center");
	}
	function test_cycleSkipsDisabledPanels() {
		const enabled = ({ calendar: true, "command-center": false, devices: true });
		compare(Panels.cycle("calendar", 1, enabled), "devices");
		compare(Panels.cycle("calendar", -1, enabled), "devices");
		compare(Panels.cycle("devices", 1, enabled), "calendar");
	}
	// The content's inset from the pill's sides: Bloom's panel content box
	// pads 12 px (its .qp, the Wi-Fi and Bluetooth panels, sits inside it);
	// the Command Center and shelf use 14, the calendar lays out edge to edge.
	function test_insets() {
		compare(Panels.inset("wifi"), 12);
		compare(Panels.inset("bluetooth"), 12);
		compare(Panels.inset("devices"), 12);
		compare(Panels.inset("command-center"), 14);
		compare(Panels.inset("shelf"), 14);
		compare(Panels.inset("calendar"), 0);
	}
	function test_sizes() {
		compare(Panels.size("calendar", 5, 0), { width: 480, height: 273 });
		compare(Panels.size("calendar", 6, 0), { width: 480, height: 305 });
		compare(Panels.size("command-center", 0, 0), { width: 350, height: 230 });
		compare(Panels.size("wifi", 0, 0), { width: 350, height: 300 });
		// Devices: the content's measured height, kept within 150..300.
		compare(Panels.size("devices", 0, 999), { width: 350, height: 300 });
		compare(Panels.size("devices", 0, 99), { width: 350, height: 150 });
		compare(Panels.size("devices", 0, 220.4), { width: 350, height: 221 });
		compare(Panels.size("shelf", 0, 0, 0), { width: 380, height: 130 });
		compare(Panels.size("shelf", 0, 0, 1), { width: 380, height: 176 });
		compare(Panels.size("shelf", 0, 0, 2), { width: 380, height: 190 });
	}
}
