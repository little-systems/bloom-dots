// Captures Bloom's music states (collapsed, hover, classic and compact
// players, with and without artwork) as PNGs with geometry, for the music
// parity pass. Usage: node drive-music.cjs <out-dir> <art.jpg>
// TITLE, ARTIST and LAYOUTS (comma-separated) override the defaults, to match
// what the live shell is showing.
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const path = require("path");
const OUT = path.resolve(process.argv[2] || "music");
const ART = "data:image/jpeg;base64," + fs.readFileSync(process.argv[3]).toString("base64");
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
fs.mkdirSync(OUT, { recursive: true });

const SEL = [".bloom", ".expanded-music-container *", ".album-art", ".mini-visualizer", ".premium-album-art", ".premium-player", ".premium-player *", ".cmp", ".cmp *", ".notch-ambient-glow"];
async function shot(page, name) {
	await page.waitForTimeout(200);
	await page.screenshot({ path: `${OUT}/${name}.png`, clip: { x: 140, y: 0, width: 520, height: 260 } });
	const geo = await page.evaluate(sels => {
		try {
		const out = {};
		for (const s of sels) {
			out[s] = Array.from(document.querySelectorAll(s)).slice(0, 60).map(e => {
				const r = e.getBoundingClientRect();
				const cs = getComputedStyle(e);
				return [String(e.className.baseVal ?? e.className).slice(0, 50), e.tagName, Math.round(r.x * 10) / 10, Math.round(r.y * 10) / 10, Math.round(r.width * 10) / 10, Math.round(r.height * 10) / 10, cs.fontSize, cs.fontWeight, cs.opacity, cs.borderRadius, (e.childElementCount ? "" : e.textContent || "").trim().slice(0, 30)];
			}).filter(m => m[4] > 0);
		}
		return out;
		} catch (e) { return { error: String(e) }; }
	}, SEL).catch(e => ({ error: String(e) }));
	fs.writeFileSync(`${OUT}/${name}.json`, JSON.stringify(geo, null, 1));
	console.log("shot", name);
}

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	for (const layout of (process.env.LAYOUTS || "classic,compact").split(",")) {
		for (const withArt of [true, false]) {
			const tag = `${layout}-${withArt ? "art" : "noart"}`;
			try {
			const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
			page.on("pageerror", e => console.log("pageerror", tag, e.message));
			// Through the mock's settings file too: a key only in localStorage is a
			// stale mirror to Bloom, which drops it and reloads.
			await page.addInitScript(l => {
				localStorage.setItem("bloom-media-layout", l);
				localStorage.setItem("mock-settings", JSON.stringify({ "bloom-media-layout": l }));
			}, layout);
			await page.goto("http://localhost:1420/?zoom=1");
			await page.waitForFunction(() => window.bloomMock && document.querySelector(".bloom"), null, { timeout: 15000 });
			await page.waitForTimeout(1500);
			await page.evaluate(([art, title, artist]) => window.bloomMock.emit("media-update", { title, artist, is_playing: true, has_media: true, artwork: art ? [art] : [], position_ms: 81000, duration_ms: 243000, seek_enabled: true, position_updated_at: Date.now() }), [withArt ? ART : null, process.env.TITLE || "Midnight City", process.env.ARTIST || "M83"]);
			await page.waitForTimeout(1500);
			if (layout === "classic") await shot(page, `${tag}-collapsed`);
			const box = await page.evaluate(() => { const r = document.querySelector(".bloom")?.getBoundingClientRect(); return r ? [r.x, r.width] : [380, 40]; });
			await page.mouse.move(box[0] + 20, 12);
			await page.waitForTimeout(900);
			if (layout === "classic") await shot(page, `${tag}-hover`);
			const art = await page.$(".album-art");
			if (art) {
				const b = await art.boundingBox();
				await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
				await page.waitForTimeout(1500);
				await shot(page, `${tag}-open`);
			}
			await page.close();
			} catch (e) { console.log("scenario failed", tag, String(e).split("\n")[0]); }
		}
	}
	await browser.close();
})();
