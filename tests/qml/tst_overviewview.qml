import QtQuick
import QtTest
import "../../shell/modules/overview"
import "../../shell/common/tokens.js" as Tokens

// The workspace overview: a grid of workspaces with their windows; click to
// go, drag to move, type to find, keys to walk the grid.
Item {
	id: host
	width: 1100
	height: 700

	readonly property var monitor: ({ x: 0, y: 0, width: 1920, height: 1080, scale: 1 })
	readonly property var clients: [
		{ address: "0xa", workspace: { id: 1 }, at: [0, 0], size: [960, 1080], title: "Editor", class: "code", mapped: true },
		{ address: "0xb", workspace: { id: 1 }, at: [960, 0], size: [960, 1080], title: "Terminal", class: "kitty", mapped: true },
		{ address: "0xc", workspace: { id: 3 }, at: [100, 100], size: [800, 600], title: "Music", class: "spotify", mapped: true }
	]

	Component {
		id: viewComponent
		OverviewView { width: 1100; height: 700; clients: host.clients; monitor: host.monitor; activeWorkspace: 3 }
	}

	TestCase {
		name: "OverviewView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			v.open();
			tryCompare(findChild(v, "card"), "scale", 1, 1500);
			waitForRendering(host);
			return v;
		}
		function part(v, name) {
			tryVerify(() => findChild(v, name) !== null, 1000, name);
			return findChild(v, name);
		}
		function centre(it) { return it.mapToItem(host, it.width / 2, it.height / 2); }
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_gridOfEight() {
			const v = make();
			for (let i = 1; i <= 8; i++) part(v, "workspace:" + i);
			compare(part(v, "workspace:1").width, Tokens.overview.cell);
			compare(part(v, "workspace:1").height, Math.round(Tokens.overview.cell * 9 / 16));
			verify(part(v, "workspace:3").active, "the active workspace is marked");
			verify(!part(v, "workspace:1").active);
			const card = part(v, "card");
			fuzzyCompare(card.x + card.width / 2, 550, 0.51);
		}

		function test_windowsSitWhereTheyAre() {
			const v = make();
			const w = part(v, "window:0xb");
			const cell = part(v, "workspace:1");
			compare(w.parent.parent !== undefined, true);
			fuzzyCompare(w.mapToItem(cell, 0, 0).x, cell.width / 2, 0.51);
			fuzzyCompare(w.width, cell.width / 2, 0.51);
			fuzzyCompare(w.height, cell.height, 0.51);
		}

		// A full-screen window covers its cell: the highlight and the number
		// stay readable above it.
		function test_highlightAndNumberSitAboveWindows() {
			const v = make();
			const cell = part(v, "workspace:3");
			const frame = findChild(cell, "frame");
			verify(frame, "a frame");
			compare(frame.border.width, 2, "the active workspace");
			compare(findChild(part(v, "workspace:6"), "frame").border.width, 0);
			const chip = findChild(cell, "number");
			verify(chip, "a number chip");
			compare(chip.color.a, 0.55);
			const kids = Array.from(cell.children);
			verify(kids.indexOf(frame) > kids.findIndex(k => String(k).includes("Repeater") || k.objectName.startsWith("window:")), "the frame draws after the windows");
		}

		function test_clickGoes() {
			const v = make();
			const ws = spy(v, "workspaceChosen"), win = spy(v, "windowChosen");
			let p = centre(part(v, "window:0xc"));
			mouseClick(host, p.x, p.y);
			compare(win.signalArguments[0][0], "0xc");
			p = centre(part(v, "workspace:6"));
			mouseClick(host, p.x, p.y);
			compare(ws.signalArguments[0][0], 6);
		}

		function test_dragMovesAWindow() {
			const v = make();
			const moved = spy(v, "windowMoved"), win = spy(v, "windowChosen");
			const from = centre(part(v, "window:0xa"));
			const to = centre(part(v, "workspace:6"));
			mousePress(host, from.x, from.y);
			mouseMove(host, from.x + 20, from.y + 20);
			verify(part(v, "ghost").visible, "a ghost follows the pointer");
			mouseMove(host, to.x, to.y);
			mouseRelease(host, to.x, to.y);
			compare(moved.count, 1);
			compare(Array.from(moved.signalArguments[0]), ["0xa", 6]);
			compare(win.count, 0, "a drag isn't a click");
			verify(!part(v, "ghost").visible);
		}

		function test_dropOnItsOwnWorkspaceDoesNothing() {
			const v = make();
			const moved = spy(v, "windowMoved");
			const from = centre(part(v, "window:0xa"));
			mousePress(host, from.x, from.y);
			mouseMove(host, from.x + 30, from.y);
			mouseRelease(host, from.x + 30, from.y);
			compare(moved.count, 0);
		}

		function test_searchDimsTheRest() {
			const v = make();
			part(v, "field").text = "kitty";
			compare(part(v, "window:0xb").opacity, 1);
			compare(part(v, "window:0xa").opacity, Tokens.overview.dimmed);
			const win = spy(v, "windowChosen");
			tryVerify(() => part(v, "field").activeFocus, 500);
			keyClick(Qt.Key_Return);
			compare(win.signalArguments[0][0], "0xb", "Enter goes to the first match");
		}

		function test_keysWalkTheGrid() {
			const v = make();
			const ws = spy(v, "workspaceChosen"), dismissed = spy(v, "dismissed");
			tryVerify(() => part(v, "field").activeFocus, 500);
			compare(v.selectedIndex, 2, "starts on the active workspace");
			keyClick(Qt.Key_Right);
			compare(v.selectedIndex, 3);
			keyClick(Qt.Key_Down);
			compare(v.selectedIndex, 7);
			keyClick(Qt.Key_Return);
			compare(ws.signalArguments[0][0], 8);
			keyClick(Qt.Key_Escape);
			compare(dismissed.count, 1);
		}

		function test_outsideDismisses() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			mouseClick(host, 10, 690);
			compare(dismissed.count, 1);
		}
	}
}
