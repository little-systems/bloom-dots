import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's RollDigit (App.tsx): the new digit rolls in from 72% below with a
// tilt while the old one rolls out above, over 0.4 s.
Item {
	id: host
	width: 200
	height: 100

	RollDigit { id: digit; value: "5"; color: "#f0f0f0" }
	RollDigit { id: small; x: 50; value: "1"; compact: true; color: "#f0f0f0" }
	RollDigit { id: fresh; x: 100; value: ""; color: "#f0f0f0" }

	TestCase {
		name: "RollDigit"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function settleFrames() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
		}

		function test_geometry() {
			compare(digit.width, 34);
			compare(digit.height, 58);
			verify(digit.clip, "overflow: hidden");
			const num = part(digit, "current");
			compare(num.text, digit.value);
			compare(num.font.pixelSize, 36);
			compare(num.font.weight, Font.DemiBold);
			compare(num.font.letterSpacing, -0.5);
			compare(num.color, Qt.color("#f0f0f0"));
			compare(small.width, 26);
			compare(small.height, 46);
			compare(part(small, "current").font.pixelSize, 28);
		}

		function test_restingDigitIsStill() {
			const num = part(digit, "current");
			compare(num.y, 0);
			compare(num.opacity, 1);
			compare(num.tilt, 1);
			verify(!part(digit, "leaving").visible);
		}

		function test_changeRolls() {
			digit.value = "4";
			const entering = part(digit, "current");
			const leaving = part(digit, "leaving");
			compare(entering.text, "4");
			compare(leaving.text, "5");
			verify(leaving.visible);
			// The first frame: the new digit 72% below, faded out and tilted.
			fuzzyCompare(entering.y, 58 * 0.72, 2);
			verify(entering.opacity < 0.1);
			fuzzyCompare(entering.tilt, Math.cos(50 * Math.PI / 180), 0.05);
			wait(150);
			verify(entering.y > 0 && entering.y < 58 * 0.72, `rolling in at ${entering.y}`);
			verify(leaving.y < 0, `rolling out at ${leaving.y}`);
			tryCompare(entering, "y", 0, 1000);
			compare(entering.opacity, 1);
			compare(entering.tilt, 1);
			fuzzyCompare(leaving.y, -58 * 0.72, 0.5);
			verify(!leaving.visible);
		}

		function test_rollTakes400ms() {
			small.value = "2";
			wait(300);
			verify(part(small, "current").y > 0, "still moving at 0.3 s");
			tryCompare(part(small, "current"), "y", 0, 400);
		}

		function test_appearingDigitDoesNotRoll() {
			// A digit that wasn't there (a third minute digit) appears in place,
			// as Bloom mounts it with initial={false}.
			fresh.value = "1";
			compare(part(fresh, "current").y, 0);
			compare(part(fresh, "current").opacity, 1);
			verify(!part(fresh, "leaving").visible);
		}

		function test_noFramesAtRest() {
			settleFrames();
			compare(framesIn(1000), 0);
		}
	}
}
