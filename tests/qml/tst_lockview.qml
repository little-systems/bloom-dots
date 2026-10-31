import QtQuick
import QtTest
import "../../shell/modules/lock"

// The lock screen: passwords leave the field the moment they
// are submitted, and it can't be typed into while one is being checked.
Item {
	id: host
	width: 1000
	height: 700

	Component {
		id: viewComponent
		LockView { anchors.fill: parent; user: "dhanush"; layout: "EN"; time: new Date(2026, 9, 31, 15, 7, 30); clockTurning: false }
	}

	TestCase {
		name: "LockView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
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
		function type(v, text) {
			part(v, "field").forceActiveFocus();
			keyClick(text);
		}

		function test_showsTheTimeOnTheHands() {
			const v = make();
			compare(part(v, "hourHand").rotation, 93.75);
			compare(part(v, "minuteHand").rotation, 45);
			compare(part(v, "secondHand").rotation, 180);
			compare(part(v, "date").text, "31");
			verify(findChild(v, "lockedTag"));
		}

		function test_islands() {
			const v = make();
			compare(part(v, "user").text, "dhanush");
			compare(part(v, "layout").text, "EN");
			verify(!part(v, "battery").visible, "no battery on a desktop");
			v.batteryAvailable = true;
			v.batteryLevel = 88;
			verify(part(v, "battery").visible);
			compare(part(v, "battery").text, "88");
			waitForRendering(host);
			const left = part(v, "leftIsland"), main = part(v, "fieldBox"), right = part(v, "rightIsland");
			compare(main.x + main.width / 2, v.width / 2);
			compare(main.y + main.height + 20, v.height);
			compare(left.x + left.width + 10, main.x);
			compare(right.x, main.x + main.width + 10);
		}

		function test_powerButtons() {
			const v = make();
			const sleep = spy(v, "suspendRequested"), off = spy(v, "shutdownRequested"), reboot = spy(v, "rebootRequested");
			tryCompare(part(v, "fieldBox"), "scale", 1, 1500);
			waitForRendering(host);
			for (const name of ["suspend", "shutdown", "reboot"]) {
				const it = part(v, name);
				const p = it.mapToItem(host, it.width / 2, it.height / 2);
				mouseClick(host, p.x, p.y);
			}
			compare([sleep.count, off.count, reboot.count], [1, 1, 1]);
		}

		function test_arrowSubmits() {
			const v = make();
			const submitted = spy(v, "submitted");
			tryCompare(part(v, "fieldBox"), "scale", 1, 1500);
			type(v, "a");
			waitForRendering(host);
			const it = part(v, "confirm");
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
			compare(submitted.count, 1);
		}

		function test_textIsSharedWithOtherScreens() {
			const v = make();
			const edited = spy(v, "textEdited");
			type(v, "a");
			compare(Array.from(edited.signalArguments[0]), ["a"]);
			v.text = "ab";
			compare(part(v, "field").text, "ab");
		}

		function test_pointerMovementRefocuses() {
			const v = make();
			waitForRendering(host);
			host.forceActiveFocus();
			mouseMove(host, 20, 20);
			mouseMove(host, 40, 40);
			verify(part(v, "field").activeFocus);
		}

		function test_passwordIsHidden() {
			const v = make();
			compare(part(v, "field").echoMode, TextInput.Password);
			v.responseVisible = true;
			compare(part(v, "field").echoMode, TextInput.Normal);
		}

		function test_submitClearsTheField() {
			const v = make();
			const submitted = spy(v, "submitted");
			type(v, "a");
			type(v, "b");
			keyClick(Qt.Key_Return);
			compare(submitted.count, 1);
			compare(Array.from(submitted.signalArguments[0]), ["ab"]);
			compare(part(v, "field").text, "");
		}

		function test_emptySubmitDoesNothing() {
			const v = make();
			const submitted = spy(v, "submitted");
			part(v, "field").forceActiveFocus();
			keyClick(Qt.Key_Return);
			compare(submitted.count, 0);
		}

		function test_noTypingWhileChecking() {
			const v = make();
			const submitted = spy(v, "submitted");
			type(v, "a");
			v.busy = true;
			keyClick(Qt.Key_Return);
			compare(submitted.count, 0);
			verify(part(v, "field").readOnly);
			compare(part(v, "field").text, "a");
		}

		function test_escapeClears() {
			const v = make();
			type(v, "a");
			keyClick(Qt.Key_Escape);
			compare(part(v, "field").text, "");
		}

		function test_messagesShowInTheEmptyField() {
			const v = make();
			const m = part(v, "message");
			compare(m.text, "Enter password");
			v.message = "Incorrect password";
			v.messageIsError = true;
			compare(m.text, "Incorrect password");
			compare(String(m.color), "#ff8a80");
			type(v, "a");
			verify(!m.visible, "typing replaces it");
		}

		function test_capsLockWarning() {
			const v = make();
			verify(!part(v, "caps").visible);
			v.capsLock = true;
			verify(part(v, "caps").visible);
			compare(part(v, "caps").text, "Caps Lock is on");
		}

		function test_failureShakesTheField() {
			const v = make();
			const box = part(v, "fieldBox");
			const home = box.x;
			v.shake();
			tryVerify(() => box.x !== home, 500, "moves");
			tryCompare(box, "x", home, 1000);
		}

		// A correct password: the view leaves, and the surface shows what's under it.
		function test_leavingFadesOut() {
			const v = make();
			tryCompare(part(v, "fieldBox"), "scale", 1, 1500);
			v.leaving = true;
			tryCompare(v, "opacity", 0, 1000);
		}

		function test_opensWithTheFieldFocused() {
			const v = make();
			v.focusField();
			verify(part(v, "field").activeFocus);
		}
	}
}
