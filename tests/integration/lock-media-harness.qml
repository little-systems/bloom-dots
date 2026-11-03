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
		property int skips: 0
		function previous() { skips--; }
		function next() { skips++; }
		function togglePlaying() { isPlaying = !isPlaying; }
	}
	LockSurface {
		id: surface
		mediaSource: fake
		pamConfig: "bloom-test"
		pamDir: Quickshell.env("BLOOM_TEST_PAM")
		clockTurning: false
		monitors: []
	}
	IpcHandler {
		target: "lockmedia"
		function lock(): string { surface.lock(); return "ok"; }
		function transport(action: string): string { surface.mediaAction(action); return "ok"; }
		function enabled(value: bool): string { return Settings.set("bloom-lock-media-enabled", value) || "ok"; }
		function state(): string {
			return JSON.stringify({ locked: surface.locked, secure: surface.status().secure,
				available: surface.lockMedia.hasMedia, playing: fake.isPlaying, skips: fake.skips });
		}
	}
}
