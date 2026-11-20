import QtQuick
import QtTest
import "../../shell/modules/onboarding"
import "../../shell/common/i18n"

// The guide card (Bloom Onboarding.tsx/.css at 63a9bf5, our pages).
Item {
	id: host
	width: 1200
	height: 800

	QtObject {
		id: fakeStore
		property var values: ({ "bloom-notch-mode": "fixed", "bloom-dock-mode": "smart", "bloom-theme-mode": "dark", "bloom-show-update-indicator": true })
		property var sets: []
		property string failWith: ""
		function set(key, value, done) {
			sets = sets.concat([[key, value]]);
			if (failWith === "") {
				const next = Object.assign({}, values);
				next[key] = value;
				values = next;
			}
			if (done) done(failWith);
		}
	}

	Component {
		id: cardComponent
		OnboardingCard { store: fakeStore; reducedMotion: true }
	}

	TestCase {
		name: "Onboarding"
		when: windowShown

		function make(props) {
			fakeStore.sets = [];
			fakeStore.failWith = "";
			const c = createTemporaryObject(cardComponent, host, props || {});
			verify(c !== null);
			return c;
		}
		// A control created by a page change takes clicks once its row is laid out.
		function click(c, name) {
			const it = part(c, name);
			waitForItemPolished(it.parent);
			mouseClick(it);
		}
		function part(c, name) {
			tryVerify(() => findChild(c, name) !== null, 1000, name);
			return findChild(c, name);
		}

		function test_cardKeepsItsSizeOnEveryPage() {
			const c = make();
			for (let i = 0; i < 10; i++) {
				c.index = i;
				compare([c.cardWidth, c.cardHeight], [500, 400], "page " + i);
			}
		}

		function test_progressAndButtons() {
			const c = make();
			compare(part(c, "progress").text, "1 / 10");
			verify(!part(c, "back").visible, "no Back on the first page");
			compare(part(c, "primaryLabel").text, "Show me around");
			c.next();
			compare(c.index, 1);
			compare(part(c, "progress").text, "2 / 10");
			verify(part(c, "back").visible);
			compare(part(c, "primaryLabel").text, "Continue");
			c.index = 9;
			compare(part(c, "primaryLabel").text, "Let's bloom");
			verify(!part(c, "skip").visible, "no Skip on the last page");
			c.back();
			compare(c.index, 8);
		}

		function test_pagesShowTheirText() {
			const c = make();
			compare(part(c, "title").text, "Welcome to Bloom.");
			compare(part(c, "description").text, "Bloom makes your Linux desktop feel alive.");
			c.index = 6;
			compare(part(c, "title").text, "Catch up anytime");
			compare(part(c, "description").text, "Notifications slide in at the top-right corner, then tuck themselves away. Bloom just sent you one to try.");
			compare(part(c, "hint:0").text, "Point at the very top-right corner to see them again");
			compare(part(c, "hint:1").text, "Clear All empties the list");
			compare(part(c, "hint:2").text, "Turn on Do Not Disturb in the Command Center");
			c.index = 7;
			compare(part(c, "title").text, "Everything a keystroke away.");
			compare(part(c, "hint:3").text, "Super+/ lists every shortcut.");
		}

		function test_revealFollowsTheIntroductions() {
			const c = make();
			const seen = [];
			for (let i = 0; i < 10; i++) { c.index = i; seen.push(c.reveal); }
			compare(seen, ["", "island", "", "dock", "", "", "", "", "", ""]);
		}

		function test_closeEscapeSkipAndFinish() {
			const c = make();
			let closed = 0;
			c.closeRequested.connect(() => closed++);
			c.forceActiveFocus();
			keyClick(Qt.Key_Escape);
			compare(closed, 1, "Escape closes");
			mouseClick(part(c, "skip"));
			compare(closed, 2, "Skip closes");
			mouseClick(part(c, "close"));
			compare(closed, 3, "the header's close button closes");
			c.index = 9;
			mouseClick(part(c, "primary"));
			compare(closed, 4, "Let's bloom closes");
		}

		function test_arrowDrawsOnlyBesideItsSurface() {
			const c = make({ anchorPlacement: { inside: false, x: 326, y: -56, width: 112, height: 56, rotation: 0 } });
			c.index = 0;
			verify(!part(c, "arrow").visible);
			c.index = 1;
			verify(part(c, "arrow").visible);
			compare([part(c, "arrow").x, part(c, "arrow").y], [326, -56]);
			verify(!part(c, "arrow").mirrored);
		}

		// Owner: the notifications page points up-right, into the corner.
		function test_notificationsArrowPointsAtTheCorner() {
			const c = make({ anchorPlacement: { inside: false, x: 388, y: -56, width: 112, height: 56, rotation: 0, mirror: true } });
			c.index = 6;
			verify(part(c, "arrow").visible);
			verify(part(c, "arrow").mirrored);
		}

		function test_choicesApplyAndAFailureKeepsTheOldValue() {
			const c = make();
			c.index = 2;
			click(c, "segment:peek");
			compare(fakeStore.sets, [["bloom-notch-mode", "peek"]]);
			compare(fakeStore.values["bloom-notch-mode"], "peek");
			c.index = 4;
			fakeStore.failWith = "disk full";
			click(c, "segment:fixed");
			compare(fakeStore.values["bloom-dock-mode"], "smart", "the old value stays");
			verify(part(c, "error").visible);
			compare(part(c, "error").text, "Couldn't save that. Please try again. disk full");
			c.next();
			verify(!part(c, "error").visible, "leaving the page clears the error");
		}

		function test_preferencesApplyLive() {
			const c = make();
			c.index = 8;
			click(c, "segment:light");
			click(c, "updates");
			compare(fakeStore.sets, [["bloom-theme-mode", "light"], ["bloom-show-update-indicator", false]]);
		}

		function test_replayKeepsACustomTheme() {
			const c = make();
			fakeStore.values = Object.assign({}, fakeStore.values, { "bloom-theme-mode": "custom" });
			c.index = 8;
			verify(part(c, "segment:custom").selected, "Custom (current) is offered and selected");
			c.index = 9;
			compare(fakeStore.sets, [], "visiting the page writes nothing");
			fakeStore.values = Object.assign({}, fakeStore.values, { "bloom-theme-mode": "dark" });
		}
	}
}
