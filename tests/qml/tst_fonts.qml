import QtQuick
import QtTest
import "../../shell/common/render"

// The shell draws Bloom's font: the Inter Google Fonts serves Bloom, bundled
// as "Bloom Inter" (and "Bloom Inter Medium") so an installed Inter of
// another build never stands in. Text names Fonts.familyFor(weight).
Item {
	Text { id: regular; text: "Looks like"; font.family: Fonts.familyFor(Font.Normal); font.pixelSize: 100 }
	Text { id: medium; text: "Looks like"; font.family: Fonts.familyFor(Font.Medium); font.pixelSize: 100; font.weight: Font.Medium }
	Text { id: semibold; text: "Headphones"; font.family: Fonts.familyFor(Font.DemiBold); font.pixelSize: 100; font.weight: Font.DemiBold }
	Text { id: bold; text: "Looks like"; font.family: Fonts.familyFor(Font.Bold); font.pixelSize: 100; font.weight: Font.Bold }
	Text { id: cyrillic; text: "Ж"; font.family: Fonts.family; font.pixelSize: 40 }
	Text { id: fallback; text: "Ж"; font.family: "DejaVu Sans"; font.pixelSize: 40 }

	TestCase {
		name: "Fonts"

		function test_families() {
			compare(Fonts.family, "Bloom Inter");
			compare(Fonts.familyFor(Font.Medium), "Bloom Inter Medium");
			compare(Fonts.familyFor(Font.DemiBold), "Bloom Inter");
			verify(Fonts.ready, "all four weights loaded");
			verify(Qt.fontFamilies().indexOf("Bloom Inter") >= 0);
			verify(Qt.fontFamilies().indexOf("Bloom Inter Medium") >= 0);
		}

		// Google's served build at each weight: Chromium measures these at
		// 100 px as 472, 477, 613 (whole-pixel advances); the system's Inter
		// 4.1 and google/fonts' repository build differ.
		function test_googleMetrics() {
			fuzzyCompare(regular.implicitWidth, 472, 1);
			fuzzyCompare(medium.implicitWidth, 477, 1);
			fuzzyCompare(semibold.implicitWidth, 613, 1.5);
			verify(bold.implicitWidth > medium.implicitWidth + 5, "bold is its own, wider face");
		}

		// Every script subset Google serves is in the merged font: a Cyrillic
		// letter draws in Bloom Inter, not a fallback.
		function test_coverage() {
			verify(Math.abs(cyrillic.implicitWidth - fallback.implicitWidth) > 0.5, "Ж comes from Bloom Inter");
		}
	}
}
