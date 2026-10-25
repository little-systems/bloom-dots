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
		// SVG has no #aarrggbb, so the colour goes in as rgb; use opacity for alpha.
		const c = root.color;
		const hex = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
		const painted = svg.replace(/currentColor/g, hex).replace('stroke-width="2"', `stroke-width="${root.strokeWidth}"`);
		return "data:image/svg+xml;utf8," + encodeURIComponent(painted);
	}
}
