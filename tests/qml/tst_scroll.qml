import QtQuick
import QtTest
import "../../shell/modules/notch/qp"

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
	QpScroll { id: scroller; flickable: f }

	TestCase {
		name: "Scroll"
		when: windowShown

		function init() { f.contentY = 0; scroller._driving = false; }

		function test_wheelMovesAndLands() {
			mouseWheel(host, 150, 150, 0, -120);
			tryVerify(() => f.contentY > 50, 1000, "moves");
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentY, 100, 1);
		}

		function test_itBounces() {
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
			tryCompare(scroller, "_driving", true, 500);
			tryCompare(scroller, "_driving", false, 3000);
			fuzzyCompare(f.contentY, 700, 1);
		}
	}
}
