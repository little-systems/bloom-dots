// Bloom's edge shine geometry and colours (components/edgeSurfaceContour.ts
// and EdgeSurface.css), for EdgeSurface's rim.

// SVG path of the surface's free edge, through the 13 px flares into the
// screen edge, in untransformed pixels of a top surface (a bottom surface is
// drawn flipped). radii: [rx, ry] for top-left, top-right, bottom-left,
// bottom-right. Without flares, a bottom surface whose back corners are
// rounded (the collapsed dock pill) is outlined all round.
function contour(width, height, radii, edge, flares) {
	const bottom = edge === "bottom";
	const left = 13;
	const right = width - 13;
	const radius = r => [Math.min(r[0], (right - left) / 2), Math.min(r[1], height / 2)];
	const rl = radius(radii[bottom ? 0 : 2]);
	const rr = radius(radii[bottom ? 1 : 3]);
	const backLeft = radius(radii[2]);
	const backRight = radius(radii[3]);
	if (bottom && !flares && (backLeft.some(r => r > 0) || backRight.some(r => r > 0))) {
		return `M ${left} ${backLeft[1]} A ${backLeft[0]} ${backLeft[1]} 0 0 1 ${left + backLeft[0]} 0 L ${right - backRight[0]} 0 A ${backRight[0]} ${backRight[1]} 0 0 1 ${right} ${backRight[1]}`
			+ ` L ${right} ${height - rr[1]} A ${rr[0]} ${rr[1]} 0 0 1 ${right - rr[0]} ${height} L ${left + rl[0]} ${height} A ${rl[0]} ${rl[1]} 0 0 1 ${left} ${height - rl[1]} Z`;
	}
	let path = flares ? "M 0 0 C 10 0 13 3 13 13" : `M ${left} 0`;
	path += ` L ${left} ${height - rl[1]} A ${rl[0]} ${rl[1]} 0 0 0 ${left + rl[0]} ${height}`;
	path += ` L ${right - rr[0]} ${height} A ${rr[0]} ${rr[1]} 0 0 0 ${right} ${height - rr[1]}`;
	path += flares ? ` L ${right} 13 C ${right} 3 ${width - 10} 0 ${width} 0` : ` L ${right} 0`;
	return path;
}

function _mix(a, b, amount) {
	return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1);
}

// --surface-line, --surface-side-light and --surface-highlight: the opaque
// fill mixed towards the text colour, then towards white.
function rimColors(solid, text) {
	const white = Qt.rgba(1, 1, 1, 1);
	const line = _mix(Qt.rgba(solid.r, solid.g, solid.b, 1), text, 0.18);
	return { line: line, side: _mix(line, white, 0.05), highlight: _mix(line, white, 0.14) };
}
