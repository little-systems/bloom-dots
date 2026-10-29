import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 600
	height: 400

	readonly property var track: ({ title: "Song", artist: "Artist", artUrl: "", isPlaying: true, lengthMs: 200000, canSeek: true })

	ClassicPlayer { id: classic; width: 316; height: 120; media: host.track; volume: 0.5; mixerAvailable: false }
	CompactPlayer { id: compactBloom; x: 300; y: 150; width: 276; height: 132; media: ({ title: "Midnight City", artist: "M83", artUrl: "", isPlaying: true, lengthMs: 243000, canSeek: true }); positionMs: 85000; volume: 0.5; mixerAvailable: true }
	CompactPlayer { id: compact; y: 150; width: 276; height: 132; media: host.track; positionMs: 65000; volume: 0.5; mixerAvailable: true }

	SignalSpy { id: playSpy; target: classic; signalName: "togglePlay" }
	SignalSpy { id: prevSpy; target: classic; signalName: "previousTrack" }
	SignalSpy { id: layoutSpy; target: classic; signalName: "switchLayout" }
	SignalSpy { id: seekSpy; target: compact; signalName: "seekTo" }
	SignalSpy { id: mixerSpy; target: compact; signalName: "openMixer" }

	TestCase {
		name: "Players"
		when: windowShown

		function centre(item) { return item.mapToItem(host, item.width / 2, item.height / 2); }
		function click(name, root) {
			const it = findChild(root, name);
			verify(it !== null, name);
			const p = centre(it);
			mouseClick(host, p.x, p.y);
		}

		function test_classicControls() {
			click("playButton", classic);
			compare(playSpy.count, 1);
			click("prevButton", classic);
			tryCompare(prevSpy, "count", 1, 1000);
			click("bigArt", classic);
			compare(layoutSpy.count, 1, "clicking the art switches layout");
		}

		// Bloom's classic player as Chromium lays it out (measured with
		// tools/bloom-audit/drive-music.cjs; player origin = pill x - 12).
		function test_classicMatchesBloomsLayout() {
			function at(name, x, y, w, h) {
				const it = findChild(classic, name);
				verify(it !== null, name);
				const p = it.mapToItem(classic, 0, 0);
				fuzzyCompare(p.x, x, 0.51, `${name} x`);
				fuzzyCompare(p.y, y, 0.51, `${name} y`);
				if (w !== undefined) fuzzyCompare(it.width, w, 0.51, `${name} width`);
				if (h !== undefined) fuzzyCompare(it.height, h, 0.51, `${name} height`);
				return it;
			}
			// 96 px of art inside a hairline border (content-box), centred.
			at("bigArt", 0, 11, 98, 98);
			const title = at("marqueeLabel", 120, 11);
			fuzzyCompare(title.font.pixelSize * title.scale, 14.5, 0.01, "title size");
			const artist = at("artist", 120, 30);
			compare(artist.font.weight, Font.Normal);
			// Bars centred in the 30 px visualizer box.
			at("bar0", 288.5, 20.2);
			at("prevButton", 124, 56, 48, 32);
			at("playButton", 196, 50, 44, 44);
			at("nextButton", 264, 56, 48, 32);
			at("volumeTrack", 140, 102.5, 154, 5);
		}

		// Bloom's compact player as Chromium lays it out (player origin =
		// pill x - 12): line-height 1.2 boxes, a 20 px progress row, and
		// time boxes at least 30 px wide that grow with their text.
		function test_compactMatchesBloomsLayout() {
			function at(name, x, y, w, h) {
				const it = findChild(compactBloom, name);
				verify(it !== null, name);
				const p = it.mapToItem(compactBloom, 0, 0);
				if (x !== null) fuzzyCompare(p.x, x, 0.51, `${name} x`);
				if (y !== null) fuzzyCompare(p.y, y, 0.51, `${name} y`);
				if (w !== undefined) fuzzyCompare(it.width, w, 0.51, `${name} width`);
				if (h !== undefined) fuzzyCompare(it.height, h, 0.51, `${name} height`);
				return p;
			}
			at("marqueeLabel", 61, 12.3);
			at("artist", 61, 31.3);
			compare(findChild(compactBloom, "artist").font.weight, Font.Normal);
			at("bar0", 245.5, 26.4);
			at("elapsed", 3, 62);
			const rem = findChild(compactBloom, "remaining");
			const r = at("remaining", null, 62);
			fuzzyCompare(r.x + rem.width, 273, 0.51, "remaining ends at the row's edge");
			verify(rem.width >= 30);
			const t = at("progressTrack", 39, 67.5, undefined, 3);
			fuzzyCompare(t.x + findChild(compactBloom, "progressTrack").width, r.x - 6, 0.51, "track ends 6 px before the time");
			at("speakerButton", 3, 93, 32, 32);
			at("prevButton", 70, 88, 42, 42);
			at("playButton", 116, 87, 44, 44);
			at("nextButton", 164, 88, 42, 42);
		}

		function test_classicHidesMixerButtonWithoutMixer() {
			compare(findChild(classic, "mixerButton").visible, false);
		}

		function test_compactTimes() {
			compare(findChild(compact, "elapsed").text, "1:05");
			compare(findChild(compact, "remaining").text, "-2:15");
		}

		function test_compactSeek() {
			const bar = findChild(compact, "progressBar");
			const p = bar.mapToItem(host, bar.width / 2, bar.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			compare(seekSpy.count, 1);
			fuzzyCompare(seekSpy.signalArguments[0][0], 100000, 3000);
		}

		// Review focus 4.
		function test_noSeekWhenNotSeekable() {
			compact.media = { title: "Live", artist: "", artUrl: "", isPlaying: true, lengthMs: 200000, canSeek: false };
			const before = seekSpy.count;
			const bar = findChild(compact, "progressBar");
			const p = bar.mapToItem(host, bar.width / 2, bar.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			compare(seekSpy.count, before);
			compact.media = host.track;
		}

		function test_noProgressWithoutLength() {
			compact.media = { title: "Stream", artist: "", artUrl: "", isPlaying: true, lengthMs: 0, canSeek: false };
			verify(!compact.hasProgress);
			compare(findChild(compact, "progressRow").visible, false);
			compact.media = host.track;
			verify(compact.hasProgress);
		}

		function test_compactSpeakerTogglesVolume() {
			compact.volumeExpanded = false;
			click("speakerButton", compact);
			verify(compact.volumeExpanded);
			click("speakerButton", compact);
			verify(!compact.volumeExpanded);
		}

		function test_compactMixer() {
			click("mixerButton", compact);
			compare(mixerSpy.count, 1);
		}
	}
}
