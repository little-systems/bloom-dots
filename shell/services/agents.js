.pragma library

// Agent live activities (Bloom agentAlerts.ts and agent_alerts.rs at 63a9bf5).
// Events arrive from `bloom agent-hook` over IPC; nothing here touches disk.

var AGENTS = ["claude", "codex", "opencode"];
var KINDS = ["working", "ready", "attention", "error", "resolved", "stopped"];
var ACTIVITIES = ["thinking", "reading", "editing", "running", "working", "checking"];
var FIELDS = ["agent", "session", "project", "kind", "activity", "at", "pid", "started"];
var MAX_PAYLOAD = 4096;

var EMPTY = { entries: [], active: null };

// A validated event, or null (Bloom's AgentAlert::validate, unknown fields rejected).
function parse(text) {
	if (typeof text !== "string" || text.length > MAX_PAYLOAD)
		return null;
	var a;
	try { a = JSON.parse(text); } catch (e) { return null; }
	if (a === null || typeof a !== "object" || Array.isArray(a))
		return null;
	for (var key in a)
		if (FIELDS.indexOf(key) < 0)
			return null;
	if (AGENTS.indexOf(a.agent) < 0 || KINDS.indexOf(a.kind) < 0
		|| (a.activity !== undefined && ACTIVITIES.indexOf(a.activity) < 0)
		|| typeof a.session !== "string" || a.session.length === 0 || a.session.length > 256)
		return null;
	var project = Array.from(String(a.project || "")).filter(function (c) { return !/[\u0000-\u001f\u007f-\u009f]/.test(c); }).slice(0, 64).join("");
	var out = { agent: a.agent, session: a.session, project: project || "Agent session", kind: a.kind };
	if (a.activity !== undefined)
		out.activity = a.activity;
	for (var i = 0; i < 3; i++) {
		var n = ["at", "pid", "started"][i];
		if (typeof a[n] === "number" && isFinite(a[n]))
			out[n] = a[n];
	}
	return out;
}

// Background hooks can finish out of order: an event launched before one
// already seen for its session is stale (bounded to 512 sessions).
function ordered(order, key, at) {
	if (order[key] !== undefined && at < order[key])
		return { stale: true, order: order };
	var next = Object.assign({}, order);
	if (Object.keys(next).length >= 512 && next[key] === undefined)
		next = {};
	next[key] = at;
	return { stale: false, order: next };
}

function sameSession(a, b) { return a.agent === b.agent && a.session === b.session; }
function fresh(entry, now) { return now - entry.received < (entry.kind === "working" ? 86400000 : 600000); }

function reduce(state, action) {
	switch (action.type) {
	case "clear":
		return EMPTY;
	case "prune": {
		var kept = state.entries.filter(function (e) { return fresh(e, action.now); });
		return { entries: kept, active: state.active && kept.indexOf(state.active) >= 0 ? state.active : null };
	}
	case "receive": {
		var alert = action.alert, now = action.now;
		var previous = state.entries.filter(function (e) { return sameSession(e, alert); })[0];
		if (previous && previous.kind === alert.kind && previous.activity === alert.activity && now - previous.received < 2000)
			return state;
		var entries = state.entries.filter(function (e) { return !sameSession(e, alert) && fresh(e, now); });
		var continuing = previous && (previous.kind === "working" || previous.kind === "attention");
		var next = { agent: alert.agent, session: alert.session, project: alert.project, kind: alert.kind,
			received: now, started: continuing ? previous.started : now, shown: false };
		if (alert.activity !== undefined)
			next.activity = alert.activity;
		var removed = alert.kind === "resolved" || alert.kind === "stopped";
		if (!removed)
			entries.push(next);
		var active = state.active;
		if (active && sameSession(active, alert))
			active = removed ? null : next;
		else if (active && active.kind === "working" && !removed && alert.kind !== "working")
			active = next;
		var bounded = entries.slice(-12);
		return { entries: bounded, active: active && bounded.indexOf(active) >= 0 ? active : null };
	}
	case "present": {
		if (state.active)
			return state;
		var live = state.entries.filter(function (e) { return fresh(e, action.now); });
		var pick = live.filter(function (e) { return !e.shown && e.kind === "attention"; })[0]
			|| live.filter(function (e) { return !e.shown && e.kind !== "working"; })[0]
			|| live.filter(function (e) { return e.kind === "working"; })[0];
		return { entries: live, active: pick || null };
	}
	case "finish": {
		if (!state.active || state.active.kind === "working")
			return state;
		var shownEntries = [];
		state.entries.forEach(function (e) {
			if (e !== state.active)
				shownEntries.push(e);
			else if (e.kind === "attention")
				shownEntries.push(Object.assign({}, e, { shown: true }));
		});
		return { active: null, entries: shownEntries };
	}
	case "replay":
		return { entries: state.entries, active: action.entry };
	case "dismiss":
		return { entries: state.entries.filter(function (e) { return !sameSession(e, action.entry); }),
			active: state.active && sameSession(state.active, action.entry) ? null : state.active };
	}
	return state;
}

// How long a finished activity holds the Island before it steps aside.
function holdMs(kind) { return kind === "attention" ? 8000 : 4000; }

// Alerts wait while the Island is busy (a panel, the shelf, a device alert,
// an announcement) or Do Not Disturb is on.
function canPresent(s) { return s.enabled && !s.blocked && !s.dnd && s.hasEntries && !s.active; }

// Sessions whose agent process is known, keyed agent:session, so a session
// ends when its agent exits even if no end hook ran (at most 256).
function track(owners, alert) {
	var key = alert.agent + ":" + alert.session;
	var next = Object.assign({}, owners);
	if (alert.kind === "resolved" || alert.kind === "stopped") {
		delete next[key];
		return next;
	}
	if (typeof alert.pid !== "number" || typeof alert.started !== "number")
		return owners;
	if (Object.keys(next).length >= 256 && next[key] === undefined)
		return owners;
	next[key] = { alert: { agent: alert.agent, session: alert.session, project: alert.project, kind: "stopped" },
		pid: alert.pid, started: alert.started };
	return next;
}

// pid -> start time from lines of "<pid> <stat fields after comm>".
function aliveFromStat(text) {
	var alive = {};
	String(text).split("\n").forEach(function (line) {
		var f = line.trim().split(/\s+/);
		if (f.length > 20)
			alive[f[0]] = Number(f[20]);
	});
	return alive;
}

function takeEnded(owners, alive) {
	var next = {}, ended = [];
	for (var key in owners) {
		var o = owners[key];
		if (alive[String(o.pid)] === o.started)
			next[key] = o;
		else
			ended.push(o.alert);
	}
	return { owners: next, ended: ended };
}

function pids(owners) {
	return Object.keys(owners).map(function (k) { return String(owners[k].pid); });
}

// "Connected" is remembered from the first real event per agent (Unix seconds).
function verify(verified, agent, seconds) {
	if (verified[agent] !== undefined)
		return verified;
	var next = Object.assign({}, verified);
	next[agent] = seconds;
	return next;
}

function formatElapsed(started, now) {
	var seconds = Math.max(0, Math.floor((now - started) / 1000));
	return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
}

// Logo + status form one group; reserve a 24px gap before the elapsed time.
function activityWidth(statusWidth, elapsedWidth) {
	return Math.max(224, Math.ceil(32 + 20 + 8 + statusWidth + 24 + elapsedWidth));
}
