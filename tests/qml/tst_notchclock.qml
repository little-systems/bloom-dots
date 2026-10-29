import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's notch time (App.tsx .time-center): the clock, or the Pomodoro
// timer while one runs or has finished, flipping between them; the panel
// arrows sit 4 px outside its 60 px box.
Item {
	id: host
	width: 300
	height: 100

	NotchClock {
		id: clock
		x: 120
		y: 30
		now: new Date(2026, 9, 29, 14, 5, 0)
		textColor: "#f0f0f0"
		textMuted: "#909090"
	}

	SignalSpy { id: clicks; target: clock; signalName: "clicked" }
	SignalSpy { id: prev; target: clock; signalName: "previous" }
	SignalSpy { id: next; target: clock; signalName: "next" }

	TestCase {
		name: "NotchClock"
		when: windowShown

		function part(name) {
			const found = findChild(clock, name);
			verify(found, name);
			return found;
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function init() {
			clock.timerActive = false;
			clock.timerFinished = false;
			clock.timerSeconds = 0;
			clock.arrows = false;
			clock.use24h = false;
			clicks.clear();
			prev.clear();
			next.clear();
			wait(400);
		}

		function cleanup() {
			mouseMove(host, 295, 95);
		}

		function test_box() {
			compare(clock.width, 60);
			compare(clock.height, 24);
			const t = part("clockText");
			compare(t.text, "02:05 PM");
			compare(t.font.pixelSize, 13);
			compare(t.font.weight, Font.Medium);
			compare(part("pointer").cursorShape, Qt.PointingHandCursor);
		}

		// At rest the clock is drawn at full height (its flip squash is 1).
		function test_clockIsDrawnAtRest() {
			const t = part("clockText");
			compare(t.transform[0].yScale, 1);
			compare(t.opacity, 1);
		}

		function test_hoverMutesAndPressShrinks() {
			const t = part("clockText");
			mouseMove(clock, 30, 12);
			tryCompare(t, "color", Qt.color("#909090"), 1000);
			mousePress(clock, 30, 12);
			tryCompare(clock, "scale", 0.95, 500);
			mouseRelease(clock, 30, 12);
			compare(clicks.count, 1);
			tryCompare(clock, "scale", 1, 500);
		}

		function test_timerFlipsIn() {
			clock.timerSeconds = 65;
			clock.timerActive = true;
			const timer = part("timerText");
			compare(timer.text, "1:05");
			// The spring is under way: the clock tilting out, the timer in.
			wait(30);
			verify(part("clockText").opacity < 1);
			verify(part("timerRow").opacity < 1);
			tryCompare(part("timerRow"), "opacity", 1, 1000);
			tryCompare(part("clockText"), "opacity", 0, 1000);
			tryCompare(part("timerRow"), "tilt", 1, 1000);
			verify(!part("bell").visible);
		}

		function test_finishedIsRedWithTheBell() {
			clock.timerActive = true;
			clock.timerFinished = true;
			tryCompare(part("timerRow"), "opacity", 1, 1000);
			compare(part("timerText").text, "0:00");
			compare(part("timerText").color, Qt.color("#ff453a"));
			verify(part("bell").visible);
			compare(part("bell").name, "bell-ring");
			compare(part("bell").size, 13);
			verify(part("pop").running || part("heartbeat").running, "the timer pops, then beats");
			verify(part("wiggle").running, "the bell wiggles");
			// Red stays red on hover (!important).
			mouseMove(clock, 30, 12);
			wait(300);
			compare(part("timerText").color, Qt.color("#ff453a"));
			clock.timerFinished = false;
			verify(!part("heartbeat").running);
		}

		function test_arrows() {
			clock.arrows = true;
			const left = part("arrowPrev");
			const right = part("arrowNext");
			tryCompare(left, "opacity", 1, 1000);
			compare(left.width, 18);
			compare(left.x + left.offset, -4 - 18);
			compare(right.x + right.offset, 60 + 4);
			compare(left.y, (24 - 18) / 2);
			compare(part("prevGlyph").color, Qt.color("#909090"));
			mouseMove(left, 9, 9);
			tryCompare(part("prevGlyph"), "color", Qt.color("#f0f0f0"), 1000);
			mouseClick(left);
			mouseClick(right);
			compare(prev.count, 1);
			compare(next.count, 1);
			compare(clicks.count, 0, "an arrow isn't a click on the time");
			clock.arrows = false;
			tryCompare(left, "opacity", 0, 1000);
			verify(!left.visible);
		}

		function test_arrowsSlideIn() {
			clock.arrows = true;
			const left = part("arrowPrev");
			wait(30);
			verify(left.offset > 0 && left.offset <= 4, `prev slides from 4 px right: ${left.offset}`);
			verify(part("arrowNext").offset < 0, "next slides from 4 px left");
			tryCompare(left, "offset", 0, 1000);
		}

		function test_noFramesAtRest() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
			compare(framesIn(1000), 0);
		}
	}
}
