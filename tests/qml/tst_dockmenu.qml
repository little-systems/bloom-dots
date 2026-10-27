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
		function test_submenuClosesOnAnotherItem() {
			const m = make();
			m.openAt(300, 480);
			mouseMove(findChild(m, "menu-submenu-bloom"), 10, 10);
			const quit = findChild(m, "menu-item-quit");
			tryCompare(quit, "visible", true, 500);
			mouseMove(findChild(m, "menu-item-unpin"), 10, 10);
			tryCompare(quit, "visible", false, 500);
		}

		// Owner report: long desktop actions (Claude's "Continue Last Claude
		// Code Session") ran past the box; it must grow to its widest label.
		function test_widthFitsTheLongestLabel() {
			const m = make();
			m.entries = Dock.menuFor({ kind: "app", id: "x", pinned: false, pinnable: true, running: true, windows: 1, hasCustomIcon: false, actions: ["Continue Last Claude Code Session"] });
			m.openAt(300, 480);
			const item = findChild(m, "menu-item-action:0");
			const box = findChild(m, "menu-box");
			verify(item.implicitWidth > 200, "a long label");
			verify(box.width >= item.implicitWidth + 2 * 6 - 0.5, `box ${box.width} fits ${item.implicitWidth}`);
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
