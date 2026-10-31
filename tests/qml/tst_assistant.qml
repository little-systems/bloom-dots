import QtTest
import "../../shell/services/assistant.js" as Logic

TestCase {
	name: "Assistant"

	function test_contents() {
		compare(Logic.contents([{ role: "user", text: "hi" }]), [{ role: "user", parts: [{ text: "hi" }] }]);
	}
	function test_replyBuildsUp() {
		let m = [{ role: "user", text: "hi" }];
		m = Logic.withDelta(m, "Hel");
		m = Logic.withDelta(m, "lo");
		compare(m, [{ role: "user", text: "hi" }, { role: "model", text: "Hello" }]);
	}
	function test_errors() {
		verify(Logic.errorText("no-key").indexOf("Settings") >= 0);
		compare(Logic.errorText("nonsense"), Logic.errorText("server"));
	}
	function test_checkNeverFakesSuccess() {
		compare(Logic.checkText('{"ok":true}\n'), "The key works");
		compare(Logic.checkText('{"error":"bad-key"}'), Logic.errorText("bad-key"));
		compare(Logic.checkText(""), Logic.errorText("server"));
	}
	function test_garbageLine() {
		compare(Logic.parseLine("not json"), {});
	}
}
