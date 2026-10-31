import QtQuick
import QtTest
import "../../shell/modules/lock/lock.js" as Lock

// What the lock screen says for each PAM outcome, and its clock and date.
TestCase {
	name: "LockLogic"

	function test_outcomes() {
		compare(Lock.failureText("failed"), "That password didn't work");
		compare(Lock.failureText("maxtries"), "Too many tries. Wait a moment, then try again");
		compare(Lock.failureText("error"), "Couldn't check the password");
	}

	function test_clockFollowsTheFormat() {
		const t = new Date(2026, 9, 31, 15, 7);
		compare(Lock.clock(t, true), "15:07");
		compare(Lock.clock(t, false), "3:07");
		compare(Lock.clock(new Date(2026, 9, 31, 0, 5), false), "12:05");
	}

	function test_date() {
		compare(Lock.date(new Date(2026, 9, 31)), "Saturday, October 31");
	}

	function test_capsLockFromTheCompositor() {
		compare(Lock.capsLock(JSON.stringify({ keyboards: [{ capsLock: false, main: false }, { capsLock: true, main: true }] })), true);
		compare(Lock.capsLock(JSON.stringify({ keyboards: [{ capsLock: true, main: false }, { capsLock: false, main: true }] })), false);
		compare(Lock.capsLock(JSON.stringify({ keyboards: [{ capsLock: true }] })), true);
		compare(Lock.capsLock("not json"), false);
		compare(Lock.capsLock(""), false);
	}
}
