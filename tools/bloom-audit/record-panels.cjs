// Captures Bloom's Wi-Fi and Bluetooth panels (and an expanded row, and the
// "Add a device" view) as PNGs with every .qp element's box relative to the
// pill, for the quick-panel parity checks. Usage: node record-panels.cjs <out>
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const EXE = process.env.CHROME || process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });

async function shot(page, name) {
	await page.waitForTimeout(400);
	const geo = await page.evaluate(() => {
		const pill = document.querySelector(".bloom").getBoundingClientRect();
		return Array.from(document.querySelectorAll(".qp, .qp *")).map(e => {
			const r = e.getBoundingClientRect();
			const cs = getComputedStyle(e);
			return { cls: String(e.className.baseVal ?? e.className).slice(0, 40), tag: e.tagName,
				r: [r.x - pill.x, r.y - pill.y, r.width, r.height].map(v => Math.round(v * 10) / 10),
				font: cs.fontSize + " " + cs.fontWeight, color: cs.color, bg: cs.backgroundColor,
				text: e.childElementCount ? "" : (e.textContent || e.placeholder || "").trim().slice(0, 40) };
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
	await page.goto("http://localhost:1420/?zoom=1");
	await page.waitForFunction(() => window.bloomMock && document.querySelector(".bloom"), null, { timeout: 15000 });
	await page.waitForTimeout(2500);
	const b = await page.evaluate(() => { const r = document.querySelector(".bloom").getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2]; });
	await page.mouse.move(b[0] - 40, 10);
	await page.waitForTimeout(800);
	await page.mouse.click(b[0] - 40, 10);
	await page.waitForTimeout(1200);
	// Calendar → Command Center.
	await page.click(".panel-arrow.next");
	await page.waitForTimeout(1000);
	await page.mouse.move(400, 120);
	await page.click(".cc-pill-more >> nth=0");
	await page.waitForTimeout(1000);
	await shot(page, "wifi");
	await page.click(".qp-row-main >> nth=2");
	await shot(page, "wifi-expanded");
	await page.click(".qp-icon-btn >> nth=0");
	await page.waitForTimeout(800);
	await page.click(".cc-pill-more >> nth=1");
	await page.waitForTimeout(1000);
	await shot(page, "bluetooth");
	await page.click(".qp-row-main >> nth=0");
	await shot(page, "bluetooth-expanded");
	await page.click(".qp-icon-btn >> nth=1");
	await page.waitForTimeout(800);
	await shot(page, "bluetooth-add");
	await browser.close();
})();
