// Bloom theme maths, ported from Bloom src/theme.ts (b5fb962) so colours
// match exactly. Colours are {r, g, b, a}: channels 0-255, alpha 0-1.

function _rgba(r, g, b, a) {
	return { r: r, g: g, b: b, a: a };
}

function _expand(hex) {
	hex = hex.replace("#", "");
	if (hex.length === 3)
		hex = hex.split("").map(c => c + c).join("");
	return hex;
}

function _hexToRgb(hex, a) {
	hex = _expand(hex);
	return _rgba(parseInt(hex.substring(0, 2), 16) || 0, parseInt(hex.substring(2, 4), 16) || 0, parseInt(hex.substring(4, 6), 16) || 0, a);
}

function hexToHsl(hex) {
	hex = _expand(hex);
	const r = (parseInt(hex.substring(0, 2), 16) || 0) / 255;
	const g = (parseInt(hex.substring(2, 4), 16) || 0) / 255;
	const b = (parseInt(hex.substring(4, 6), 16) || 0) / 255;
	const max = Math.max(r, g, b);
	const min = Math.min(r, g, b);
	let h = 0;
	let s = 0;
	const l = (max + min) / 2;
	if (max !== min) {
		const d = max - min;
		s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
		switch (max) {
		case r:
			h = (g - b) / d + (g < b ? 6 : 0);
			break;
		case g:
			h = (b - r) / d + 2;
			break;
		case b:
			h = (r - g) / d + 4;
			break;
		}
		h /= 6;
	}
	return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
}

function hslToHex(h, s, l) {
	s /= 100;
	l /= 100;
	const c = (1 - Math.abs(2 * l - 1)) * s;
	const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
	const m = l - c / 2;
	let r = 0, g = 0, b = 0;
	if (0 <= h && h < 60) { r = c; g = x; b = 0; }
	else if (60 <= h && h < 120) { r = x; g = c; b = 0; }
	else if (120 <= h && h < 180) { r = 0; g = c; b = x; }
	else if (180 <= h && h < 240) { r = 0; g = x; b = c; }
	else if (240 <= h && h < 300) { r = x; g = 0; b = c; }
	else if (300 <= h && h < 360) { r = c; g = 0; b = x; }
	const toHex = val => {
		const hexVal = Math.round((val + m) * 255).toString(16);
		return hexVal.length === 1 ? "0" + hexVal : hexVal;
	};
	return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

// Mirrors Bloom's applyTheme(). For adaptive, `adaptiveAccent` is the
// wallpaper accent; while it is null (no wallpaper theming yet) the theme
// falls back to dark, as Bloom does when the system accent is unavailable.
function compute(mode, customColor, opacity, saturation, brightness, adaptiveAccent) {
	const op = opacity;
	const opExpanded = Math.min(1, opacity + 0.12);

	if (mode === "light") {
		return {
			mode: "light",
			isLight: true,
			bg: _rgba(255, 255, 255, op),
			bgExpanded: _rgba(245, 245, 247, opExpanded),
			text: _rgba(28, 28, 30, 1),
			textMuted: _rgba(28, 28, 30, 0.65),
			border: _rgba(0, 0, 0, 0.12),
			groupBg: _rgba(0, 0, 0, 0.04),
			accent: _rgba(0, 122, 255, 1),
			scrollbarThumb: _rgba(0, 0, 0, 0.15)
		};
	}

	if (mode === "custom" || (mode === "adaptive" && adaptiveAccent)) {
		const accent = mode === "custom" ? customColor : adaptiveAccent;
		const hsl = hexToHsl(accent);
		const bg = _hexToRgb(hslToHex(hsl.h, saturation * 100, brightness * 100), op);
		const light = brightness > 0.55;
		const ink = light ? 0 : 255;
		return {
			mode: mode,
			isLight: light,
			bg: bg,
			bgExpanded: _rgba(bg.r, bg.g, bg.b, opExpanded),
			text: light ? _rgba(28, 28, 30, 1) : _rgba(255, 255, 255, 1),
			textMuted: light ? _rgba(28, 28, 30, 0.65) : _rgba(255, 255, 255, 0.65),
			border: _rgba(ink, ink, ink, 0.12),
			groupBg: _rgba(ink, ink, ink, 0.04),
			accent: _hexToRgb(accent, 1),
			scrollbarThumb: _rgba(ink, ink, ink, 0.15)
		};
	}

	return {
		mode: "dark",
		isLight: false,
		bg: _rgba(0, 0, 0, op),
		bgExpanded: _rgba(0, 0, 0, opExpanded),
		text: _rgba(255, 255, 255, 1),
		textMuted: _rgba(255, 255, 255, 0.6),
		border: _rgba(255, 255, 255, 0.1),
		groupBg: _rgba(255, 255, 255, 0.04),
		accent: _rgba(0, 122, 255, 1),
		scrollbarThumb: _rgba(255, 255, 255, 0.1)
	};
}
