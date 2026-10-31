import QtQuick
import QtTest
import "../../shell/modules/osk"
import "../../shell/modules/osk/osk.js" as Logic

Item {
	id: host
	width: 800
	height: 300

	Component {
		id: viewComponent
		OskView { width: 760; height: 280 }
	}

	TestCase {
		name: "Osk"
		when: windowShown

		function letter(c) { return { id: c, label: c, shift: c.toUpperCase() }; }

		function test_typing() {
			compare(Logic.command(letter("a"), []), ["wtype", "--", "a"]);
			compare(Logic.command(letter("a"), ["shift"]), ["wtype", "--", "A"]);
			compare(Logic.command({ id: "1", label: "1", shift: "!" }, ["shift"]), ["wtype", "--", "!"]);
		}
		// A leading dash must be text, not an option.
		function test_dashIsText() {
			compare(Logic.command({ id: "-", label: "-", shift: "_" }, []), ["wtype", "--", "-"]);
		}
		function test_shortcuts() {
			compare(Logic.command(letter("c"), ["ctrl"]), ["wtype", "-M", "ctrl", "-k", "c", "-m", "ctrl"]);
		}
		function test_specialKeys() {
			compare(Logic.command({ key: "Return" }, []), ["wtype", "-k", "Return"]);
			compare(Logic.command({ key: "Tab" }, ["alt"]), ["wtype", "-M", "alt", "-k", "Tab", "-m", "alt"]);
		}
		function test_rowsFit() {
			verify(Logic.rows().length === 5);
		}
		function test_pressSignals() {
			const v = createTemporaryObject(viewComponent, host);
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = v;
			s.signalName = "pressed";
			tryCompare(findChild(v, "keyboard"), "height", 280, 2000);
			waitForRendering(host);
			const key = findChild(v, "key:q");
			const p = key.mapToItem(host, key.width / 2, key.height / 2);
			mouseClick(host, p.x, p.y);
			compare(s.count, 1);
			compare(s.signalArguments[0][0].id, "q");
		}
		function test_shiftChangesTheCaps() {
			const v = createTemporaryObject(viewComponent, host, { held: ["shift"] });
			tryVerify(() => findChild(findChild(v, "key:q"), "cap") !== null, 1000, "key");
			compare(findChild(findChild(v, "key:q"), "cap").text, "Q");
		}
		function test_keysFitTheBoard() {
			const v = createTemporaryObject(viewComponent, host);
			tryCompare(findChild(v, "keyboard"), "width", 760, 2000);
			waitForRendering(host);
			for (const id of ["Backspace", "Tab", "Return", "alt", "Right"]) {
				const key = findChild(v, "key:" + id);
				const p = key.mapToItem(v, 0, 0);
				verify(p.x >= 0 && p.x + key.width <= v.width, id + " fits");
			}
		}
	}
}
