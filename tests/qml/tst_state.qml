import QtQuick
import QtTest
import "../../shell/services/state.js" as State

TestCase {
	name: "StateParse"

	function test_parse() {
		compare(State.parse('{"items": [1]}'), { ok: true, value: { items: [1] } });
		compare(State.parse("[]"), { ok: true, value: [] });
	}

	// State files are only ever written whole (atomic); empty means damaged.
	function test_emptyOrBrokenIsCorrupt() {
		verify(!State.parse("").ok);
		verify(!State.parse("{\"items\": [").ok);
	}

	function test_serialize() {
		compare(JSON.parse(State.serialize({ a: 1 })), { a: 1 });
		verify(State.serialize({}).endsWith("\n"));
	}

	function test_checkBudgetCountsUtf8Bytes() {
		compare(State.utf8Bytes("aé€😀"), 1 + 2 + 3 + 4);
		compare(State.check('{"a":1}', 7, null).ok, true);
		compare(State.check('{"a":"é"}', 9, null).kind, "too-large");
	}

	function test_checkKinds() {
		compare(State.check("{", 0, null).kind, "malformed");
		const shape = v => Array.isArray(v?.items) ? v : undefined;
		compare(State.check('{"items": 5}', 0, shape).kind, "invalid");
		compare(State.check('{"items": [1]}', 0, shape), { ok: true, value: { items: [1] } });
		compare(State.check("[]", 0, () => { throw new Error("x"); }).kind, "invalid");
	}

	function test_validateMayNormalize() {
		compare(State.check('{"n": "3"}', 0, v => ({ n: Number(v.n) })).value, { n: 3 });
	}
}
