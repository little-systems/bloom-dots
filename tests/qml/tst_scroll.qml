import QtQuick
import QtTest
import "../../shell/modules/notch/qp"
import "../../shell/common/render"

// The shared scroller's spring.
Item {
	id: host
	width: 300
	height: 300

	Flickable {
		id: f
		anchors.fill: parent
		contentHeight: 1000
		interactive: false
		Rectangle { width: 300; height: 1000; color: "gray" }
	}
	Rectangle {
		id: wheelControl
		parent: f.contentItem
		width: 60; height: 50; visible: false
		readonly property bool ownsScrollWheel: true
		property int steps: 0
		MouseArea { anchors.fill: parent; onWheel: event => { wheelControl.steps++; event.accepted = true; } }
	}
	QpScroll { id: scroller; flickable: f }

	TestCase {
		name: "Scroll"
		when: windowShown

		function init() { Render.reduceMotion = false; wheelControl.visible = false; wheelControl.steps = 0; scroller.stop(); scroller.horizontal = false; f.contentWidth = 300; f.contentHeight = 1000; f.contentY = 0; f.contentX = 0; }
		function cleanup() { scroller.stop(); Render.reduceMotion = false; Render.animationStyle = "macos"; }

		function test_wheelMovesAndLands() {
			mouseWheel(host, 150, 150, 0, -120);
			tryVerify(() => f.contentY > 50, 1000, "moves");
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentY, 100, 1);
		}

		function test_defaultGlidesWithoutBounce() {
			mouseWheel(host, 150, 150, 0, -120);
			let previous = 0;
			for (let i = 0; i < 60; i++) {
				verify(f.contentY >= previous && f.contentY <= 100);
				previous = f.contentY; wait(16);
			}
			fuzzyCompare(f.contentY, 100, 1);
		}

		function test_configCanKeepBloomsBounce() {
			Render.animationStyle = "bloom";
			let peak = 0;
			mouseWheel(host, 150, 150, 0, -120);
			for (let i = 0; i < 60; i++) {
				peak = Math.max(peak, f.contentY);
				wait(16);
			}
			verify(peak > 101, "overshoots a little, peak " + peak);
			verify(peak < 125, "only a little, peak " + peak);
		}

		function test_rubberBandComesHome() {
			f.contentY = -40;
			scroller._settle.restart();
			tryVerify(() => scroller._driving, 500, "starts home");
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentY, 0, 1);
		}

		function test_endsAreKept() {
			f.contentY = 700;
			mouseWheel(host, 150, 150, 0, -1200);
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentY, 700, 1);
		}
		function test_volumeWheelControlKeepsItsInput() {
			wheelControl.visible = true;
			mouseWheel(host, 30, 20, 0, -120);
			compare(wheelControl.steps, 1);
			compare(f.contentY, 0);
			verify(!scroller._driving);
		}

		function test_touchpadGlidesAfterRelease() {
			scroller.scroll(20, true, 1000, Qt.ScrollBegin);
			scroller.scroll(20, true, 1016, Qt.ScrollUpdate);
			const release = f.contentY;
			tryVerify(() => f.contentY > release + 20, 1000, "continues after fingers lift");
			tryCompare(scroller, "_coasting", false, 3000);
			verify(f.contentY < 700);
		}
		function test_pressBrakesGlide() {
			scroller.scroll(20, true, 1000, Qt.ScrollBegin);
			scroller.scroll(20, true, 1016, Qt.ScrollUpdate);
			tryCompare(scroller, "_coasting", true, 500);
			mousePress(host, 150, 150);
			verify(!scroller._coasting);
			const y = f.contentY;
			wait(100);
			compare(f.contentY, y);
			mouseRelease(host, 150, 150);
		}

		function test_nativeMomentumIsNotDoubled() {
			scroller.scroll(20, true, 1000, Qt.ScrollBegin);
			scroller.scroll(10, true, 1016, Qt.ScrollMomentum);
			scroller.scroll(0, true, 1032, Qt.ScrollEnd);
			wait(150);
			compare(f.contentY, 30);
			verify(!scroller._coasting);
		}
		function test_externalNavigationCancelsGlide() {
			scroller.scroll(20, true, 1000, Qt.ScrollBegin);
			scroller.scroll(20, true, 1016, Qt.ScrollUpdate);
			tryCompare(scroller, "_coasting", true, 500);
			f.contentY = 300; // keyboard selection, scrollbar drag or a new page
			wait(150);
			compare(f.contentY, 300);
			verify(!scroller._coasting);
		}
		function test_horizontalWheelGlides() {
			scroller.horizontal = true; f.contentWidth = 1200;
			mouseWheel(host, 150, 150, 0, -120);
			tryVerify(() => f.contentX > 50, 1000);
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentX, 100, 1);
			compare(f.contentY, 0);
		}
		function test_reduceMotionSkipsGlide() {
			Render.reduceMotion = true;
			scroller.scroll(100, false, 1000, Qt.NoScrollPhase);
			compare(f.contentY, 100);
			scroller.scroll(30, true, 1016, Qt.ScrollUpdate);
			wait(150);
			compare(f.contentY, 130);
			verify(!scroller._driving && !scroller._coasting);
		}
		function test_contentShrinkingCancelsMomentum() {
			scroller.scroll(20, true, 1000, Qt.ScrollBegin);
			scroller.scroll(20, true, 1016, Qt.ScrollUpdate);
			f.contentHeight = 100;
			wait(150);
			compare(f.contentY, 0);
			verify(!scroller._coasting);
		}

	}
}
