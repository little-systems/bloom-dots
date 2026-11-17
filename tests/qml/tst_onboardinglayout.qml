import QtQuick
import QtTest
import "../../shell/modules/onboarding/pages.js" as Pages
import "../../shell/modules/onboarding/layout.js" as Layout

// Our guide's pages (docs/specs round 3, C) and Bloom's placement (Onboarding.tsx).
TestCase {
	name: "OnboardingLayout"

	function test_ninePagesInOrder() {
		compare(Pages.PAGES.map(p => p.kind), ["welcome", "intro", "island-mode", "intro", "dock-mode", "controls", "keys", "preferences", "finish"]);
		compare(Pages.PAGES.map(p => p.anchor), ["center", "island", "island", "dock", "dock", "center", "center", "center", "center"]);
		compare(Pages.PAGES[0].title, "ui.onboarding.welcomeToBloom");
		compare(Pages.PAGES[0].description, "linux.onboarding.welcomeDesc");
		compare(Pages.PAGES[6].title, "linux.onboarding.keysTitle");
		compare(Pages.PAGES[8].title, "ui.onboarding.alreadyBlooming");
	}

	function test_revealOnlyDuringIntroductions() {
		compare(Pages.PAGES.map(Pages.reveal), ["", "island", "", "dock", "", "", "", "", ""]);
	}

	// Bloom: fitScale = max(0.4, min(scale, (w-40)/500, (h-160)/400)), centred,
	// 96 px (scaled) from the anchored edge, capped by the room left.
	function test_placement() {
		const p = (anchor, w, h, s) => Layout.place(anchor, w, h, s || 1);
		const island = p("island", 1920, 1080);
		compare([island.scale, island.width, island.height, island.x, island.y], [1, 500, 400, 710, 96]);
		compare(p("dock", 1920, 1080).y, 1080 - 400 - 96);
		compare(p("center", 1920, 1080).y, 340);
		const small = p("island", 800, 500);
		compare(small.scale, (500 - 160) / 400);
		compare(small.y, Math.min(96 * small.scale, (500 - small.height) / 2));
		compare(p("center", 300, 300).scale, 0.4);
		compare(p("island", 2560, 1440, 1.3).scale, 1.3);
	}

	// Outside the card when the edge gap holds them (gap/scale >= 88), else inside.
	function test_arrowPlacement() {
		compare(Layout.arrow("island", 1920, 1080, 1).inside, false);
		compare(Layout.arrow("island", 1920, 540, 1).inside, true, "gap 80 at scale 0.95: 84 < 88");
		const up = Layout.arrow("island", 1920, 1080, 1);
		compare([up.x, up.y, up.width, up.height, up.rotation], [250 + 76, -56, 112, 56, 0]);
		const down = Layout.arrow("dock", 1920, 1080, 1);
		compare([down.x, down.y, down.rotation], [250 - 188, 400 + 54 - 56, 180]);
		const inside = Layout.arrow("island", 1920, 540, 1);
		compare([inside.x, inside.y, inside.width, inside.height], [500 - 24 - 32, 65, 32, 28]);
		compare(Layout.arrow("dock", 1920, 540, 1).y, 63);
		compare(Layout.arrow("center", 1920, 1080, 1), null);
	}

	// The input region: the card (+20 px, as Bloom reports it) and the arrow (+4 px).
	function test_region() {
		const rects = Layout.region("island", 1920, 1080, 1);
		compare(rects[0], { x: 690, y: 76, width: 540, height: 440 });
		compare(rects.length, 2);
		compare(Layout.region("center", 1920, 1080, 1).length, 1);
	}
}
