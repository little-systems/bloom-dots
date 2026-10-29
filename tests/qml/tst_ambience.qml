import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's .notch-ambient-glow::after: radial-gradient(ellipse at center, ...)
// sizes the ellipse to the farthest corner, so its radii are √2 times the
// half-width and half-height, and the notch colour only reaches the corners.
// Its motion (App.tsx): the glow fades over 0.15 s; each art enters over
// 0.3 s easeInOut, opacity 0 → 1 and scale 1.1 → 1.8, after the previous art
// has faded out (AnimatePresence mode="wait").
Item {
	id: host
	width: 400
	height: 200

	Ambience { id: amb; width: 300; height: 132; bg: "black" }
	Ambience { id: moving; y: 140; width: 300; height: 132; bg: "black" }

	readonly property url artA: Qt.resolvedUrl("../../shell/assets/device-art/anim/mouse.png")
	readonly property url artB: Qt.resolvedUrl("../../shell/assets/device-art/anim/keyboard.png")

	TestCase {
		name: "Ambience"
		when: windowShown

		function test_vignetteReachesFarthestCorner() {
			const v = findChild(amb, "vignette");
			verify(v, "has a vignette");
			fuzzyCompare(v.radiusX, 150 * Math.SQRT2, 0.01);
			fuzzyCompare(v.radiusY, 66 * Math.SQRT2, 0.01);
		}

		function test_blurScalesWithTheArt() {
			// CSS applies filter before transform: blur(52px) under scale(1.8).
			const f = findChild(amb, "glow");
			fuzzyCompare(f.delta.y * f.height, 52 * 1.8, 0.01);
		}

		function init() {
			moving.active = true;
			moving.source = "";
			wait(450);
		}

		function test_artEntersFromSmallerScale() {
			moving.source = host.artA;
			tryVerify(() => moving.zoom < 1.8 && moving.artOpacity < 1, 1000, "the entrance has begun");
			verify(moving.zoom >= 1.1, `starts at 1.1, ${moving.zoom}`);
			// The blur grows with the art.
			const f = findChild(moving, "glow");
			fuzzyCompare(f.delta.y * f.height, 52 * moving.zoom, 0.5);
			wait(150);
			verify(moving.zoom > 1.25 && moving.zoom < 1.75, `midway at 150 ms, ${moving.zoom}`);
			wait(250);
			compare(moving.zoom, 1.8);
			compare(moving.artOpacity, 1);
		}

		function test_newArtWaitsForTheOldToLeave() {
			moving.source = host.artA;
			tryCompare(moving, "artOpacity", 1, 1500);
			moving.source = host.artB;
			wait(150);
			// Still the old art, fading out at full size.
			compare(moving.shownSource, host.artA);
			compare(moving.zoom, 1.8);
			verify(moving.artOpacity > 0.1 && moving.artOpacity < 0.9, `fading, ${moving.artOpacity}`);
			tryCompare(moving, "shownSource", host.artB, 1000);
			tryCompare(moving, "zoom", 1.8, 1000);
			compare(moving.artOpacity, 1);
		}

		function test_glowFadesWhenInactive() {
			moving.source = host.artA;
			tryCompare(moving, "artOpacity", 1, 1500);
			compare(moving.opacity, 1);
			moving.active = false;
			wait(75);
			verify(moving.opacity > 0.1 && moving.opacity < 0.9, `fading, ${moving.opacity}`);
			verify(moving.visible);
			tryCompare(moving, "visible", false, 500);
		}

		function test_cssFilterTokens() {
			const f = findChild(amb, "glow");
			verify(f, "has the filtered glow");
			compare(f.saturate, 3.5);
			compare(f.contrast, 1.1);
			compare(f.brightness, 1.4);
			// The CSS says opacity 0.85, but framer-motion's animate
			// { opacity: 1 } overrides it inline (measured in Bloom).
			compare(f.alpha, 1);
		}
	}
}
