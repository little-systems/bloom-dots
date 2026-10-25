import QtQuick
import qs.services

// The notch's view of the music services. NotchWindow loads it only while
// music mode is on, so a shell without music never connects to MPRIS or runs cava.
Item {
	readonly property var media: ({
		hasMedia: Media.hasMedia, isPlaying: Media.isPlaying, title: Media.title, artist: Media.artist,
		artUrl: Media.artUrl, lengthMs: Media.lengthMs, canSeek: Media.canSeek
	})
	readonly property real positionMs: Media.positionMs
	readonly property var levels: Cava.levels
	readonly property bool visualizerAvailable: Cava.available

	// cava only runs when the visualizer is actually drawn.
	function hold(key, on, visualizer) {
		Media.hold(key, on);
		Cava.hold(key, on && visualizer);
	}

	function togglePlay() { Media.togglePlaying(); }
	function previousTrack() { Media.previous(); }
	function nextTrack() { Media.next(); }
	function seekTo(ms) { Media.seek(ms); }
}
