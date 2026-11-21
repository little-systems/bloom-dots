import QtQuick
import QtTest
import "../../shell/modules/grab"

// The floating-window grab handle: a pill that shows while the pointer is in
// its zone or dragging, and reports the drag in its window's coordinates.
Item {
	id: host
	width: 800
	height: 600

	Component {
		id: handleComponent
		GrabHandle { x: 300; y: 100; width: 180; height: 18 }
	}
	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "GrabHandle"
		when: windowShown

		function make() {
			const h = createTemporaryObject(handleComponent, host);
			verify(h);
			return h;
		}
		function spy(target, signal) {
			return createTemporaryObject(spyComponent, host, { target: target, signalName: signal });
		}

		function test_thePillShowsOnlyWhileThePointerIsIn() {
			const h = make();
			const pill = findChild(h, "pill");
			verify(pill);
			compare(h.shown, false);
			mouseMove(h, 90, 9);
			tryCompare(h, "shown", true);
			tryCompare(pill, "opacity", 1);
			mouseMove(host, 10, 10);
			tryCompare(h, "shown", false);
			tryCompare(pill, "opacity", 0);
		}

		function test_aDragReportsWhereThePointerIs() {
			const h = make();
			const grabbed = spy(h, "grabbed");
			const dragged = spy(h, "dragged");
			const dropped = spy(h, "dropped");
			mousePress(h, 90, 9);
			compare(grabbed.count, 1);
			compare(grabbed.signalArguments[0][0], Qt.point(390, 109));
			verify(h.dragging);
			mouseMove(h, 140, 30);
			verify(dragged.count >= 1);
			compare(dragged.signalArguments[dragged.count - 1][0], Qt.point(440, 130));
			verify(h.shown);
			mouseRelease(h, 140, 30);
			compare(dropped.count, 1);
			verify(!h.dragging);
		}

		function test_otherButtonsDontGrab() {
			const h = make();
			const grabbed = spy(h, "grabbed");
			mousePress(h, 90, 9, Qt.RightButton);
			mouseRelease(h, 90, 9, Qt.RightButton);
			compare(grabbed.count, 0);
		}
	}
}
