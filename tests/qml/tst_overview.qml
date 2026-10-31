import QtQuick
import QtTest
import "../../shell/modules/overview/overview.js" as Overview

TestCase {
	name: "OverviewRules"

	readonly property var monitor: ({ name: "eDP-1", x: 1920, y: 0, width: 1920, height: 1080, scale: 1, activeWorkspace: { id: 3 } })
	function client(address, ws, x, y, w, h, title, cls) {
		return { address, workspace: { id: ws }, at: [x, y], size: [w, h], title: title || "", class: cls || "", monitor: 0, mapped: true };
	}

	// Pages of eight, on the page holding the active workspace.
	function test_pages() {
		compare(Overview.page(1), [1, 2, 3, 4, 5, 6, 7, 8]);
		compare(Overview.page(8), [1, 2, 3, 4, 5, 6, 7, 8]);
		compare(Overview.page(9), [9, 10, 11, 12, 13, 14, 15, 16]);
	}

	// A window at its place on the monitor, scaled into a workspace's cell.
	function test_windowRect() {
		const r = Overview.windowRect(client("0x1", 1, 1920 + 960, 540, 960, 540), monitor, 192, 108);
		compare([r.x, r.y, r.width, r.height], [96, 54, 96, 54]);
	}

	function test_groupsByWorkspace() {
		const g = Overview.byWorkspace([client("0x1", 1, 0, 0, 1, 1), client("0x2", 2, 0, 0, 1, 1), client("0x3", 1, 0, 0, 1, 1), client("0x4", -99, 0, 0, 1, 1)]);
		compare(g[1].map(c => c.address), ["0x1", "0x3"]);
		compare(g[2].length, 1);
		compare(g[-99], undefined, "special workspaces stay out");
	}

	function test_search() {
		const cs = [client("0x1", 1, 0, 0, 1, 1, "Overview | StockSync", "zen"), client("0x2", 2, 0, 0, 1, 1, "Terminal", "kitty")];
		compare(Overview.matches(cs, "kitty").map(c => c.address), ["0x2"]);
		compare(Overview.matches(cs, "STOCK").map(c => c.address), ["0x1"]);
		compare(Overview.matches(cs, "").length, 0, "no term, nothing to highlight");
	}

	function test_keyboardGrid() {
		compare(Overview.step(0, "right"), 1);
		compare(Overview.step(3, "right"), 0, "wraps in its row");
		compare(Overview.step(0, "left"), 3);
		compare(Overview.step(1, "down"), 5);
		compare(Overview.step(5, "down"), 1);
		compare(Overview.step(5, "up"), 1);
	}

	// A dispatch moves the window and stays where you are.
	function test_moveCommand() {
		compare(Overview.moveArg("0x55ab", 4), 'hl.dsp.window.move({ workspace = 4, follow = false, window = "address:0x55ab" })');
		compare(Overview.moveArg("bad; rm", 4), "");
		compare(Overview.moveArg("0x55ab", "4; x"), "");
	}
}
