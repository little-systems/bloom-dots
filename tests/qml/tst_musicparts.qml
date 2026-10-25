import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 400
	height: 300

	Visualizer { id: viz; levels: [0.05, 0.5, 1, 0.3, 0.9] }
	TitleMarquee { id: shortTitle; y: 40; width: 300; text: "Short" }
	TitleMarquee { id: longTitle; y: 70; width: 100; text: "A very long title that cannot possibly fit in a hundred pixels" }
	TitleMarquee { id: emptyTitle; y: 100; width: 100; text: "" }
	SkipButton { id: next; y: 130; forward: true }
	SkipButton { id: prev; x: 60; y: 130; forward: false }
	PlayButton { id: play; x: 120; y: 130 }
	VolumeRow { id: vol; y: 200; width: 200; volume: 0.25 }
	AlbumArt { id: art; x: 300; y: 200; width: 50; height: 50; source: "" ; flipMs: 50 }

	SignalSpy { id: nextSpy; target: next; signalName: "activated" }
	SignalSpy { id: playSpy; target: play; signalName: "clicked" }
	SignalSpy { id: volSpy; target: vol; signalName: "moved" }

	TestCase {
		name: "MusicParts"
		when: windowShown

		function test_visualizerTargets() {
			const bar = i => findChild(viz, "bar" + i);
			viz.playing = true;
			compare(bar(0).targetScale, 0.2, "never below 0.2 while playing");
			compare(bar(2).targetScale, 1);
			compare(bar(0).targetOpacity, 0.95);
			viz.playing = false;
			compare(bar(2).targetScale, 0.1);
			compare(bar(2).targetOpacity, 0.5);
			compare(viz.width, 5 * 3 + 4 * 2.5);
		}

		// Review focus 5.
		function test_marqueeScrollsOnlyWhenTooLong() {
			verify(!shortTitle.scrolling);
			verify(longTitle.scrolling);
			verify(longTitle.overflow > 0);
			compare(longTitle.cycleMs, Math.max(longTitle.overflow / 30, 5) * 1000);
		}

		function test_emptyTitle() {
			verify(!emptyTitle.scrolling);
			compare(emptyTitle.overflow, 0);
		}

		function test_skipPushesThenActivates() {
			mouseClick(next);
			compare(nextSpy.count, 0, "the skip is sent once the slide ends");
			tryCompare(nextSpy, "count", 1, 1000);
		}

		function test_playSwapsIcon() {
			play.playing = false;
			mouseClick(play);
			compare(playSpy.count, 1);
			play.playing = true;
			tryCompare(play, "shownPlaying", true, 1000);
		}

		function test_volumeDrag() {
			const track = findChild(vol, "volumeTrack");
			const p = track.mapToItem(host, track.width * 0.75, track.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			verify(volSpy.count >= 1);
			fuzzyCompare(volSpy.signalArguments[volSpy.count - 1][0], 0.75, 0.05);
		}

		function test_albumArtFlipsOnChange() {
			compare(art.shown.toString(), "");
			art.source = "file:///nonexistent-a.png";
			verify(art.flipping, "the old art turns away first");
			tryCompare(art, "flipping", false, 1000);
			compare(art.shown.toString(), "file:///nonexistent-a.png");
		}
	}
}
