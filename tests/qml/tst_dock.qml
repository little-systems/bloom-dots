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

	// Hyprland keeps the last window at focus history 0 after you switch to an
	// empty workspace; only a window on the focused monitor's shown workspace
	// is really active.
	function test_activeAddress() {
		const monitors = [{ name: "eDP-1", focused: true, activeWorkspace: { id: 3 }, specialWorkspace: { id: 0 } }];
		const on = (address, ws, focus, extra) => {
			const c = { address: address, workspace: { id: ws }, focusHistoryID: focus, mapped: true, hidden: false };
			for (const k in extra || {}) c[k] = extra[k];
			return c;
		};
		compare(Dock.activeAddress([on("0xa", 1, 0)], monitors), "", "an empty workspace has no active window");
		compare(Dock.activeAddress([on("0xa", 3, 0)], monitors), "0xa");
		compare(Dock.activeAddress([on("0xa", 3, 1), on("0xb", 1, 0)], monitors), "");
		compare(Dock.activeAddress([on("0xa", 3, 0, { hidden: true })], monitors), "");
		compare(Dock.activeAddress([on("0xs", -98, 0)], [{ focused: true, activeWorkspace: { id: 3 }, specialWorkspace: { id: -98 } }]), "0xs", "an open special workspace");
		compare(Dock.activeAddress([on("0xa", 3, 0)], []), "", "no monitors (before Hyprland answers)");
	}

	// A never-focused window (focusHistoryID -1, e.g. autostarted silently)
	// is the least recent, not the most.
	function test_neverFocusedIsLeastRecent() {
		const ws = [{ address: "0xa", focus: -1 }, { address: "0xb", focus: 4 }];
		compare(Dock.clickAction({ id: "x", windows: ws }, ""), { kind: "focus", address: "0xb" });
		compare(Dock.clickAction({ id: "x", windows: [{ address: "0xa", focus: -1 }] }, ""), { kind: "focus", address: "0xa" });
	}

	// A hand-edited or damaged dock.json must not empty the dock.
	function test_pinsOf() {
		compare(Dock.pinsOf({ pinned: ["firefox", "kitty"] }), ["firefox", "kitty"]);
		compare(Dock.pinsOf(null), []);
		compare(Dock.pinsOf({ pinned: "firefox" }), []);
		compare(Dock.pinsOf({ pinned: ["a", 3, "a", "", null, "b"] }), ["a", "b"], "strings only, once each");
	}

	function test_slotsMarkPinned() {
		const items = { pinned: [{ id: "a", name: "A", icon: "", windows: [] }], unpinned: [{ id: "b", name: "B", icon: "", windows: [1] }] };
		const s = Dock.slots(items, true);
		compare(s.map(x => x.pinned), [true, false, false]);
	}
	function labels(entries) {
		return entries.map(e => e.kind === "divider" ? "-" : e.kind === "submenu" ? e.label + ">" : e.label);
	}

	function menuApp(props) {
		const t = { kind: "app", id: "firefox", pinned: false, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] };
		for (const k in props) t[k] = props[k];
		return t;
	}

	// Bloom Dock.tsx menus, mapped to Linux (plan ruling 2).
	function test_menuFor() {
		compare(labels(Dock.menuFor(menuApp({}))), ["Pin to Dock", "-", "Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor(menuApp({ pinned: true }))),
			["Unpin from Dock", "-", "Change Icon...", "-", "Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor(menuApp({ pinned: true, hasCustomIcon: true, running: true, windows: 2, actions: ["New Window", "New Private Window"] }))),
			["Unpin from Dock", "-", "Change Icon...", "Reset Icon", "-", "Add App to Dock...", "Bloom Options>",
			 "-", "New Window", "New Private Window", "Open New Window", "Close all windows"]);
		compare(labels(Dock.menuFor(menuApp({ running: true, windows: 1, pinnable: false }))),
			["Add App to Dock...", "Bloom Options>", "-", "Open New Window", "Close window"], "no pin without a desktop entry");
		const bloom = Dock.menuFor(menuApp({})).find(e => e.kind === "submenu");
		compare(labels(bloom.children), ["Restart Bloom", "-", "Quit Bloom"]);
		verify(bloom.children[2].danger);
		const close = Dock.menuFor(menuApp({ running: true, windows: 1 })).pop();
		compare(close.key, "close");
		verify(close.danger);
		compare(labels(Dock.menuFor({ kind: "background" })), ["Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor({ kind: "workspaces" })), ["Hide Workspaces"]);
		compare(Dock.menuFor(menuApp({ actions: ["A", "B"] })).filter(e => e.key && e.key.startsWith("action:")).map(e => e.key), ["action:0", "action:1"]);
	}

	function test_menuPosition() {
		compare(Dock.menuPosition(500, 400, 160, 120, 1920), { left: 500, top: 272 }, "opens above the pointer");
		compare(Dock.menuPosition(1900, 400, 160, 120, 1920), { left: 1752, top: 272 }, "kept inside the right edge");
		compare(Dock.menuPosition(2, 60, 160, 120, 1920), { left: 8, top: 8 }, "and the left and top edges");
	}

	// framer Reorder: the dragged item takes the slot whose neighbour centre it passed.
	function test_reorderIndex() {
		const centers = [18, 66, 114]; // the other three pinned icons
		compare(Dock.reorderIndex(centers, 0), 0);
		compare(Dock.reorderIndex(centers, 30), 1);
		compare(Dock.reorderIndex(centers, 70), 2);
		compare(Dock.reorderIndex(centers, 500), 3);
		compare(Dock.reorderIndex([], 50), 0);
		compare(Dock.moveKey(["a", "b", "c"], "a", 2), ["b", "c", "a"]);
		compare(Dock.moveKey(["a", "b", "c"], "c", 0), ["c", "a", "b"]);
		compare(Dock.moveKey(["a", "b", "c"], "b", 1), ["a", "b", "c"]);
	}

	function a(id, name) {
		return { id: id, name: name, icon: "" };
	}

	function test_addAppSections() {
		const all = [a("kitty", "kitty"), a("firefox", "Firefox"), a("dolphin", "Dolphin"), a("gimp", "GIMP"), a("chrome", "Google Chrome")];
		const running = [a("chrome", "Google Chrome")];
		const browse = Dock.addAppSections(all, running, ["firefox"], "");
		compare(browse.map(s => s.title), ["Running", "All apps"]);
		compare(browse[0].items.map(i => i.id), ["chrome"]);
		compare(browse[1].items.map(i => i.id), ["dolphin", "gimp", "kitty"], "sorted, without pinned or running");
		const q = Dock.addAppSections(all, running, ["firefox"], "  i ");
		compare(q.length, 1);
		compare(q[0].title, null);
		compare(q[0].items.map(i => i.id), ["dolphin", "firefox", "gimp", "kitty"], "contains 'i', by name; a search covers pinned too");
		const g = Dock.addAppSections(all, [], [], "g");
		compare(g[0].items.map(i => i.id), ["gimp", "chrome"], "starts-with before contains");
		compare(Dock.addAppSections([], [], [], ""), [], "nothing to show");
	}

	function test_workspaceCells() {
		const cells = Dock.workspaceCells([{ id: -1337, name: "web" }, { id: 3, name: "3" }, { id: 1, name: "1" }, { id: -1338, name: "mail" }], 3);
		compare(cells.map(c => c.label), ["1", "3", "W", "M"], "numbered first, then named as created");
		compare(cells.map(c => c.tip), ["Workspace 1", "Workspace 3", "web", "mail"]);
		compare(cells.map(c => c.active), [false, true, false, false]);
		compare(Dock.workspaceCells([{ id: 2, name: "2" }, { id: -98, name: "special:magic" }], 2).map(c => c.id), [2], "no special workspaces");
		compare(Dock.segmentWidth(3), 6 + 3 * 24 + 2 * 2 + 6);
		compare(Dock.segmentWidth(1), 36);
	}

	function test_iconState() {
		compare(Dock.iconsOf({ pinned: [], icons: { firefox: "/s/firefox.png", bad: 3 } }), { firefox: "/s/firefox.png" });
		compare(Dock.iconsOf(null), {});
		compare(Dock.iconFile("org.kde.dolphin", "/home/x/Pics/My Icon.PNG"), "org.kde.dolphin.png");
		compare(Dock.iconFile("firefox", "/a/b.svg"), "firefox.svg");
		compare(Dock.iconFile("firefox", "/a/b.exe"), "", "only Bloom's image types");
		compare(Dock.iconFile("../evil", "/a/b.png"), "___evil.png", "ids can't leave the icons folder");
	}

	function test_pickerScript() {
		verify(Dock.pickerScript.indexOf("kdialog") < Dock.pickerScript.indexOf("zenity"), "kdialog first (installed here)");
		verify(Dock.pickerScript.indexOf("exit 127") > 0);
		verify(Dock.pickerScript.indexOf('"$BLOOM_PICKER"') >= 0, "tests point it at a stub");
	}
	function test_slotsWithSegment() {
		const items = { pinned: [{ id: "a", name: "A", icon: "", windows: [] }], unpinned: [] };
		const s = Dock.slots(items, true, [{ id: 1 }, { id: 2 }]);
		compare(s.map(x => x.key), [Dock.workspacesKey, Dock.dividerKey + "ws", "a"]);
		compare(Dock.slots({ pinned: [], unpinned: [] }, true, [{ id: 1 }]).map(x => x.key), [Dock.workspacesKey], "no divider with nothing after it");
		compare(Dock.slots(items, true, []).map(x => x.key), ["a"], "no cells, no segment");
		compare(Dock.layout([Dock.workspacesKey, Dock.dividerKey + "ws", "a"], 2), { xs: [0, 74, 91], width: 127 }, "62 + 12 + 5 + 12 + 36");
	}

	// Review I6: each copy has its own name, so a new icon is a new URL.
	function test_iconFileTag() {
		compare(Dock.iconFile("firefox", "/a/b.svg", "k3"), "firefox-k3.svg");
		compare(Dock.iconFile("firefox", "/a/b.svg"), "firefox.svg");
	}

	// Review M3: Bloom only ever deletes its own copies.
	function test_ownsIconPath() {
		verify(Dock.ownsIconPath("/s/bloom/dock-icons", "/s/bloom/dock-icons/firefox-k3.png"));
		verify(!Dock.ownsIconPath("/s/bloom/dock-icons", "/home/me/Pictures/logo.png"));
		verify(!Dock.ownsIconPath("/s/bloom/dock-icons", "/s/bloom/dock-icons/../dock.json"));
		verify(!Dock.ownsIconPath("/s/bloom/dock-icons", "/s/bloom/dock-icons-evil/x.png"));
		verify(!Dock.ownsIconPath("/s/bloom/dock-icons", "/s/bloom/dock-icons/sub/x.png"), "no subfolders");
	}
	function hw(id, name, monitor) {
		return { id: id, name: name, monitor: monitor };
	}

	// Hyprland gives named workspaces ids from -1337 down; only special
	// (scratchpad) workspaces are left out.
	function test_workspaceState() {
		const m = { name: "eDP-1" };
		const other = { name: "HDMI-A-1" };
		const all = [hw(1, "1", m), hw(2, "2", m), hw(3, "3", other), hw(-1337, "web", m), hw(-98, "special:magic", m)];
		compare(Dock.workspaceState(hw(2, "2", m), all, m), { id: 2, name: "2", ids: [-1337, 1, 2] });
		compare(Dock.workspaceState(hw(-1337, "web", m), all, m), { id: -1337, name: "web", ids: [-1337, 1, 2] });
		compare(Dock.workspaceState(hw(-98, "special:magic", m), all, m), null);
		compare(Dock.workspaceState(null, all, m), null);
		compare(Dock.workspaceState(hw(5, "5", m), [], m), { id: 5, name: "5", ids: [5] }, "not listed yet");
	}
}
