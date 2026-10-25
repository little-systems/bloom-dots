import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 600
	height: 400

	readonly property var track: ({ title: "Song", artist: "Artist", artUrl: "", isPlaying: true, lengthMs: 200000, canSeek: true })

	ClassicPlayer { id: classic; width: 316; height: 120; media: host.track; volume: 0.5; mixerAvailable: false }
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
