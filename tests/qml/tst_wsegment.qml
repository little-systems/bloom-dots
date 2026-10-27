import QtQuick
import QtTest
import "../../shell/modules/dock"
import "../../shell/modules/dock/dock.js" as Dock

Item {
	id: host
	width: 400
	height: 200

	Component {
		id: segComponent
		WorkspaceSegment {
			x: 50
			y: 100
			cells: Dock.workspaceCells([{ id: 1, name: "1" }, { id: 2, name: "2" }, { id: 3, name: "3" }], 2)
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "WorkspaceSegment"
		when: windowShown

		function make() {
			mouseMove(host, 0, 0);
			const s = createTemporaryObject(segComponent, host);
			verify(s !== null);
			return s;
		}

		function test_size() {
			const s = make();
			compare(s.width, Dock.segmentWidth(3));
			compare(s.height, 36);
		}

		function test_highlightSprings() {
			const s = make();
			const hl = findChild(s, "ws-highlight");
			const cell = id => findChild(s, "ws-cell-" + id);
			compare(hl.x, cell(2).x, "starts on the active cell");
			s.cells = Dock.workspaceCells([{ id: 1, name: "1" }, { id: 2, name: "2" }, { id: 3, name: "3" }], 3);
			verify(Math.abs(hl.x - cell(2).x) < 1, "springs, not jumps");
			tryVerify(() => Math.abs(hl.x - cell(3).x) < 0.5, 1500);
		}

		function test_clickSwitches() {
			const s = make();
			const sw = createTemporaryObject(spyComponent, host, { target: s, signalName: "switchTo" });
			mouseClick(findChild(s, "ws-cell-3"), 12, 12);
			compare(sw.count, 1);
			compare(sw.signalArguments[0][0].id, 3);
		}

		function test_wheelSteps() {
			const s = make();
			const step = createTemporaryObject(spyComponent, host, { target: s, signalName: "step" });
			mouseWheel(s, 20, 18, 0, -120);
			compare(step.signalArguments[0][0], 1, "wheel down: next workspace");
			mouseWheel(s, 20, 18, 0, 120);
			compare(step.signalArguments[1][0], -1);
		}

		// Review M5: a touchpad sends many small deltas; only a full notch
		// (120) steps, and a sideways scroll doesn't step at all.
		function test_wheelAccumulates() {
			const s = make();
			const step = createTemporaryObject(spyComponent, host, { target: s, signalName: "step" });
			mouseWheel(s, 20, 18, 0, -40);
			mouseWheel(s, 20, 18, 0, -40);
			compare(step.count, 0, "two thirds of a notch");
			mouseWheel(s, 20, 18, 0, -40);
			compare(step.count, 1);
			mouseWheel(s, 20, 18, -120, 0);
			compare(step.count, 1, "sideways");
		}

		function test_rightClickAsksForTheMenu() {
			const s = make();
			const menu = createTemporaryObject(spyComponent, host, { target: s, signalName: "menuRequested" });
			mouseClick(s, 20, 18, Qt.RightButton);
			compare(menu.count, 1);
		}
	}
}
