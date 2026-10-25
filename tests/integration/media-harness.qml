import QtQuick
import Quickshell
import qs.services

// Test harness for Media, run by tests/integration/test_media.sh with two
// fake players: "idle" (paused) and "busy" (playing). Prints RESULT lines.
ShellRoot {
	Component.onCompleted: Media.hold("harness", true)

	Timer {
		id: step1
		interval: 800
		running: true
		onTriggered: {
			console.log(`RESULT follows=${Media.title} playing=${Media.isPlaying} length=${Media.lengthMs} canSeek=${Media.canSeek}`);
			Media.seek(42000);
			Media.next();
			Media.togglePlaying();
			step2.start();
		}
	}

	Timer {
		id: step2
		interval: 800
		onTriggered: {
			console.log(`RESULT after title=${Media.title} playing=${Media.isPlaying} position>=42=${Media.positionMs >= 42000}`);
			Qt.exit(0);
		}
	}
}
