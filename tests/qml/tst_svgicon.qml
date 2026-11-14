import QtQuick
import QtTest
import "../../shell/common"

Item {
	id: host
	width: 80
	height: 30

	Rectangle { anchors.fill: parent; color: "black" }

	SvgIcon { id: red; name: "sun"; color: "#ff0000"; size: 24 }
	SvgIcon { id: thick; x: 30; name: "cpu"; color: "white"; size: 24; strokeWidth: 2.2 }
	Component { id: missingComponent; SvgIcon { name: "no-such-icon" } }
	Component { id: probeComponent; SvgIcon { name: "sun" } }

	// Bloom's muted icons: white at 0.6 (the theme's textMuted).
	SvgIcon { id: muted; x: 56; name: "plus"; color: Qt.rgba(1, 1, 1, 0.6); size: 24 }
	SvgIcon { id: play; x: 0; y: 0; name: "sf-play.fill"; color: "#00ff00"; size: 24; visible: false }

	TestCase {
		name: "SvgIcon"
		when: windowShown

		function test_recoloursTheStroke() {
			tryCompare(red, "status", Image.Ready, 3000);
			const img = grabImage(host);
			// The sun's top ray runs from (12, 2) to (12, 4) in the 24 px box.
			verify(Qt.colorEqual(img.pixel(12, 3), "#ff0000"), `got ${img.pixel(12, 3)}`);
		}

		// A translucent colour draws translucent: SVG takes no alpha in a
		// colour, so it goes on as the drawing's opacity.
		function test_colourAlphaIsKept() {
			tryCompare(muted, "status", Image.Ready, 3000);
			const img = grabImage(host);
			// The plus's strokes cross at the box's centre (68, 12).
			const c = img.pixel(68, 12);
			fuzzyCompare(c.r, 0.6, 0.05, `white at 0.6 over black, got ${c}`);
		}

		function test_strokeWidthIsApplied() {
			verify(thick.source.toString().indexOf(encodeURIComponent('stroke-width="2.2"')) > 0);
		}

		// Every icon the Bloom 3.10.2 port names (calendar header, Command
		// Center sliders, settings rows) is in the generated set.
		function test_portIconsExist() {
			for (const name of ["check", "chevron-left", "chevron-right", "volume", "volume-1", "volume-2", "volume-x", "sun-dim", "sun-medium", "sun", "sparkles", "layers", "calendar"]) {
				const icon = createTemporaryObject(probeComponent, host, { name: name });
				verify(icon.source.toString() !== "", name);
			}
		}

		function test_unknownIconIsEmpty() {
			// The warning fires at creation, so create the icon after expecting it.
			ignoreWarning(/unknown icon "no-such-icon"/);
			const missing = createTemporaryObject(missingComponent, host);
			compare(missing.source.toString(), "");
		}
			// Bloom's SF player icons are filled; recolouring must reach the fill.
		function test_recoloursAFilledIcon() {
			red.visible = false;
			play.visible = true;
			tryCompare(play, "status", Image.Ready, 3000);
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(10, 12), "#00ff00"), `got ${img.pixel(10, 12)}`);
			play.visible = false;
			red.visible = true;
		}
	}
}
