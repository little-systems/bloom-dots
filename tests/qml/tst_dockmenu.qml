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
