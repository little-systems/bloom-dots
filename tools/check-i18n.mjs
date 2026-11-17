// Checks bloom-dots' text against its catalogs (shell/i18n: Bloom's locales and
// the Linux overlay): every key the shell uses exists in English; translations
// are known keys, nonempty, with English's placeholders; plural sets are
// complete for their language. Prints coverage per language (partial is fine:
// English fills in). Usage: node tools/check-i18n.mjs --check [--root <dir>]
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const rootAt = args.indexOf("--root");
const root = rootAt >= 0 ? args[rootAt + 1] : fileURLToPath(new URL("..", import.meta.url));
const i18n = join(root, "shell/i18n");
const CATEGORIES = { ru: ["one", "few", "many", "other"] };
const categories = lang => CATEGORIES[lang] ?? ["one", "other"];
const errors = [];

const read = path => JSON.parse(readFileSync(path, "utf8"));
function catalog(lang) {
	const result = existsSync(join(i18n, "locales", lang + ".json")) ? read(join(i18n, "locales", lang + ".json")) : {};
	const overlay = join(i18n, "linux", lang + ".json");
	if (existsSync(overlay)) result.linux = read(overlay).linux ?? {};
	return result;
}
function flatten(node, prefix = "", out = new Map()) {
	for (const [key, value] of Object.entries(node ?? {})) {
		const path = prefix ? `${prefix}.${key}` : key;
		if (value && typeof value === "object") flatten(value, path, out);
		else out.set(path, value);
	}
	return out;
}
const placeholders = text => [...new Set([...String(text).matchAll(/\{\{\s*(\w+)\s*\}\}/g)].map(m => m[1]))].sort().join(",");
const PLURAL = /^(.*)_(zero|one|two|few|many|other)$/;
const message = key => key.replace(PLURAL, "$1");

const english = flatten(catalog("en"));
const englishMessages = new Set([...english.keys()].map(message));
const langs = readdirSync(join(i18n, "locales")).filter(n => n.endsWith(".json")).map(n => n.slice(0, -5)).filter(l => l !== "en").sort();

// Keys the shell uses.
function files(dir, out = []) {
	for (const name of readdirSync(dir)) {
		const path = join(dir, name);
		if (statSync(path).isDirectory()) { if (name !== "i18n") files(path, out); }
		else if (/\.(qml|js)$/.test(name) && name !== "catalogs.js") out.push(path);
	}
	return out;
}
for (const path of files(join(root, "shell"))) {
	const text = readFileSync(path, "utf8");
	for (const m of text.matchAll(/I18n\.(t|tCount)\(\s*"([^"]+)"/g)) {
		const [, fn, key] = m;
		const known = fn === "tCount" ? english.has(key + "_other") || english.has(key) : english.has(key);
		if (!known) errors.push(`${relative(root, path)}: ${key} is not in the English catalog`);
	}
}

for (const lang of langs) {
	const entries = flatten(catalog(lang));
	const covered = new Set();
	const groups = new Map();
	for (const [key, value] of entries) {
		const plural = PLURAL.exec(key);
		const reference = english.get(key) ?? (plural ? english.get(plural[1] + "_other") : undefined);
		if (reference === undefined) { errors.push(`${lang}: ${key} is not an English key`); continue; }
		if (typeof value !== "string" || !value.trim()) { errors.push(`${lang}: ${key} is empty`); continue; }
		if (placeholders(value) !== placeholders(reference)) {
			errors.push(`${lang}: ${key} uses {{${placeholders(value)}}}, English uses {{${placeholders(reference)}}}`);
			continue;
		}
		if (plural) groups.set(plural[1], [...(groups.get(plural[1]) ?? []), plural[2]]);
		covered.add(message(key));
	}
	for (const [base, have] of groups) {
		const missing = categories(lang).filter(c => !have.includes(c));
		if (missing.length) errors.push(`${lang}: ${base} lacks plural forms ${missing.join(", ")}`);
	}
	console.log(`${lang}: ${[...covered].filter(k => englishMessages.has(k)).length}/${englishMessages.size}`);
}

if (errors.length) {
	for (const error of errors) console.error(error);
	process.exit(1);
}
