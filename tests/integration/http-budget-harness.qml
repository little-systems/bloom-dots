import QtQuick
import Quickshell
import qs.services

// Response budgets, plaintext refusal and latest-query cancellation for
// Http, run by tests/integration/test_http.sh. Prints RESULT lines.
ShellRoot {
	id: root
	property var results: ({})
	readonly property string base: `http://127.0.0.1:${Quickshell.env("BLOOM_TEST_WEB_PORT")}`
	readonly property string hang: `http://127.0.0.1:${Quickshell.env("BLOOM_TEST_PORT")}/`

	function record(name, value) {
		const next = Object.assign({}, root.results);
		next[name] = value;
		root.results = next;
		if (Object.keys(next).length === 5) {
			console.log(`RESULT small=${next.small} big=${next.big} plaintext=${next.plaintext} superseded=${next.superseded} latest=${next.latest}`);
			Qt.exit(0);
		}
	}

	Timer {
		interval: 200
		running: true
		onTriggered: {
			Http.get(root.base + "/small", json => root.record("small", json?.ok === true), 3000);
			Http.get(root.base + "/big", json => root.record("big", json === null), 3000, { maxBytes: 4096 });
			const started = Date.now();
			Http.get("http://weather.example.invalid/json", json => root.record("plaintext", json === null && Date.now() - started < 200), 3000);
			const first = Date.now();
			Http.get(root.hang, json => root.record("superseded", json === null && Date.now() - first < 300), 3000, { key: "city" });
			Http.get(root.base + "/small", json => root.record("latest", json?.ok === true), 3000, { key: "city" });
		}
	}

	Timer { interval: 8000; running: true; onTriggered: { console.log("RESULT budget never finished " + JSON.stringify(root.results)); Qt.exit(1); } }
}
