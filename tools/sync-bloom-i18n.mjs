// Copies Bloom's language catalogs into shell/i18n/locales, so bloom-dots shares
// Bloom's keys and translations. Linux-only messages live in shell/i18n/linux.
// Usage: node tools/sync-bloom-i18n.mjs <bloom checkout> [--check] [--out <dir>]
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const check = args.includes("--check");
const outAt = args.indexOf("--out");
const out = outAt >= 0 ? args[outAt + 1] : fileURLToPath(new URL("../shell/i18n", import.meta.url));
const bloom = args.find((arg, i) => !arg.startsWith("--") && args[i - 1] !== "--out");
if (!bloom) {
	console.error("usage: node tools/sync-bloom-i18n.mjs <bloom checkout> [--check] [--out <dir>]");
	process.exit(2);
}
const source = join(bloom, "src/i18n/locales");
const names = readdirSync(source).filter(name => name.endsWith(".json")).sort();
const target = join(out, "locales");

if (check) {
	const drift = names.filter(name => !existsSync(join(target, name))
		|| readFileSync(join(target, name), "utf8") !== readFileSync(join(source, name), "utf8"));
	const extra = existsSync(target) ? readdirSync(target).filter(name => !names.includes(name)) : [];
	if (drift.length || extra.length) {
		console.error(`catalogs differ from ${bloom}: ${[...drift, ...extra].join(", ")}; run: node tools/sync-bloom-i18n.mjs ${bloom}`);
		process.exit(1);
	}
	console.log("ok");
	process.exit(0);
}

rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
for (const name of names)
	writeFileSync(join(target, name), readFileSync(join(source, name), "utf8"));
const commit = execFileSync("git", ["-C", bloom, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).trim();
writeFileSync(join(out, "SOURCE"), `${commit} Bloom src/i18n/locales (copied by tools/sync-bloom-i18n.mjs)\n`);
console.log(`copied ${names.length} catalogs from Bloom ${commit}`);
