// Export Bloom's own device drawings as standalone SVGs for Quickshell.
// Run beside the Windows source checkout: node tools/gen-device-art.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const source = resolve(process.env.BLOOM_WINDOWS_ART || "../bloom/src/devices/art.ts");
const { DEVICE_ART, DEVICE_ART_DEFS } = await import(pathToFileURL(source).href);
const out = resolve("shell/assets/device-art");
mkdirSync(out, { recursive: true });
const palette = {
	hi: "#fbfbfd",
	body: "#dcdde2",
	shade: "#a9abb3",
	dark: "#2a2b30",
	accent: "#f5f5f7"
};
function standalone(markup) {
	return markup.replace(/var\(--(hi|body|shade|dark|accent)\)/g, (_, key) => palette[key])
		.replace(/ style="--[^"]*"/g, "");
}
for (const [name, drawing] of Object.entries(DEVICE_ART)) {
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><defs>${standalone(DEVICE_ART_DEFS)}</defs>${standalone(drawing)}</svg>\n`;
	writeFileSync(resolve(out, name + ".svg"), svg);
}
console.log(`wrote ${Object.keys(DEVICE_ART).length} Bloom device drawings`);
