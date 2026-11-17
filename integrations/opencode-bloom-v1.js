// Bloom-owned OpenCode 1.x plugin (Bloom integrations/opencode-bloom.js at
// 63a9bf5, delivering through bloom agent-hook instead of HTTP). No prompts, tool arguments or output are sent.
import { spawn } from "node:child_process";
import { basename } from "node:path";
const hook = "__BLOOM_HOOK__";

// Hands one event to Bloom (bloom agent-hook opencode-event): it reaches the
// running shell, or nothing happens. Never waits more than 3 s.
function deliver(payload) {
	return new Promise((resolve) => {
		try {
			const child = spawn(hook, ["agent-hook", "opencode-event"], { stdio: ["pipe", "ignore", "ignore"] });
			const timer = setTimeout(() => child.kill(), 3000);
			const done = () => { clearTimeout(timer); resolve(); };
			child.on("error", done);
			child.on("close", done);
			child.stdin.on("error", () => {});
			child.stdin.end(JSON.stringify(payload));
		} catch {
			resolve();
		}
	});
}

export const BloomNotifications = async ({ directory, client }) => {
	const children = new Set();
	const toolActivity = (tool) =>
		/^(edit|write|apply_patch|multiedit)$/.test(tool)
			? "editing"
			: /^(read|glob|grep|list)$/.test(tool)
				? "reading"
				: tool === "bash"
					? "running"
					: "thinking";
	const send = async (session, kind, activity) => {
		try {
			if (!kind || !session || children.has(session)) return;
			const result = await client.session.get({ path: { id: session } });
			if (result.data?.parentID) {
				children.add(session);
				return;
			}
			await deliver({
				agent: "opencode",
				session,
				project: basename(directory),
				kind,
				...(activity ? { activity } : {})
			});
		} catch {
			/* Bloom is optional; never interrupt an agent. */
		}
	};
	return {
		"tool.execute.before": async (input) =>
			send(input.sessionID, "working", toolActivity(input.tool)),
		"tool.execute.after": async (input) => send(input.sessionID, "working", "thinking"),
		event: async ({ event }) => {
			const info = event.properties?.info;
			if (event.type === "session.created" && info?.parentID) children.add(info.id);
			if (event.type === "session.deleted") {
				await send(info?.id, "stopped");
				children.delete(info?.id);
				return;
			}
			const kind =
				{
					"session.idle": "ready",
					"permission.asked": "attention",
					"permission.replied": "working",
					"question.asked": "attention",
					"question.replied": "working",
					"question.rejected": "working",
					"session.error": "error"
				}[event.type] ??
				(event.type === "session.status" &&
				["busy", "retry"].includes(event.properties?.status?.type)
					? "working"
					: undefined);
			await send(event.properties?.sessionID, kind, kind === "working" ? "thinking" : undefined);
		}
	};
};
