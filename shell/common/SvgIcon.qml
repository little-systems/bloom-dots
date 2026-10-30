import QtQuick
import "icons.js" as Icons

// A Lucide icon recoloured by rewriting its SVG (stroke colour and width), so
// it follows the theme without a graphics effect pass.
Image {
	id: root

	required property string name
	property color color: "white"
	property real size: 12
	property real strokeWidth: 2

	width: size
	height: size
	sourceSize: Qt.size(Math.ceil(size * 2), Math.ceil(size * 2))
	fillMode: Image.PreserveAspectFit
	smooth: true

	source: {
		const svg = Icons.svg[root.name];
		if (!svg) {
			console.warn(`bloom: unknown icon "${root.name}"`);
			return "";
		}
		// SVG has no #aarrggbb: the colour goes in as rgb and its alpha as a
		// group opacity, which QtSvg composites as a whole, as browsers do, so
		// crossing strokes don't darken (Bloom's muted icons: white at 0.6).
		const c = root.color;
		const hex = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
		let painted = svg.replace(/currentColor/g, hex).replace('stroke-width="2"', `stroke-width="${root.strokeWidth}"`);
		if (c.a < 1)
			painted = painted.replace(/(<svg[^>]*>)/, `$1<g opacity="${Math.round(c.a * 1000) / 1000}">`).replace("</svg>", "</g></svg>");
		return "data:image/svg+xml;utf8," + encodeURIComponent(painted);
	}
}
