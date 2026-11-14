import QtQuick
import QtTest
import "../../shell/common"

Item {
	id: host
	width: 500
	height: 220

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

	EdgeSurface {
		id: shiny
		x: 100
		y: 130
		edge: "top"
		pillWidth: 200
		pillHeight: 36
		edgeRadius: 0
		farRadius: 18
		color: "black"
		edgeColor: "white"
		reflective: true
	}

	// The same surface without the rim, for differences.
	EdgeSurface {
		id: plain
		x: 100
		y: 175
		edge: "top"
		pillWidth: 200
		pillHeight: 36
		edgeRadius: 0
		farRadius: 18
		color: "black"
	}

	SignalSpy { id: paints; signalName: "painted" }

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

		function lum(c) { return c.r + c.g + c.b; }

		function test_rimOffByDefault() {
			const rim = findChild(top, "rim");
			verify(!rim || !rim.visible, "no rim unless reflective");
		}

		function test_rimPaintsTheFreeEdge() {
			wait(100);
			const img = grabImage(host);
			const edge = img.pixel(shiny.x + 13 + 100, shiny.y + 35);
			const inside = img.pixel(shiny.x + 13 + 100, shiny.y + 20);
			verify(lum(edge) > lum(inside) + 0.1, `edge ${edge} vs fill ${inside}`);
			compare(lum(inside), 0, "the fill keeps its colour away from the rim");
		}

		function test_rimFadesIntoTheScreenEdge() {
			wait(100);
			const img = grabImage(host);
			const diff = (dx, dy) => Math.abs(lum(img.pixel(shiny.x + dx, shiny.y + dy)) - lum(img.pixel(plain.x + dx, plain.y + dy)));
			const side = diff(13, 15);
			let outer = 0;
			for (let dy = 0; dy < 3; dy++)
				outer = Math.max(outer, diff(3, dy));
			verify(side > 0.1, `the pill's side is lit: ${side}`);
			verify(outer < side * 0.35, `faded near the screen edge: ${outer} vs ${side}`);
		}

		function test_rimFollowsResize() {
			shiny.pillWidth = 300;
			wait(100);
			const img = grabImage(host);
			const newEnd = img.pixel(shiny.x + 13 + 290, shiny.y + 35);
			const oldSide = img.pixel(shiny.x + 13 + 199, shiny.y + 18);
			verify(lum(newEnd) > 0.1, `lit at the new end: ${newEnd}`);
			verify(lum(oldSide) < 0.03, `nothing left at the old side: ${oldSide}`);
			shiny.pillWidth = 200;
		}

		function test_rimRepaintsOnlyOnChange() {
			wait(300);
			paints.target = findChild(shiny, "rim");
			paints.clear();
			shiny.pillWidth = 200;
			shiny.flares = true;
			wait(50);
			compare(paints.count, 0, "same geometry, no repaint");
			shiny.farRadius = 12;
			tryVerify(() => paints.count > 0);
			shiny.farRadius = 18;
		}
	}
}
