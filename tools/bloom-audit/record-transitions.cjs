// Records Bloom's notch transitions at exactly 60 fps on a virtual clock
// (as record-device-art.cjs), one PNG per frame, for a side-by-side with
// the shell. Usage: node record-transitions.cjs <out-dir> [scale]
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const path = require("path");

const OUT = path.resolve(process.argv[2] || "transitions");
const SCALE = Number(process.argv[3] || 1);
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const BASE = process.env.BLOOM_URL || "http://localhost:1420";

const CLOCK = `
	window.__t = 0;
	window.__raf = [];
	performance.now = () => window.__t;
	window.requestAnimationFrame = cb => { window.__raf.push(cb); return window.__raf.length; };
	window.cancelAnimationFrame = id => { if (window.__raf[id - 1]) window.__raf[id - 1] = null; };
	window.__advance = ms => {
		const end = window.__t + ms;
		while (window.__t < end) {
			window.__t = Math.min(end, window.__t + 1000 / 60);
			// CSS and Web Animations run from when they first appear.
			for (const a of document.getAnimations()) {
				if (a.__born === undefined) a.__born = window.__t - 1000 / 60;
				a.pause();
				a.currentTime = window.__t - a.__born;
			}
			const due = window.__raf; window.__raf = [];
			for (const cb of due) if (cb) cb(window.__t);
		}
	};
`;

async function frames(page, name, clip, ms) {
	const dir = path.join(OUT, name);
	fs.mkdirSync(dir, { recursive: true });
	for (let i = 0, t = 0; t <= ms; i++, t += 1000 / 60) {
		await page.screenshot({ path: path.join(dir, String(i).padStart(4, "0") + ".png"), clip });
		await page.evaluate(() => window.__advance(1000 / 60));
	}
	console.log(name, "done");
}

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	const page = await browser.newPage({ viewport: { width: 800, height: 450 }, deviceScaleFactor: SCALE });
	await page.addInitScript(CLOCK);
	await page.goto(`${BASE}/?zoom=1`);
	// Let React and the startup drop-in settle on the virtual clock.
	for (let i = 0; i < 40; i++) {
		await page.waitForTimeout(60);
		await page.evaluate(() => window.__advance(100));
	}
	const clip = { x: 140, y: 0, width: 520, height: 330 };
	const box = await page.evaluate(() => { const r = document.querySelector(".bloom").getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2]; });
	const step = ms => page.evaluate(m => window.__advance(m), ms);

	await page.mouse.move(box[0] - 40, 10);
	await frames(page, "hover", clip, 700);
	await page.mouse.click(box[0] - 40, 10);
	await frames(page, "open-calendar", clip, 900);
	await page.click(".panel-arrow.next");
	await frames(page, "switch-to-cc", clip, 700);
	await page.mouse.move(400, 440);
	await frames(page, "close", clip, 900);
	await step(1500);
	await page.evaluate(() => window.bloomMock.emit("bluetooth-connection", { id: "bt1", name: "AirPods Pro", kind: "audio", form: "earbuds", connected: true, battery: 72 }));
	await page.waitForTimeout(100);
	await frames(page, "device-alert", clip, 1800);
	await browser.close();
})();
