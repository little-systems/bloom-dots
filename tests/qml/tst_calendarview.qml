import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's calendar and timer split view (App.tsx .calendar-timer-content,
// App.css .calendar-*, .timer-*). Tasks are gone (owner decision 3).
Item {
	id: host
	width: 520
	height: 300

	QtObject {
		id: colours
		property color text: "#f0f0f0"
		property color textMuted: "#909090"
		property color groupBg: "#202020"
		property color border: "#404040"
		property color bgExpanded: "#080808"
		property color scrollbarThumb: "#303030"
	}

	// 480 x 273 (5 rows) less the 36 px clock strip.
	CalendarView {
		id: cal
		theme: colours
		width: 480
		height: 237
		now: new Date(2026, 9, 29, 14, 30, 0)
		durationSec: 1500
		remainingSec: 0
	}

	SignalSpy { id: primary; target: cal; signalName: "primaryRequested" }
	SignalSpy { id: resets; target: cal; signalName: "resetRequested" }
	SignalSpy { id: presets; target: cal; signalName: "presetChosen" }
	SignalSpy { id: commits; target: cal; signalName: "durationCommitted" }

	TestCase {
		name: "CalendarView"
		when: windowShown

		// Flex 1.2 : 1 over 448 - 16 gap - 17 (the timer column's border and
		// padding) = 415 px.
		readonly property real calWidth: 415 * 1.2 / 2.2
		readonly property real timerWidth: 415 / 2.2
		readonly property real timerX: 16 + calWidth + 16 + 1 + 16

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function at(item) {
			return item.mapToItem(cal, 0, 0);
		}

		function centre(item) {
			return item.mapToItem(host, item.width / 2, item.height / 2);
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function settleFrames() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
		}

		function digits() {
			return ["m3", "m2", "m1", "s2", "s1"].map(n => part(cal, "digit-" + n)).filter(d => d.visible).map(d => d.value).join("");
		}

		function init() {
			cal.durationSec = 1500;
			cal.remainingSec = 0;
			cal.running = false;
			cal.finished = false;
			cal.use24h = false;
			cal.cancelEdit();
			[primary, resets, presets, commits].forEach(s => s.clear());
		}

		function cleanup() {
			mouseMove(host, 515, 295);
			wait(300);
		}

		function test_columns() {
			const column = part(cal, "calendarColumn");
			compare(at(column).x, 16);
			// padding 16 plus the 1 px top margin.
			compare(at(column).y, 17);
			fuzzyCompare(column.width, calWidth, 0.01);
			const divider = part(cal, "divider");
			fuzzyCompare(at(divider).x, 16 + calWidth + 16, 0.01);
			compare(divider.width, 1);
			compare(divider.color, colours.border);
			const timer = part(cal, "timerColumn");
			fuzzyCompare(at(timer).x, timerX, 0.01);
			fuzzyCompare(timer.width, timerWidth, 0.01);
		}

		function test_monthHeader() {
			const month = part(cal, "month");
			compare(month.text, "October 2026");
			compare(month.font.pixelSize, 13);
			compare(month.font.weight, Font.DemiBold);
			compare(month.opacity, 0.9);
			fuzzyCompare(month.height, 13 * 1.3, 0.01);
		}

		function test_grid() {
			compare(cal.rows, 5);
			const names = part(cal, "dayNames");
			const labels = names.children.filter(c => c.text !== undefined);
			compare(labels.length, 7);
			const first = labels[0];
			compare(first.text, "S");
			compare(first.font.pixelSize, 9);
			compare(first.font.weight, Font.DemiBold);
			compare(first.opacity, 0.4);
			compare(first.color, colours.text);
			const cell = (calWidth - 12) / 7;
			// October 2026 starts on a Thursday: four blanks, then the 1st.
			const blank = part(cal, "day-0");
			compare(blank.label, "");
			const one = part(cal, "day-4");
			compare(one.label, "1");
			fuzzyCompare(one.width, cell, 0.01);
			compare(one.height, one.width);
			compare(one.radius, 4);
			compare(part(one, "dayText").font.pixelSize, 10);
			compare(part(one, "dayText").font.weight, Font.Normal);
			compare(one.color, Qt.rgba(0, 0, 0, 0));
			// 2 px gaps.
			fuzzyCompare(at(part(cal, "day-5")).x - at(one).x, cell + 2, 0.01);
		}

		function test_today() {
			const today = part(cal, "day-" + (4 + 28));
			compare(today.label, "29");
			compare(today.color, colours.text);
			compare(part(today, "dayText").color, colours.bgExpanded);
			compare(part(today, "dayText").font.weight, Font.DemiBold);
		}

		function test_status() {
			const status = part(cal, "status");
			compare(status.text, "Click to edit");
			compare(status.height, 14);
			compare(status.font.pixelSize, 10);
			compare(status.font.weight, Font.Medium);
			// Qt keeps letter spacing in 1/64 px steps.
			fuzzyCompare(status.font.letterSpacing, 0.2, 1 / 64);
			compare(status.opacity, 0.4);
			cal.running = true;
			cal.remainingSec = 600;
			compare(status.text, "ends 02:40 PM");
			cal.use24h = true;
			compare(status.text, "ends 14:40");
			cal.running = false;
			compare(status.text, "Paused · ends 14:40");
			cal.remainingSec = 0;
			cal.finished = true;
			compare(status.text, "Time's up");
			compare(status.opacity, 0.9);
		}

		function test_clock() {
			compare(digits(), "2500");
			verify(!part(cal, "digit-m3").visible);
			const d = part(cal, "digit-m1");
			compare(d.width, 34);
			compare(d.compact, false);
			const colon = part(cal, "colon");
			compare(colon.text, ":");
			compare(colon.font.pixelSize, 32);
			compare(colon.opacity, 0.3);
			// gap 5 between the digits and the colon (2 px padding each side).
			const m1 = at(d).x;
			fuzzyCompare(at(part(cal, "digit-m2")).x, m1 - 5 - 34, 0.01);
			fuzzyCompare(at(colon).x, m1 + 34 + 5, 0.01);
			compare(colon.width, Math.ceil(colon.implicitWidth) + 4);
			compare(part(cal, "clockPointer").cursorShape, Qt.IBeamCursor);
			cal.durationSec = 100 * 60;
			compare(digits(), "10000");
			verify(part(cal, "digit-m3").visible);
			compare(part(cal, "digit-m1").compact, true);
			compare(part(cal, "digit-m1").width, 26);
			// Paused shows the time left; finished shows 0:00.
			cal.durationSec = 1500;
			cal.remainingSec = 65;
			compare(digits(), "0105");
			cal.remainingSec = 0;
			cal.finished = true;
			compare(digits(), "0000");
		}

		function test_stateColours() {
			const d = part(cal, "digit-m1");
			const colon = part(cal, "colon");
			compare(d.color, colours.text);
			compare(colon.color, colours.text);
			cal.remainingSec = 600;
			// Paused: the section turns textMuted over 0.3 s; the digits stay text.
			tryCompare(colon, "color", colours.textMuted, 1000);
			compare(d.color, colours.text);
			cal.remainingSec = 0;
			cal.finished = true;
			tryCompare(colon, "color", Qt.color("#ff453a"), 1000);
			compare(d.color, Qt.color("#ff453a"));
			verify(part(cal, "pulse").running, "the finished clock pulses");
			cal.finished = false;
			verify(!part(cal, "pulse").running);
			tryCompare(part(cal, "clock"), "scale", 1, 2000);
		}

		function test_playButton() {
			const play = part(cal, "play");
			compare(play.height, 44);
			compare(part(play, "background").radius, 22);
			compare(part(play, "background").color, colours.text);
			// flex: 1 between the 32 px spacer and the 32 px reset, gaps 8.
			fuzzyCompare(play.width, timerWidth - 32 - 8 - 8 - 32, 0.01);
			fuzzyCompare(at(play).x, timerX + 32 + 8, 0.01);
			const label = part(play, "label");
			compare(label.text, "Start");
			compare(label.font.pixelSize, 12);
			compare(label.font.weight, Font.DemiBold);
			compare(label.color, colours.bgExpanded);
			compare(part(play, "glyph").name, "play-filled");
			compare(part(play, "glyph").size, 14);
			cal.running = true;
			cal.remainingSec = 300;
			compare(label.text, "Pause");
			compare(part(play, "glyph").name, "pause-filled");
			cal.running = false;
			compare(label.text, "Resume");
			cal.remainingSec = 0;
			cal.finished = true;
			compare(label.text, "Restart");
			mouseClick(play);
			compare(primary.count, 1);
		}

		function test_playHoverAndPress() {
			const play = part(cal, "play");
			const p = centre(play);
			mouseMove(host, p.x, p.y);
			tryCompare(play, "opacity", 0.9, 1000);
			mousePress(host, p.x, p.y);
			tryCompare(play, "scale", 0.97, 1000);
			mouseRelease(host, p.x, p.y);
			tryCompare(play, "scale", 1, 1000);
		}

		function test_reset() {
			const reset = part(cal, "reset");
			compare(reset.width, 32);
			compare(reset.height, 32);
			// Idle: nothing to reset.
			compare(reset.enabled, false);
			tryCompare(reset, "opacity", 0.08, 1000);
			cal.remainingSec = 300;
			tryCompare(reset, "opacity", 0.35, 1000);
			compare(part(reset, "glyph").name, "rotate-ccw");
			compare(part(reset, "glyph").size, 14);
			compare(part(reset, "glyph").strokeWidth, 2.5);
			const p = centre(reset);
			mouseMove(host, p.x, p.y);
			tryCompare(reset, "opacity", 0.8, 1000);
			mouseClick(reset);
			compare(resets.count, 1);
			cal.remainingSec = 0;
			cal.finished = true;
			verify(reset.enabled, "a finished timer resets");
		}

		function test_presets() {
			const cellW = (timerWidth - 12) / 4;
			const names = ["5m", "15m", "25m", "50m"];
			names.forEach((n, i) => {
				const b = part(cal, "preset-" + i);
				compare(part(b, "label").text, n);
				fuzzyCompare(b.width, cellW, 0.01);
				fuzzyCompare(at(b).x, timerX + i * (cellW + 4), 0.01);
				compare(part(b, "background").radius, 7);
				compare(part(b, "label").font.pixelSize, 10);
				compare(part(b, "label").color, colours.text);
				compare(b.height, Math.ceil(part(b, "label").implicitHeight) + 12);
			});
			// 25 min is the duration: active.
			compare(part(part(cal, "preset-2"), "background").color, colours.border);
			compare(part(cal, "preset-2").opacity, 1);
			compare(part(cal, "preset-0").opacity, 0.5);
			compare(part(part(cal, "preset-0"), "background").color, Qt.rgba(0, 0, 0, 0));
			cal.finished = true;
			tryCompare(part(cal, "preset-2"), "opacity", 0.5, 1000);
			mouseClick(part(cal, "preset-1"));
			compare(presets.count, 1);
			compare(presets.signalArguments[0][0], 15 * 60);
		}

		function test_verticalCentring() {
			// The timer section is centred in the column: status 14 + 4 + clock
			// 58, 18, controls 44, 18, presets.
			const status = part(cal, "status");
			const preset = part(cal, "preset-0");
			const top = at(status).y;
			const bottom = at(preset).y + preset.height;
			fuzzyCompare(at(part(cal, "digit-m1")).y, top + 14 + 4, 0.5);
			fuzzyCompare(at(part(cal, "play")).y, top + 14 + 4 + 58 + 18, 0.5);
			fuzzyCompare(at(preset).y, top + 14 + 4 + 58 + 18 + 44 + 18, 0.5);
			fuzzyCompare((top + bottom) / 2, 17 + (237 - 1 - 32) / 2, 0.5);
		}

		function test_edit() {
			mouseClick(part(cal, "clock"));
			verify(cal.editing);
			compare(part(cal, "status").text, "Set duration");
			compare(digits(), "2500");
			const underline = part(cal, "underline");
			tryCompare(underline, "opacity", 0.3, 1000);
			fuzzyCompare(underline.width, timerWidth * 0.74, 0.5);
			// The first digit replaces the selected duration; digits fill from the right.
			keyClick(Qt.Key_1);
			compare(digits(), "0001");
			keyClick(Qt.Key_3);
			keyClick(Qt.Key_0);
			compare(digits(), "0130");
			keyClick(Qt.Key_Return);
			verify(!cal.editing);
			compare(commits.count, 1);
			compare([commits.signalArguments[0][0], commits.signalArguments[0][1]], [90, true]);
		}

		// The underline is 74% of the row (Bloom's width: 74%): a resize moves
		// it at once.
		function test_underlineFollowsAResize() {
			mouseClick(part(cal, "clock"));
			const underline = part(cal, "underline");
			tryCompare(underline, "opacity", 0.3, 1000);
			cal.width = 520;
			fuzzyCompare(underline.width, part(cal, "timerColumn").width * 0.74, 0.5);
			cal.width = 480;
			keyClick(Qt.Key_Escape);
		}

		function test_editInvalidTurnsRed() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_0);
			compare(digits(), "0000");
			compare(part(cal, "digit-s1").color, Qt.color("#ff453a"));
			keyClick(Qt.Key_Backspace);
			keyClick(Qt.Key_5);
			compare(part(cal, "digit-s1").color, colours.text);
			// Five digits at most.
			[1, 2, 3, 4, 5].forEach(n => keyClick(Qt.Key_0 + n));
			compare(digits(), "51234");
			keyClick(Qt.Key_Escape);
			verify(!cal.editing);
			// Escape leaves the edit like Bloom's blur: an invalid entry is dropped.
			compare(commits.count, 0);
		}

		function test_editCommitsOnBlur() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_4);
			keyClick(Qt.Key_5);
			cal.forceActiveFocus();
			verify(!cal.editing);
			compare(commits.count, 1);
			compare([commits.signalArguments[0][0], commits.signalArguments[0][1]], [45, false]);
		}

		function test_unchangedEditCommitsNothing() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_Escape);
			compare(commits.count, 0, "a tap that changes nothing keeps the state");
		}

		function test_playWhileEditingStarts() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_9);
			mouseClick(part(cal, "play"));
			compare(commits.count, 1);
			compare([commits.signalArguments[0][0], commits.signalArguments[0][1]], [9, true]);
			compare(primary.count, 0);
		}

		function test_noEditWhileRunning() {
			cal.running = true;
			cal.remainingSec = 300;
			mouseClick(part(cal, "clock"));
			verify(!cal.editing);
		}

		function test_editFromFinishedResets() {
			cal.finished = true;
			mouseClick(part(cal, "clock"));
			compare(resets.count, 1);
			verify(cal.editing);
			compare(digits(), "2500");
		}

		function test_restDrawsNoFrames() {
			settleFrames();
			compare(framesIn(1000), 0);
		}
	}
}
