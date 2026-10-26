import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	id: host
	width: 300
	height: 200

	Component {
		id: iconComponent
		DockIcon {
			x: 100
			y: 100
			name: "Firefox"
			present: true
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockIcon"
		when: windowShown

		function make(props) {
			mouseMove(host, 0, 0);
			const v = createTemporaryObject(iconComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		// Bloom: items pop in after 150 ms (scale 0 → 1, spring 400/25).
		function test_entryWaitsThenPops() {
			const v = make();
			const lift = findChild(v, "dock-lift");
			wait(60);
			compare(v.shown, false, "still in the entry delay");
			tryCompare(v, "shown", true, 400);
			tryVerify(() => Math.abs(lift.mapToItem(v, 36, 0).x - lift.mapToItem(v, 0, 0).x - 36) < 0.36, 1500);
		}

		function test_leavingShrinksAway() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			v.present = false;
			tryCompare(v, "shown", false, 400, "after the same 150 ms delay");
			const lift = findChild(v, "dock-lift");
			tryVerify(() => Math.abs(lift.mapToItem(v, 36, 0).x - lift.mapToItem(v, 0, 0).x) < 0.36, 1500);
		}

		// Bloom: a running (unpinned) app's exit is a 120 ms tween, no delay.
		function test_quickExitForRunningApps() {
			const v = make({ quickExit: true });
			tryCompare(v, "shown", true, 400);
			wait(500);
			v.present = false;
			compare(v.shown, false, "no exit delay");
			const lift = findChild(v, "dock-lift");
			const width = () => Math.abs(lift.mapToItem(v, 36, 0).x - lift.mapToItem(v, 0, 0).x);
			tryVerify(() => width() < 0.36, 250, "gone within about 120 ms");
		}

		function test_hoverLiftsAndPressSinks() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const lift = findChild(v, "dock-lift");
			wait(600);
			mouseMove(v, 18, 18);
			tryCompare(v, "hovered", true, 500);
			tryVerify(() => Math.abs(lift.y - -5) < 0.05 && Math.abs(lift.scale - 1.1) < 0.005, 1500, "hover: y -5, scale 1.1");
			mousePress(v, 18, 18);
			tryVerify(() => Math.abs(lift.scale - 0.95) < 0.005, 1500, "tap: scale 0.95");
			verify(Math.abs(lift.y - -5) < 0.05, "tap keeps the hover lift (its variant sets only scale)");
			mouseRelease(v, 18, 18);
		}

		function test_tooltipOnHover() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const tip = findChild(v, "dock-tooltip");
			compare(tip.opacity, 0);
			mouseMove(v, 18, 18);
			tryCompare(tip, "opacity", 1, 600);
			compare(tip.y, -36 + 0, "Bloom: top -36px");
			mouseMove(host, 0, 0);
			tryCompare(tip, "opacity", 0, 600);
		}

		function test_dots() {
			const v = make({ windows: 0 });
			compare(findChild(v, "dock-dots").count, 0);
			v.windows = 2;
			compare(findChild(v, "dock-dots").count, 2);
			v.windows = 9;
			compare(findChild(v, "dock-dots").count, 3, "at most three");
		}

		function test_fallbackLetter() {
			const v = make({ iconSource: "" });
			verify(findChild(v, "dock-fallback").visible);
			compare(findChild(v, "dock-fallback").text, "F");
			compare(findChild(v, "dock-image").visible, false);
		}

		function test_iconOnly() {
			const v = make({ iconOnly: true });
			compare(findChild(v, "dock-tile").visible, false);
			compare(findChild(v, "dock-image").width, 32);
			v.iconOnly = false;
			compare(findChild(v, "dock-image").width, 28);
		}

		function test_clicks() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const left = createTemporaryObject(spyComponent, host, { target: v, signalName: "clicked" });
			const middle = createTemporaryObject(spyComponent, host, { target: v, signalName: "middleClicked" });
			mouseClick(v, 18, 18);
			compare(left.count, 1);
			mouseClick(v, 18, 18, Qt.MiddleButton);
			compare(middle.count, 1);
			compare(left.count, 1);
		}
	}
}
