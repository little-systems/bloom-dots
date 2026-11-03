import QtQuick
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch"

// Transport only: this is a child of the secure session-lock surface, never
// a desktop window, application launcher, volume mixer or authentication path.
Rectangle {
	id: root
	required property QtObject theme
	property var media: ({})
	property bool compact: false
	signal previousRequested()
	signal toggleRequested()
	signal nextRequested()

	readonly property var metrics: Tokens.lock.media
	height: compact ? metrics.smallHeight : metrics.height
	radius: metrics.radius
	color: root.theme.bgExpanded
	border.width: 1
	border.color: root.theme.border

	AlbumArt {
		id: art
		x: root.metrics.padding
		y: root.metrics.padding
		width: root.metrics.art
		height: width
		radius: root.metrics.artRadius
		source: root.media.artUrl || ""
		noteColor: root.theme.textMuted
	}
	Column {
		x: art.x + art.width + root.metrics.gap
		y: art.y + (art.height - height) / 2
		width: root.width - x - root.metrics.padding
		spacing: 3
		Text {
			objectName: "mediaTitle"
			width: parent.width
			text: root.media.title || "Now Playing"
			textFormat: Text.PlainText
			elide: Text.ElideRight
			color: root.theme.text
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Fonts.px(15)
			font.weight: Font.DemiBold
		}
		Text {
			objectName: "mediaArtist"
			width: parent.width
			text: root.media.artist || ""
			textFormat: Text.PlainText
			elide: Text.ElideRight
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Fonts.px(12)
		}
	}
	Row {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.bottom: parent.bottom
		anchors.bottomMargin: root.compact ? 6 : root.metrics.padding
		spacing: root.metrics.gap
		SkipButton {
			objectName: "mediaPrevious"
			enabled: root.media.canPrevious === true
			opacity: enabled ? 0.9 : 0.3
			forward: false
			color: root.theme.text
			boxWidth: root.metrics.button
			boxHeight: root.metrics.button
			padding: 0
			iconWidth: 22
			iconHeight: 11
			onActivated: root.previousRequested()
			Accessible.name: "Previous track"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.previousRequested()
		}
		PlayButton {
			objectName: "mediaToggle"
			enabled: root.media.canToggle === true
			opacity: enabled ? 1 : 0.3
			playing: root.media.isPlaying === true
			color: root.theme.text
			box: root.metrics.button
			iconSize: 24
			onClicked: root.toggleRequested()
			Accessible.name: playing ? "Pause" : "Play"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.toggleRequested()
		}
		SkipButton {
			objectName: "mediaNext"
			enabled: root.media.canNext === true
			opacity: enabled ? 0.9 : 0.3
			forward: true
			color: root.theme.text
			boxWidth: root.metrics.button
			boxHeight: root.metrics.button
			padding: 0
			iconWidth: 22
			iconHeight: 11
			onActivated: root.nextRequested()
			Accessible.name: "Next track"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.nextRequested()
		}
	}
}
