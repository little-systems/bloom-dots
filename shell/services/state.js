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

// UTF-8 size of a string, without encoders that QML's JS engine lacks.
function utf8Bytes(text) {
	let bytes = 0;
	for (let i = 0; i < text.length; i++) {
		const c = text.charCodeAt(i);
		if (c < 0x80) bytes += 1;
		else if (c < 0x800) bytes += 2;
		else if (c >= 0xd800 && c <= 0xdbff && i + 1 < text.length) { bytes += 4; i++; }
		else bytes += 3;
	}
	return bytes;
}

// A document's checks in order: size budget, JSON, then the caller's shape.
// `validate` returns the (possibly normalized) value, or undefined if invalid.
// kind: "too-large" | "malformed" | "invalid".
function check(text, maxBytes, validate) {
	if (maxBytes > 0 && utf8Bytes(text || "") > maxBytes)
		return { ok: false, kind: "too-large", error: "larger than " + maxBytes + " bytes" };
	const r = parse(text);
	if (!r.ok)
		return { ok: false, kind: "malformed", error: r.error };
	return accept(r.value, validate);
}

function accept(value, validate) {
	if (typeof validate !== "function")
		return { ok: true, value: value };
	let shaped;
	try {
		shaped = validate(value);
	} catch (e) {
		shaped = undefined;
	}
	return shaped === undefined ? { ok: false, kind: "invalid", error: "unexpected shape" } : { ok: true, value: shaped };
}
