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

	function test_probeKeepsOwnersAddedOrReplacedWhileItRuns() {
		const sampled = Agents.track({}, alert("working", { pid: 500, started: 100 }));
		let current = Agents.track(sampled, alert("working", { session: "s2", pid: 600, started: 200 }));
		let result = Agents.takeEnded(current, {}, sampled);
		compare(result.ended.map(a => a.session), ["s1"]);
		compare(Object.keys(result.owners), ["claude:s2"]);
		current = Agents.track(sampled, alert("working", { pid: 700, started: 300 }));
		result = Agents.takeEnded(current, {}, sampled);
		compare(result.ended.length, 0, "a replaced owner was never sampled");
		compare(result.owners, current);
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

	// Bloom's .agent-activity-status shimmer: a 250%-wide gradient whose
	// bright centre sweeps the label between 16% and 66% of each period.
	function test_shimmerFollowsTheActivity() {
		compare(Agents.shimmer("thinking"), { periodMs: 4800, half: 0.25 });
		compare(Agents.shimmer("editing"), { periodMs: 3200, half: 0.1 });
		compare(Agents.shimmer("reading"), { periodMs: 4000, half: 0.15 });
		compare(Agents.shimmer("running"), { periodMs: 3800, half: 0.25 });
		compare(Agents.shimmer("working"), { periodMs: 5200, half: 0.25 });
		compare(Agents.shimmer("checking"), { periodMs: 5200, half: 0.25 });
	}

	function test_parseKeepsAPlainTranscriptPath() {
		const base = { agent: "claude", session: "s", project: "p", kind: "working" };
		compare(Agents.parse(JSON.stringify(Object.assign({ transcript: "/h/.claude/projects/p/s.jsonl" }, base))).transcript,
			"/h/.claude/projects/p/s.jsonl");
		for (const bad of ["rel/s.jsonl", "/h/s.json", "/h/../s.jsonl", "/h/a\nb.jsonl", "/" + "a".repeat(1100) + ".jsonl", 5])
			compare(Agents.parse(JSON.stringify(Object.assign({ transcript: bad }, base))), null, String(bad));
	}

	function test_transcriptsFollowSessions() {
		let t = Agents.follow({}, alert("working", { transcript: "/h/s1.jsonl" }));
		t = Agents.follow(t, alert("working", { session: "s2" }));
		compare(t, { "claude:s1": "/h/s1.jsonl" }, "no path, not followed");
		compare(Agents.follow(t, alert("working")), t, "a later event without a path keeps it");
		compare(Agents.follow(t, alert("ready")), t, "a finished turn keeps it for the next one");
		compare(Agents.follow(t, alert("stopped")), {}, "an ended session forgets it");
	}

	// Working sessions that have been silent long enough to check their transcript.
	function test_quietWorkingSessions() {
		let s = receive(Agents.EMPTY, alert("working"), 1000);
		s = receive(s, alert("ready", { session: "s2" }), 1000);
		s = receive(s, alert("working", { session: "s3" }), 1000);
		const t = { "claude:s1": "/h/s1.jsonl", "claude:s2": "/h/s2.jsonl" };
		compare(Agents.quiet(s, t, 5999).length, 0, "not yet");
		const q = Agents.quiet(s, t, 6000);
		compare(q.map(c => [c.entry.session, c.path]), [["s1", "/h/s1.jsonl"]], "working, with a path, silent 5 s");
		verify(q[0].entry === s.entries[0]);
	}

	function line(o) { return JSON.stringify(o) + "\n"; }
	function user(content) { return line({ type: "user", message: { role: "user", content: content } }); }
	function test_turnEndedReadsTheLastEntry() {
		const prompt = user("make it persistent");
		const tool = line({ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash" }] } });
		const noise = line({ type: "queue-operation" }) + line({ type: "file-history-snapshot" }) + line({ type: "pr-link" })
			+ line({ type: "attachment" }) + line({ type: "system", subtype: "informational" });
		compare(Agents.turnEnded(prompt + tool + user([{ type: "text", text: "[Request interrupted by user]" }])), "stopped");
		compare(Agents.turnEnded(prompt + user("[Request interrupted by user for tool use]") + noise), "stopped",
			"bookkeeping after the marker is skipped");
		compare(Agents.turnEnded(prompt + tool + line({ type: "system", subtype: "stop_hook_summary" })), "ready");
		compare(Agents.turnEnded(prompt + tool + noise), "", "still working");
		compare(Agents.turnEnded(line({ type: "system", subtype: "stop_hook_summary" }) + prompt), "", "a new turn began");
		compare(Agents.turnEnded(user("[Request interrupted by user] is what I typed")), "", "only the marker itself");
		compare(Agents.turnEnded('ted by user]"}]}}\n' + prompt), "", "a cut first line is ignored");
		compare(Agents.turnEnded(""), "");
		compare(Agents.turnEnded("garbage"), "");
	}

	function test_splitTails() {
		compare(Agents.splitTails("\u001e\na\nb\n\u001e\n\u001e\nc\n"), ["a\nb\n", "", "c\n"]);
	}
}
