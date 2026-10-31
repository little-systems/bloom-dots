pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/launcher/launcher.js" as Logic

// The launcher's results and actions: apps, clipboard (cliphist), emoji,
// calculator (qalc), shell commands, web search and user actions (scripts in
// ~/.config/bloom/actions). Tools run bounded, only while it is open.
Singleton {
	id: root

	property bool opened: false
	property var results: []
	property string query: ""
	readonly property var _parsed: Logic.parse(root.query)
	property var _clips: []
	property var _actions: []

	function show() { root.opened = true; root.setQuery(""); }
	function hide() { root.opened = false; }
	function toggle() { if (root.opened) root.hide(); else root.show(); }

	function setQuery(text) {
		root.query = text;
		root._refresh();
	}
	function _refresh() {
		const q = root._parsed;
		if (q.mode === "apps") root.results = Logic.rank(Apps.all(), q.term).slice(0, 50).map(a => ({
			id: a.id, name: a.name, sub: "", icon: a.icon, glyph: "", action: { kind: "app", value: a.id } }));
		else if (q.mode === "emoji") root.results = Logic.emoji(q.term);
		else if (q.mode === "command") root.results = Logic.commandRow(q.term);
		else if (q.mode === "web") root.results = Logic.webRow(q.term);
		else if (q.mode === "clipboard") { root._showClips(); if (!clips.running) clips.running = true; }
		else if (q.mode === "actions") { root._showActions(); if (!actions.running) actions.running = true; }
		else if (q.mode === "calc") calcDelay.restart();
	}
	function _showClips() {
		root.results = Logic.filterClips(root._clips, root._parsed.term).slice(0, 50).map(e => ({
			id: e.id, name: e.text, sub: "", icon: "", glyph: "", action: { kind: "clip", value: e.raw } }));
	}
	function _showActions() {
		root.results = Logic.rank(root._actions, root._parsed.term).map(a => ({
			id: a.id, name: a.name, sub: "Your action", icon: "", glyph: "!", action: { kind: "action", value: a.path } }));
	}

	// Enter on a result: it runs, and the launcher closes.
	function accept(item) {
		const a = item && item.action;
		if (!a) return "nothing to do";
		root.hide();
		if (a.kind === "app") Apps.launch(a.value);
		else if (a.kind === "copy") Quickshell.execDetached(["wl-copy", "--", a.value]);
		else if (a.kind === "clip") Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", a.value]);
		else if (a.kind === "command") Apps.run(["sh", "-c", a.value], "launcher-command", false, Quickshell.env("HOME"));
		else if (a.kind === "url") Quickshell.execDetached(["xdg-open", a.value]);
		else if (a.kind === "action") Apps.run([a.value], "launcher-action", false, Quickshell.env("HOME"));
		return "ok";
	}

	Timer {
		id: calcDelay
		interval: 150
		onTriggered: {
			const term = root._parsed.term;
			if (!term) { root.results = []; return; }
			// A leading space keeps a "-3" from reading as an option.
			calc.term = term;
			calc.command = ["timeout", "-k", "1s", "2s", "qalc", "-t", " " + term];
			if (!calc.running) calc.running = true;
		}
	}
	Process {
		id: calc
		property string term: ""
		stdout: StdioCollector { id: calcOut }
		onExited: code => {
			if (root._parsed.mode === "calc" && root._parsed.term === term)
				root.results = Logic.calcRow(term, code === 0 ? calcOut.text.trim() : "");
		}
	}
	Process {
		id: clips
		command: ["timeout", "-k", "1s", "3s", "cliphist", "list"]
		stdout: StdioCollector { id: clipsOut }
		onExited: code => {
			root._clips = code === 0 ? Logic.clipEntries(clipsOut.text) : [];
			if (root._parsed.mode === "clipboard") root._showClips();
		}
	}
	Process {
		id: actions
		command: ["find", (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/bloom/actions", "-maxdepth", "1", "-type", "f", "-executable"]
		stdout: StdioCollector { id: actionsOut }
		onExited: {
			root._actions = actionsOut.text.split("\n").filter(p => p).map(p => ({ id: p, path: p, name: p.split("/").pop() }));
			if (root._parsed.mode === "actions") root._showActions();
		}
	}
}
