import QtQuick
import QtTest
import "../../shell/common"

// A shadow drawn in another window, over the spot where its box is drawn:
// the box's scene rectangle, scale and fade, followed frame by frame.
Item {
	id: host
	width: 600
	height: 400

	Item {
		id: stage
		width: 600
		height: 400
		scale: 0.5
		transformOrigin: Item.TopLeft
		Item {
			id: fader
			x: 100
			y: 60
			Rectangle { id: box; x: 20; y: 10; width: 200; height: 80; radius: 12 }
		}
	}

	Item {
		id: other
		anchors.fill: parent
		ShadowMirror {
			id: mirror
			target: box
			offset.y: 10
			blur: 30
			color: Qt.rgba(0, 0, 0, 0.5)
		}
	}

	TestCase {
		name: "ShadowMirror"
		when: windowShown

		function init() {
			fader.opacity = 1;
			fader.visible = true;
			stage.scale = 0.5;
			mirror.sync();
		}

		function test_coversTheBoxOnScreen() {
			compare(mirror.x, 60);
			compare(mirror.y, 35);
			compare(mirror.width, 100);
			compare(mirror.height, 40);
		}

		function test_scalesTheShadowWithTheBox() {
			compare(mirror.shadow.radius, 6);
			compare(mirror.shadow.blur, 15);
			compare(mirror.shadow.offset.y, 5);
		}

		function test_fadesWithEveryParent() {
			fader.opacity = 0.4;
			mirror.sync();
			fuzzyCompare(mirror.opacity, 0.4, 1e-9);
		}

		function test_hiddenBoxHasNoShadow() {
			fader.visible = false;
			mirror.sync();
			verify(!mirror.visible);
		}

		function test_followsTheBoxAsItsWindowRedraws() {
			stage.scale = 1;
			tryCompare(mirror, "width", 200, 2000);
			compare(mirror.x, 120);
		}
	}
}
