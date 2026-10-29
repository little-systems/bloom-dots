#!/usr/bin/env node
// Bloom's cursor rule (UI parity 1): every clickable control shows a pointer
// (or a text cursor for editable text), as Bloom's CSS does with `cursor:`.
//
// A clickable is a TapHandler or a MouseArea. It is covered when the item that
// holds it also holds a HoverHandler or MouseArea with a `cursorShape`, or when
// the handler is a MouseArea with its own `cursorShape`, or when it is a
// PressArea/PointerArea (which set the cursor themselves). A handler that must
// keep the default cursor (an invisible outside-click catcher, a drag area)
// says so with a `// cursor: default — <why>` comment on its line or the line
// above.
//
// Usage: node tools/check-cursors.mjs [--list]; exit 1 when anything is missing.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const shell = join(root, "shell");

function files(dir) {
	const out = [];
	for (const name of readdirSync(dir)) {
		const p = join(dir, name);
		if (statSync(p).isDirectory()) out.push(...files(p));
		else if (name.endsWith(".qml")) out.push(p);
	}
	return out;
}

// Blocks as { type, start, end, parent } from a brace scan that skips strings
// and comments, enough for the QML in this repo.
function blocks(text) {
	const list = [];
	const stack = [];
	let i = 0;
	while (i < text.length) {
		const c = text[i];
		if (c === "/" && text[i + 1] === "/") { i = text.indexOf("\n", i); if (i < 0) break; continue; }
		if (c === "/" && text[i + 1] === "*") { i = text.indexOf("*/", i) + 2; continue; }
		if (c === '"' || c === "'" || c === "`") {
			const q = c; i++;
			while (i < text.length && text[i] !== q) { if (text[i] === "\\") i++; i++; }
			i++; continue;
		}
		if (c === "{") {
			const head = text.slice(Math.max(0, i - 80), i);
			const m = /([A-Za-z_][A-Za-z0-9_.]*)\s*$/.exec(head);
			const b = { type: m ? m[1] : "", start: i, end: -1, parent: stack.length ? stack[stack.length - 1] : null, children: [] };
			if (b.parent) b.parent.children.push(b);
			list.push(b);
			stack.push(b);
		} else if (c === "}") {
			const b = stack.pop();
			if (b) b.end = i;
		}
		i++;
	}
	return list;
}

const lineOf = (text, at) => text.slice(0, at).split("\n").length;

function optedOut(text, b) {
	const ln = lineOf(text, b.start);
	const lines = text.split("\n");
	return [lines[ln - 1], lines[ln - 2] || ""].some(l => /\/\/\s*cursor:\s*default/.test(l));
}

const ownBody = (text, b) => {
	// The block's own text without its child blocks.
	let s = "";
	let at = b.start + 1;
	for (const c of b.children) { s += text.slice(at, c.start); at = c.end + 1; }
	return s + text.slice(at, b.end);
};

const missing = [];
for (const file of files(shell)) {
	const text = readFileSync(file, "utf8");
	for (const b of blocks(text)) {
		if (b.type !== "TapHandler" && b.type !== "MouseArea") continue;
		if (b.type === "MouseArea" && /cursorShape\s*:/.test(ownBody(text, b))) continue;
		// Not clickable: a wheel- or hover-only area.
		if (b.type === "MouseArea" && /acceptedButtons\s*:\s*Qt\.NoButton/.test(ownBody(text, b))) continue;
		if (optedOut(text, b)) continue;
		const holder = b.parent;
		if (!holder) continue;
		if (/^(PressArea|PointerArea)$/.test(holder.type)) continue;
		const siblings = holder.children.filter(c => c !== b);
		const covered = /cursorShape\s*:/.test(ownBody(text, holder))
			|| siblings.some(s => /^(HoverHandler|MouseArea)$/.test(s.type) && /cursorShape\s*:/.test(ownBody(text, s)));
		if (!covered) missing.push(`${relative(root, file)}:${lineOf(text, b.start)} ${b.type} in ${holder.type || "?"}`);
	}
}

if (missing.length) {
	console.error(`${missing.length} clickable(s) without Bloom's cursor:`);
	for (const m of missing) console.error("  " + m);
	process.exit(1);
}
console.log("ok: every clickable sets a cursor");
