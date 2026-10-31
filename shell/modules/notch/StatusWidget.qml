import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// One status widget (Bloom .passive-feature): a 12 px icon and an 11 px label.
// The battery widget draws Bloom's battery glyph instead of a Lucide icon.
Row {
	id: root

	required property string widgetId
	property string icon: ""
	property real strokeWidth: 2
	property string label: ""
	property color textColor: "white"
	property var battery: null
	readonly property bool hovered: hover.hovered
	readonly property Item tooltipAnchor: root

	objectName: "widget-" + widgetId
	spacing: Tokens.statusStrip.itemGap
	height: 14

	HoverHandler { id: hover }

	BatteryIcon {
		visible: root.widgetId === "battery"
		anchors.verticalCenter: parent.verticalCenter
		level: root.battery?.level ?? 0
		charging: root.battery?.charging ?? false
		threshold: root.battery?.threshold ?? 20
		color: root.textColor
	}

	SvgIcon {
		visible: root.widgetId !== "battery"
		anchors.verticalCenter: parent.verticalCenter
		name: root.icon || "thermometer"
		size: Tokens.statusStrip.iconSize
		strokeWidth: root.strokeWidth
		color: root.textColor
	}

	Text {
		anchors.verticalCenter: parent.verticalCenter
		// Bloom nudges the label 0.5 px down for Inter's baseline.
		anchors.verticalCenterOffset: 0.5
		text: root.label
		color: root.textColor
		opacity: Tokens.statusStrip.labelOpacity
		font.family: Fonts.familyFor(Font.Medium)
		font.pixelSize: Fonts.px(Tokens.statusStrip.labelSize)
		font.weight: Font.Medium
	}
}
