import QtQuick
import QtTest
import "../../shell/modules/polkit"
import "../../shell/common/tokens.js" as Tokens

// Bloom's password dialog: what's asking, a field, Bloom's error colour. The
// password stays in the field and goes as soon as it's used.
Item {
	id: host
	width: 900
	height: 600

	Component {
		id: viewComponent
		PolkitView { width: 900; height: 600; message: "Authentication is required to mount a disk"; prompt: "Password:" }
	}

	TestCase {
		name: "PolkitView"
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

		function test_showsWhatsAsking() {
			const v = make();
			compare(part(v, "title").text, "Authentication required");
			compare(part(v, "message").text, "Authentication is required to mount a disk");
			compare(part(v, "password").placeholder, "Password");
			compare(part(v, "card").width, Tokens.polkit.width);
		}

		function test_passwordIsHiddenAndTakesFocus() {
			const v = make();
			const field = part(v, "password");
			compare(field.echoMode, TextInput.Password);
			tryVerify(() => field.focused, 500, "the field takes focus");
			v.responseVisible = true;
			compare(field.echoMode, TextInput.Normal, "a prompt that may show its answer");
		}

		function test_enterSubmitsAndClearsTheField() {
			const v = make();
			const submitted = spy(v, "submitted");
			const field = part(v, "password");
			tryVerify(() => field.focused, 500);
			field.text = "secret";
			keyClick(Qt.Key_Return);
			compare(submitted.count, 1);
			compare(submitted.signalArguments[0][0], "secret");
			compare(field.text, "", "the password doesn't linger");
		}

		function test_authenticateNeedsAnAnswer() {
			const v = make();
			verify(!part(v, "authenticate").enabled);
			part(v, "password").text = "x";
			verify(part(v, "authenticate").enabled);
			const submitted = spy(v, "submitted");
			click(v, "authenticate");
			compare(submitted.count, 1);
		}

		function test_cancel() {
			const v = make();
			const cancelled = spy(v, "cancelled");
			part(v, "password").text = "half typed";
			click(v, "cancel");
			compare(cancelled.count, 1);
			compare(part(v, "password").text, "");
			tryVerify(() => part(v, "password").focused, 500);
			keyClick(Qt.Key_Escape);
			compare(cancelled.count, 2);
		}

		function test_errorShowsInBloomsColour() {
			const v = make({ supplementary: "Sorry, try again.", supplementaryIsError: true });
			const e = part(v, "supplementary");
			verify(e.visible);
			compare(String(e.color), Tokens.qp.error.color);
			v.supplementaryIsError = false;
			verify(String(e.color) !== Tokens.qp.error.color);
		}

		function test_waitingLocksTheForm() {
			const v = make({ busy: true });
			verify(!part(v, "password").enabled);
			verify(part(v, "authenticate").busy);
			verify(!part(v, "authenticate").enabled);
		}

		// A wrong password comes back to the field, ready to retype.
		function test_retryTakesFocusBack() {
			const v = make();
			const field = part(v, "password");
			tryVerify(() => field.focused, 500);
			v.busy = true;
			v.busy = false;
			tryVerify(() => field.focused, 500);
		}

		function test_closingClearsTheField() {
			const v = make();
			part(v, "password").text = "secret";
			v.close();
			compare(part(v, "password").text, "");
		}

		// It asks on purpose: a stray click outside must not cancel it.
		function test_outsideDoesNotDismiss() {
			const v = make();
			const cancelled = spy(v, "cancelled");
			mouseClick(host, 10, 590);
			compare(cancelled.count, 0);
		}
	}
}
