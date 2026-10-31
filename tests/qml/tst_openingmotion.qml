import QtQuick
import QtTest
import "../../shell/common"
import "../../shell/common/render"
import "../../shell/common/tokens.js" as Tokens

Item {
	id: host
	Component { id: motion; OpeningMotion { autoRun: false; initial: 0; target: 0 } }
	TestCase {
		name: "OpeningMotion"
		function init() { Render.animationStyle = "macos"; Render.reduceMotion = false; }
		function cleanup() { Render.animationStyle = "macos"; Render.reduceMotion = false; }
		function test_configRestoresBloomsMorph() {
			Render.animationStyle = "bloom";
			const m = createTemporaryObject(motion, host);
			compare(m.extent, Tokens.morph.from);
			compare(m.zoom, 1);
			m.target = 1; m.step(0.05);
			verify(m.extent > Tokens.morph.from && m.extent < 1);
		}
		function test_defaultKeepsLayoutAndScalesTheCard() {
			const m = createTemporaryObject(motion, host);
			compare(m.extent, 1);
			compare(m.zoom, 0.97);
			m.target = 1; m.step(0.05);
			compare(m.extent, 1);
			verify(m.zoom > 0.97 && m.zoom < 1);
		}
		function test_reduceMotionSkipsEitherEntrance() {
			for (const style of ["macos", "bloom"]) {
				Render.animationStyle = style; Render.reduceMotion = true;
				const m = createTemporaryObject(motion, host);
				m.target = 1;
				compare(m.progress, 1); compare(m.extent, 1); compare(m.zoom, 1);
				verify(m.settled);
			}
		}
	}
}
