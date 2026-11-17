pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "agents.js" as Logic

// Agent live activities (docs/specs round 3, D; Bloom useAgentAlerts.ts and
// agent_alerts.rs at 63a9bf5). `bloom agent-hook` delivers events with
// `qs ipc call agents event <json>`; the queue lives in memory only, so a
// restart or turning alerts off clears it. The Island sets `blocked` while a
// panel, the shelf, a device alert or an announcement holds it.
Singleton {
	id: root

	readonly property bool enabled: Settings.values["bloom-agent-alerts-enabled"] !== false
	readonly property bool dnd: Settings.values["bloom-notifications-dnd"] === true
	property bool blocked: false
	property var state: Logic.EMPTY
	readonly property var active: root.blocked ? null : root.state.active
	readonly property bool hasEntries: root.state.entries.length > 0
	// Wall clock for elapsed time, ticking while an activity shows.
	property real now: Date.now()

	property var _order: ({})
	property var _owners: ({})

	function _dispatch(action) { root.state = Logic.reduce(root.state, action); }

	// One event from the hook; returns "ok", "off", "stale" or "invalid".
	function event(text) {
		const alert = Logic.parse(text);
		if (!alert)
			return "invalid";
		verified.save(Logic.verify(verified.value, alert.agent, Math.floor(Date.now() / 1000)));
		if (!root.enabled)
			return "off";
		if (alert.at !== undefined) {
			const r = Logic.ordered(root._order, alert.agent + ":" + alert.session, alert.at);
			root._order = r.order;
			if (r.stale)
				return "stale";
		}
		root._owners = Logic.track(root._owners, alert);
		root._dispatch({ type: "receive", alert: alert, now: Date.now() });
		return "ok";
	}

	// Settings' Test notch: the same path, without a hook or an owner.
	function test(agent, kind, activity) {
		const alert = { agent: agent, session: "bloom-preview", project: "Bloom preview", kind: kind };
		if (activity)
			alert.activity = activity;
		const parsed = Logic.parse(JSON.stringify(alert));
		if (!parsed) return "invalid";
		if (!root.enabled) return "off";
		root._dispatch({ type: "receive", alert: parsed, now: Date.now() });
		return "ok";
	}

	function dismiss() {
		if (root.state.active)
			root._dispatch({ type: "dismiss", entry: root.state.active });
	}

	onEnabledChanged: {
		if (!root.enabled) {
			root._dispatch({ type: "clear" });
			root._owners = {};
		}
	}

	StateFile {
		id: verified
		name: "agents"
		defaultValue: ({})
		validate: v => v !== null && typeof v === "object" && !Array.isArray(v) ? v : undefined
		maxBytes: 4096
	}

	Timer {
		interval: 30000
		repeat: true
		running: root.hasEntries
		onTriggered: root._dispatch({ type: "prune", now: Date.now() })
	}
	Timer {
		interval: 2000
		repeat: true
		triggeredOnStart: true
		running: Logic.canPresent({ enabled: root.enabled, blocked: root.blocked, dnd: root.dnd,
			hasEntries: root.hasEntries, active: !!root.state.active })
		onTriggered: root._dispatch({ type: "present", now: Date.now() })
	}
	// A finished activity holds the Island, then steps aside.
	Timer {
		interval: root.state.active?.session === "bloom-preview" && root.state.active?.kind === "working" ? 4000 : Logic.holdMs(root.state.active ? root.state.active.kind : "")
		running: !!root.state.active && (root.state.active.kind !== "working" || root.state.active.session === "bloom-preview") && !root.blocked
		onTriggered: {
			if (root.state.active.kind === "working") root.dismiss();
			else root._dispatch({ type: "finish" });
		}
	}
	Timer {
		interval: 1000
		repeat: true
		running: !!root.active
		onTriggered: root.now = Date.now()
		onRunningChanged: root.now = Date.now()
	}

	// A session ends when its agent process exits, even without an end hook
	// (a crash, a closed terminal); its start time catches a reused pid.
	Timer {
		interval: 3000
		repeat: true
		running: Object.keys(root._owners).length > 0
		onTriggered: if (!probe.running) {
			probe.command = ["sh", "-c", 'for p; do s=$(cat "/proc/$p/stat" 2>/dev/null) && echo "$p ${s##*) }"; done', "sh"].concat(Logic.pids(root._owners));
			probe.running = true;
		}
	}
	Process {
		id: probe
		stdout: StdioCollector { id: probeOut }
		onExited: {
			const r = Logic.takeEnded(root._owners, Logic.aliveFromStat(probeOut.text));
			root._owners = r.owners;
			for (const alert of r.ended)
				root._dispatch({ type: "receive", alert: alert, now: Date.now() });
		}
	}
}
