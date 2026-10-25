import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 1000
	height: 480

	Component {
		id: viewComponent
		NotchView {
			width: 1000
			height: 480
			weather: ({ shown: true, label: "28°C", icon: "sun", tooltip: "Clear — Chennai" })
			battery: ({ available: true, level: 80, charging: false, threshold: 20, tooltip: "80% remaining" })
		}
	}

	TestCase {
		name: "NotchView"
		when: windowShown

		function make(props) {
		// Tests share one offscreen pointer; keep its previous hover out of new views.
		mouseMove(host, 0, 400);
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		// After the drop-in: impacted, expanded and no longer startup-locked.
		function settle(v) {
			v.ready = true;
			tryCompare(v, "impacted", true, 1000);
			tryCompare(v, "startupAnimating", false, 3000);
		}

		function centre(v) { return { x: 500, y: v.target.height / 2 }; }

		function test_startupDropIn() {
			const v = make();
			compare(v.target.y, 250, "parked below before ready");
			v.ready = true;
			compare(v.target.y, 0);
			compare(v.target.width, 30.6, "a dot rising to the edge");
			tryCompare(v, "impacted", true, 1000);
			compare(v.target.width, 140);
			compare(v.target.height, 36);
			compare(v.target.edgeRadius, 0);
		}

		function test_hoverOpensTheStatusStrip() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(v.target.width, 300, "200 + 2 widgets x 50");
			mouseMove(v, 500, 300);
			tryCompare(v, "statusHover", false, 500);
			compare(v.target.width, 140);
		}

		function test_twentyFourHourClockIsNarrower() {
			const v = make({ use24h: true });
			settle(v);
			compare(v.target.width, 124);
		}

		// Review focus 4.
		function test_widgetWithoutDataIsHidden() {
			const v = make({ battery: { available: false } });
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(findChild(v, "widget-battery"), null);
			verify(findChild(v, "widget-weather") !== null);
			compare(v.target.width, 300, "width still counts configured widgets, as Bloom");
		}

		function test_tooltipAfterDelay() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			wait(600); // let the pill finish widening before locating the widget
			const w = findChild(v, "widget-battery");
			verify(w !== null);
			const p = w.mapToItem(v, w.width / 2, w.height / 2);
			mouseMove(v, p.x, p.y);
			const tip = findChild(v, "statusTooltip");
			verify(!tip.shown, "not before the delay");
			tryCompare(tip, "shown", true, 1000);
			compare(tip.text, "80% remaining");
			mouseMove(v, 500, 300);
			tryCompare(tip, "shown", false, 500);
		}

		function test_peekModeHidesUntilShown() {
			const v = make({ mode: "peek" });
			settle(v);
			verify(v.hidden);
			compare(v.target.y, -100);
			compare(v.target.width, 39.1);
			v.peek(300);
			verify(!v.hidden);
			tryCompare(v, "hidden", true, 1500);
		}

		// Review focus 1: the band takes input only while the notch is hidden.
		function test_bandOnlyWhileHidden() {
			const fixed = make();
			settle(fixed);
			verify(!fixed.bandActive);
			const smart = make({ mode: "smart", overlapped: true });
			settle(smart);
			verify(smart.hidden);
			verify(smart.bandActive);
			smart.overlapped = false;
			verify(!smart.hidden);
			verify(!smart.bandActive);
		}

		function test_edgeDwellRevealsAndGraceHides() {
			const v = make({ mode: "peek", edgeDelay: 200 });
			settle(v);
			verify(v.hidden);
			const b = v.bandItem.mapToItem(v, v.bandItem.width / 2, 1);
			mouseMove(v, b.x, b.y);
			wait(100);
			verify(v.hidden, "not before the dwell");
			tryCompare(v, "hidden", false, 1000);
			// The pointer never reaches the pill: the reveal lets go after the
			// 1 s hand-off, then the 800 ms grace runs.
			wait(1200);
			verify(!v.hidden, "hand-off, then grace");
			tryCompare(v, "hidden", true, 1500);
		}

		function test_smartModeFollowsOverlap() {
			const v = make({ mode: "smart" });
			settle(v);
			verify(!v.hidden);
			v.overlapped = true;
			verify(v.hidden);
			compare(v.target.y, -100);
		}

		function test_userVisibility() {
			const v = make();
			settle(v);
			v.userVisible = false;
			compare(v.target.y, -150);
			compare(v.target.opacity, 0);
		}

		function test_statsWantedOnlyForStatsWidgets() {
			const v = make({ widgets: { left: ["cpu"], right: ["battery"] } });
			const spy = createTemporaryQmlObject("import QtQuick; import QtTest; SignalSpy { signalName: \"statsWanted\" }", host);
			spy.target = v;
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(spy, "count", 1, 500);
			compare(spy.signalArguments[0][0], true);
			mouseMove(v, 500, 300);
			tryCompare(spy, "count", 2, 500);
			compare(spy.signalArguments[1][0], false);
		}

		// Review focus 5: a destroyed notch gives back its stats hold.
		function test_releasesHoldsOnDestruction() {
			const v = make({ widgets: { left: ["cpu"], right: [] } });
			let last = null;
			v.statsWanted.connect(w => last = w);
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(last, true);
			v.destroy();
			wait(0);
			compare(last, false);
		}

		// A fullscreen app on this monitor: the reveal band must not take the
		// top edge from it (Bloom drops edge input while fullscreen is in front).
		function test_fullscreenSuppressesTheBand() {
			const v = make({ mode: "smart", overlapped: true });
			settle(v);
			verify(v.hidden);
			verify(v.bandActive);
			v.suppressed = true;
			verify(!v.bandActive);
		}

		function test_stateObject() {
			const v = make({ mode: "smart" });
			settle(v);
			const s = v.stateObject();
			compare(s.mode, "smart");
			compare(s.hidden, false);
			compare(s.width, 140);
			compare(s.visible, true);
		}
	}
}
