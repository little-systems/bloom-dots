// Generates docs/SETTINGS.md from shell/services/settings.js.
// Usage: node tools/gen-settings-doc.mjs           (write)
//        node tools/gen-settings-doc.mjs --check   (exit 1 if out of date)
import { readFileSync, writeFileSync } from "node:fs";
import vm from "node:vm";

const root = new URL("../", import.meta.url);
const ctx = {};
vm.createContext(ctx);
vm.runInContext(readFileSync(new URL("shell/services/settings.js", root), "utf8"), ctx);

const allowed = s => {
	if (s.type === "enum") {
		const aliases = s.aliases ? Object.keys(s.aliases).map(a => ` (\`${a}\` = \`${s.aliases[a]}\`)`).join("") : "";
		return s.values.map(v => `\`${v}\``).join(", ") + aliases;
	}
	if (s.type === "list") return s.values.map(v => `\`${v}\``).join(", ");
	if (s.type === "widgets") return `\`{"left": [...], "right": [...]}\` of ${s.values.map(v => `\`${v}\``).join(", ")}`;
	if (s.type === "number") return `${s.min} to ${s.max}${s.nullable ? ", or `null`" : ""}`;
	if (s.type === "color") return "`#rgb` or `#rrggbb`";
	if (s.type === "bool") return "`true`, `false`";
	if (s.type === "string") return `text, up to ${s.maxLength} characters`;
	return "";
};

const rows = ctx.keys().map(k => {
	const s = ctx.SCHEMA[k];
	return `| \`${k}\` | ${s.type} | \`${JSON.stringify(s.default)}\` | ${allowed(s)} | ${s.doc} |`;
});

const doc = `# Bloom settings

Generated from \`shell/services/settings.js\` by \`node tools/gen-settings-doc.mjs\`; do not edit by hand.

Settings live in \`~/.config/bloom/settings.json\` (\`$XDG_CONFIG_HOME/bloom/settings.json\`) as one flat JSON object. Edits apply live. An invalid or missing value uses its default and logs a warning; a file with a syntax error is ignored (the last good settings stay) until it is fixed. Values in Bloom for Windows' string form (\`"true"\`, \`"0.8"\`) are accepted.

| Key | Type | Default | Allowed | Description |
|---|---|---|---|---|
${rows.join("\n")}
`;

const target = new URL("docs/SETTINGS.md", root);
if (process.argv.includes("--check")) {
	let current = "";
	try { current = readFileSync(target, "utf8"); } catch {}
	if (current !== doc) {
		console.error("docs/SETTINGS.md is out of date; run: node tools/gen-settings-doc.mjs");
		process.exit(1);
	}
	console.log("ok");
} else {
	writeFileSync(target, doc);
	console.log("wrote docs/SETTINGS.md");
}
