// Pure, bounded notification history. Live QML objects and action handles are
// deliberately kept outside this model and never written to disk.
function text(value, fallback, maximum) {
	if (typeof value !== "string") return fallback;
	return value.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "").slice(0, maximum).trim();
}

function urgency(value) {
	if (value === 2 || String(value).toLowerCase() === "critical") return "critical";
	if (value === 0 || String(value).toLowerCase() === "low") return "low";
	return "normal";
}

function normalize(raw, now, session) {
	if (!raw || !Number.isInteger(raw.id) || raw.id <= 0 || raw.id > 2147483647) return null;
	return {
		key: String(session) + ":" + raw.id,
		id: raw.id,
		app: text(raw.appName, "Unknown app", 128) || "Unknown app",
		summary: text(raw.summary, "", 256),
		body: text(raw.body, "", 2048),
		time: Number.isFinite(now) ? now : 0,
		urgency: urgency(raw.urgency),
		read: false
	};
}

function ingest(history, raw, now, session, dnd, limit) {
	const item = normalize(raw, now, session);
	if (!item) return { history: history || [], popup: false, item: null };
	const transient = raw.transient === true || raw.hints?.transient === true;
	const popup = !dnd || item.urgency === "critical";
	if (transient) return { history: history || [], popup: popup, item: item };
	const next = [item].concat((history || []).filter(x => x.key !== item.key));
	return { history: next.slice(0, Math.max(1, Math.min(1000, limit || 200))), popup: popup, item: item };
}

function timeout(expireTimeout, defaultTimeout) {
	if (expireTimeout === 0) return 0;
	return Number.isFinite(expireTimeout) && expireTimeout > 0 ? Math.min(expireTimeout, defaultTimeout) : defaultTimeout;
}

function unread(history) { return (history || []).filter(x => !x.read).length; }

function close(history, key, reason) {
	const valid = ["expired", "dismissed", "closeRequested"];
	if (valid.indexOf(reason) < 0) return history;
	return (history || []).map(item => item.key === key && !item.closeReason
		? Object.assign({}, item, { closeReason: reason }) : item);
}

function groups(history) {
	const result = [];
	for (const item of history || []) {
		let group = result.find(g => g.app === item.app);
		if (!group) { group = { app: item.app, items: [] }; result.push(group); }
		group.items.push(item);
	}
	return result;
}

function cardViewport(screenHeight, scale, contentHeight) {
	return Math.max(0, Math.min(contentHeight, screenHeight - 72 * scale));
}

function restore(value, limit) {
	if (!value || !Array.isArray(value.entries)) return [];
	const items = [];
	for (const item of value.entries) {
		if (!item || typeof item !== "object" || typeof item.key !== "string"
			|| !Number.isInteger(item.id) || item.id <= 0 || typeof item.app !== "string"
			|| typeof item.summary !== "string" || typeof item.body !== "string"
			|| !Number.isFinite(item.time) || typeof item.urgency !== "string" || typeof item.read !== "boolean") continue;
		const restored = { key: text(item.key, "", 80), id: item.id, app: text(item.app, "Unknown app", 128),
			summary: text(item.summary, "", 256), body: text(item.body, "", 2048), time: item.time,
			urgency: urgency(item.urgency), read: item.read };
		if (["expired", "dismissed", "closeRequested"].indexOf(item.closeReason) >= 0)
			restored.closeReason = item.closeReason;
		items.push(restored);
	}
	return items.slice(0, Math.max(1, Math.min(1000, limit || 200)));
}

function action(live, id, identifier) {
	const notification = live?.[id];
	return notification?.actions?.find(a => a.identifier === identifier) ?? null;
}

function actionForKey(live, session, key, id, identifier) {
	return key === String(session) + ":" + id ? action(live, id, identifier) : null;
}

function safeImage(value) {
	if (typeof value !== "string" || value.length > 2048 || /[\u0000-\u001f]/.test(value)) return "";
	return value.startsWith("image://") || value.startsWith("file:///") ? value : "";
}
