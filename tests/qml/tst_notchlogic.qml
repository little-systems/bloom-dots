import QtQuick
import QtTest
import "../../shell/modules/notch/notch.js" as Notch

TestCase {
	name: "NotchLogic"

	function test_statusWidth() {
		compare(Notch.statusWidth(false, 2, 0, false), 140);
		compare(Notch.statusWidth(false, 2, 0, true), 124);
		compare(Notch.statusWidth(true, 2, 0, false), 300);
		compare(Notch.statusWidth(true, 6, 0, false), 380);
		compare(Notch.statusWidth(true, 6, 0, true), 364);
		compare(Notch.statusWidth(true, 2, 330, false), 330, "content wider than the formula wins");
	}

	function test_fitWidth() {
		compare(Notch.fitWidth(60, 80, 50), 60 + 2 * (80 + 10) + 24);
		compare(Notch.fitWidth(60.2, 0, 0), 0, "no widgets measured yet");
	}

	function shown() { return { ready: true, visible: true, hidden: false, expanded: true, impacted: true }; }

	function test_geometryShown() {
		compare(Notch.geometry(shown(), { width: 140, height: 36 }), { y: 0, width: 140, height: 36, edgeRadius: 0, farRadius: 18, opacity: 1 });
	}

	function test_geometryStartup() {
		compare(Notch.geometry({ ready: false, visible: true, hidden: false, expanded: false, impacted: false }, { width: 140, height: 36 }),
			{ y: 250, width: 34, height: 34, edgeRadius: 18, farRadius: 18, opacity: 1 });
		compare(Notch.geometry({ ready: true, visible: true, hidden: false, expanded: false, impacted: false }, { width: 140, height: 36 }),
			{ y: 0, width: 30.6, height: 44.2, edgeRadius: 18, farRadius: 18, opacity: 1 });
	}

	function test_geometryHidden() {
		const s = shown();
		s.hidden = true;
		compare(Notch.geometry(s, { width: 300, height: 36 }), { y: -100, width: 39.1, height: 28.9, edgeRadius: 0, farRadius: 18, opacity: 1 });
	}

	function test_geometryInvisible() {
		const s = shown();
		s.visible = false;
		const g = Notch.geometry(s, { width: 140, height: 36 });
		compare(g.y, -150);
		compare(g.opacity, 0);
		compare(g.width, 39.1);
	}

	function test_isHidden() {
		verify(!Notch.isHidden("fixed", true, "none", false, false));
		verify(Notch.isHidden("smart", true, "none", false, false));
		verify(!Notch.isHidden("smart", true, "grace", false, false), "grace keeps it shown");
		verify(!Notch.isHidden("smart", false, "none", false, false));
		verify(Notch.isHidden("peek", false, "none", false, false));
		verify(!Notch.isHidden("peek", false, "active", false, false));
		verify(!Notch.isHidden("peek", false, "none", true, false), "event peek shows it");
		verify(!Notch.isHidden("peek", false, "none", false, true), "startup animation shows it");
	}

	function monitor() {
		return { id: 0, name: "eDP-1", x: 1920, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 45, 0, 0], activeWorkspace: { id: 2 } };
	}

	function client(props) {
		const c = { mapped: true, hidden: false, monitor: 0, workspace: { id: 2 }, at: [1924, 49], size: [1912, 1027], fullscreen: 0, focusHistoryID: 1 };
		for (const k in props) c[k] = props[k];
		return c;
	}

	function test_focusedWindow() {
		const clients = [
			client({ focusHistoryID: 3, at: [10, 10] }),
			client({ focusHistoryID: 1, at: [1924, 49] }),
			client({ focusHistoryID: 0, workspace: { id: 5 } }),
			client({ focusHistoryID: 0, monitor: 1 }),
			client({ focusHistoryID: 0, hidden: true })
		];
		compare(Notch.focusedWindow(clients, monitor()), { x: 1924, y: 49, width: 1912, height: 1027, fullscreen: 0 });
		compare(Notch.focusedWindow([], monitor()), null);
	}

	function test_notchRect() {
		compare(Notch.notchRect(monitor(), 140, 1), { left: 1920 + 890, right: 1920 + 1030, top: 45, rowHeight: 36 });
		const hidpi = monitor();
		hidpi.width = 3840;
		hidpi.scale = 2;
		compare(Notch.notchRect(hidpi, 140, 1.2), { left: 1920 + 960 - 84, right: 1920 + 960 + 84, top: 45, rowHeight: 43.2 });
	}

	function test_overlaps() {
		const rect = { left: 2810, right: 2950, top: 45, rowHeight: 36 };
		verify(Notch.overlaps({ x: 1924, y: 49, width: 1912, height: 1027, fullscreen: 0 }, rect), "tiled window under the notch");
		verify(!Notch.overlaps({ x: 1924, y: 77, width: 1912, height: 900, fullscreen: 0 }, rect), "starts below the trigger line");
		verify(!Notch.overlaps({ x: 1924, y: 49, width: 890, height: 900, fullscreen: 0 }, rect), "ends left of the notch");
		verify(!Notch.overlaps({ x: 2946, y: 49, width: 500, height: 900, fullscreen: 0 }, rect), "within the 4 px inset");
		verify(Notch.overlaps({ x: 1920, y: 500, width: 100, height: 100, fullscreen: 1 }, rect), "maximised counts");
		verify(!Notch.overlaps(null, rect));
	}

	// Hyprland fullscreen states: 0 none, 1 maximised, 2 fullscreen, 3 both.
	function test_fullscreenOn() {
		verify(!Notch.fullscreenOn([], monitor()));
		verify(!Notch.fullscreenOn([client({ fullscreen: 1 })], monitor()), "maximised is not fullscreen");
		verify(Notch.fullscreenOn([client({ fullscreen: 2 })], monitor()));
		verify(Notch.fullscreenOn([client({ fullscreen: 3 })], monitor()));
		verify(!Notch.fullscreenOn([client({ fullscreen: 2, workspace: { id: 5 } })], monitor()), "another workspace");
		verify(!Notch.fullscreenOn([client({ fullscreen: 2, monitor: 1 })], monitor()), "another monitor");
	}

	function test_clockText() {
		compare(Notch.clockText(new Date(2026, 9, 25, 13, 5), false), "01:05 PM");
		compare(Notch.clockText(new Date(2026, 9, 25, 0, 30), false), "12:30 AM");
		compare(Notch.clockText(new Date(2026, 9, 25, 12, 0), false), "12:00 PM");
		compare(Notch.clockText(new Date(2026, 9, 25, 13, 5), true), "13:05");
		compare(Notch.clockText(new Date(2026, 9, 25, 7, 9), true), "07:09");
	}
}
