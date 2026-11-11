pragma Singleton

import QtQuick
import Quickshell

// JSON over HTTP GET for services (weather, city search). QML's
// XMLHttpRequest has no working timeout (`timeout`/`ontimeout` do nothing), so
// a server that accepts and never answers would stall a caller for good; a
// Timer ends the request instead. `done` runs exactly once, with the parsed
// JSON or null.
//
// Budgets: replies larger than `maxBytes` (default 256 KiB) are discarded.
// Remote requests must use HTTPS; plain HTTP is allowed only to this machine.
// A request with a `key` cancels the previous request with the same key, so
// a slow, stale answer can never overwrite a newer one.
Singleton {
	id: root

	property var _latest: ({})

	function allowed(url) {
		const s = String(url);
		return s.startsWith("https://") || /^http:\/\/(127\.0\.0\.1|localhost|\[::1\])(:\d+)?\//.test(s);
	}

	function get(url, done, timeoutMs, options) {
		const maxBytes = options?.maxBytes > 0 ? options.maxBytes : 262144;
		const key = options?.key || "";
		if (!root.allowed(url)) {
			console.warn("bloom http: refused a plaintext request to a remote host");
			done(null);
			return;
		}
		if (key && root._latest[key]) root._latest[key]();
		const xhr = new XMLHttpRequest();
		const watchdog = Qt.createQmlObject("import QtQuick; Timer {}", root);
		let finished = false;
		let cancel = null;
		const finish = json => {
			if (finished)
				return;
			finished = true;
			watchdog.stop();
			watchdog.destroy();
			if (key && root._latest[key] === cancel) {
				const next = Object.assign({}, root._latest);
				delete next[key];
				root._latest = next;
			}
			done(json);
		};
		// Aborting from inside the request's own callback crashes Qt; defer it.
		cancel = () => {
			finish(null);
			Qt.callLater(() => xhr.abort());
		};
		if (key) root._latest = Object.assign({}, root._latest, { [key]: cancel });
		watchdog.interval = timeoutMs > 0 ? timeoutMs : 10000;
		watchdog.triggered.connect(cancel);
		xhr.onreadystatechange = () => {
			if (finished)
				return;
			if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
				const length = Number(xhr.getResponseHeader("Content-Length"));
				if (length > maxBytes) { cancel(); return; }
			}
			if (xhr.readyState !== XMLHttpRequest.DONE)
				return;
			let json = null;
			if (xhr.status === 200 && xhr.responseText.length <= maxBytes) {
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
