import QtQuick
import QtTest
import "../../shell/common/edge.js" as Edge

// Bloom's edgeSurfaceContour (scripts/edgeSurfaceContour.test.ts) and the
// rim colours of EdgeSurface.css.
TestCase {
	name: "EdgeContour"

	function test_topWithFlares() {
		const path = Edge.contour(226, 37, [[0, 0], [0, 0], [18, 18], [18, 18]], "top", true);
		verify(path.startsWith("M 0 0 C 10 0 13 3 13 13"), path);
		verify(path.endsWith("C 213 3 216 0 226 0"), path);
		verify(path.includes("A 18 18 0 0 0 31 37"), path);
	}

	function test_clampsEllipticalAxesIndependently() {
		const path = Edge.contour(226, 52, [[40, 18], [40, 18], [0, 0], [0, 0]], "bottom", true);
		verify(path.includes("L 13 34 A 40 18 0 0 0 53 52"), path);
		verify(path.includes("L 173 52 A 40 18 0 0 0 213 34"), path);
	}

	function test_cornerPairsAndCollapsedOutline() {
		const radii = [[18, 12], [16, 10], [8, 6], [7, 5]];
		verify(Edge.contour(226, 52, radii, "top", true).includes("A 8 6"));
		const collapsed = Edge.contour(226, 52, radii, "bottom", false);
		verify(collapsed.startsWith("M 13 6 A 8 6"), collapsed);
		verify(collapsed.includes("A 18 12"), collapsed);
		verify(collapsed.endsWith(" Z"), collapsed);
	}

	function test_radiiClampedToHalf() {
		const path = Edge.contour(226, 30, [[0, 0], [0, 0], [40, 40], [40, 40]], "top", false);
		verify(path.includes("A 40 15"), path);
		verify(path.startsWith("M 13 0"), path);
	}

	function test_rimColors() {
		const c = Edge.rimColors(Qt.color("#000000"), Qt.color("#ffffff"));
		const near = (a, b) => Math.abs(a - b) <= 1 / 255;
		verify(near(c.line.r, 0.18) && near(c.line.g, 0.18) && near(c.line.b, 0.18), c.line);
		verify(near(c.side.r, 0.18 * 0.95 + 0.05), c.side);
		verify(near(c.highlight.r, 0.18 * 0.86 + 0.14), c.highlight);
		compare(c.line.a, 1);
	}
}
