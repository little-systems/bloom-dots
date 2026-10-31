// Captures Bloom's settings window, tab by tab, with each element's box, for
// the settings app's parity checks. Usage: node record-settings.cjs <out>
const { chromium } = require(process.env.PLAYWRIGHT_CORE || process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const EXE = process.env.CHROME || require("fs").readdirSync(process.env.HOME + "/.cache/ms-playwright").filter(d => d.startsWith("chromium_headless_shell")).sort().pop();
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });
const SELECTORS = [".title-bar", ".title-text", ".close-btn", ".settings-sidebar", ".settings-sidebar-intro", ".sidebar-tab", ".settings-content",
	".settings-page-heading h1", ".settings-page-heading p", ".feature-preview", ".setting-group-label", ".setting-group", ".setting-item",
	".setting-label", ".setting-desc", ".toggle-switch", ".settings-slider", ".settings-select", ".setting-divider", ".scale-button-container"];

(async () => {
	const browser = await chromium.launch({ executablePath: process.env.CHROME || `${process.env.HOME}/.cache/ms-playwright/${EXE}/chrome-linux/headless_shell` });
	const page = await browser.newPage({ viewport: { width: 740, height: 560 } });
	await page.goto("http://localhost:1420/settings.html");
	await page.waitForTimeout(1500);
	for (const tab of ["General", "Appearance", "Notch", "Dock", "Overlays", "About"]) {
		await page.locator(".sidebar-tab", { hasText: tab }).click();
		await page.waitForTimeout(400);
		const geo = await page.evaluate(selectors => selectors.flatMap(s => Array.from(document.querySelectorAll(s)).map(e => {
			const r = e.getBoundingClientRect();
			return { s, text: e.childElementCount ? "" : e.textContent.trim().slice(0, 30), r: [r.x, r.y, r.width, r.height].map(v => Math.round(v * 10) / 10) };
		})), SELECTORS);
		fs.writeFileSync(`${OUT}/${tab}.json`, JSON.stringify(geo));
		await page.screenshot({ path: `${OUT}/${tab}.png` });
		console.log(tab, geo.length);
	}
	await browser.close();
})();
