// Records Bloom's device art (src/devices: DeviceArt, devices.css, caseArt.ts)
// frame by frame into animated WebP for the shell's DeviceArt.
//
// Needs Bloom's UI served by Vite with the audit page (see README.md here).
// Time is virtual: performance.now and requestAnimationFrame are replaced
// before the page loads, and every CSS or Web Animation is pinned to the
// same time each frame, so each run is exact and repeatable.
//
// Usage: node record-device-art.cjs <out-dir> [art ...]
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const OUT = path.resolve(process.argv[2] || "device-art");
const ARTS = process.argv.slice(3).length ? process.argv.slice(3) : [
	"stem-buds", "round-buds", "headphones", "headphones-wired", "neckband", "earbuds-usbc", "earbuds-jack",
	"speaker", "phone", "controller", "watch", "mouse", "keyboard", "device", "flash-drive", "ssd", "hub",
	"webcam", "microphone", "sd-card"
];
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const BASE = process.env.BLOOM_URL || "http://localhost:1420";
// 60 px drawings with 20 px of room for glows, at 2.5x (bloom-scale 1.25 on a
// 2x screen stays sharp).
const SCALE = 2.5;
// 100 fps: WebP delays are whole centiseconds in ImageMagick, so 1/100 s per
// frame keeps the timing exact (1/60 s would round to 20 ms and run slow).
const FPS = 100;
const MAX_MS = 2400;

const CLOCK = `
	window.__t = 0;
	window.__raf = [];
	performance.now = () => window.__t;
	window.requestAnimationFrame = cb => { window.__raf.push(cb); return window.__raf.length; };
	window.cancelAnimationFrame = id => { if (window.__raf[id - 1]) window.__raf[id - 1] = null; };
	window.__step = t => {
		window.__t = t;
		for (const a of document.getAnimations()) { a.pause(); a.currentTime = t; }
		const due = window.__raf; window.__raf = [];
		for (const cb of due) if (cb) cb(t);
		return document.getAnimations().some(a => a.playState !== "finished" && (a.currentTime ?? 0) < (a.effect?.getComputedTiming().endTime ?? 0)) || window.__raf.length > 0;
	};
`;

(async () => {
	fs.mkdirSync(OUT, { recursive: true });
	const browser = await chromium.launch({ executablePath: EXE });
	const page = await browser.newPage({ viewport: { width: 100, height: 100 }, deviceScaleFactor: SCALE });
	await page.addInitScript(CLOCK);
	for (const art of ARTS) {
		for (const phase of ["play", "leave"]) {
			const frames = fs.mkdtempSync(path.join(OUT, `.${art}-${phase}-`));
			await page.goto(`${BASE}/art.html?art=${art}&phase=${phase}`);
			await page.waitForSelector("svg.device-art .dev", { state: "attached" });
			let n = 0;
			for (let t = 0; t <= MAX_MS; t += 1000 / FPS) {
				const busy = await page.evaluate(t => window.__step(t), t);
				await page.screenshot({ path: path.join(frames, String(n++).padStart(4, "0") + ".png"), omitBackground: true });
				if (!busy && t > 200) break;
			}
			const pngs = fs.readdirSync(frames).filter(f => f.endsWith(".png")).sort().map(f => path.join(frames, f));
			// One run, no loop, 1/100 s per frame.
			execFileSync("magick", ["-dispose", "Background", "-delay", "1", ...pngs, "-loop", "1", "-define", "webp:lossless=false", "-quality", "92", path.join(OUT, `${art}-${phase}.webp`)]);
			if (phase === "play") fs.copyFileSync(pngs[pngs.length - 1], path.join(OUT, `${art}.png`));
			fs.rmSync(frames, { recursive: true });
			console.log(art, phase, pngs.length, "frames");
		}
	}
	await browser.close();
})();
