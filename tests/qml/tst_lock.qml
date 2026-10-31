import QtQuick
import QtTest
import "../../shell/modules/lock/lock.js" as Lock

// What the lock screen says for each PAM outcome, and its clock.
TestCase {
	name: "LockLogic"

	function test_outcomes() {
		compare(Lock.failureText("failed"), "Incorrect password");
		compare(Lock.failureText("maxtries"), "Too many tries. Wait a moment, then try again");
		compare(Lock.failureText("error"), "Couldn't check the password");
	}

	function test_keyboardFromTheCompositor() {
		const json = keyboards => JSON.stringify({ keyboards: keyboards });
		compare(Lock.keyboard(json([{ capsLock: false, main: false, active_keymap: "German" }, { capsLock: true, main: true, active_keymap: "English (US)" }])), { capsLock: true, layout: "EN" });
		compare(Lock.keyboard(json([{ capsLock: true, main: false }, { capsLock: false, main: true }])).capsLock, false);
		compare(Lock.keyboard(json([{ capsLock: true }])).capsLock, true);
		compare(Lock.keyboard("not json"), { capsLock: false, layout: "" });
		compare(Lock.keyboard(""), { capsLock: false, layout: "" });
	}

	function test_wallpaperFromIi() {
		compare(Lock.wallpaperFrom('{"background":{"wallpaperPath":"/a.jpg"}}'), "/a.jpg");
		compare(Lock.wallpaperFrom("{}"), "");
		compare(Lock.wallpaperFrom("nope"), "");
	}

	function test_hands() {
		compare(Lock.hands(new Date(2026, 9, 31, 3, 0, 0)), { hour: 90, minute: 0, second: 0 });
		compare(Lock.hands(new Date(2026, 9, 31, 15, 30, 0)), { hour: 105, minute: 180, second: 0 });
		compare(Lock.hands(new Date(2026, 9, 31, 12, 0, 15)).second, 90);
	}

	function test_cookieStaysInItsBox() {
		const points = Lock.cookie(200, 9, 0.055);
		const far = Math.max(...points.map(p => Math.hypot(p.x - 100, p.y - 100)));
		const near = Math.min(...points.map(p => Math.hypot(p.x - 100, p.y - 100)));
		verify(Math.abs(far - 100) < 0.01, "lobes touch the box");
		verify(near < 90, "the lobes are visible");
	}
}
