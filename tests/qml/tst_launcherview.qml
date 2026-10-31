import QtQuick
import QtTest
import "../../shell/modules/launcher"
import "../../shell/common/tokens.js" as Tokens

// The launcher's bar (owner: Spotlight-style): a field that grows on a spring
// as results appear, in the Add App card's language.
Item {
	id: host
	width: 800
	height: 700

	readonly property var results: Array.from({ length: 12 }, (_, i) => ({ id: "a" + i, name: "App " + i, sub: i === 1 ? "Copy the result" : "", icon: "", glyph: "" }))

	Component {
		id: viewComponent
		LauncherView { width: 800; height: 700 }
	}

	TestCase {
		name: "LauncherView"
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

		function test_barSitsCentred() {
			const v = make();
			v.open();
			const card = part(v, "card");
			compare(card.width, Tokens.launcher.width);
			fuzzyCompare(card.x, (800 - 560) / 2, 0.51);
			fuzzyCompare(card.y, 700 * Tokens.launcher.top, 0.51);
		}

		function test_growsWithResults() {
			const v = make();
			v.open();
			const card = part(v, "card");
			tryVerify(() => card.height > 0, 500);
			const bar = v.barHeight;
			tryCompare(card, "height", bar, 1000);
			v.results = host.results;
			const full = bar + Tokens.launcher.gap + Tokens.launcher.maxRows * Tokens.dock.popup.row.height;
			compare(v.targetHeight, full, "eight rows at most");
			verify(card.height < full, "it grows on a spring, not at once");
			tryCompare(card, "height", full, 1500);
			v.results = host.results.slice(0, 2);
			compare(v.targetHeight, bar + Tokens.launcher.gap + 2 * Tokens.dock.popup.row.height);
		}

		function test_typingAsks() {
			const v = make();
			const changed = spy(v, "queryEdited");
			v.open();
			part(v, "field").text = "fire";
			compare(changed.signalArguments[changed.count - 1][0], "fire");
		}

		function test_keysMoveAndChoose() {
			const v = make({ results: host.results });
			const chosen = spy(v, "chosen");
			v.open();
			tryVerify(() => part(v, "field").activeFocus, 500, "the field takes focus");
			compare(v.selectedIndex, 0);
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Down);
			compare(v.selectedIndex, 2);
			keyClick(Qt.Key_Up);
			compare(v.selectedIndex, 1);
			keyClick(Qt.Key_Up);
			keyClick(Qt.Key_Up);
			compare(v.selectedIndex, 11, "wraps");
			keyClick(Qt.Key_Tab);
			compare(v.selectedIndex, 0);
			keyClick(Qt.Key_Return);
			compare(chosen.count, 1);
			compare(chosen.signalArguments[0][0].id, "a0");
		}

		function test_escapeAndOutsideDismiss() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			v.open();
			tryVerify(() => part(v, "field").activeFocus, 500);
			keyClick(Qt.Key_Escape);
			compare(dismissed.count, 1);
			v.open();
			waitForRendering(host);
			mouseClick(host, 20, 650);
			compare(dismissed.count, 2);
		}

		function test_newResultsSelectTheFirst() {
			const v = make({ results: host.results });
			v.selectedIndex = 3;
			v.results = host.results.slice(0, 5);
			compare(v.selectedIndex, 0);
		}

		function test_rowShowsNameSubAndHoverSelects() {
			const v = make({ results: host.results });
			v.open();
			const row = part(v, "row:a1");
			compare(findChild(row, "name").text, "App 1");
			compare(findChild(row, "sub").text, "Copy the result");
			compare(findChild(row, "name").font.pixelSize, Tokens.dock.popup.row.name);
			const card = part(v, "card");
			tryCompare(card, "height", v.targetHeight, 1500);
			waitForRendering(host);
			const p = row.mapToItem(host, 40, 24);
			mouseMove(host, p.x, p.y);
			tryCompare(v, "selectedIndex", 1, 500);
		}

		function test_emojiDrawsInFullColour() {
			const v = make({ results: [{ id: "😀", name: "Grinning face", sub: "", icon: "", glyph: "😀" }] });
			v.open();
			const row = part(v, "row:😀");
			const glyph = findChild(row, "glyph");
			compare(glyph.color.a, 1);
		}

		function test_emptyField() {
			const v = make();
			v.open();
			compare(part(v, "placeholder").text, "Search apps, or ; : = > ? ! for more");
		}
	}
}
