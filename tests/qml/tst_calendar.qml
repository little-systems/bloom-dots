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
		compare(Calendar.timerDigits("9999"), null);
		compare(Calendar.remaining(12000, 99, 10500), 2);
		compare(Calendar.remaining(0, 30, 10500), 30);
		compare(Calendar.timerText(7200), "120:00");
	}
	function test_restoreRejectsMalformedState() {
		const got = Calendar.restored({ todos: [{ id: 1, text: "write", done: false }, { id: 2, text: "", done: false }], durationSec: 999999, deadlineMs: 999999999, pausedSec: -5 }, 1000);
		compare(got.todos.length, 1);
		compare(got.durationSec, 1500);
		compare(got.deadlineMs, 0);
		compare(got.pausedSec, 1500);
		compare(got.expired, false);
		const expired = Calendar.restored({ deadlineMs: 900, pausedSec: 5 }, 1000);
		compare(expired.expired, true);
		compare(expired.pausedSec, 0);
	}
}
