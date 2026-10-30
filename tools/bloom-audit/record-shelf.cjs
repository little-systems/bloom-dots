// Captures Bloom's shelf (a text item, a text file with its opening, and a
// folder) as a PNG with every .shelf element's box relative to the pill, at
// rest and with a tile hovered, for the shelf parity checks.
// Usage: node record-shelf.cjs <out-dir>
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });

const ITEMS = [
	{ id: "t1", type: "text", name: "Meeting notes", text: "Meeting notes: ship the shelf parity, then the owner check and the whole-branch review before merging anything.", timestamp: 3 },
	{ id: "f1", type: "file", name: "notes.md", path: "C:\\Users\\me\\notes.md", timestamp: 2 },
	{ id: "d1", type: "file", name: "Photos", path: "C:\\Users\\me\\Photos", timestamp: 1 }
];
const PREVIEWS = {
	"C:\\Users\\me\\notes.md": { thumb: null, text: "# Notes\nFirst line of the file, then a second one that runs on long enough to wrap.", folder: false },
	"C:\\Users\\me\\Photos": { thumb: null, text: null, folder: true }
};

async function shot(page, name) {
	await page.waitForTimeout(400);
	const geo = await page.evaluate(() => {
		const pill = document.querySelector(".bloom").getBoundingClientRect();
		return Array.from(document.querySelectorAll(".shelf-content, .shelf-content *")).map(e => {
			const r = e.getBoundingClientRect();
			const cs = getComputedStyle(e);
			return { cls: String(e.className.baseVal ?? e.className).slice(0, 40), tag: e.tagName,
				r: [r.x - pill.x, r.y - pill.y, r.width, r.height].map(v => Math.round(v * 10) / 10),
				font: cs.fontSize + " " + cs.fontWeight, opacity: cs.opacity, color: cs.color, bg: cs.backgroundColor,
				text: e.childElementCount ? "" : (e.textContent || "").trim().slice(0, 40) };
		}).filter(m => m.r[2] > 0);
	});
	fs.writeFileSync(`${OUT}/${name}.json`, JSON.stringify(geo, null, 1));
	const box = await page.evaluate(() => { const r = document.querySelector(".bloom").getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height }; });
	await page.screenshot({ path: `${OUT}/${name}.png`, clip: box });
	console.log("shot", name);
}

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
	page.on("pageerror", e => console.log("pageerror", e.message));
	// Through the mock's settings file too: a key only in localStorage is a
	// stale mirror to Bloom, which drops it and reloads.
	await page.addInitScript(([items, previews]) => {
		localStorage.setItem("bloom-shelf-persist", "true");
		localStorage.setItem("bloom-shelf-items", JSON.stringify(items));
		localStorage.setItem("mock-settings", JSON.stringify({ "bloom-shelf-persist": "true" }));
		window.__shelfPreviews = previews;
	}, [ITEMS, PREVIEWS]);
	await page.goto("http://localhost:1420/?zoom=1");
	await page.waitForFunction(() => window.bloomMock && document.querySelector(".bloom"), null, { timeout: 15000 });
	await page.waitForTimeout(2500);
	// The shelf opens from its bubble on the collapsed pill.
	await page.waitForSelector(".shelf-bubble", { timeout: 5000 });
	await page.click(".shelf-bubble");
	await page.waitForSelector(".shelf-content", { timeout: 5000 });
	await page.waitForTimeout(900);
	// Rest the pointer inside the open notch, off the tiles.
	const pill = await page.evaluate(() => { const r = document.querySelector(".bloom").getBoundingClientRect(); return [r.x, r.y, r.width, r.height]; });
	await page.mouse.move(pill[0] + pill[2] - 8, pill[1] + 20);
	await shot(page, "shelf");
	const tile = await page.$(".shelf-tile >> nth=1");
	const t = await tile.boundingBox();
	await page.mouse.move(t.x + t.width / 2, t.y + t.height / 2);
	await shot(page, "shelf-hover");
	await browser.close();
})();
