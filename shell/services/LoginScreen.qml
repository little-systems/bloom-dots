import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the Bloom login screen showing this wallpaper, in the lock screen's
// colours and scale. A second after the last change the state goes to
// scripts/login-state.py, which does nothing unless the installer made the
// login folder and this user may write to it.
Scope {
	id: root

	readonly property string request: JSON.stringify({
		wallpaper: Wallpaper.path,
		zoom: Wallpaper.zoom,
		accent: String(Theme.accent),
		bgExpanded: String(Theme.bgExpanded),
		text: String(Theme.text),
		textMuted: String(Theme.textMuted),
		border: String(Theme.border),
		groupBg: String(Theme.groupBg),
		scale: Number(Settings.values["bloom-scale"]) || 1
	})
	onRequestChanged: settle.restart()

	Timer {
		id: settle
		interval: 1000
		onTriggered: {
			if (writer.running) settle.restart();
			else writer.running = true;
		}
	}
	Process {
		id: writer
		command: ["python3", Quickshell.shellPath("scripts/login-state.py")]
		stdinEnabled: true
		onStarted: { writer.write(root.request); writer.stdinEnabled = false; }
		onExited: writer.stdinEnabled = true
	}
}
