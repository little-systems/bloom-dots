import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's panel AnimatePresence: the new panel's opacity springs in
// (400/30) while the old one fades and blurs out over 0.1 s, together.
Item {
	id: host
	width: 400
	height: 300

	PanelStage {
		id: stage
		width: 350
		height: 200
	}

	TestCase {
		name: "PanelStage"
		when: windowShown

		readonly property string a: Qt.resolvedUrl("stage/PanelA.qml")
		readonly property string b: Qt.resolvedUrl("stage/PanelB.qml")

		function slots() {
			return stage.children.filter(c => c.objectName === "panelSlot");
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function cleanup() {
			stage.show("", 0);
			tryVerify(() => slots().length === 0, 1000);
		}

		function test_entersWithASpring() {
			stage.show(a, 12);
			const s = slots();
			compare(s.length, 1);
			verify(s[0].opacity < 0.2, `starts faded at ${s[0].opacity}`);
			compare(s[0].x, 12);
			compare(s[0].width, 350 - 24);
			wait(80);
			verify(s[0].opacity > 0.2 && s[0].opacity < 1, `springing at ${s[0].opacity}`);
			tryCompare(s[0], "opacity", 1, 1000);
			verify(stage.item, "the current panel's item");
			compare(stage.item.color, Qt.color("red"));
		}

		function test_switchCrossfades() {
			stage.show(a, 12);
			tryCompare(slots()[0], "opacity", 1, 1000);
			const old = slots()[0];
			stage.show(b, 0);
			const both = slots();
			compare(both.length, 2, "the old panel stays while it leaves");
			verify(old.leaving);
			compare(old.x, 12, "the leaving panel keeps its place");
			compare(stage.item.color, Qt.color("blue"));
			wait(50);
			verify(old.opacity > 0 && old.opacity < 1, `fading at ${old.opacity}`);
			compare(old.blur, 0, "the default crossfade stays sharp");
			tryVerify(() => slots().length === 1, 500, "gone after 0.1 s");
			compare(slots()[0].x, 0);
		}

		// Bloom's exiting panel is still width: 100% with overflow hidden: it
		// shrinks with the pill and never draws outside it.
		function test_leavingPanelFollowsTheWidthAndClips() {
			stage.show(a, 12);
			const old = slots()[0];
			verify(old.clip);
			stage.show(b, 0);
			stage.width = 300;
			compare(old.width, 300 - 24);
			stage.width = 350;
		}

		function test_closeFadesOut() {
			stage.show(a, 12);
			tryCompare(slots()[0], "opacity", 1, 1000);
			stage.show("", 0);
			compare(stage.item, null);
			compare(slots().length, 1);
			verify(stage.leaving, "busy while the last panel leaves");
			tryVerify(() => slots().length === 0, 500);
			verify(!stage.leaving);
		}

		function test_sameSourceDoesNothing() {
			stage.show(a, 12);
			const first = slots()[0];
			stage.show(a, 12);
			compare(slots().length, 1);
			compare(slots()[0], first);
		}

		function test_currentItemSignalsAndState() {
			stage.show(a, 12);
			compare(stage.item.pinned, true);
		}

		function test_noFramesAtRest() {
			stage.show(a, 12);
			tryCompare(slots()[0], "opacity", 1, 1000);
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
			compare(framesIn(1000), 0);
		}
	}
}
