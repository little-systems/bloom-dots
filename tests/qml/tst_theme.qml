import QtQuick
import QtTest
import "../../shell/services/theme.js" as Theme

TestCase {
	name: "ThemeMaths"

	function rgb(c) { return [c.r, c.g, c.b]; }

	function test_darkDefault() {
		const t = Theme.compute("dark", "#007aff", 0.8, 0.5, 0.15, null);
		compare(t.mode, "dark");
		verify(!t.isLight);
		compare(rgb(t.bg), [0, 0, 0]);
		fuzzyCompare(t.bg.a, 0.8, 1e-9);
		fuzzyCompare(t.bgExpanded.a, 0.92, 1e-9);
		compare(t.text, { r: 255, g: 255, b: 255, a: 1 });
		compare(t.textMuted, { r: 255, g: 255, b: 255, a: 0.6 });
		compare(t.border, { r: 255, g: 255, b: 255, a: 0.1 });
		compare(t.accent, { r: 0, g: 122, b: 255, a: 1 });
	}

	function test_expandedOpacityCapsAtOne() {
		fuzzyCompare(Theme.compute("dark", "#007aff", 0.95, 0.5, 0.15, null).bgExpanded.a, 1, 1e-9);
	}

	function test_light() {
		const t = Theme.compute("light", "#007aff", 0.8, 0.5, 0.15, null);
		verify(t.isLight);
		compare(rgb(t.bg), [255, 255, 255]);
		compare(rgb(t.bgExpanded), [245, 245, 247]);
		compare(t.text, { r: 28, g: 28, b: 30, a: 1 });
		compare(t.textMuted, { r: 28, g: 28, b: 30, a: 0.65 });
	}

	// Reference values computed with Bloom's own theme.ts functions.
	function test_customDark() {
		const t = Theme.compute("custom", "#007aff", 0.8, 0.5, 0.15, null);
		compare(t.mode, "custom");
		verify(!t.isLight);
		compare(rgb(t.bg), [0x13, 0x26, 0x39]);
		compare(t.textMuted, { r: 255, g: 255, b: 255, a: 0.65 });
		compare(t.accent, { r: 0, g: 122, b: 255, a: 1 });
	}

	function test_customLight() {
		const t = Theme.compute("custom", "#ff9500", 0.8, 0.3, 0.7, null);
		verify(t.isLight);
		compare(rgb(t.bg), [0xc9, 0xb6, 0x9c]);
		compare(t.text, { r: 28, g: 28, b: 30, a: 1 });
	}

	function test_adaptiveWithoutAccentFallsBackToDark() {
		compare(Theme.compute("adaptive", "#007aff", 0.8, 0.5, 0.15, null).mode, "dark");
	}

	function test_adaptiveWithAccent() {
		const t = Theme.compute("adaptive", "#007aff", 0.8, 0.5, 0.15, "#ff9500");
		compare(t.mode, "adaptive");
		compare(t.accent, { r: 255, g: 149, b: 0, a: 1 });
	}

	function test_hslHelpers() {
		compare(Theme.hexToHsl("#007aff"), { h: 211, s: 100, l: 50 });
		compare(Theme.hexToHsl("#fff"), { h: 0, s: 0, l: 100 });
		compare(Theme.hslToHex(211, 50, 15), "#132639");
	}
}
