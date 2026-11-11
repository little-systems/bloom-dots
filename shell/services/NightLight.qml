pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light, through hyprsunset: it runs only while the setting is on, and
// changing the warmth restarts it.
Singleton {
	id: root

	readonly property bool wanted: Settings.values["bloom-night-light"]
	readonly property int temperature: Settings.values["bloom-night-temperature"]

	SupervisedProcess {
		id: sunset
		backend: "night-light"
		wanted: root.wanted
		command: ["hyprsunset", "-t", String(root.temperature)]
		onCommandChanged: if (running) sunset.restart()
	}
}
