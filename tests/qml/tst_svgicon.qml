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

	TestCase {
		name: "SvgIcon"
		when: windowShown

		function test_recoloursTheStroke() {
			tryCompare(red, "status", Image.Ready, 3000);
			const img = grabImage(host);
			// The sun's top ray runs from (12, 2) to (12, 4) in the 24 px box.
			verify(Qt.colorEqual(img.pixel(12, 3), "#ff0000"), `got ${img.pixel(12, 3)}`);
		}

		function test_strokeWidthIsApplied() {
			verify(thick.source.toString().indexOf(encodeURIComponent('stroke-width="2.2"')) > 0);
		}

		function test_unknownIconIsEmpty() {
			// The warning fires at creation, so create the icon after expecting it.
			ignoreWarning(/unknown icon "no-such-icon"/);
			const missing = createTemporaryObject(missingComponent, host);
			compare(missing.source.toString(), "");
		}
	}
}
