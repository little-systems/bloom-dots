import QtQuick
import Quickshell
import Quickshell.Io
import "../common/i18n"

Item {
	id: root
	visible: false
	property var integrations: []
	readonly property bool busy: job.running
	property string error: ""
	// The last finished action worth confirming: "preview" or "disconnected".
	property string message: ""
	property string messageAgent: ""

	function request(action, agent, kind) {
		if (job.running) return;
		root.error = "";
		if (action !== "status")
			root.message = "";
		if (action === "test") {
			job.command = ["qs", "-c", "bloom", "ipc", "call", "agents", "preview", agent, kind];
		} else {
			const base = [Quickshell.shellPath("../bin/bloom"), "agents", action];
			job.command = action === "status" ? base : base.concat([agent]);
		}
		job.action = action;
		job.agent = agent ?? "";
		job.running = true;
	}

	Process {
		id: job
		property string action
		property string agent
		stdout: StdioCollector { id: output }
		onExited: code => {
			if (job.action === "test") {
				if (code !== 0 || output.text.trim() !== "ok") root.error = I18n.t("linux.agents.previewFailed");
				else root.message = "preview";
				return;
			}
			let result;
			try { result = JSON.parse(output.text); } catch (_) {}
			if (code !== 0 || !result) {
				root.error = result?.error || I18n.t("linux.agents.requestFailed");
			} else if (job.action === "status") {
				root.integrations = result.integrations;
			} else {
				if (job.action === "disconnect") {
					root.message = "disconnected";
					root.messageAgent = job.agent;
				}
				Qt.callLater(() => root.request("status"));
			}
		}
	}
}
