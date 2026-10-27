// Rules for mapping Hyprland windows to Quickshell toplevel captures. Never
// match by title or app ID: two windows can share both of those strings.

function normalizeAddress(address) {
	if (typeof address !== "string" || !/^0x[0-9a-f]+$/i.test(address))
		return "";
	return address.toLowerCase();
}

function candidates(item, toplevels) {
	const byAddress = {};
	for (const t of toplevels || []) {
		const address = normalizeAddress(t.address);
		if (address && t.toplevel && !byAddress[address])
			byAddress[address] = t.toplevel;
	}
	return (item && item.windows || [])
		.filter(w => normalizeAddress(w.address))
		.map(w => ({
			address: normalizeAddress(w.address), title: w.title || "Untitled window",
			focus: w.focus, toplevel: byAddress[normalizeAddress(w.address)] || null
		}))
		.sort((a, b) => {
			const rank = w => w.focus >= 0 ? w.focus : Infinity;
			return rank(a) - rank(b) || a.address.localeCompare(b.address);
		});
}

function previewVisible(s) {
	if (!s.enabled || !s.running || s.menuOpen || s.dragging || s.hidden || s.suppressed)
		return false;
	if (s.cardHovered)
		return true;
	if (s.iconHovered)
		return s.now - s.hoverSince >= 300;
	return s.leaveAt >= 0 && s.now - s.leaveAt <= 100;
}

// Coordinates are in the unscaled dock surface, with a physical 8 px margin.
function previewPlacement(anchor, card, screen, scale) {
	const width = card.width * scale;
	const height = card.height * scale;
	const x = Math.max(8, Math.min(anchor.x + (anchor.width - width) / 2, screen.width - width - 8));
	const y = Math.max(8, Math.min(anchor.y - height - 20, screen.height - height - 8));
	return { x: x, y: y };
}

function liveCards(viewport, cards) {
	const out = [];
	for (let i = 0; i < cards.length && out.length < 3; i++)
		if (cards[i].right > viewport.left && cards[i].left < viewport.right)
			out.push(i);
	return out;
}
