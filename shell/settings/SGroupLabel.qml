import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's .setting-group-label.
Text {
	property QtObject theme
	property real above: Tokens.settings.group.label.top
	width: parent.width
	leftPadding: Tokens.settings.group.label.h
	topPadding: above
	bottomPadding: Tokens.settings.group.label.bottom
	color: theme.textMuted
	font.family: Fonts.familyFor(Font.DemiBold)
	font.pixelSize: Tokens.settings.group.label.size
	font.weight: Font.DemiBold
	font.letterSpacing: Tokens.settings.group.label.spacing
	font.capitalization: Font.AllUppercase
}
