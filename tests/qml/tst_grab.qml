import QtQuick
import QtTest
import "../../shell/modules/grab/grab.js" as Logic

// Where the floating-window grab handle goes and where a drag puts the window.
// Hyprland gives windows in layout pixels; monitors in device pixels.
TestCase {
	name: "GrabLogic"

	readonly property var screen: ({ id: 0, x: 0, y: 0, width: 1920, height: 1080, scale: 1 })
	readonly property var sizes: ({ zoneWidth: 180, zoneHeight: 18, keep: 64 })

	function win(extra) {
		return Object.assign({ address: "0x5586", at: [500, 200], size: [1280, 800], floating: true, fullscreen: 0, monitor: 0, focusHistoryID: 0, mapped: true, hidden: false }, extra || {});
	}

	function test_theFocusedFloatingWindowOnThisScreenGetsTheHandle() {
		const windows = [win({ address: "0xb", focusHistoryID: 1 }), win()];
		compare(Logic.target(windows, 0).address, "0x5586");
		compare(Logic.target(windows, 1), null);
		compare(Logic.target([win({ floating: false })], 0), null);
		compare(Logic.target([win({ fullscreen: 2 })], 0), null);
		compare(Logic.target([win({ hidden: true })], 0), null);
		compare(Logic.target([win({ focusHistoryID: 1 })], 0), null);
		compare(Logic.target([], 0), null);
		compare(Logic.target(null, 0), null);
	}

	function test_theZoneIsCentredOnTheTopEdge() {
		const zone = Logic.zone({ x: 500, y: 200, width: 1280, height: 800 }, screen, sizes);
		compare(zone, { x: 1050, y: 191, width: 180, height: 18 });
	}

	function test_theZoneStaysOnScreenAndFitsANarrowWindow() {
		compare(Logic.zone({ x: 10, y: 4, width: 120, height: 300 }, screen, sizes), { x: 10, y: 0, width: 120, height: 18 });
		// A second screen to the right, at 200%: local coordinates, layout pixels.
		const right = { id: 1, x: 1920, y: 0, width: 2560, height: 1440, scale: 2 };
		compare(Logic.zone({ x: 2020, y: 100, width: 600, height: 400 }, right, sizes), { x: 310, y: 91, width: 180, height: 18 });
	}

	function test_aDragMovesTheWindowWithThePointer() {
		compare(Logic.moved({ x: 500, y: 200 }, { x: 1100, y: 200 }, { x: 1150, y: 260 }, { width: 1280, height: 800 }, screen, sizes), { x: 550, y: 260 });
	}

	function test_aDragKeepsTheTopEdgeReachable() {
		const size = { width: 1280, height: 800 };
		compare(Logic.moved({ x: 500, y: 200 }, { x: 0, y: 0 }, { x: 0, y: -500 }, size, screen, sizes), { x: 500, y: 0 });
		compare(Logic.moved({ x: 500, y: 200 }, { x: 0, y: 0 }, { x: 0, y: 2000 }, size, screen, sizes), { x: 500, y: 1080 - 64 });
		compare(Logic.moved({ x: 500, y: 200 }, { x: 0, y: 0 }, { x: -5000, y: 0 }, size, screen, sizes), { x: 64 - 1280, y: 200 });
		compare(Logic.moved({ x: 500, y: 200 }, { x: 0, y: 0 }, { x: 5000, y: 0 }, size, screen, sizes), { x: 1920 - 64, y: 200 });
	}

	function test_theMoveNamesTheWindow() {
		compare(Logic.dispatch("0x5586", { x: 550, y: 260 }), 'hl.dsp.window.move({ x = 550, y = 260, relative = false, window = "address:0x5586" })');
		compare(Logic.dispatch("5586", { x: 1, y: 2 }), 'hl.dsp.window.move({ x = 1, y = 2, relative = false, window = "address:0x5586" })');
		compare(Logic.dispatch("0x55;rm", { x: 1, y: 2 }), "");
	}
}
