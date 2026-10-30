// Captures Bloom's collapsed album art (the 24 px tile and its glow) for an
// art image: at rest, hovered and paused, cropped around the tile, with the
// tile's box. Usage: node record-mini-art.cjs <out-dir> <art.jpg>
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const ART = "data:image/jpeg;base64," + fs.readFileSync(process.argv[3]).toString("base64");
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	const page = await browser.newPage({ viewport: { width: 800, height: 300 } });
	await page.goto("http://localhost:1420/?zoom=1");
	await page.waitForFunction(() => window.bloomMock && document.querySelector(".bloom"), null, { timeout: 15000 });
	await page.waitForTimeout(1500);
	const emit = playing => page.evaluate(([art, playing]) => window.bloomMock.emit("media-update", { title: "x", artist: "y", is_playing: playing, has_media: true, artwork: [art], position_ms: 0, duration_ms: 1000, seek_enabled: true, position_updated_at: Date.now() }), [ART, playing]);
	await emit(true);
	await page.waitForTimeout(2000);
	const box = await page.evaluate(() => { const r = document.querySelector(".album-art").getBoundingClientRect(); return [r.x, r.y, r.width, r.height]; });
	const clip = { x: box[0] - 16, y: 0, width: box[2] + 32, height: 40 };
	await page.screenshot({ path: `${OUT}/rest.png`, clip });
	await page.mouse.move(box[0] + 12, box[1] + 12);
	await page.waitForTimeout(1000);
	await page.screenshot({ path: `${OUT}/hover.png`, clip });
	await page.mouse.move(10, 290);
	await emit(false);
	await page.waitForTimeout(1500);
	await page.screenshot({ path: `${OUT}/paused.png`, clip });
	console.log("tile", box.join(" "), "clip", JSON.stringify(clip));
	await browser.close();
})();
