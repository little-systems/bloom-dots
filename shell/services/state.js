// UI state file parsing. Plain JS (shared with tests). State files are only
// written whole and atomically, so an empty file means damage.

function parse(text) {
	if (!text || !text.trim())
		return { ok: false, error: "file is empty" };
	try {
		return { ok: true, value: JSON.parse(text) };
	} catch (e) {
		return { ok: false, error: String(e.message || e) };
	}
}

function serialize(value) {
	return JSON.stringify(value, null, "\t") + "\n";
}
