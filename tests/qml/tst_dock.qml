import QtQuick
import QtTest
import "../../shell/modules/dock/dock.js" as Dock

TestCase {
	name: "DockRules"

	function client(cls, address, focus, extra) {
		const c = { class: cls, address: address, focusHistoryID: focus, title: cls + " " + address, mapped: true, hidden: false };
		for (const k in extra || {}) c[k] = extra[k];
		return c;
	}

	function idOf(cls) {
		return Dock.identity(cls, { firefox: "firefox", kitty: "kitty" }[cls] || "");
	}

	function test_identityAndGroups() {
		compare(Dock.identity("firefox", "firefox"), "firefox");
		compare(Dock.identity("code", ""), "class:code", "no desktop entry");
		const groups = Dock.groupWindows([
			client("kitty", "0xa", 2), client("firefox", "0xb", 0), client("kitty", "0xc", 1),
			client("code", "0xd", 3), client("", "0xe", 4), client("ghost", "0xf", 5, { mapped: false }), client("hid", "0x10", 6, { hidden: true })
		], idOf);
		compare(groups.map(g => g.id), ["kitty", "firefox", "class:code"], "first-seen order; unnamed, unmapped and hidden windows skipped");
		compare(groups[0].windows.map(w => w.address), ["0xa", "0xc"]);
		compare(groups[0].windows[1].focus, 1);
	}

	// Bloom's activeOrder: running apps keep their place, new ones join the end.
	function test_nextOrder() {
		compare(Dock.nextOrder([], ["a", "b"]), ["a", "b"]);
		compare(Dock.nextOrder(["a", "b"], ["b", "c", "a"]), ["a", "b", "c"]);
		compare(Dock.nextOrder(["a", "b", "c"], ["c", "a"]), ["a", "c"]);
	}

	function info(id) {
		return { name: id.toUpperCase(), icon: "icon:" + id };
	}

	function test_buildItems() {
		const groups = [{ id: "kitty", windows: [{ address: "0xa", focus: 0 }] }, { id: "class:code", windows: [{ address: "0xd", focus: 1 }] }];
		const items = Dock.buildItems(["firefox", "kitty"], groups, ["kitty", "class:code"], info);
		compare(items.pinned.map(i => i.id), ["firefox", "kitty"]);
		compare(items.pinned[0].windows, [], "pinned and not running");
		compare(items.pinned[1].windows.length, 1, "a pinned app picks up its windows");
		compare(items.unpinned.map(i => i.id), ["class:code"], "running pins are not repeated");
		compare(items.unpinned[0].name, "CLASS:CODE");
	}

	function test_slots() {
		const items = { pinned: [{ id: "a", name: "A", icon: "", windows: [] }], unpinned: [{ id: "b", name: "B", icon: "x", windows: [1, 2, 3, 4] }] };
		const s = Dock.slots(items, true);
		compare(s.map(x => x.key), ["a", Dock.dividerKey, "b"]);
		compare(s[2].windows, 4);
		compare(Dock.slots(items, false).map(x => x.key), ["a", "b"], "separator off");
		compare(Dock.slots({ pinned: [], unpinned: items.unpinned }, true).map(x => x.key), ["b"], "no pinned, no divider");
		compare(Dock.slots({ pinned: items.pinned, unpinned: [] }, true).map(x => x.key), ["a"], "nothing unpinned, no divider");
	}

	// framer AnimatePresence: a leaving item keeps its place until its exit ends.
	function test_reconcile() {
		const rows = keys => keys.map(k => ({ key: k, leaving: false }));
		compare(Dock.reconcile([], ["a", "b"], []), rows(["a", "b"]));
		compare(Dock.reconcile(rows(["a", "b", "c"]), ["a", "c"], []), [{ key: "a", leaving: false }, { key: "b", leaving: true }, { key: "c", leaving: false }]);
		compare(Dock.reconcile(rows(["a", "b", "c"]), ["a", "c"], ["b"]), rows(["a", "c"]), "expired exits are dropped");
		compare(Dock.reconcile([{ key: "a", leaving: false }, { key: "b", leaving: true }], ["a", "b"], []), rows(["a", "b"]), "a returning item reuses its slot");
		compare(Dock.reconcile(rows(["x", "a"]), ["a"], []), [{ key: "x", leaving: true }, { key: "a", leaving: false }], "a leaving first item stays first");
		compare(Dock.reconcile(rows(["a", "b"]), ["c"], []), [{ key: "a", leaving: true }, { key: "b", leaving: true }, { key: "c", leaving: false }], "leaving items keep their place; the new one follows");
	}

	function test_layout() {
		compare(Dock.layout([]), { xs: [], width: 0 });
		compare(Dock.layout(["a"]), { xs: [0], width: 36 });
		compare(Dock.layout(["a", Dock.dividerKey, "b"]), { xs: [0, 48, 65], width: 101 }, "36 + 12 + 5 + 12 + 36");
	}

	function app(windows) {
		return { id: "x", windows: windows };
	}

	function test_clickAction() {
		compare(Dock.clickAction(app([]), "0x1"), { kind: "launch" });
		const ws = [{ address: "0xb", focus: 3 }, { address: "0xa", focus: 1 }, { address: "0xc", focus: 2 }];
		compare(Dock.clickAction(app(ws), "0xff"), { kind: "focus", address: "0xa" }, "from another app: the most recent window");
		compare(Dock.clickAction(app(ws), "0xa"), { kind: "focus", address: "0xb" }, "focused: the next in a stable order");
		compare(Dock.clickAction(app(ws), "0xb"), { kind: "focus", address: "0xc" });
		compare(Dock.clickAction(app(ws), "0xc"), { kind: "focus", address: "0xa" }, "wraps around");
		compare(Dock.clickAction(app([{ address: "0xa", focus: 0 }]), "0xa"), { kind: "none" }, "no minimise on Hyprland");
	}

	function test_dotCount() {
		compare(Dock.dotCount(0), 0);
		compare(Dock.dotCount(1), 1);
		compare(Dock.dotCount(7), 3);
	}

	function test_isHidden() {
		verify(!Dock.isHidden("fixed", true, "none", false));
		verify(Dock.isHidden("smart", true, "none", false));
		verify(!Dock.isHidden("smart", true, "grace", false));
		verify(!Dock.isHidden("smart", false, "none", false));
		verify(Dock.isHidden("peek", false, "none", false));
		verify(!Dock.isHidden("peek", false, "active", false));
		verify(!Dock.isHidden("peek", false, "none", true), "never during startup");
	}

	function geo(props) {
		const s = { ready: true, visible: true, hidden: false, expanded: true, impacted: true, contentWidth: 200, adaptive: false, adaptiveWidth: 1872 };
		for (const k in props) s[k] = props[k];
		return Dock.geometry(s);
	}

	function test_geometry() {
		compare(geo({ ready: false, expanded: false, impacted: false }), { y: -800, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 1 });
		compare(geo({}), { y: 0, width: 200, height: 52, edgeRadius: 0, farRadius: 18, opacity: 1 });
		compare(geo({ expanded: false }), { y: 0, width: 34, height: 34, edgeRadius: 0, farRadius: 18, opacity: 1 }, "impacted, not yet expanded");
		compare(geo({ hidden: true }), { y: 100, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 1 });
		compare(geo({ visible: false }), { y: 150, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 0 });
		compare(geo({ adaptive: true }).width, 1872);
		compare(Dock.adaptiveWidth(1920, 1), 1872);
		compare(Dock.adaptiveWidth(1920, 1.2), 1552);
	}

	// Bloom window_reaches_dock, plus maximised/fullscreen always counting.
	function test_overlaps() {
		const monitor = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 0, 0, 0] };
		const rect = Dock.dockRect(monitor, 200, 1);
		compare(rect, { left: 860, right: 1060, bottom: 1080 });
		verify(Dock.overlaps({ x: 800, y: 600, width: 400, height: 440, fullscreen: 0 }, rect, 1), "reaches below 1080 - 56");
		verify(!Dock.overlaps({ x: 800, y: 600, width: 400, height: 420, fullscreen: 0 }, rect, 1), "stops above the trigger");
		verify(!Dock.overlaps({ x: 0, y: 600, width: 860, height: 480, fullscreen: 0 }, rect, 1), "beside the dock");
		verify(Dock.overlaps({ x: 0, y: 0, width: 10, height: 10, fullscreen: 1 }, rect, 1), "maximised");
		verify(!Dock.overlaps(null, rect, 1));
		verify(Dock.maximized({ fullscreen: 1 }));
		verify(!Dock.maximized({ fullscreen: 2 }), "fullscreen is not maximised");
		verify(!Dock.maximized(null));
		const scaled = Dock.dockRect({ x: 1920, y: 0, width: 2880, height: 1620, scale: 1.5, reserved: [0, 0, 0, 0] }, 200, 1);
		compare(scaled, { left: 1920 + 860, right: 1920 + 1060, bottom: 1080 }, "logical pixels on a scaled second monitor");
	}

	function test_focusArg() {
		compare(Dock.focusArg("0x55f359ed2430"), 'hl.dsp.focus({ window = "address:0x55f359ed2430" })');
		compare(Dock.focusArg("0x1\" })os.execute(\"x"), "", "only hex addresses reach the dispatcher");
		compare(Dock.focusArg(""), "");
	}
}
