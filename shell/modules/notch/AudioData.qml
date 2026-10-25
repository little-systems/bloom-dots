import QtQuick
import qs.services

// Volume and mixer for the open player. Loaded only while the player is open,
// so the collapsed notch never connects to PipeWire.
Item {
	readonly property real volume: Audio.volume
	readonly property bool muted: Audio.muted
	readonly property bool mixerAvailable: Audio.mixer !== ""

	function setVolume(v) { Audio.setVolume(v); }
	function openMixer() { Audio.openMixer(); }
}
