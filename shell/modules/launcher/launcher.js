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
		if (tab > 0) out.push({ id: line.slice(0, tab), text: line.slice(tab + 1), raw: line });
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
