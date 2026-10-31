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
	}
	IpcHandler {
		target: "lock"
		function lock(): string { surface.lock(); return "ok"; }
		function state(): string { return JSON.stringify(surface.status()); }
	}
}
