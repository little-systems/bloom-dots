import QtQuick
import Quickshell
import qs.services

ShellRoot {
	property bool requested: false
	property bool afterReadback: false
	property bool externalSeen: false
	Timer {
		interval: 50
		repeat: true
		running: true
		onTriggered: {
			if (!requested && Brightness.available && Brightness.percent === 50) {
				console.log("RESULT initial=" + Brightness.device + ":" + Brightness.percent);
				requested = true;
				Brightness.setPercent(60);
			} else if (requested && !afterReadback && Brightness.percent === 60) {
				console.log("RESULT after=" + Brightness.percent);
				afterReadback = true;
				finish.restart();
			} else if (afterReadback && !externalSeen && Brightness.percent === 80) {
				console.log("RESULT external=" + Brightness.percent);
				externalSeen = true;
			}
		}
	}
	Timer { id: finish; interval: 2500; onTriggered: Qt.exit(externalSeen ? 0 : 1) }
	Timer { interval: 8000; running: true; onTriggered: Qt.exit(1) }
}
