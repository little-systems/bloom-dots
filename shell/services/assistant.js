// The launcher's chat: messages to Gemini's shape, and what its helper prints
// back. Pure; Assistant.qml runs it.
var ERRORS = {
	"no-key": "Add your Gemini API key in Settings, under AI.",
	"bad-key": "Gemini didn't accept that key. Check it in Settings, under AI.",
	"bad-model": "That model isn't available on your key. Pick another in Settings, under AI.",
	"rate-limit": "Gemini's limit was reached. Try again in a moment.",
	"offline": "Couldn't reach Gemini. Check your connection.",
	"server": "Gemini had a problem. Try again.",
	"too-long": "The answer was too long and was cut off.",
	"timeout": "Gemini took too long to answer. Try again."
};

function errorText(code) {
	return ERRORS[code] || ERRORS.server;
}

// Request budget: only the newest history that fits is sent, starting on a
// user turn (the API expects that); the newest message is always included.
var HISTORY_BYTES = 48 * 1024;

function contents(messages) {
	const all = messages.map(m => ({ role: m.role, parts: [{ text: m.text }] }));
	let start = all.length, size = 0;
	while (start > 0) {
		const next = JSON.stringify(all[start - 1]).length;
		if (start < all.length && size + next > HISTORY_BYTES) break;
		size += next;
		start--;
	}
	while (start < all.length - 1 && all[start].role !== "user") start++;
	return all.slice(start);
}

function parseLine(line) {
	try {
		return JSON.parse(line);
	} catch (e) {
		return {};
	}
}

function checkText(output) {
	const reply = parseLine(output.trim());
	if (reply.ok) return "The key works";
	return errorText(reply.error);
}

// Adds a piece of the reply, starting the reply if this is the first.
function withDelta(messages, delta, id) {
	const last = messages[messages.length - 1];
	if (last && last.role === "model") return messages.slice(0, -1).concat([Object.assign({}, last, { text: last.text + delta })]);
	const next = { role: "model", text: delta };
	if (id) next.id = id;
	return messages.concat([next]);
}

function retryTurn(messages) {
	for (let i = messages.length - 1; i >= 0; i--)
		if (messages[i].role === "user") return { before: messages.slice(0, i), text: messages[i].text };
	return null;
}
