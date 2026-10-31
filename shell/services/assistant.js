// The launcher's chat: messages to Gemini's shape, and what its helper prints
// back. Pure; Assistant.qml runs it.
var ERRORS = {
	"no-key": "Add your Gemini API key in Settings, under AI.",
	"bad-key": "Gemini didn't accept that key. Check it in Settings, under AI.",
	"bad-model": "That model isn't available on your key. Pick another in Settings, under AI.",
	"rate-limit": "Gemini's limit was reached. Try again in a moment.",
	"offline": "Couldn't reach Gemini. Check your connection.",
	"server": "Gemini had a problem. Try again."
};

function errorText(code) {
	return ERRORS[code] || ERRORS.server;
}

function contents(messages) {
	return messages.map(m => ({ role: m.role, parts: [{ text: m.text }] }));
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
function withDelta(messages, delta) {
	const last = messages[messages.length - 1];
	if (last && last.role === "model") return messages.slice(0, -1).concat([{ role: "model", text: last.text + delta }]);
	return messages.concat([{ role: "model", text: delta }]);
}
