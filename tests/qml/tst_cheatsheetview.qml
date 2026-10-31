import QtQuick
import QtTest
import "../../shell/modules/cheatsheet"

Item {
	id: host
	width: 1000
	height: 700

	readonly property var sample: [
		{ name: "Session", binds: [{ keys: ["Super", "L"], text: "Lock" }] },
		{ name: "Window", binds: [{ keys: ["Super", "Q"], text: "Close" }, { keys: ["Super", "F"], text: "Fullscreen" }] }
	]

	Component {
		id: viewComponent
		CheatsheetView { anchors.fill: parent; groups: host.sample }
	}

	TestCase {
		name: "CheatsheetView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			v.open();
			return v;
		}
		function part(v, name) {
			tryVerify(() => findChild(v, name) !== null, 1000, name);
			return findChild(v, name);
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_showsGroupsAndKeys() {
			const v = make();
			compare(part(v, "group:Window").title, "Window");
			compare(part(v, "bind:Fullscreen").text, "Fullscreen");
			compare(part(v, "cap:Fullscreen:Super").text, "Super");
			compare(part(v, "cap:Fullscreen:F").text, "F");
		}

		function test_emptyState() {
			const v = make({ groups: [] });
			compare(part(v, "empty").text, "No keybinds have descriptions yet");
			tryVerify(() => part(v, "empty").visible, 1000, "shown");
			verify(part(v, "card").height >= part(v, "empty").implicitHeight + 40, "the card holds it");
		}

		function test_escapeDismisses() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			keyClick(Qt.Key_Escape);
			compare(dismissed.count, 1);
		}

		function test_clickOutsideDismisses() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			tryCompare(part(v, "card"), "scale", 1, 1500);
			mouseClick(host, 5, 5);
			compare(dismissed.count, 1);
		}

		function test_clickOnTheCardStays() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			tryCompare(part(v, "card"), "scale", 1, 1500);
			const card = part(v, "card");
			mouseClick(host, card.x + card.width / 2, card.y + 10);
			compare(dismissed.count, 0);
		}

		function test_closes() {
			const v = make();
			tryCompare(part(v, "card"), "scale", 1, 1500);
			v.close();
			tryVerify(() => !v.shown, 1000, "hidden");
		}
	}
}
