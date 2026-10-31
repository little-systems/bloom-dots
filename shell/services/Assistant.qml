pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "assistant.js" as Logic

// Gemini chat for Spotlight. Only what's typed in chat is sent, and the
// conversation lives in memory: it goes when the shell does.
Singleton {
	id: root

	property var messages: []
	property bool busy: false
	property string error: ""
	property bool _cancelled: false
	property int _sequence: 0
	function _id() { return "turn-" + (++root._sequence); }

	function checkText(output) { return Logic.checkText(output); }
	function clear() {
		root.stop();
		root.messages = [];
		root.error = "";
	}
	function ask(text) {
		if (root.busy || text.trim() === "") return;
		root.error = "";
		root._cancelled = false;
		root.messages = root.messages.concat([{ id: root._id(), role: "user", text: text.trim() }]);
		root.busy = true;
		proc.stdinEnabled = true;
		proc.running = true;
	}

	function stop() {
		if (!root.busy) return;
		root._cancelled = true;
		proc.running = false;
	}
	function retry() {
		if (root.busy) return;
		const turn = Logic.retryTurn(root.messages);
		if (!turn) return;
		root.messages = turn.before;
		root.ask(turn.text);
	}

	Process {
		id: proc
		command: ["python3", Quickshell.shellPath("scripts/assistant.py")]
		stdinEnabled: true
		onStarted: {
			proc.write(JSON.stringify({ model: Settings.values["bloom-ai-model"], contents: Logic.contents(root.messages) }));
			proc.stdinEnabled = false;
		}
		stdout: SplitParser {
			onRead: line => {
				if (root._cancelled) return;
				const event = Logic.parseLine(line);
				if (event.delta) root.messages = Logic.withDelta(root.messages, event.delta, root._id());
				if (event.error) root.error = Logic.errorText(event.error);
			}
		}
		onExited: code => {
			root.busy = false;
			if (!root._cancelled && code !== 0 && root.error === "") root.error = Logic.errorText("server");
		}
	}
}
