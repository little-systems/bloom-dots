// Captures Bloom's ambient glow alone (the compact player open with its
// controls hidden) over the notch, for the ambience parity check.
// Usage: node record-glow.cjs <out.png> <art.jpg>
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const ART = "data:image/jpeg;base64," + fs.readFileSync(process.argv[3]).toString("base64");

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
	// Through the mock's settings file too: a key only in localStorage is a
	// stale mirror to Bloom, which drops it and reloads.
	await page.addInitScript(() => {
		localStorage.setItem("bloom-media-layout", "compact");
		localStorage.setItem("mock-settings", JSON.stringify({ "bloom-media-layout": "compact" }));
	});
	await page.goto("http://localhost:1420/?zoom=1");
	await page.waitForFunction(() => window.bloomMock && document.querySelector(".bloom"), null, { timeout: 15000 });
	await page.waitForTimeout(1500);
	await page.evaluate(art => window.bloomMock.emit("media-update", { title: "x", artist: "y", is_playing: true, has_media: true, artwork: [art], position_ms: 0, duration_ms: 1000, seek_enabled: true, position_updated_at: Date.now() }), ART);
	await page.waitForTimeout(1500);
	await page.click(".album-art");
	await page.waitForTimeout(2000);
	await page.addStyleTag({ content: ".cmp, .edge-surface { visibility: hidden !important; } body { background: #000 !important; }" });
	await page.waitForTimeout(300);
	const r = await page.evaluate(() => { const b = document.querySelector(".bloom").getBoundingClientRect(); return [b.x, b.y, b.width, b.height]; });
	await page.screenshot({ path: process.argv[2], clip: { x: r[0], y: r[1], width: r[2], height: r[3] } });
	console.log("glow", r.join(" "));
	await browser.close();
})();
