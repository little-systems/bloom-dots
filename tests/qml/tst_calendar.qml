import QtQuick
import QtTest
import "../../shell/modules/notch/calendar.js" as Calendar

TestCase {
	name: "CalendarRules"
	function test_monthBoundaries() {
		compare(Calendar.monthGrid(2026, 1).length, 28);
		compare(Calendar.monthGrid(2026, 7).length, 42);
		compare(Calendar.monthGrid(2026, 7)[0], { day: -5, inMonth: false });
		compare(Calendar.monthRows(2026, 7), 6);
	}
	function test_timerDigitsAndDeadline() {
		compare(Calendar.timerDigits("130"), 90);
		compare(Calendar.timerDigits("2500"), 1500);
		compare(Calendar.timerDigits("45"), 45);
		// Bloom doesn't cap the typed seconds at 59: 99:99 is 6039 s.
		compare(Calendar.timerDigits("9999"), 99 * 60 + 99);
		compare(Calendar.timerDigits("18000"), 180 * 60);
		compare(Calendar.timerDigits("18001"), null);
		compare(Calendar.timerDigits("0"), null);
		compare(Calendar.timerDigits(""), null);
		compare(Calendar.remaining(12000, 99, 10500), 2);
		compare(Calendar.remaining(0, 30, 10500), 30);
		compare(Calendar.timerText(7200), "120:00");
	}
	function test_restoreRejectsMalformedState() {
		const got = Calendar.restored({ todos: [{ id: 1, text: "write", done: false }, { id: 2, text: "", done: false }], durationSec: 999999, deadlineMs: 999999999, pausedSec: -5 }, 1000);
		compare(got.todos, undefined, "Bloom has no task list (owner, 2026-10-29); old todos are dropped");
		compare(got.durationSec, 1500);
		compare(got.deadlineMs, 0);
		compare(got.pausedSec, 0, "unreadable time left restores as idle");
		compare(got.expired, false);
		const expired = Calendar.restored({ deadlineMs: 900, pausedSec: 5 }, 1000);
		compare(expired.expired, true);
		compare(expired.pausedSec, 0);
		compare(expired.finished, true);
	}
	// Bloom: idle is 0 s left (the clock shows the last duration); paused has
	// time left; finished stays until reset, a start or an edit.
	function test_restoreKeepsBloomStates() {
		const idle = Calendar.restored({ durationSec: 600, deadlineMs: 0, pausedSec: 0 }, 1000);
		compare(idle.pausedSec, 0);
		compare(idle.finished, false);
		const paused = Calendar.restored({ durationSec: 600, deadlineMs: 0, pausedSec: 200 }, 1000);
		compare(paused.pausedSec, 200);
		const finished = Calendar.restored({ durationSec: 600, deadlineMs: 0, pausedSec: 0, finished: true }, 1000);
		compare(finished.finished, true);
		// Files from before: a reset left pausedSec at the duration, meaning idle.
		const old = Calendar.restored({ durationSec: 600, deadlineMs: 0, pausedSec: 600 }, 1000);
		compare(old.pausedSec, 0);
		compare(Calendar.restored({}, 1000).pausedSec, 0);
	}
	function test_editDigits() {
		compare(Calendar.formatDigits(""), "0:00");
		compare(Calendar.formatDigits("5"), "0:05");
		compare(Calendar.formatDigits("130"), "1:30");
		compare(Calendar.formatDigits("12345"), "123:45");
		compare(Calendar.secondsToDigits(1500), "2500");
		compare(Calendar.secondsToDigits(45), "45");
		compare(Calendar.secondsToDigits(5), "5");
		compare(Calendar.secondsToDigits(0), "0");
	}
	function test_clockDigits() {
		compare(Calendar.clockText(1500), "25:00");
		compare(Calendar.clockText(65), "1:05");
		compare(Calendar.clockDigits("25:00"), { minutes: ["2", "5"], seconds: ["0", "0"], compact: false });
		compare(Calendar.clockDigits("1:05"), { minutes: ["0", "1"], seconds: ["0", "5"], compact: false });
		compare(Calendar.clockDigits("123:45"), { minutes: ["1", "2", "3"], seconds: ["4", "5"], compact: true });
	}
	function test_statusText() {
		const now = new Date(2026, 9, 29, 14, 30, 0);
		compare(Calendar.status({ editing: true }, now, false), "Set duration");
		compare(Calendar.status({ finished: true, remaining: 0 }, now, false), "Time's up");
		compare(Calendar.status({ running: true, remaining: 600 }, now, false), "ends 02:40 PM");
		compare(Calendar.status({ running: true, remaining: 600 }, now, true), "ends 14:40");
		compare(Calendar.status({ running: false, remaining: 600 }, now, false), "Paused · ends 02:40 PM");
		compare(Calendar.status({ running: false, remaining: 0 }, now, false), "Click to edit");
	}
	function test_primaryLabel() {
		compare(Calendar.primaryLabel(true, 600, false), "Pause");
		compare(Calendar.primaryLabel(false, 600, false), "Resume");
		compare(Calendar.primaryLabel(false, 0, true), "Restart");
		compare(Calendar.primaryLabel(false, 0, false), "Start");
	}
}
