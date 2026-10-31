import QtQuick
import QtTest
import "../../shell/modules/cheatsheet/cheatsheet.js" as Logic

// Turning `hyprctl binds -j` into the sheet's groups.
TestCase {
	name: "CheatsheetLogic"

	function bind(modmask, key, description) {
		return { modmask: modmask, key: key, description: description };
	}

	function test_modifiersInOrder() {
		compare(Logic.keys(bind(64, "L", "")), ["Super", "L"]);
		compare(Logic.keys(bind(69, "T", "")), ["Super", "Ctrl", "Shift", "T"]);
		compare(Logic.keys(bind(76, "Delete", "")), ["Super", "Ctrl", "Alt", "Delete"]);
		compare(Logic.keys(bind(0, "XF86AudioMute", "")), ["XF86AudioMute"]);
	}

	function test_keyNames() {
		compare(Logic.keyName("mouse:272"), "Left click");
		compare(Logic.keyName("mouse:273"), "Right click");
		compare(Logic.keyName("mouse_down"), "Scroll down");
		compare(Logic.keyName("slash"), "/");
		compare(Logic.keyName("SUPER_L"), "Super");
		compare(Logic.keyName("q"), "Q");
		compare(Logic.keyName("Return"), "Return");
	}

	function test_groupsByPrefix() {
		const groups = Logic.parse(JSON.stringify([
			bind(64, "L", "Session: Lock"),
			bind(64, "Q", "Window: Close"),
			bind(64, "F", "Window: Fullscreen"),
			bind(64, "X", "No group here"),
			bind(64, "Y", "")
		]));
		compare(groups.map(g => g.name), ["Session", "Window", "Other"]);
		compare(groups[1].binds.map(b => b.text), ["Close", "Fullscreen"]);
		compare(groups[2].binds[0].text, "No group here");
	}

	function test_undescribedBindsAreLeftOut() {
		compare(Logic.parse(JSON.stringify([bind(64, "Y", "")])), []);
	}

	// The same action on two keys, such as volume with held-key variants.
	function test_duplicatesKeepTheFirstKey() {
		const groups = Logic.parse(JSON.stringify([bind(64, "A", "Media: Next"), bind(64, "B", "Media: Next")]));
		compare(groups[0].binds.length, 1);
		compare(groups[0].binds[0].keys, ["Super", "A"]);
	}

	function test_columnsStayEven() {
		const group = (name, n) => ({ name: name, binds: new Array(n).fill({}) });
		const cols = Logic.columns([group("a", 10), group("b", 3), group("c", 3), group("d", 3)], 3);
		compare(cols.map(c => c.map(g => g.name)), [["a"], ["b", "d"], ["c"]]);
		compare(Logic.columns([], 3), [[], [], []]);
	}

	function test_badInput() {
		compare(Logic.parse("not json"), []);
		compare(Logic.parse(""), []);
		compare(Logic.parse("{}"), []);
	}
}
