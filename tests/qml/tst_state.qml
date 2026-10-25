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
}
