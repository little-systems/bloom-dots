import QtQuick
import QtTest
import "../../shell/modules/notch/music.js" as Music

TestCase {
	name: "MusicRules"

	function test_collapsedMode() {
		compare(Music.collapsedMode({ enabled: true, compactNotch: true, hasMedia: true, activityVisible: true }), "music");
		compare(Music.collapsedMode({ enabled: true, compactNotch: true, hasMedia: true, activityVisible: false }), "status");
		compare(Music.collapsedMode({ enabled: true, compactNotch: false, hasMedia: true, activityVisible: true }), "status");
		compare(Music.collapsedMode({ enabled: false, compactNotch: true, hasMedia: true, activityVisible: true }), "status");
	}

	function hover(props) {
		const s = { open: false, hovered: true, mode: "status", enabled: true, hasMedia: true, activityVisible: false, compactNotch: true };
		for (const k in props) s[k] = props[k];
		return Music.musicOnStatusHover(s);
	}

	function test_musicOnStatusHover() {
		verify(hover({}), "a faded session shows on hover");
		verify(hover({ activityVisible: true, compactNotch: false }), "compact notch off: hover is the only way in");
		verify(!hover({ activityVisible: true }), "still the live activity");
		verify(!hover({ hovered: false }));
		verify(!hover({ open: true }));
		verify(!hover({ hasMedia: false }));
	}

	function widthOf(props) {
		const s = { open: false, mode: "status", hovered: false, onStatusHover: false, layout: "classic", visualizer: true, playing: true, albumArt: true, widgetCount: 2, fitWidth: 0, use24h: false };
		for (const k in props) s[k] = props[k];
		return Music.contentWidth(s);
	}

	// Bloom getDynamicWidth, in its order.
	function test_contentWidth() {
		compare(widthOf({ onStatusHover: true }), 200);
		compare(widthOf({ onStatusHover: true, visualizer: false }), 170);
		compare(widthOf({ hovered: true }), 300, "status hover");
		compare(widthOf({ mode: "music", open: true }), 340);
		compare(widthOf({ mode: "music", open: true, layout: "compact" }), 300);
		compare(widthOf({ mode: "music" }), 200);
		compare(widthOf({ mode: "music", playing: false }), 170, "visualizer width only while playing");
		compare(widthOf({ mode: "music", albumArt: false }), 170);
		compare(widthOf({ mode: "music", use24h: true }), 184);
		compare(widthOf({}), 140);
	}

	// Bloom: a pulse widens the collapsed pill to 200, after the hover and
	// open-player checks.
	function test_pulseWidth() {
		compare(widthOf({ pulse: "power" }), 200, "status mode");
		compare(widthOf({ pulse: "update", mode: "music" }), 200, "collapsed music");
		compare(widthOf({ pulse: "", mode: "status" }), 140);
		compare(widthOf({ pulse: "power", hovered: true }), 300, "the hovered strip wins");
		compare(widthOf({ pulse: "power", open: true, mode: "music" }), 340, "the open player wins");
	}

	function test_contentHeight() {
		compare(Music.contentHeight({ open: false, mode: "music", layout: "classic", hasProgress: false, volumeExpanded: false }), 36);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "classic", hasProgress: true, volumeExpanded: true }), 120);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: false, volumeExpanded: false }), 116);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: true, volumeExpanded: false }), 132);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: true, volumeExpanded: true }), 168);
	}

	function test_shouldPeek() {
		verify(Music.shouldPeek({ title: "A", playing: true }, { title: "B", playing: true }), "new track while playing");
		verify(Music.shouldPeek({ title: "A", playing: false }, { title: "A", playing: true }), "playback started");
		verify(!Music.shouldPeek({ title: "A", playing: true }, { title: "A", playing: true }));
		verify(!Music.shouldPeek({ title: "A", playing: true }, { title: "B", playing: false }), "new track while paused");
	}

	function test_marqueeAndBars() {
		compare(Music.marqueeDuration(60), 5, "5 s minimum");
		compare(Music.marqueeDuration(300), 10, "30 px/s");
		compare(Music.barScale(true, 0.05), 0.2);
		compare(Music.barScale(true, 0.8), 0.8);
		compare(Music.barScale(false, 0.8), 0.1);
	}
}
