import QtQuick
import Quickshell
import qs.services

// Test harness for Http, run by tests/integration/test_http.sh. A server that
// accepts and never replies must still end the request (with null) once the
// timeout passes, so callers like Weather can't stall for good.
ShellRoot {
	Timer {
		interval: 200
		running: true
		onTriggered: {
			const port = Quickshell.env("BLOOM_TEST_PORT");
			const started = Date.now();
			let calls = 0;
			Http.get(`http://127.0.0.1:${port}/`, json => {
				calls++;
				console.log(`RESULT hang json=${JSON.stringify(json)} ms=${Date.now() - started} calls=${calls}`);
				done.restart();
			}, 500);
		}
	}

	// Give a late second callback a chance to show up before exiting.
	Timer {
		id: done
		interval: 700
		onTriggered: Qt.exit(0)
	}

	Timer {
		interval: 8000
		running: true
		onTriggered: {
			console.log("RESULT hang never finished");
			Qt.exit(1);
		}
	}
}
