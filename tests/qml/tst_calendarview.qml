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
		onMonthChosen: (year, month) => { cal.viewYear = year; cal.viewMonth = month; }
	}

	// The notch's wheel handler, beneath the panel.
	property int notchWheels: 0
	WheelHandler { target: null; onWheel: host.notchWheels++ }

	SignalSpy { id: primary; target: cal; signalName: "primaryRequested" }
	SignalSpy { id: resets; target: cal; signalName: "resetRequested" }
	SignalSpy { id: presets; target: cal; signalName: "presetChosen" }
	SignalSpy { id: commits; target: cal; signalName: "durationCommitted" }
	SignalSpy { id: months; target: cal; signalName: "monthChosen" }

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
			cal.closeMonthPicker();
			cal.mondayFirst = false;
			cal.viewYear = 2026;
			cal.viewMonth = 9;
			host.forceActiveFocus();
			mouseMove(host, 515, 295);
			wait(350);
			[primary, resets, presets, commits, months].forEach(s => s.clear());
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
			compare(month.font.pixelSize, 12);
			compare(month.font.weight, Font.DemiBold);
			compare(month.opacity, 1);
			compare(part(cal, "calendarHeader").height, 24);
			compare(at(part(cal, "dayNames")).y - at(part(cal, "calendarColumn")).y, 24 + 8);
			const today = part(cal, "todayButton");
			compare(today.width, 34);
			const nav = part(cal, "monthNav");
			compare(nav.width, 46);
			compare(nav.height, 24);
			compare(nav.border.color, colours.border);
			compare(nav.color, colours.groupBg);
			compare(part(cal, "nextMonth").width, 22);
		}

		function test_dayNamesAreThreeLetters() {
			const names = () => part(cal, "dayNames").children.filter(c => c.text !== undefined).map(c => c.text);
			compare(names(), ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]);
			cal.mondayFirst = true;
			compare(names(), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
			// October 2026 starts on a Thursday: three blanks Monday-first.
			compare(part(cal, "day-3").label, "1");
		}

		function test_rowsFollowViewedMonth() {
			cal.viewYear = 2026;
			cal.viewMonth = 1;
			compare(cal.rows, 4);
			cal.mondayFirst = true;
			compare(cal.rows, 5);
			cal.viewMonth = 7;
			compare(cal.rows, 6);
		}

		function test_arrowsChangeMonth() {
			mouseMove(part(cal, "calendarColumn"), 20, 60);
			tryCompare(part(cal, "monthNav"), "opacity", 1);
			mouseClick(part(cal, "nextMonth"));
			compare(months.count, 1);
			compare(Array.from(months.signalArguments[0]), [2026, 10]);
			mouseClick(part(cal, "previousMonth"));
			compare(Array.from(months.signalArguments[1]), [2026, 9]);
		}

		function test_navigationHiddenUntilHover() {
			compare(part(cal, "monthNav").opacity, 0);
			mouseMove(part(cal, "calendarColumn"), 20, 60);
			tryCompare(part(cal, "monthNav"), "opacity", 1);
		}

		function test_todayOnlyAwayFromCurrentMonth() {
			verify(!part(cal, "todayButton").visible);
			cal.viewMonth = 11;
			verify(part(cal, "todayButton").visible);
			compare(part(cal, "todayLabel").font.pixelSize, 9);
			fuzzyCompare(part(cal, "todayLabel").opacity, 0.65, 0.001);
			mouseClick(part(cal, "todayButton"));
			compare(Array.from(months.signalArguments[0]), [2026, 9]);
			cal.viewMonth = 9;
			verify(part(cal, "day-" + (4 + 28)).today);
		}

		function test_wheelThrottled() {
			const day = part(cal, "day-10");
			mouseWheel(day, 5, 5, 0, -120);
			mouseWheel(day, 5, 5, 0, -120);
			compare(months.count, 1);
			compare(Array.from(months.signalArguments[0]), [2026, 10]);
			wait(320);
			mouseWheel(day, 5, 5, 0, 3);
			compare(months.count, 1, "tiny deltas ignored");
			mouseWheel(day, 5, 5, 0, 120, Qt.NoButton, Qt.ShiftModifier);
			compare(Array.from(months.signalArguments[1]), [2025, 10]);
		}

		function test_pageKeys() {
			mouseClick(part(cal, "day-10"));
			keyClick(Qt.Key_PageDown);
			compare(Array.from(months.signalArguments[0]), [2026, 10]);
			keyClick(Qt.Key_PageUp, Qt.ShiftModifier);
			compare(Array.from(months.signalArguments[1]), [2025, 10]);
			keyClick(Qt.Key_Home);
			compare(Array.from(months.signalArguments[2]), [2026, 9]);
		}

		function test_headingOpensPicker() {
			mouseClick(part(cal, "month"));
			verify(part(cal, "monthPicker").visible);
			const year = part(cal, "yearField");
			compare(year.text, "2026");
			compare(year.width, 49);
			keyClick(Qt.Key_1); keyClick(Qt.Key_9); keyClick(Qt.Key_9); keyClick(Qt.Key_9);
			keyClick(Qt.Key_Return);
			compare(Array.from(months.signalArguments[0]), [1999, 9]);
			verify(!part(cal, "monthPicker").visible, "Enter closes the picker");
			mouseClick(part(cal, "month"));
			keyClick(Qt.Key_5); keyClick(Qt.Key_0);
			keyClick(Qt.Key_Return);
			compare(months.count, 1, "year 50 is out of range");
			compare(part(cal, "yearField").text, "1999");
			mouseClick(part(cal, "month"));
			keyClick(Qt.Key_Escape);
			verify(!part(cal, "monthPicker").visible);
		}

		function test_typingReplacesTheYear() {
			mouseClick(part(cal, "month"));
			keyClick(Qt.Key_1); keyClick(Qt.Key_9); keyClick(Qt.Key_9); keyClick(Qt.Key_9);
			keyClick(Qt.Key_Return);
			compare(Array.from(months.signalArguments[0]), [1999, 9]);
		}

		function test_clickingAwayClosesThePicker() {
			mouseClick(part(cal, "month"));
			keyClick(Qt.Key_2); keyClick(Qt.Key_0); keyClick(Qt.Key_3); keyClick(Qt.Key_0);
			mouseClick(part(cal, "day-10"));
			verify(!part(cal, "monthPicker").visible, "a click in the grid closes it");
			compare(Array.from(months.signalArguments[0]), [2030, 9], "and keeps the typed year");
			mouseClick(part(cal, "month"));
			mouseClick(part(cal, "clock"));
			verify(!part(cal, "monthPicker").visible, "opening the timer editor closes it");
			verify(cal.editing);
		}

		function test_pageKeysIgnoredWhilePicking() {
			mouseClick(part(cal, "month"));
			keyClick(Qt.Key_PageUp, Qt.ShiftModifier);
			compare(months.count, 0);
		}

		function test_headerLayoutWhilePicking() {
			const header = part(cal, "calendarHeader");
			const today = part(cal, "todayButton");
			cal.viewMonth = 11;
			fuzzyCompare(part(cal, "month").parent.width, today.x - 4, 0.01);
			mouseClick(part(cal, "month"));
			fuzzyCompare(today.x, header.width - 34, 0.01);
			fuzzyCompare(part(cal, "monthPicker").width, header.width - 34 - 4, 0.01);
		}

		function test_monthListChoosesMonth() {
			mouseClick(part(cal, "month"));
			mouseClick(part(cal, "monthSelect"));
			mouseClick(part(cal, "monthOption-2"));
			compare(Array.from(months.signalArguments[0]), [2026, 2]);
			mouseClick(part(cal, "pickerDone"));
			verify(!part(cal, "monthPicker").visible);
		}

		function test_grid() {
			compare(cal.rows, 5);
			const names = part(cal, "dayNames");
			const labels = names.children.filter(c => c.text !== undefined);
			compare(labels.length, 7);
			const first = labels[0];
			compare(first.text, "Sun");
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
			compare(one.height, 28);
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
			compare(d.width, 23);
			compare(d.height, 52);
			compare(d.compact, false);
			const colon = part(cal, "colon");
			compare(colon.text, ":");
			compare(colon.font.pixelSize, 32);
			compare(colon.opacity, 0.3);
			// No gap between the digits and the colon (1 px padding each side).
			const m1 = at(d).x;
			fuzzyCompare(at(part(cal, "digit-m2")).x, m1 - 23, 0.01);
			fuzzyCompare(at(colon).x, m1 + 23, 0.01);
			compare(colon.width, Math.ceil(colon.implicitWidth) + 2);
			compare(part(cal, "clockPointer").cursorShape, Qt.IBeamCursor);
			cal.durationSec = 100 * 60;
			compare(digits(), "10000");
			verify(part(cal, "digit-m3").visible);
			compare(part(cal, "digit-m1").compact, true);
			compare(part(cal, "digit-m1").width, 18);
			compare(part(cal, "digit-m1").height, 44);
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
			// 52, 18, controls 44, 18, presets.
			const status = part(cal, "status");
			const preset = part(cal, "preset-0");
			const top = at(status).y;
			const bottom = at(preset).y + preset.height;
			fuzzyCompare(at(part(cal, "digit-m1")).y, top + 14 + 4, 0.5);
			fuzzyCompare(at(part(cal, "play")).y, top + 14 + 4 + 52 + 18, 0.5);
			fuzzyCompare(at(preset).y, top + 14 + 4 + 52 + 18 + 44 + 18, 0.5);
			fuzzyCompare((top + bottom) / 2, 17 + (237 - 1 - 32) / 2, 0.5);
		}

		function test_edit() {
			mouseClick(part(cal, "clock"));
			verify(cal.editing);
			compare(part(cal, "status").text, "Type to set duration");
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

		// Bloom ignores the wheel over the calendar grid and the timer: it
		// doesn't reach the notch to switch panels.
		function test_escapeDiscards() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_5);
			keyClick(Qt.Key_Escape);
			verify(!cal.editing);
			compare(commits.count, 0);
		}

		function test_invalidStartKeepsEditing() {
			mouseClick(part(cal, "clock"));
			keyClick(Qt.Key_1);
			keyClick(Qt.Key_9);
			keyClick(Qt.Key_0);
			keyClick(Qt.Key_Return);
			verify(cal.editing, "1:90 is not a duration");
			compare(commits.count, 0);
			mouseClick(part(cal, "play"));
			verify(cal.editing);
			compare(commits.count, 0);
		}

		function test_wheelDoesNotLeaveTheCalendar() {
			host.notchWheels = 0;
			const day = part(cal, "day-10");
			mouseWheel(day, 5, 5, 0, -120);
			mouseWheel(part(cal, "play"), 5, 5, 0, -120);
			compare(host.notchWheels, 0);
		}

		function test_restDrawsNoFrames() {
			settleFrames();
			compare(framesIn(1000), 0);
		}
	}
}
