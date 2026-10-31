pragma Singleton
import QtQuick
import Quickshell

// Bloom's chimes, from the desktop's own sound theme. Each has its own setting.
Singleton {
	id: root

	readonly property string _dir: "/usr/share/sounds/freedesktop/stereo/"
	readonly property bool _low: Battery.available && !Battery.pluggedIn && Battery.level <= Battery.threshold

	function _play(name) {
		Quickshell.execDetached(["pw-play", root._dir + name + ".oga"]);
	}
	// Once per drop to the alert level, as the notch's own warning.
	on_LowChanged: if (root._low && Settings.values["bloom-battery-sound-enabled"]) root._play("dialog-warning")

	Connections {
		target: CalendarState
		function onFinishedChanged() {
			if (CalendarState.finished && Settings.values["bloom-timer-sound-enabled"]) root._play("alarm-clock-elapsed");
		}
	}
}
