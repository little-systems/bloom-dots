import QtQuick
import Quickshell
import qs.services

// hypridle with Bloom's idle settings (scripts/idle.py), loaded with the lock
// module. It also answers `loginctl lock-session` (the session menu's Lock
// and the lock before sleep) by locking this lock screen.
SupervisedProcess {
	id: root
	backend: "idle"
	wanted: true
	readonly property var minutes: ["bloom-idle-lock", "bloom-idle-screen-off", "bloom-idle-sleep"]
		.map(key => String(Math.max(0, Math.round(Number(Settings.values[key]) || 0))))
	command: ["python3", Quickshell.shellPath("scripts/idle.py"), ...minutes]
	onMinutesChanged: root.restart()
}
