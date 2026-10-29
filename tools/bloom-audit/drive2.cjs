const { chromium } = require(process.env.HOME + "/Projects/AgentComms/node_modules/playwright-core");
const fs = require("fs");
const OUT = __dirname + "/out";
const EXE = process.env.HOME + "/.cache/ms-playwright/chromium_headless_shell-1234/chrome-headless-shell-linux64/chrome-headless-shell";
(async () => {
	const browser = await chromium.launch({ executablePath: EXE });
	// Dock: the bottom of its 1920 x 600 window, shown at 800 wide.
	const dock = await browser.newPage({ viewport: { width: 800, height: 300 } });
	dock.on("pageerror", e => console.log("dock pageerror", e.message));
	await dock.goto("http://localhost:1420/dock.html?w=dock&zoom=1");
	await dock.waitForTimeout(5000);
	await dock.screenshot({ path: `${OUT}/20-dock.png` });
	const icons = await dock.$$(".dock-icon");
	console.log("dock icons", icons.length);
	if (icons.length) {
		const b = await icons[0].boundingBox();
		await dock.mouse.move(b.x + b.width / 2, b.y + b.height / 2);
		await dock.waitForTimeout(1200);
		await dock.screenshot({ path: `${OUT}/21-dock-hover.png` });
		const b2 = await icons[1].boundingBox();
		await dock.mouse.move(b2.x + b2.width / 2, b2.y + b2.height / 2);
		await dock.waitForTimeout(1200);
		await dock.screenshot({ path: `${OUT}/22-dock-hover-notrunning.png` });
		await dock.mouse.click(b.x + b.width / 2, b.y + b.height / 2, { button: "right" });
		await dock.waitForTimeout(800);
		await dock.screenshot({ path: `${OUT}/23-dock-menu.png` });
	}
	const geo = await dock.evaluate(() => Array.from(document.querySelectorAll(".dock-container, .dock, .dock-icon, .dock-icon-wrapper, .tooltip, .running-indicator, .dock-separator, .context-menu")).slice(0, 30).map(e => { const r = e.getBoundingClientRect(); return [e.className.baseVal ?? e.className, Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)]; }));
	fs.writeFileSync(`${OUT}/20-dock.json`, JSON.stringify(geo, null, 1));
	// OSD: the overlay window, volume then brightness.
	const osd = await browser.newPage({ viewport: { width: 800, height: 450 } });
	osd.on("pageerror", e => console.log("osd pageerror", e.message));
	await osd.goto("http://localhost:1420/overlay.html?w=overlay&zoom=1");
	await osd.waitForTimeout(4000);
	await osd.evaluate(() => window.bloomMock.emit("volume-change", { volume: 0.45, is_muted: false }));
	await osd.waitForTimeout(700);
	await osd.screenshot({ path: `${OUT}/30-osd-volume.png` });
	const og = await osd.evaluate(() => Array.from(document.querySelectorAll("body *")).filter(e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.width < 400 && getComputedStyle(e).opacity !== "0"; }).slice(0, 40).map(e => { const r = e.getBoundingClientRect(); return [e.tagName, String(e.className.baseVal ?? e.className).slice(0, 40), Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)]; }));
	fs.writeFileSync(`${OUT}/30-osd.json`, JSON.stringify(og, null, 1));
	await browser.close();
})();
