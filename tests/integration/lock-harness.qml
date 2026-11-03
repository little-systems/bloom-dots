import QtQuick
import Quickshell
import Quickshell.Io
import "modules/lock"

// The real lock surface against a fixture PAM directory (test_lock.sh).
ShellRoot {
	LockSurface {
		id: surface
		pamConfig: "bloom-test"
		pamDir: Quickshell.env("BLOOM_TEST_PAM")
		clockTurning: false
		mediaSource: null
		monitors: [{ name: "HEADLESS-1", activeWorkspace: { id: 3 } }]
	}
	IpcHandler {
		target: "lock"
		function lock(): string { surface.lock(); return "ok"; }
		function state(): string { return JSON.stringify(surface.status()); }
	}
}
