import QtQuick
import QtTest
import "../../shell/common"

Item {
	id: host
	width: 400
	height: 200

	Rectangle { anchors.fill: parent; color: "white" }

	EdgeSurface {
		id: top
		x: 20
		edge: "top"
		pillWidth: 140
		pillHeight: 36
		edgeRadius: 0
		farRadius: 18
		color: Qt.rgba(0, 0, 0, 0.8)
	}

	EdgeSurface {
		id: left
		x: 0
		y: 80
		edge: "left"
		pillWidth: 40
		pillHeight: 80
		color: Qt.rgba(0, 0, 0, 0.8)
		flares: false
	}

	TestCase {
		name: "EdgeSurface"
		when: windowShown

		function test_boxIncludesFlareMargins() {
			compare(top.width, 140 + 26);
			compare(top.height, 36);
			compare(top.pillRect, Qt.rect(13, 0, 140, 36));
			compare(left.width, 40);
			compare(left.height, 80 + 26);
			compare(left.pillRect, Qt.rect(0, 13, 40, 80));
		}

		function test_flaresPaintAtThePillsAlpha() {
			const img = grabImage(host);
			const pill = img.pixel(20 + 13 + 70, 18);
			const nearEdge = img.pixel(20 + 10, 0); // start flare where it meets the edge (the curve leaves the edge at x≈6)
			const end = img.pixel(20 + 13 + 140 + 2, 0); // end flare, mirrored
			verify(Qt.colorEqual(nearEdge, pill), `start flare ${nearEdge} vs pill ${pill}`);
			verify(Qt.colorEqual(end, pill), `end flare ${end} vs pill ${pill}`);
			verify(!Qt.colorEqual(pill, "white"));
		}

		function test_flareIsConcave() {
			const img = grabImage(host);
			// Bottom-left of the start flare's box is outside the curve.
			verify(Qt.colorEqual(img.pixel(20 + 1, 12), "white"));
		}

		function test_farCornersAreRounded() {
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(20 + 13, 35), "white"), "bottom-left corner cut by farRadius");
			verify(!Qt.colorEqual(img.pixel(20 + 13, 0), "white"), "top-left corner square (edgeRadius 0)");
		}

		function test_flaresOff() {
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(0 + 1, 80 + 2), "white"), "left surface has no flares");
		}
	}
}
