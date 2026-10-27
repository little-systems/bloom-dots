import QtQuick
import QtTest
import "../../shell/modules/dock"
import "../../shell/common/tokens.js" as Tokens

Item {
	id: host
	width: 1000
	height: 420

	function app(id, windows) {
		return { id: id, name: id, icon: "", windows: windows || [] };
	}

	Component {
		id: viewComponent
		DockView {
			width: 1000
			height: 420
			mode: "fixed"
			items: ({ pinned: [host.app("a"), host.app("b", [{ address: "0x1", focus: 0 }])], unpinned: [host.app("c", [{ address: "0x2", focus: 1 }])] })
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockView"
		when: windowShown

		function make(props) {
			mouseMove(host, 0, 0);
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		function settle(v) {
			v.ready = true;
			tryCompare(v, "expanded", true, 1000);
			tryCompare(v, "startupAnimating", false, 3000);
		}

		function test_startup() {
			const v = make();
			compare(v.target.y, -800, "parked above before ready");
			v.ready = true;
			compare(v.target.y, 0);
			compare(v.target.width, 34);
			tryCompare(v, "impacted", true, 1000);
			tryCompare(v, "expanded", true, 1000);
			compare(v.target.height, 52);
			compare(v.target.width, 36 * 3 + 12 * 3 + 5 + 16, "three icons, a divider, gaps and padding");
		}

		function test_separatorSetting() {
			const v = make({ separatorEnabled: false });
			settle(v);
			compare(v.target.width, 36 * 3 + 12 * 2 + 16);
			compare(v.stateObject().keys, ["a", "b", "c"]);
		}

		function test_peekHidesUntilTheEdgeDwell() {
			const v = make({ mode: "peek", edgeDelay: 100 });
			settle(v);
			tryCompare(v, "hidden", true, 3000);
			compare(v.target.y, 100);
			verify(v.bandActive);
			const band = v.bandItem;
			mouseMove(band, band.width / 2, 1);
			tryCompare(v, "hidden", false, 1000, "revealed after the dwell");
		}

		function test_smartFollowsOverlapWithGrace() {
			const v = make({ mode: "smart" });
			settle(v);
			v.overlapped = true;
			tryCompare(v, "hidden", true, 1000);
			v.overlapped = false;
			compare(v.hidden, false);
		}

		function test_adaptive() {
			const v = make({ adaptiveEnabled: true, maximized: true });
			settle(v);
			compare(v.target.width, 1000 - 48, "nearly full width");
			v.mode = "smart";
			v.maximized = false;
			compare(v.target.width, v.naturalWidth, "fixed mode only");
		}

		function test_userVisibility() {
			const v = make();
			settle(v);
			v.userVisible = false;
			compare(v.target.y, 150);
			compare(v.target.opacity, 0);
		}

		function test_addAndRemoveItems() {
			const v = make();
			settle(v);
			v.items = { pinned: [host.app("a"), host.app("b")], unpinned: [host.app("c"), host.app("d", [{ address: "0x3", focus: 2 }])] };
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c", "d"]);
			v.items = { pinned: [host.app("a"), host.app("b")], unpinned: [host.app("d", [{ address: "0x3", focus: 2 }])] };
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c", "d"], "c is still leaving");
			tryVerify(() => v.stateObject().keys.length === 4, 1500, "removed once its exit has played");
			compare(v.stateObject().keys, ["a", "b", "|divider|", "d"]);
		}

		// Review focus 2.
		function test_reopenDuringExitReusesTheSlot() {
			const v = make();
			settle(v);
			const withC = v.items;
			v.items = { pinned: withC.pinned, unpinned: [] };
			wait(100);
			v.items = withC;
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c"], "one c, back in its place");
			wait(800);
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c"]);
		}

		// Review focus 2: framer layout animation. Neighbours stay where they
		// were in the frame of the change, then slide; nothing jumps.
		function test_neighboursSlideNotJump() {
			const v = make({ items: { pinned: [host.app("a"), host.app("b")], unpinned: [] } });
			settle(v);
			settleFrames();
			const a = findChild(v, "dock-slot-a");
			const b = findChild(v, "dock-slot-b");
			const at = item => item.mapToItem(v, 0, 0).x;
			const ax = at(a);
			const bx = at(b);
			v.items = { pinned: [host.app("a"), host.app("n"), host.app("b")], unpinned: [] };
			compare(Math.round(at(a)), Math.round(ax), "a holds its place in the frame of the change");
			compare(Math.round(at(b)), Math.round(bx), "b too");
			tryVerify(() => Math.abs(at(a) - (ax - 24)) < 0.5, 2000, "then a slides half a slot left");
			tryVerify(() => Math.abs(at(b) - (bx + 24)) < 0.5, 2000, "and b half a slot right");
		}

		// Bloom: a closing app (not pinned) exits in 120 ms; pinned ones keep
		// the delayed spring.
		function test_closingAppLeavesQuickly() {
			const v = make();
			settle(v);
			v.items = { pinned: [host.app("a"), host.app("b")], unpinned: [] };
			tryVerify(() => v.stateObject().keys.indexOf("c") < 0, 300, "the closed app's slot is gone quickly");
			v.items = { pinned: [host.app("a")], unpinned: [] };
			wait(300);
			verify(v.stateObject().keys.indexOf("b") >= 0, "a pinned app still plays its slower exit");
			tryVerify(() => v.stateObject().keys.indexOf("b") < 0, 1000);
		}

		function test_clicksReachTheDock() {
			const v = make();
			settle(v);
			wait(500);
			const activated = createTemporaryObject(spyComponent, host, { target: v, signalName: "activated" });
			const newInstance = createTemporaryObject(spyComponent, host, { target: v, signalName: "newInstance" });
			const hit = v.hitItem;
			const first = hit.mapToItem(v, 8 + 18, 8 + 18);
			mouseClick(v, first.x, first.y);
			compare(activated.count, 1);
			compare(activated.signalArguments[0][0], "a");
			mouseClick(v, first.x, first.y, Qt.MiddleButton);
			compare(newInstance.signalArguments[0][0], "a");
		}

		function test_previewHoverAndClose() {
			const v = make({ previewSources: [{ address: "0x1", toplevel: null }] });
			settle(v);
			const slot = findChild(v, "dock-slot-b");
			const point = slot.mapToItem(v, slot.width / 2, slot.height / 2);
			mouseMove(v, point.x, point.y);
			tryCompare(v, "previewOpen", true, 1000);
			compare(v.previewItem.candidates.map(c => c.address), ["0x1"]);
			const focus = createTemporaryObject(spyComponent, host, { target: v, signalName: "previewFocus" });
			v.previewItem.focusRequested("0x1");
			compare(focus.signalArguments[0][0], "0x1");
			v.closeMenus();
			compare(v.previewOpen, false);
		}

		function test_previewSettingCanDisableCapture() {
			const v = make({ previewEnabled: false, previewSources: [{ address: "0x1", toplevel: null }] });
			settle(v);
			const slot = findChild(v, "dock-slot-b");
			const point = slot.mapToItem(v, slot.width / 2, slot.height / 2);
			mouseMove(v, point.x, point.y);
			wait(350);
			compare(v.previewOpen, false);
		}

		function test_extraTilesKeepPinnedAppOrder() {
			const extras = [{ key: "drive:USB", kind: "drive", name: "USB", icon: "", path: "/run/media/me/USB" }];
			const v = make({ extraItems: extras, extrasPosition: "left" });
			settle(v);
			compare(v.stateObject().keys, ["extra:drive:USB", "|divider|extras", "a", "b", "|divider|", "c"], "extras sit before apps");
			compare(v.items.pinned.map(x => x.id), ["a", "b"], "shortcuts stay app-only");
			v.extrasPosition = "right";
			tryVerify(() => v.stateObject().keys.indexOf("extra:drive:USB") > v.stateObject().keys.indexOf("c"), 1000);
			v.extrasPosition = "off";
			tryVerify(() => v.stateObject().keys.indexOf("extra:drive:USB") < 0, 1000);
		}

		function test_emptyTrashOutsideDismissesWithoutRunning() {
			const v = make();
			settle(v);
			const emptied = createTemporaryObject(spyComponent, host, { target: v, signalName: "emptyTrashConfirmed" });
			v.confirmEmptyTrash();
			compare(v.confirmOpen, true);
			v.closeMenus();
			compare(v.confirmOpen, false);
			compare(emptied.count, 0);
		}

		function test_trayOnlyItemHasItsOwnAction() {
			const v = make({ trayOnlyItems: [{ key: "sni-1", title: "Chat", icon: "" }] });
			settle(v);
			compare(v.stateObject().keys.slice(-2), ["|divider|tray", "tray:sni-1"]);
			const activated = createTemporaryObject(spyComponent, host, { target: v, signalName: "trayActivated" });
			const slot = findChild(v, "dock-slot-tray:sni-1");
			const point = slot.mapToItem(v, slot.width / 2, slot.height / 2);
			wait(250);
			mouseClick(v, point.x, point.y);
			compare(activated.count, 1);
			compare(activated.signalArguments[0][0], "sni-1");
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

		function test_idleDockDrawsNoFrames() {
			const v = make();
			settle(v);
			settleFrames();
			compare(framesIn(1000), 0);
		}

		// Review focus 3: smart mode's poll re-sends equal window data every second.
		function test_identicalItemsDrawNoFrames() {
			const v = make();
			settle(v);
			settleFrames();
			const same = JSON.stringify(v.items);
			let n = 0;
			const churn = () => { v.items = JSON.parse(same); };
			for (let i = 0; i < 5; i++) {
				churn();
				n += framesIn(200);
			}
			compare(n, 0);
		}

		function test_hiddenDockDrawsNoFrames() {
			const v = make({ mode: "peek" });
			settle(v);
			tryCompare(v, "hidden", true, 3000);
			settleFrames();
			compare(framesIn(1000), 0);
		}

		// Review focus 2.
		function test_dragReorders() {
			const v = make();
			settle(v);
			settleFrames();
			const spy = createTemporaryObject(spyComponent, host, { target: v, signalName: "reordered" });
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 64; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			mouseRelease(v, start.x + 64, start.y);
			compare(spy.count, 1);
			compare(spy.signalArguments[0][0], ["b", "a"]);
		}

		function test_dragIsNotAClick() {
			const v = make();
			settle(v);
			settleFrames();
			const activated = createTemporaryObject(spyComponent, host, { target: v, signalName: "activated" });
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 40; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			mouseRelease(v, start.x + 40, start.y);
			compare(activated.count, 0);
		}

		function test_runningAppsDoNotDrag() {
			const v = make();
			settle(v);
			settleFrames();
			const spy = createTemporaryObject(spyComponent, host, { target: v, signalName: "reordered" });
			const c = findChild(v, "dock-slot-c");
			const start = c.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 64; dx += 4)
				mouseMove(v, start.x - dx, start.y);
			mouseRelease(v, start.x - 64, start.y);
			compare(spy.count, 0);
		}

		function rightClickA(v) {
			const p = findChild(v, "dock-slot-a").mapToItem(v, 18, 18);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			return p;
		}

		// Review C1: the menu item and the outside-click catcher both saw the
		// release, so Add App opened and closed in one click.
		function test_addAppFromTheMenu() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			settleFrames();
			rightClickA(v);
			mouseClick(findChild(v, "menu-item-add-app"), 10, 10);
			verify(v.keyboardWanted, "the card is open");
		}

		// Review I1: a click on the card's own padding must not close it.
		function test_cardPaddingKeepsItOpen() {
			const v = make();
			settle(v);
			v.openAddApp();
			wait(400);
			mouseClick(v.popupItem, 180, 436);
			verify(v.keyboardWanted, "bottom padding");
			mouseClick(v.popupItem, 3, 200);
			verify(v.keyboardWanted, "side margin");
		}

		// Review I2: the window's mask uses these, so they must be the boxes,
		// not the full-surface menu root.
		function test_maskItemsAreTheBoxes() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			rightClickA(v);
			verify(v.menuBoxItem.width < 300 && v.menuBoxItem.height < 400, "the menu box");
			compare(v.popupItem.width, 360);
		}

		// Review I3 (Bloom: an open menu or card counts as interaction).
		function test_openMenuKeepsTheDockShown() {
			const v = make({ mode: "smart", menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			v.overlapped = true;
			const p = rightClickA(v);
			mouseMove(v, 20, 20);
			wait(1500);
			verify(v.grabWanted);
			verify(!v.hidden, "not hidden while the menu is open");
		}

		// Review I4: the dropped icon springs from where it was let go.
		function test_dropSpringsToItsSlot() {
			const v = make();
			settle(v);
			settleFrames();
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 64; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			const held = a.mapToItem(v, 0, 0).x;
			mouseRelease(v, start.x + 64, start.y);
			verify(Math.abs(a.mapToItem(v, 0, 0).x - held) < 1.5, `no snap on release (${held} -> ${a.mapToItem(v, 0, 0).x})`);
			// What the Dock service does on `reordered`.
			v.items = { pinned: [host.app("b", [{ address: "0x1", focus: 0 }]), host.app("a")], unpinned: [host.app("c", [{ address: "0x2", focus: 1 }])] };
			const b = findChild(v, "dock-slot-b");
			tryVerify(() => Math.abs(a.mapToItem(v, 0, 0).x - (b.mapToItem(v, 0, 0).x + 48)) < 0.5, 2000, "then settles one slot after b");
		}

		// Review I7: the icon follows the pointer one-to-one at any bloom-scale.
		function test_dragFollowsThePointerAtScale() {
			const v = make({ uiScale: 1.3 });
			settle(v);
			settleFrames();
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			const x0 = a.mapToItem(v, 0, 0).x;
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 32; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			verify(Math.abs(a.mapToItem(v, 0, 0).x - x0 - 32) < 1.5, `moved ${a.mapToItem(v, 0, 0).x - x0} for 32`);
			mouseRelease(v, start.x + 32, start.y);
		}

		// Review I7: the card fits the surface at the largest bloom-scale.
		function test_cardFitsAtLargestScale() {
			const v = make({ uiScale: 1.3, height: Tokens.dock.surfaceHeight });
			settle(v);
			v.openAddApp();
			wait(500);
			verify(v.popupItem.mapToItem(v, 0, 0).y >= 0, "the card's top is on the surface");
		}

		function test_rightClickOpensTheMenu() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			settleFrames();
			const chosen = createTemporaryObject(spyComponent, host, { target: v, signalName: "menuChosen" });
			const a = findChild(v, "dock-slot-a");
			const p = a.mapToItem(v, 18, 18);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			verify(v.grabWanted);
			mouseClick(findChild(v, "menu-item-unpin"), 10, 10);
			compare(chosen.signalArguments[0][0], "a");
			compare(chosen.signalArguments[0][1], "unpin");
			verify(!v.grabWanted);
		}

		// Review focus 1 (the part a test can reach).
		function test_outsideClickInsideTheSurfaceCloses() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			const p = findChild(v, "dock-slot-a").mapToItem(v, 18, 18);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			verify(v.grabWanted);
			mouseClick(v, 20, 20);
			verify(!v.grabWanted);
		}

		function test_addAppTakesTheKeyboard() {
			const v = make({ menuTarget: id => ({ kind: "background" }) });
			settle(v);
			v.openAddApp();
			verify(v.keyboardWanted);
			keyClick(Qt.Key_Escape);
			verify(!v.keyboardWanted);
		}

		function test_toast() {
			const v = make();
			settle(v);
			const toast = findChild(v, "dock-toast");
			compare(toast.opacity, 0);
			v.toastMessage = "Couldn't use that image";
			v.toastSerial++;
			tryCompare(toast, "opacity", 1, 500);
			compare(findChild(v, "dock-toast-text").text, "Couldn't use that image");
		}

		function test_segment() {
			const v = make({ workspaceCells: [{ id: 1, label: "1", tip: "Workspace 1", active: true }, { id: 2, label: "2", tip: "Workspace 2", active: false }] });
			settle(v);
			compare(v.stateObject().keys.slice(0, 2), ["|workspaces|", "|divider|ws"]);
			const sw = createTemporaryObject(spyComponent, host, { target: v, signalName: "switchWorkspace" });
			mouseClick(findChild(v, "ws-cell-2"), 12, 12);
			compare(sw.signalArguments[0][0].id, 2);
		}

		function test_closedMenusDrawNoFrames() {
			const v = make({ menuTarget: id => ({ kind: "background" }) });
			settle(v);
			v.openAddApp();
			wait(300);
			keyClick(Qt.Key_Escape);
			// An open card counts as interaction (Bloom), so its 800 ms grace runs
			// after it closes; a QML Timer finishing draws a frame or two (Qt's
			// animation driver stopping), which is not the dock animating.
			wait(Tokens.dock.graceMs + 200);
			settleFrames();
			compare(framesIn(1000), 0, "nothing runs once the card has gone");
		}
	}
}
