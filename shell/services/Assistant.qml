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

	function checkText(output) { return Logic.checkText(output); }
	function clear() {
		root.messages = [];
		root.error = "";
	}
	function ask(text) {
		if (root.busy || text.trim() === "") return;
		root.error = "";
		root.messages = root.messages.concat([{ role: "user", text: text.trim() }]);
		root.busy = true;
		proc.stdinEnabled = true;
		proc.running = true;
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
				const event = Logic.parseLine(line);
				if (event.delta) root.messages = Logic.withDelta(root.messages, event.delta);
				if (event.error) root.error = Logic.errorText(event.error);
			}
		}
		onExited: code => {
			root.busy = false;
			if (code !== 0 && root.error === "") root.error = Logic.errorText("server");
		}
	}
}
