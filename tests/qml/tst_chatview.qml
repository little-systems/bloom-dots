import QtQuick
import QtTest
import "../../shell/modules/launcher"
import "../../shell/common/render"
import "../../shell/modules/launcher/chat-format.js" as Format

Item {
	id: host
	width: 660; height: 590
	QtObject {
		id: fakeTheme
		property color text: "white"
		property color textMuted: "#999999"
		property color bgExpanded: "#121212"
		property color groupBg: "#202020"
		property color border: "#333333"
	}
	Component { id: component; ChatView { width: 660; height: 590; theme: fakeTheme } }
	TestCase {
		name: "ChatView"; when: windowShown
		function init() { Render.reduceMotion = true; }
		function cleanup() { Render.reduceMotion = false; }
		function make(props) { return createTemporaryObject(component, host, props || {}); }
		function spy(v, signal) { const s = createTemporaryQmlObject('import QtTest; SignalSpy {}', host); s.target = v; s.signalName = signal; return s; }
		function test_messageRowsSurviveStreaming() {
			const v = make({ messages: [{ id: "u", role: "user", text: "Hi" }, { id: "a", role: "model", text: "Hel" }], busy: true });
			const row = findChild(v, "message:1"); verify(row);
			v.messages = [{ id: "u", role: "user", text: "Hi" }, { id: "a", role: "model", text: "Hello" }];
			compare(findChild(v, "message:1"), row);
			compare(findChild(row, "chatMessage").text.trim(), "Hello");
		}
		function test_composerSendsAndShiftEnterAddsLine() {
			const v = make(); const sent = spy(v, "submitted");
			v.draft = "Hello"; v.focusInput();
			keyClick(Qt.Key_Return, Qt.ShiftModifier);
			verify(v.draft.indexOf("\n") >= 0);
			keyClick(Qt.Key_Return);
			compare(sent.signalArguments[0][0], "Hello"); compare(v.draft, "");
		}
		function test_busyOffersStopAndDoesNotSendAgain() {
			const v = make({ busy: true, draft: "next" });
			const stopped = spy(v, "stopRequested"), sent = spy(v, "submitted");
			v.send(); compare(sent.count, 0);
			const button = findChild(v, "chatSend"); const p = button.mapToItem(host, 16, 16);
			mouseClick(host, p.x, p.y); compare(stopped.count, 1);
		}
		function test_readingEarlierRepliesDoesNotJumpToTheBottom() {
			const messages = Array.from({ length: 8 }, (_, i) => ({ id: "m" + i, role: i % 2 ? "model" : "user", text: "A message with enough lines.\n".repeat(5) }));
			const v = make({ messages: messages }); waitForRendering(host);
			const chat = findChild(v, "chat"); v.followTail = false; chat.contentY = 40;
			v.messages = messages.concat([{ id: "last", role: "model", text: "A new piece" }]);
			wait(50); compare(chat.contentY, 40);
		}
		function test_commonMathAndCodeStayReadable() {
			compare(Format.markdown("One million is $10^6$. Its tenth power is $10^{60}$."), "One million is 10⁶. Its tenth power is 10⁶⁰.");
			compare(Format.markdown("`$10^6$`"), "`$10^6$`");
			compare(Format.markdown("Costs $5 and $10"), "Costs $5 and $10");
			verify(!Format.markdown("![tracking](https://example.com/a.png)").includes("https://"));
			verify(!Format.safeLink("file:///etc/passwd")); verify(Format.safeLink("https://example.com"));
		}
	}
}
