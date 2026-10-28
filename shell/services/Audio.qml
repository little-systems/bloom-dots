pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../modules/osd/osd.js" as OSD

// System output volume for the player's volume rows, and the mixer app its
// audio-output button opens (Bloom opened Windows' sound settings). The
// button hides when no mixer is installed.
Singleton {
	id: root

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property real volume: root.sink?.audio?.volume ?? 0
	readonly property bool muted: root.sink?.audio?.muted ?? false
	readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)
	readonly property var mixerRows: OSD.mixerRows(root.streams)
	property string mixer: ""
	property bool _baselineReady: false
	property real _lastVolume: 0
	signal outputChanged(real volume, bool muted)
	signal protectionTriggered(string reason)

	function _seed() {
		if (!root.sink?.ready || !root.sink.audio || !Number.isFinite(root.sink.audio.volume)) return;
		root._lastVolume = root.sink.audio.volume;
		root._baselineReady = true;
	}
	onSinkChanged: { root._baselineReady = false; root._seed(); }
	Component.onCompleted: root._seed()
	Connections {
		target: root.sink
		function onReadyChanged() { if (root.sink?.ready) root._seed(); }
	}
	Connections {
		target: root.sink?.audio ?? null
		function onVolumeChanged() {
			const next = root.sink?.audio?.volume;
			if (!Number.isFinite(next)) { root._baselineReady = false; return; }
			if (!root._baselineReady) { root._seed(); return; }
			const result = OSD.volumeObservation(root._lastVolume, next, {
				enabled: Settings.values["bloom-volume-protection-enabled"],
				maxJump: Settings.values["bloom-volume-max-jump"],
				maxLevel: Settings.values["bloom-volume-max-level"]
			}, true);
			root._lastVolume = result.value;
			if (result.correction) {
				root.sink.audio.volume = result.value;
				root.protectionTriggered(result.reason);
				// The corrective PipeWire update will emit the one visible event.
				return;
			}
			if (result.announce) root.outputChanged(result.value, root.muted);
		}
		function onMutedChanged() {
			if (root._baselineReady) root.outputChanged(root.volume, root.muted);
		}
	}

	// Bloom: setting a non-zero volume also unmutes.
	function setVolume(v) {
		if (!root.sink || !root.sink.audio)
			return;
		const clamped = Math.max(0, Math.min(1, v));
		root.sink.audio.volume = clamped;
		if (clamped > 0)
			root.sink.audio.muted = false;
	}

	function openMixer() {
		// Its own scope, so the mixer outlives a shell restart.
		if (root.mixer)
			Apps.run([root.mixer], root.mixer);
	}
	function setStreamVolume(id, value) {
		const node = root.streams.find(n => n.id === id);
		if (!node?.audio || !Number.isFinite(value)) return "stream unavailable";
		node.audio.volume = Math.max(0, Math.min(1, value));
		return "ok";
	}
	function toggleStreamMute(id) {
		const node = root.streams.find(n => n.id === id);
		if (!node?.audio) return "stream unavailable";
		node.audio.muted = !node.audio.muted;
		return "ok";
	}

	PwObjectTracker { objects: [root.sink].concat(root.streams) }

	Process {
		running: true
		command: ["sh", "-c", "for c in pavucontrol pwvucontrol pavucontrol-qt; do command -v \"$c\" >/dev/null && { echo \"$c\"; exit 0; }; done; exit 0"]
		stdout: StdioCollector { onStreamFinished: root.mixer = text.trim() }
	}
}
