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

	function test_wallpaperZoomFromIi() {
		compare(Lock.wallpaperZoomFrom('{"background":{"parallax":{"workspaceZoom":1.04}}}'), 1.04);
		compare(Lock.wallpaperZoomFrom("{}"), 1);
		compare(Lock.wallpaperZoomFrom('{"background":{"parallax":{"workspaceZoom":0}}}'), 1);
		compare(Lock.wallpaperZoomFrom("nope"), 1);
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

	readonly property var monitors: [
		{ name: "eDP-1", activeWorkspace: { id: 3 } },
		{ name: "HDMI-A-1", activeWorkspace: { id: 7 } }
	]

	function test_workspacesAreSaved() {
		compare(Lock.saveWorkspaces(monitors), { "eDP-1": 3, "HDMI-A-1": 7 });
		compare(Lock.saveWorkspaces([]), {});
		compare(Lock.saveWorkspaces(undefined), {});
	}

	// A special workspace isn't somewhere to come back to, and a name that
	// would break out of the shell line never reaches it.
	function test_badMonitorsAreSkipped() {
		compare(Lock.saveWorkspaces([{ name: "eDP-1", activeWorkspace: { id: -98 } }]), {});
		compare(Lock.saveWorkspaces([{ name: "a'; rm -rf x", activeWorkspace: { id: 1 } }]), {});
		compare(Lock.saveWorkspaces([{ name: "eDP-1" }]), {});
	}

	function test_scripts() {
		const saved = { "eDP-1": 3 };
		compare(Lock.leaveScript(saved), "hyprctl dispatch 'hl.dsp.focus({monitor=\"eDP-1\"})'; hyprctl dispatch 'hl.dsp.focus({workspace=2147483644})';");
		compare(Lock.returnScript(saved), "hyprctl dispatch 'hl.dsp.focus({monitor=\"eDP-1\"})'; hyprctl dispatch 'hl.dsp.focus({workspace=3})';");
		compare(Lock.returnScript({}), "");
	}

	function test_markerRoundTrip() {
		compare(Lock.parseMarker(JSON.stringify({ "eDP-1": 3 })), { "eDP-1": 3 });
		compare(Lock.parseMarker('{"bad name;": 3}'), {});
		compare(Lock.parseMarker(""), {});
	}
}
