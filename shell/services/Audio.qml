pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// System output volume for the player's volume rows, and the mixer app its
// audio-output button opens (Bloom opened Windows' sound settings). The
// button hides when no mixer is installed.
Singleton {
	id: root

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property real volume: root.sink?.audio?.volume ?? 0
	readonly property bool muted: root.sink?.audio?.muted ?? false
	property string mixer: ""

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
		if (root.mixer)
			Quickshell.execDetached([root.mixer]);
	}

	PwObjectTracker { objects: [root.sink] }

	Process {
		running: true
		command: ["sh", "-c", "for c in pavucontrol pwvucontrol pavucontrol-qt; do command -v \"$c\" >/dev/null && { echo \"$c\"; exit 0; }; done; exit 0"]
		stdout: StdioCollector { onStreamFinished: root.mixer = text.trim() }
	}
}
