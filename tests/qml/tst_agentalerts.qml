import QtQuick
import QtTest
import "../../shell/services/agents.js" as Agents

// Agent sessions (Bloom agentAlerts.ts and agent_alerts.rs at 63a9bf5).
TestCase {
	name: "AgentAlerts"

	function alert(kind, extra) {
		return Object.assign({ agent: "claude", session: "s1", project: "bloom", kind: kind }, extra || {});
	}
	function receive(state, a, now) { return Agents.reduce(state, { type: "receive", alert: a, now: now }); }

	function test_parseKeepsOnlyAllowListedValues() {
		const ok = Agents.parse(JSON.stringify({ agent: "codex", session: "t", project: "p\u0007q", kind: "working",
			activity: "running", at: 5, pid: 9, started: 3 }));
		compare(ok, { agent: "codex", session: "t", project: "pq", kind: "working", activity: "running", at: 5, pid: 9, started: 3 });
		compare(Agents.parse(JSON.stringify({ agent: "claude", session: "s", project: "", kind: "ready" })).project, "Agent session");
		for (const bad of [{ agent: "gemini", session: "s", project: "", kind: "ready" },
			{ agent: "claude", session: "s", project: "", kind: "bogus" },
			{ agent: "claude", session: "s", project: "", kind: "working", activity: "rm" },
			{ agent: "claude", session: "", project: "", kind: "ready" },
			{ agent: "claude", session: "s", project: "", kind: "ready", prompt: "secret" }])
			compare(Agents.parse(JSON.stringify(bad)), null, JSON.stringify(bad));
		compare(Agents.parse("not json"), null);
		compare(Agents.parse("x".repeat(5000)), null, "over 4 KiB");
	}

	function test_staleEventsAreDropped() {
		let order = {};
		let r = Agents.ordered(order, "claude:s1", 200);
		verify(!r.stale);
		r = Agents.ordered(r.order, "claude:s1", 100);
		verify(r.stale, "an older background hook can't overwrite a newer status");
		r = Agents.ordered(r.order, "claude:s1", 300);
		verify(!r.stale);
		verify(!Agents.ordered(r.order, "codex:s1", 1).stale, "per session");
	}

	function test_statusChangesKeepTheStartTime() {
		let s = receive(Agents.EMPTY, alert("working", { activity: "thinking" }), 1000);
		s = Agents.reduce(s, { type: "present", now: 1000 });
		compare(s.active.started, 1000);
		s = receive(s, alert("working", { activity: "editing" }), 5000);
		compare([s.active.activity, s.active.started], ["editing", 1000]);
		s = receive(s, alert("ready"), 9000);
		compare([s.active.kind, s.active.started, s.active.received], ["ready", 1000, 9000], "completion freezes at its own time");
		compare(Agents.holdMs(s.active.kind), 4000);
		compare(Agents.holdMs("attention"), 8000);
		s = Agents.reduce(s, { type: "finish" });
		compare([s.active, s.entries.length], [null, 0]);
		s = receive(s, alert("working"), 20000);
		s = Agents.reduce(s, { type: "present", now: 20000 });
		compare(s.active.started, 20000, "new work resets it");
	}

	function test_duplicatesWithinTwoSecondsAreIgnored() {
		let s = receive(Agents.EMPTY, alert("working", { activity: "reading" }), 1000);
		const again = receive(s, alert("working", { activity: "reading" }), 2500);
		verify(again === s);
	}

	function test_expiry() {
		let s = receive(Agents.EMPTY, alert("attention"), 0);
		s = receive(s, alert("working", { session: "s2" }), 0);
		s = Agents.reduce(s, { type: "prune", now: 600000 - 1 });
		compare(s.entries.length, 2);
		s = Agents.reduce(s, { type: "prune", now: 600000 });
		compare(s.entries.map(e => e.session), ["s2"], "finished and attention entries last 10 min");
		s = Agents.reduce(s, { type: "prune", now: 86400000 });
		compare(s.entries.length, 0, "working entries fall back to 24 h");
	}

	function test_stoppedClearsAndTheQueueIsBounded() {
		let s = receive(Agents.EMPTY, alert("working"), 0);
		s = Agents.reduce(s, { type: "present", now: 0 });
		s = receive(s, alert("stopped"), 10);
		compare([s.active, s.entries.length], [null, 0]);
		for (let i = 0; i < 20; i++)
			s = receive(s, alert("ready", { session: "s" + i }), 100 + i);
		compare(s.entries.length, 12);
		compare(Agents.reduce(s, { type: "clear" }), Agents.EMPTY);
	}

	function test_presentPrefersAttentionThenFinished() {
		let s = receive(Agents.EMPTY, alert("working", { session: "w" }), 0);
		s = receive(s, alert("ready", { session: "r" }), 1);
		s = receive(s, alert("attention", { session: "a" }), 2);
		compare(Agents.reduce(s, { type: "present", now: 3 }).active.session, "a");
	}

	function test_presentationWaits() {
		const base = { enabled: true, blocked: false, dnd: false, hasEntries: true, active: false };
		verify(Agents.canPresent(base));
		for (const key of ["blocked", "dnd", "active"])
			verify(!Agents.canPresent(Object.assign({}, base, { [key]: true })), key);
		verify(!Agents.canPresent(Object.assign({}, base, { enabled: false })));
		verify(!Agents.canPresent(Object.assign({}, base, { hasEntries: false })));
	}

	// "<pid> " + /proc/<pid>/stat after "(comm) ": starttime is the 20th field there.
	function stat(pid, started) { return pid + " S 1 " + "0 ".repeat(17) + started + " 0\n"; }

	function test_ownersClearEndedSessions() {
		let owners = Agents.track({}, alert("working", { pid: 500, started: 100 }));
		owners = Agents.track(owners, alert("working", { session: "s2" }));
		compare(Object.keys(owners), ["claude:s1"], "no owner, not tracked");
		const alive = Agents.aliveFromStat(stat(500, 100));
		let r = Agents.takeEnded(owners, alive);
		compare(r.ended.length, 0);
		r = Agents.takeEnded(owners, Agents.aliveFromStat(stat(500, 999)));
		compare(r.ended.map(a => [a.session, a.kind]), [["s1", "stopped"]], "a reused pid is not the agent");
		compare(Object.keys(r.owners), []);
		r = Agents.takeEnded(owners, Agents.aliveFromStat(""));
		compare(r.ended.length, 1, "an exited agent ends its session");
		compare(Object.keys(Agents.track(owners, alert("stopped"))), [], "stopped forgets the owner");
	}

	function test_elapsedAndWidth() {
		compare(Agents.formatElapsed(0, 65999), "1:05");
		compare(Agents.activityWidth(40, 30), 224);
		compare(Agents.activityWidth(120, 40), Math.ceil(32 + 20 + 8 + 120 + 24 + 40));
	}

	function test_verifiedRecordsTheFirstEventOnly() {
		const v = Agents.verify({}, "codex", 1700000000);
		compare(v, { codex: 1700000000 });
		verify(Agents.verify(v, "codex", 1800000000) === v);
	}
}
