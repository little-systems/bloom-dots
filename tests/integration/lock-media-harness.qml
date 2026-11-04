import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "modules/lock"

ShellRoot {
	QtObject {
		id: fake
		property bool hasMedia: true
		property bool isPlaying: true
		property string title: "Night Drive"
		property string artist: "Bloom Media Fixture"
		property string artUrl: ""
		property bool canPrevious: true
		property bool canNext: true
		property bool canToggle: true
		property real lengthMs: 240000
		property real positionMs: 45000
		property bool canSeek: true
		function seek(ms) { positionMs = ms; }
		property int skips: 0
		function previous() { skips--; }
		function next() { skips++; }
		function togglePlaying() { isPlaying = !isPlaying; }
	}
	QtObject {
		id: fakeAudio
		property var sink: ({})
		property real volume: 0.6
		property bool muted: false
		function setVolume(value) { volume = value; }
	}
	LockSurface {
		id: surface
		mediaSource: fake
		audioSource: fakeAudio
		pamConfig: "bloom-test"
		pamDir: Quickshell.env("BLOOM_TEST_PAM")
		clockTurning: false
		monitors: []
	}
	IpcHandler {
		target: "lockmedia"
		function lock(): string { surface.lock(); return "ok"; }
		function transport(action: string): string { surface.mediaAction(action); return "ok"; }
		function control(action: string, value: real): string { surface.mediaAction(action, value); return "ok"; }
		function enabled(value: bool): string { return Settings.set("bloom-lock-media-enabled", value) || "ok"; }
		function state(): string {
			return JSON.stringify({ locked: surface.locked, secure: surface.status().secure,
				available: surface.lockMedia.hasMedia, playing: fake.isPlaying, skips: fake.skips, position: fake.positionMs, volume: fakeAudio.volume });
		}
	}
}
