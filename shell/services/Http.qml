pragma Singleton

import QtQuick
import Quickshell

// JSON over HTTP GET for services (weather). QML's XMLHttpRequest has no
// working timeout (`timeout`/`ontimeout` do nothing), so a server that
// accepts and never answers would stall a caller for good; a Timer ends the
// request instead. `done` runs exactly once, with the parsed JSON or null.
Singleton {
	id: root

	function get(url, done, timeoutMs) {
		const xhr = new XMLHttpRequest();
		const watchdog = Qt.createQmlObject("import QtQuick; Timer {}", root);
		let finished = false;
		const finish = json => {
			if (finished)
				return;
			finished = true;
			watchdog.stop();
			watchdog.destroy();
			done(json);
		};
		watchdog.interval = timeoutMs > 0 ? timeoutMs : 10000;
		watchdog.triggered.connect(() => {
			finish(null);
			xhr.abort();
		});
		xhr.onreadystatechange = () => {
			if (xhr.readyState !== XMLHttpRequest.DONE)
				return;
			let json = null;
			if (xhr.status === 200) {
				try {
					json = JSON.parse(xhr.responseText);
				} catch (e) {
					json = null;
				}
			}
			finish(json);
		};
		watchdog.start();
		try {
			xhr.open("GET", url);
			xhr.send();
		} catch (e) {
			finish(null);
		}
	}
}
