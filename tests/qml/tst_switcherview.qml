import QtQuick
import QtTest
import "../../shell/modules/switcher"

Item {
	id: host
	width: 1600
	height: 900

	function items(n) {
		const out = [];
		for (let i = 0; i < n; i++) out.push({ address: "0x" + (i + 10).toString(16), title: "Window " + i, appName: "app" + i, icon: "" });
		return out;
	}

	Component {
		id: viewComponent
		SwitcherView { anchors.fill: parent }
	}
	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "SwitcherView"
		when: windowShown

		function make(n, index) {
			const v = createTemporaryObject(viewComponent, host, { items: host.items(n), index: index });
			verify(v);
			v.open();
			tryVerify(() => v.fade === 1, 2000, "opened");
			return v;
		}

		function test_aTilePerWindowWithItsTitle() {
			const v = make(3, 1);
			for (let i = 0; i < 3; i++) {
				const tile = findChild(v, "tile:" + i);
				verify(tile, "tile " + i);
				compare(findChild(tile, "title").text, "Window " + i);
			}
			verify(!findChild(v, "tile:3"));
		}

		function test_selectionFollowsTheIndex() {
			const v = make(3, 1);
			verify(findChild(v, "tile:1").selected);
			verify(!findChild(v, "tile:0").selected);
			v.index = 2;
			verify(findChild(v, "tile:2").selected);
			verify(!findChild(v, "tile:1").selected);
		}

		function test_manyWindowsWrapIntoRows() {
			const few = make(5, 0);
			const fewHeight = findChild(few, "card").height;
			const many = make(8, 0);
			verify(findChild(many, "card").height > fewHeight + 50, "a second row");
			compare(findChild(many, "card").width, findChild(few, "card").width, "five across at most");
		}

		function test_clickingATileChoosesIt() {
			const v = make(3, 1);
			const chosen = createTemporaryObject(spyComponent, host, { target: v, signalName: "chosen" });
			mouseClick(findChild(v, "tile:2"));
			compare(chosen.count, 1);
			compare(chosen.signalArguments[0][0], 2);
		}

		function test_theCardIsCentred() {
			const v = make(3, 0);
			const card = findChild(v, "card");
			fuzzyCompare(card.x + card.width / 2, host.width / 2, 1);
			fuzzyCompare(card.y + card.height / 2, host.height / 2, 1);
		}
	}
}
