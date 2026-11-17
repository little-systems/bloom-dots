// Bloom-owned OpenCode 2.x plugin (Bloom integrations/opencode-bloom-v2.js at
// 63a9bf5, delivering through bloom agent-hook instead of HTTP). Send lifecycle metadata only.
import { spawn } from "node:child_process";
import { basename, normalize } from "node:path";

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
const events = {
	"session.execution.started": ["working", "thinking"],
	"session.execution.succeeded": ["ready"],
	"session.execution.failed": ["error"],
	"session.execution.interrupted": ["stopped"],
	"session.shell.started": ["working", "running"],
	"session.shell.ended": ["ready"],
	"session.tool.input.started": ["working"],
	"session.tool.success": ["working", "thinking"],
	"session.tool.failed": ["working", "thinking"],
	"session.retry.scheduled": ["working", "thinking"],
	"permission.asked": ["attention"],
	"permission.replied": ["working", "thinking"],
	"form.created": ["attention"],
	"form.replied": ["working", "thinking"],
	"form.cancelled": ["working", "thinking"],
	"session.deleted": ["stopped"]
};

function activityForTool(tool) {
	if (/^(edit|write|apply_patch|multiedit)$/.test(tool)) return "editing";
	if (/^(read|glob|grep|list)$/.test(tool)) return "reading";
	return tool === "bash" ? "running" : "thinking";
}

export default {
	id: "bloom.notifications",
	setup(ctx) {
		const controller = new AbortController();
		const directory = ctx.location.directory;
		const locationKey = normalize(directory).toLowerCase();
		const active = new Set();
		void (async () => {
			for await (const event of ctx.event.subscribe({
				types: Object.keys(events),
				signal: controller.signal
			})) {
				try {
					const transition = events[event.type];
					const session = event.type === "form.created"
						? event.data?.form?.sessionID
						: event.data?.sessionID;
					if (!transition || !session) continue;
					const eventDirectory = event.location?.directory;
					if (eventDirectory && normalize(eventDirectory).toLowerCase() !== locationKey) continue;

					if (event.type === "session.deleted") {
						if (!active.delete(session)) continue;
					} else {
						const result = await ctx.session.get({ sessionID: session });
						const info = result.data ?? result;
						if (!info || info.parentID) continue;
						const sessionDirectory = info.location?.directory;
						if (sessionDirectory && normalize(sessionDirectory).toLowerCase() !== locationKey) continue;
					}

					const [kind, defaultActivity] = transition;
					const activity = event.type === "session.tool.input.started"
						? activityForTool(event.data.name)
						: defaultActivity;
					if (kind === "working" || kind === "attention") active.add(session);
					else active.delete(session);

					await deliver({
						agent: "opencode",
						session,
						project: basename(directory),
						kind,
						...(activity ? { activity } : {})
					});
				} catch {
					/* Bloom is optional; never interrupt OpenCode. */
				}
			}
		})().catch(() => {});
		return () => controller.abort();
	}
};
