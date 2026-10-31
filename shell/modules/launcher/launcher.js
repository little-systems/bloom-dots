.import "emoji-data.js" as Data

// The launcher's rules: its prefixes (the owner's, 2026-10-31), app ranking
// and result shapes. Pure; services run the tools.
var PREFIXES = { ";": "clipboard", ":": "emoji", "=": "calc", ">": "command", "?": "web", "!": "actions" };

function parse(text) {
	const t = String(text || "").trim();
	const mode = PREFIXES[t.charAt(0)];
	return mode ? { mode: mode, term: t.slice(1).trim() } : { mode: "apps", term: t };
}

// 0 is the best match; -1 is a miss.
function _score(name, term) {
	const n = name.toLowerCase();
	if (n === term) return 0;
	if (n.startsWith(term)) return 1;
	if (n.split(/[\s\-_.]+/).some(word => word.startsWith(term))) return 2;
	if (n.includes(term)) return 3;
	let at = 0;
	for (const c of n) if (c === term[at]) at++;
	return at === term.length ? 4 : -1;
}

function rank(items, term) {
	const t = String(term || "").toLowerCase();
	const byName = (a, b) => a.name.localeCompare(b.name);
	if (!t) return items.slice().sort(byName);
	return items.map(item => ({ item, score: _score(item.name, t) }))
		.filter(r => r.score >= 0)
		.sort((a, b) => a.score - b.score || byName(a.item, b.item))
		.map(r => r.item);
}

function webUrl(term) {
	return "https://www.google.com/search?q=" + encodeURIComponent(term);
}

// `cliphist list`, one "<id>\t<preview>" a line. `raw` is what `cliphist
// decode` takes back.
function clipEntries(text) {
	const out = [];
	for (const line of String(text || "").split("\n")) {
		const tab = line.indexOf("\t");
		if (tab > 0) out.push(Object.assign({ id: line.slice(0, tab), text: line.slice(tab + 1), raw: line }, classifyClip(line.slice(tab + 1))));
	}
	return out;
}

function filterClips(entries, term) {
	const t = String(term || "").toLowerCase();
	return t ? entries.filter(e => e.text.toLowerCase().includes(t)) : entries;
}

// Emoji by name; Enter copies one.
function emoji(term) {
	const t = String(term || "").toLowerCase();
	const hits = t ? Data.EMOJI.filter(e => e[1].toLowerCase().includes(t)) : Data.EMOJI;
	// Start-of-name matches first, shortest name first among them.
	const sorted = t ? hits.slice().sort((a, b) => Number(b[1].toLowerCase().startsWith(t)) - Number(a[1].toLowerCase().startsWith(t))
		|| a[1].length - b[1].length) : hits;
	return sorted.slice(0, 60).map(e => ({ id: e[0], name: e[1], sub: "", icon: "", glyph: e[0], action: { kind: "copy", value: e[0] } }));
}

function commandRow(term) {
	return term ? [{ id: "command", name: term, sub: "Run this command", icon: "", glyph: ">", action: { kind: "command", value: term } }] : [];
}

function webRow(term) {
	return term ? [{ id: "web", name: term, sub: "Search Google", icon: "", glyph: "?", action: { kind: "url", value: webUrl(term) } }] : [];
}

function calcRow(term, result) {
	return result ? [{ id: "calc", name: result, sub: term + " · Enter copies it", icon: "", glyph: "=", action: { kind: "copy", value: result } }] : [];
}

var FILE_ICONS = [
	[/\.(png|jpe?g|webp|gif|bmp|svg)$/i, "file-image"],
	[/\.(mp4|mkv|webm|mov|avi)$/i, "file-video-camera"],
	[/\.(mp3|flac|wav|ogg|m4a)$/i, "file-music"],
	[/\.(pdf|txt|md|docx?|odt)$/i, "file-text"],
	[/\.(xlsx?|csv|ods)$/i, "file-spreadsheet"]
];

// A path can hold a bare %, which isn't valid escaping.
function _decodePath(text) {
	try {
		return decodeURIComponent(text);
	} catch (e) {
		return text;
	}
}

// What a clipboard entry is, from cliphist's one-line summary.
function classifyClip(text) {
	const t = String(text).trim();
	const binary = t.match(/^\[\[ binary data (.+?) (\w+) (?:(\d+)x(\d+) )?\]\]$/);
	if (binary) {
		const image = /^(png|jpe?g|webp|bmp|gif)$/i.test(binary[2]);
		return { kind: image ? "image" : "binary", size: binary[1], format: binary[2].toUpperCase(), dims: binary[3] ? binary[3] + " × " + binary[4] : "" };
	}
	if (/^file:\/\//.test(t)) {
		const path = _decodePath(t.replace(/^file:\/\//, "").split(/\s/)[0]);
		return { kind: "file", path: path, fileName: path.split("/").pop() };
	}
	if (/^https?:\/\/\S+$/i.test(t)) return { kind: "link" };
	if (/^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) return { kind: "color", color: t };
	return { kind: "text" };
}

function fileIcon(name) {
	const match = FILE_ICONS.find(([pattern]) => pattern.test(name));
	return match ? match[1] : "file";
}

// A launcher row for an entry. `thumbs` maps image ids to their decoded file.
function clipRow(e, thumbs) {
	const row = { id: e.id, name: e.text, sub: "", icon: "", glyph: "", symbol: "", swatch: "", action: { kind: "clip", value: e.raw } };
	if (e.kind === "image") {
		const thumb = thumbs[e.id] ? "file://" + thumbs[e.id] : "";
		return Object.assign(row, { name: "Image", sub: [e.format, e.dims, e.size].filter(x => x).join(" · "), icon: thumb, symbol: "file-image", preview: { kind: "image", image: thumb, caption: e.dims } });
	}
	if (e.kind === "binary") return Object.assign(row, { name: e.format + " data", sub: e.size, symbol: "file", preview: { kind: "text", text: e.format + " data, " + e.size } });
	if (e.kind === "file") return Object.assign(row, { name: e.fileName, sub: e.path, symbol: fileIcon(e.fileName), preview: { kind: "text", text: e.path } });
	if (e.kind === "link") return Object.assign(row, { sub: "Link", symbol: "globe", preview: { kind: "text", text: e.text } });
	if (e.kind === "color") return Object.assign(row, { sub: "Color", swatch: e.color, preview: { kind: "color", color: e.color, text: e.text.toUpperCase() } });
	return Object.assign(row, { sub: e.text.length + " characters", symbol: "type", preview: { kind: "text", text: e.text } });
}

function imageIds(entries) {
	return entries.filter(e => e.kind === "image").map(e => e.id);
}

function parseThumbs(text) {
	const out = {};
	text.split("\n").forEach(line => {
		const tab = line.indexOf("\t");
		if (tab > 0) out[line.slice(0, tab)] = line.slice(tab + 1);
	});
	return out;
}
