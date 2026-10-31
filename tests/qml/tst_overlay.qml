import QtQuick
import QtTest
import "../../shell/modules/overlay"

Item {
	id: host
	width: 1000
	height: 700

	Component {
		id: viewComponent
		OverlayView { anchors.fill: parent; cpu: 42; mixer: [{ id: 1, name: "Music", volume: 0.5, muted: false }] }
	}

	TestCase {
		name: "Overlay"
		when: windowShown

		function make() {
			const v = createTemporaryObject(viewComponent, host);
			verify(v);
			waitForRendering(host);
			return v;
		}
		function spy(target, name) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = name;
			return s;
		}
		function click(v, name) {
			const it = findChild(v, name);
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}

		function test_cards() {
			const v = make();
			for (const t of ["Notes", "System", "Volume", "Capture", "Crosshair"]) verify(findChild(v, "card:" + t), t);
		}
		function test_clickOnTheDimDismisses() {
			const v = make();
			const s = spy(v, "dismissed");
			mouseClick(host, 900, 650);
			compare(s.count, 1);
		}
		function test_clickOnACardStays() {
			const v = make();
			const s = spy(v, "dismissed");
			const c = findChild(v, "card:Capture");
			const p = c.mapToItem(host, c.width - 10, c.height - 10);
			mouseClick(host, p.x, p.y);
			compare(s.count, 0);
		}
		function test_crosshair() {
			const v = make();
			const s = spy(v, "crosshairToggled");
			click(v, "crosshairToggle");
			compare(Array.from(s.signalArguments[0]), [true]);
		}
		function test_capture() {
			const v = make();
			const s = spy(v, "recordRequested");
			click(v, "record");
			compare(Array.from(s.signalArguments[0]), ["record"]);
		}
		function test_notesSave() {
			const v = make();
			const s = spy(v, "notesEdited");
			findChild(v, "notes").text = "hello";
			compare(Array.from(s.signalArguments[0]), ["hello"]);
		}
		function test_mixer() {
			const v = make();
			const s = spy(v, "volumeChosen");
			const bar = findChild(v, "stream:Music");
			const p = bar.mapToItem(host, bar.width * 0.75, bar.height / 2);
			mouseClick(host, p.x, p.y);
			compare(s.signalArguments[0][0], 1);
			fuzzyCompare(s.signalArguments[0][1], 0.75, 0.05);
		}
		function test_dragACard() {
			const v = make();
			const c = findChild(v, "card:Notes"), x = c.x;
			const h = findChild(v, "drag:Notes");
			const p = h.mapToItem(host, h.width / 2, h.height / 2);
			mouseDrag(host, p.x, p.y, 100, 40);
			verify(c.x > x, "moved");
		}
	}
}
