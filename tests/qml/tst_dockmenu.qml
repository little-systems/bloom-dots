import QtQuick
import QtTest
import "../../shell/modules/dock"
import "../../shell/modules/dock/dock.js" as Dock

Item {
	id: host
	width: 800
	height: 500

	Component {
		id: menuComponent
		DockMenu {
			anchors.fill: parent
			viewWidth: 800
			entries: Dock.menuFor({ kind: "app", id: "firefox", pinned: true, pinnable: true, running: true, windows: 1, hasCustomIcon: false, actions: ["New Private Window"] })
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockMenu"
		when: windowShown

		function make() {
			mouseMove(host, 0, 0);
			const m = createTemporaryObject(menuComponent, host);
			verify(m !== null);
			return m;
		}

		function test_opensAbovePointerAndChooses() {
			const m = make();
			const chosen = createTemporaryObject(spyComponent, host, { target: m, signalName: "chosen" });
			m.openAt(300, 480);
			verify(m.opened);
			const unpin = findChild(m, "menu-item-unpin");
			verify(unpin.mapToItem(host, 0, 0).y < 480, "above the pointer");
			mouseClick(unpin, 10, 10);
			compare(chosen.count, 1);
			compare(chosen.signalArguments[0][0], "unpin");
			verify(!m.opened, "closes after a choice");
		}

		function test_submenuOnHover() {
			const m = make();
			m.openAt(300, 480);
			const sub = findChild(m, "menu-submenu-bloom");
			const quit = findChild(m, "menu-item-quit");
			verify(!quit.visible);
			mouseMove(sub, 10, 10);
			tryCompare(quit, "visible", true, 500);
			verify(quit.mapToItem(host, 0, 0).x > sub.mapToItem(host, 0, 0).x + sub.width - 10, "to the right");
		}

		// Review M2: hovering another item closes the submenu (Bloom: mouseleave).
		function test_disabledItemsAreDimAndInert() {
			const m = make();
			m.entries = [{ kind: "item", key: "a", label: "Paused", danger: false, disabled: true }, { kind: "item", key: "b", label: "Quit", danger: false }];
			const chosen = createTemporaryObject(spyComponent, host, { target: m, signalName: "chosen" });
			m.openAt(300, 480);
			const paused = findChild(m, "menu-item-a");
			verify(paused.opacity < 1);
			mouseClick(paused, 10, 10);
			compare(chosen.count, 0);
			verify(m.opened);
		}

		// Owner: separators as on Windows (Dock.css .menu-divider: 1 px, 4 px
		// above and below), between Pin, the icon, Bloom's and the app's groups.
		function test_dividersTakeTheirSpace() {
			const m = make();
			m.openAt(300, 480);
			const unpin = findChild(m, "menu-item-unpin");
			const change = findChild(m, "menu-item-change-icon");
			const gap = change.mapToItem(m, 0, 0).y - (unpin.mapToItem(m, 0, 0).y + unpin.height);
			compare(gap, 9, "1 px line with 4 px margins");
		}

		function test_submenuClosesOnAnotherItem() {
			const m = make();
			m.openAt(300, 480);
			mouseMove(findChild(m, "menu-submenu-bloom"), 10, 10);
			const quit = findChild(m, "menu-item-quit");
			tryCompare(quit, "visible", true, 500);
			mouseMove(findChild(m, "menu-item-unpin"), 10, 10);
			tryCompare(quit, "visible", false, 500);
		}

		// Owner: one fixed width for the menu and its submenus, whatever the
		// labels; a long one (Claude's "Continue Last Claude Code Session")
		// ends in an ellipsis inside the box.
		function test_fixedWidthElidesLongLabels() {
			const m = make();
			m.entries = [{ kind: "item", key: "short", label: "Pin" }, { kind: "submenu", key: "s", label: "Quick actions",
				children: [{ kind: "item", key: "long", label: "Continue Last Claude Code Session and then some more" }] }];
			m.openAt(300, 480);
			const box = findChild(m, "menu-box");
			compare(box.width, 200);
			mouseMove(findChild(m, "menu-submenu-s"), 10, 10);
			const long = findChild(m, "menu-item-long");
			tryCompare(long, "visible", true, 500);
			compare(m.submenuBoxItem.width, 200);
			const label = findChild(long, "menu-label");
			verify(label.truncated, "elided");
			verify(label.mapToItem(m.submenuBoxItem, label.width, 0).x <= 200 - 6 - 12 + 0.5, "inside its padding");
			m.entries = [{ kind: "item", key: "a", label: "A" }];
			compare(box.width, 200, "the same for every menu");
		}

		// Owner report: the submenu sat above its item. Bloom: to the right,
		// its bottom 6 px below the item's bottom (bottom: -6px), growing up.
		function test_submenuAlignsWithItsItem() {
			const m = make();
			m.openAt(300, 480);
			const sub = findChild(m, "menu-submenu-bloom");
			mouseMove(sub, 10, 10);
			const quit = findChild(m, "menu-item-quit");
			tryCompare(quit, "visible", true, 500);
			const subBox = m.submenuBoxItem;
			const itemBottom = sub.mapToItem(host, 0, sub.height).y;
			const boxBottom = subBox.mapToItem(host, 0, subBox.height).y;
			verify(Math.abs(boxBottom - (itemBottom + 6)) < 1, `submenu bottom ${boxBottom}, item bottom ${itemBottom}`);
		}

		function test_hoverColours() {
			const m = make();
			m.openAt(300, 480);
			const close = findChild(m, "menu-item-close");
			const unpin = findChild(m, "menu-item-unpin");
			mouseMove(unpin, 10, 10);
			tryCompare(unpin, "hoverColor", Qt.color("#3b82f6"), 500);
			mouseMove(close, 10, 10);
			tryCompare(close, "hoverColor", Qt.color("#ef4444"), 500, "destructive items turn red");
		}

		function test_escapeCloses() {
			const m = make();
			m.openAt(300, 480);
			m.forceActiveFocus();
			keyClick(Qt.Key_Escape);
			verify(!m.opened);
		}

		function test_staysInside() {
			const m = make();
			m.openAt(790, 480);
			const box = findChild(m, "menu-box");
			verify(box.x + box.width <= 800 - 8 + 0.5);
		}
	}
}
