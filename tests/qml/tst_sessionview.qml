import QtQuick
import QtTest
import "../../shell/modules/session"
import "../../shell/common/tokens.js" as Tokens

// The session menu: seven actions on the launcher's card; ending the session
// with work running asks first.
Item {
	id: host
	width: 900
	height: 600

	Component {
		id: viewComponent
		SessionView { width: 900; height: 600 }
	}

	TestCase {
		name: "SessionView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			v.open();
			tryCompare(findChild(v, "card"), "opacity", 1, 2000);
			waitForRendering(host);
			return v;
		}
		function part(v, name) {
			tryVerify(() => findChild(v, name) !== null, 1000, name);
			return findChild(v, name);
		}
		function click(v, name) {
			waitForRendering(host);
			const it = part(v, name);
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_sevenActionsCentred() {
			const v = make();
			for (const id of ["lock", "logout", "suspend", "hibernate", "reboot", "shutdown", "firmware"]) part(v, "action:" + id);
			compare(findChild(part(v, "action:shutdown"), "label").text, "Shut down");
			const card = part(v, "card");
			fuzzyCompare(card.x + card.width / 2, 450, 0.51);
			fuzzyCompare(card.y + card.height / 2, 300, 0.51);
		}

		function test_clickRuns() {
			const v = make();
			const chosen = spy(v, "actionChosen");
			click(v, "action:suspend");
			compare(chosen.signalArguments[0][0], "suspend");
		}

		function test_workRunningAsksFirst() {
			const v = make({ busy: { pacman: true, downloads: 0 } });
			const chosen = spy(v, "actionChosen");
			click(v, "action:shutdown");
			compare(chosen.count, 0, "not yet");
			compare(part(v, "warning").text, "pacman is running.");
			compare(part(v, "confirm").text, "Shut down anyway");
			click(v, "cancel");
			tryVerify(() => !part(v, "warning").visible, 500);
			click(v, "action:shutdown");
			click(v, "confirm");
			compare(chosen.signalArguments[0][0], "shutdown");
		}

		function test_keys() {
			const v = make();
			const chosen = spy(v, "actionChosen"), dismissed = spy(v, "dismissed");
			tryVerify(() => v.activeFocus || findChild(v, "keys").activeFocus, 500);
			compare(v.selectedIndex, 0);
			keyClick(Qt.Key_Right);
			keyClick(Qt.Key_Right);
			compare(v.selectedIndex, 2);
			keyClick(Qt.Key_Left);
			keyClick(Qt.Key_Left);
			keyClick(Qt.Key_Left);
			compare(v.selectedIndex, 6, "wraps");
			keyClick(Qt.Key_Return);
			compare(chosen.signalArguments[0][0], "firmware");
			keyClick(Qt.Key_Escape);
			compare(dismissed.count, 1);
		}

		function test_outsideDismisses() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			mouseClick(host, 10, 590);
			compare(dismissed.count, 1);
		}
	}
}
