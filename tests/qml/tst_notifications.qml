import QtQuick
import QtTest
import "../../shell/modules/notifications/notifications.js" as N

TestCase {
	name: "NotificationRules"

	function test_replaceAndBoundHistory() {
		let h = [];
		h = N.ingest(h, { id: 7, appName: "Mail", summary: "first" }, 100, "s1", false, 2).history;
		h = N.ingest(h, { id: 7, appName: "Mail", summary: "updated" }, 101, "s1", false, 2).history;
		compare(h.length, 1);
		compare(h[0].summary, "updated");
		h = N.ingest(h, { id: 8, appName: "Chat", summary: "next" }, 102, "s1", false, 2).history;
		h = N.ingest(h, { id: 9, appName: "Music", summary: "third" }, 103, "s1", false, 2).history;
		compare(h.map(x => x.key), ["s1:9", "s1:8"]);
	}

	function test_dndCriticalAndTransient() {
		const normal = N.ingest([], { id: 1, appName: "Mail", summary: "Hi" }, 100, "s", true, 200);
		compare(normal.popup, false);
		compare(normal.history.length, 1);
		compare(N.unread(normal.history), 1);
		const critical = N.ingest([], { id: 2, urgency: "critical", summary: "Alert" }, 100, "s", true, 200);
		compare(critical.popup, true);
		const transient = N.ingest([], { id: 3, transient: true, summary: "secret" }, 100, "s", false, 200);
		compare(transient.popup, true);
		compare(transient.history, []);
	}

	function test_timeoutAndGrouping() {
		compare(N.timeout(0, 7000), 0);
		compare(N.timeout(-1, 7000), 7000);
		compare(N.timeout(2000, 7000), 2000);
		const h = [
			{ key: "s:3", app: "Mail", time: 300 },
			{ key: "s:2", app: "Chat", time: 200 },
			{ key: "s:1", app: "Mail", time: 100 }
		];
		compare(N.groups(h).map(g => [g.app, g.items.length]), [["Mail", 2], ["Chat", 1]]);
	}

	function test_malformedInputAndReload() {
		const r = N.ingest([], { id: 5, appName: null, summary: "<b>hello</b>\u0000", body: "x".repeat(5000), hints: { transient: "false" } }, 10, "s", false, 200);
		compare(r.history[0].summary, "<b>hello</b>");
		compare(r.history[0].body.length, 2048);
		compare(r.history[0].app, "Unknown app");
		verify(!Object.prototype.hasOwnProperty.call(r.history[0], "actions"));
		compare(N.restore({ entries: r.history }, 200), r.history);
		compare(N.restore({ entries: [{ key: "x", actions: [{ invoke: "bad" }] }] }, 200), []);
	}

	function test_actionsNeedLiveHandle() {
		const live = { 7: { actions: [{ identifier: "open", invoke: () => 42 }] } };
		verify(N.action(live, 7, "open") !== null);
		compare(N.action(live, 7, "wrong"), null);
		compare(N.action({}, 7, "open"), null);
	}
}
