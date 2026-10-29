// Audit driver: runs Bloom's notch UI (mocked Tauri) in headless Chromium,
// captures each state as a PNG plus measured geometry, and samples motion.
const { chromium } = require(process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const OUT = __dirname + "/out";
fs.mkdirSync(OUT, { recursive: true });
const URL = "http://localhost:1420/?zoom=1";
const EXE = process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";

const SELECTORS = [
	".bloom", ".time", ".time-flip-container", ".panel-arrow.prev", ".panel-arrow.next", ".side-content.left", ".side-content.right",
	".passive-features-group", ".status-widget", ".album-art", ".mini-visualizer",
	".command-center-content-minimal", ".cc-pill-tile", ".cc-circular-btn", ".cc-classic-slider-row",
	".calendar-timer-content", ".calendar-day", ".roll-digit", ".timer-btn-play", ".timer-preset-segment",
	".qp", ".qp-header", ".qp-row", ".qp-footer", ".bh-row", ".bh-group-title",
	".device-alert", ".device-alert *", ".premium-album-art", ".cmp", ".cmp *"
];

async function measure(page) {
	return page.evaluate((sels) => {
		const out = {};
		for (const s of sels) {
			const els = Array.from(document.querySelectorAll(s)).slice(0, 40);
			if (!els.length) continue;
			out[s] = els.map(e => {
				const r = e.getBoundingClientRect();
				const cs = getComputedStyle(e);
				return { cls: e.className && e.className.baseVal === undefined ? e.className : (e.className.baseVal || ""), tag: e.tagName,
					r: [r.x, r.y, r.width, r.height].map(v => Math.round(v * 10) / 10),
					font: cs.fontSize + " " + cs.fontWeight, op: cs.opacity, text: (e.childElementCount === 0 ? e.textContent : "").trim().slice(0, 40) };
			}).filter(m => m.r[2] > 0 && m.r[3] > 0);
		}
		return out;
	}, SELECTORS);
}

async function shot(page, name) {
	await page.waitForTimeout(150);
	await page.screenshot({ path: `${OUT}/${name}.png` });
	fs.writeFileSync(`${OUT}/${name}.json`, JSON.stringify(await measure(page), null, 1));
	console.log("shot", name);
}

// .bloom's rect every frame for `ms` after `action`.
async function sample(page, name, action, ms) {
	await page.evaluate(() => {
		window.__samples = [];
		const t0 = performance.now();
		const tick = () => {
			const b = document.querySelector(".bloom");
			if (b) {
				const r = b.getBoundingClientRect();
				window.__samples.push([Math.round(performance.now() - t0), Math.round(r.y * 10) / 10, Math.round(r.width * 10) / 10, Math.round(r.height * 10) / 10]);
			}
			if (performance.now() - t0 < window.__sampleMs) requestAnimationFrame(tick);
		};
		window.__sampleMs = 1e9;
		requestAnimationFrame(tick);
	});
	await page.evaluate(ms => { window.__sampleMs = ms; }, ms);
	await action();
	await page.waitForTimeout(ms + 100);
	const s = await page.evaluate(() => window.__samples);
	fs.writeFileSync(`${OUT}/motion-${name}.json`, JSON.stringify(s));
	console.log("motion", name, s.length, "frames");
}

async function emit(page, event, payload) {
	await page.evaluate(([e, p]) => window.bloomMock.emit(e, p), [event, payload]);
}

async function center(page, sel) {
	const r = await page.evaluate(s => { const b = document.querySelector(s).getBoundingClientRect(); return [b.x + b.width / 2, b.y + b.height / 2]; }, sel);
	return r;
}

(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	const scale = Number(process.env.SCALE || 1);
	const page = await browser.newPage({ viewport: { width: 800, height: 450 }, deviceScaleFactor: scale });
	page.on("pageerror", e => console.log("pageerror", e.message));
	await page.goto(URL);
	await page.waitForTimeout(4500);
	await shot(page, "01-collapsed");

	// Hover beside the clock: the status strip.
	const [bx, by] = await center(page, ".bloom");
	await sample(page, "hover", () => page.mouse.move(bx - 40, 10), 900);
	await shot(page, "02-hover");

	// Click opens the default panel (calendar).
	await sample(page, "open-calendar", () => page.mouse.click(bx - 40, 10), 1200);
	await shot(page, "03-calendar");
	await sample(page, "to-command-center", () => page.click(".panel-arrow.next"), 1000);
	await shot(page, "04-command-center");
	await page.mouse.move(400, 120);
	await page.waitForTimeout(100);
	await page.click(".panel-arrow.next");
	await page.waitForTimeout(1000);
	await shot(page, "05-devices");
	await page.click(".panel-arrow.next");
	await page.waitForTimeout(800);
	await page.click(".panel-arrow.next");
	await page.waitForTimeout(1000);
	// Command Center's Wi-Fi chevron, then back and Bluetooth's.
	await page.click(".cc-pill-more >> nth=0");
	await page.waitForTimeout(1000);
	await shot(page, "06-wifi");
	await page.click(".qp-icon-btn >> nth=0");
	await page.waitForTimeout(800);
	await page.click(".cc-pill-more >> nth=1");
	await page.waitForTimeout(1000);
	await shot(page, "07-bluetooth");
	// Leave: the panel closes.
	await sample(page, "close", () => page.mouse.move(400, 440), 1200);
	await shot(page, "08-closed");

	// Music.
	await emit(page, "media-update", { title: "Midnight City", artist: "M83", is_playing: true, has_media: true, artwork: [], position_ms: 81000, duration_ms: 243000, seek_enabled: true, position_updated_at: Date.now() });
	await page.waitForTimeout(1200);
	await shot(page, "09-music-collapsed");
	await page.mouse.move(bx - 40, 10);
	await page.waitForTimeout(900);
	await shot(page, "10-music-hover");
	const art = await page.$(".album-art");
	if (art) {
		const b = await art.boundingBox();
		await sample(page, "open-music", () => page.mouse.click(b.x + b.width / 2, b.y + b.height / 2), 1200);
		await shot(page, "11-music-open");
	}
	await page.mouse.move(400, 440);
	await page.waitForTimeout(1500);

	// Device alert.
	await sample(page, "device-alert", () => emit(page, "bluetooth-connection", { id: "bt1", name: "AirPods Pro", kind: "audio", form: "earbuds", connected: true, battery: 72 }), 1500);
	await shot(page, "12-device-alert");
	await page.waitForTimeout(400);
	await shot(page, "13-device-alert-later");
	await page.waitForTimeout(5000);
	await emit(page, "bluetooth-connection", { id: "bt2", name: "MX Master 3", kind: "mouse", form: null, connected: false, battery: 15 });
	await page.waitForTimeout(900);
	await shot(page, "14-device-alert-disconnect");

	await browser.close();
})();
