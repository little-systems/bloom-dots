import QtQuick
import QtTest
import "../../shell/modules/lock"

// The lock screen: opaque always, passwords leave the field the moment they
// are submitted, and it can't be typed into while one is being checked.
Item {
	id: host
	width: 1000
	height: 700

	Component {
		id: viewComponent
		LockView { anchors.fill: parent; user: "dhanush"; time: new Date(2026, 9, 31, 15, 7); clock24: true }
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

		// session_lock_xray shows whatever is behind a translucent surface.
		function test_opaque() {
			const v = make();
			const bg = part(v, "background");
			compare(bg.color.a, 1);
			compare(bg.opacity, 1);
			compare(bg.width, v.width);
			compare(bg.height, v.height);
			verify(bg.visible);
		}

		function test_showsTimeDateAndUser() {
			const v = make();
			compare(part(v, "clock").text, "15:07");
			compare(part(v, "date").text, "Saturday, October 31");
			compare(part(v, "user").text, "dhanush");
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

		function test_messages() {
			const v = make();
			const m = part(v, "message");
			verify(!m.visible);
			v.message = "That password didn't work";
			v.messageIsError = true;
			verify(m.visible);
			compare(m.text, "That password didn't work");
			compare(String(m.color), "#ff8a80");
			v.messageIsError = false;
			verify(String(m.color) !== "#ff8a80");
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

		function test_opensWithTheFieldFocused() {
			const v = make();
			v.focusField();
			verify(part(v, "field").activeFocus);
		}
	}
}
