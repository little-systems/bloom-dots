import QtQuick
import Quickshell
import qs.services

ShellRoot {
	property bool requested: false
	Timer {
		interval: 50
		repeat: true
		running: true
		onTriggered: {
			if (!requested && Brightness.available && Brightness.percent === 50) {
				console.log("RESULT initial=" + Brightness.device + ":" + Brightness.percent);
				requested = true;
				Brightness.setPercent(60);
			} else if (requested && Brightness.percent === 60) {
				console.log("RESULT after=" + Brightness.percent);
				Qt.exit(0);
			}
		}
	}
	Timer { interval: 4500; running: true; onTriggered: { console.log("RESULT timeout"); Qt.exit(1); } }
}
