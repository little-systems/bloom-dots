import QtTest
import "../../shell/services/assistant.js" as Logic

TestCase {
	name: "Assistant"

	// Only recent history is sent, within a byte budget, newest kept whole.
	function test_contentsAreBounded() {
		const long = [];
		for (let i = 0; i < 80; i++) long.push({ role: i % 2 ? "model" : "user", text: "m" + i + " " + "y".repeat(2000) });
		const sent = Logic.contents(long);
		verify(sent.length < long.length);
		verify(JSON.stringify(sent).length <= Logic.HISTORY_BYTES + 4096);
		compare(sent[sent.length - 1].parts[0].text, long[long.length - 1].text);
		compare(sent[0].role, "user");
		compare(Logic.errorText("too-long").length > 0, true);
		verify(Logic.errorText("too-long") !== Logic.errorText("server"));
		verify(Logic.errorText("timeout") !== Logic.errorText("server"));
	}

	function test_contents() {
		compare(Logic.contents([{ role: "user", text: "hi" }]), [{ role: "user", parts: [{ text: "hi" }] }]);
	}
	function test_replyBuildsUp() {
		let m = [{ role: "user", text: "hi" }];
		m = Logic.withDelta(m, "Hel");
		m = Logic.withDelta(m, "lo");
		compare(m, [{ role: "user", text: "hi" }, { role: "model", text: "Hello" }]);
	}
	function test_streamKeepsIdentityAndRetryReplacesTheLastTurn() {
		let m = [{ id: "u", role: "user", text: "hi" }];
		m = Logic.withDelta(m, "Hel", "a"); m = Logic.withDelta(m, "lo", "unused");
		compare(m[1].id, "a"); compare(m[1].text, "Hello");
		compare(Logic.retryTurn(m), { before: [], text: "hi" });
		compare(Logic.contents(m)[1], { role: "model", parts: [{ text: "Hello" }] });
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
