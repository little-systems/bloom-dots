import QtQuick
import "render"

// Text at a fractional pixel size (Bloom's 10.5, 9.5, 7.5 px). Qt rounds font
// sizes to whole pixels, so this draws at the next whole size and scales the
// glyphs down; its own box is the scaled size, as CSS lays it out.
Item {
	id: root

	property real pixelSize: 11
	property alias text: label.text
	property alias color: label.color
	property alias elide: label.elide
	property alias wrapMode: label.wrapMode
	property alias maximumLineCount: label.maximumLineCount
	property alias horizontalAlignment: label.horizontalAlignment
	property alias verticalAlignment: label.verticalAlignment
	property alias lineHeight: label.lineHeight
	property alias lineHeightMode: label.lineHeightMode
	property alias font: label.font
	readonly property alias truncated: label.truncated

	readonly property real _base: Math.ceil(root.pixelSize)
	readonly property real _k: root.pixelSize / root._base

	implicitWidth: label.implicitWidth * root._k
	implicitHeight: label.implicitHeight * root._k

	Text {
		id: label
		width: root.width / root._k
		height: root.height / root._k
		scale: root._k
		transformOrigin: Item.TopLeft
		font.pixelSize: Fonts.px(root._base)
	}
}
