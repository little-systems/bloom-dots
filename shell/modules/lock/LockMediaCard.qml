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
	readonly property real artworkSize: compact ? 96 : metrics.art
	readonly property real contentX: art.x + art.width + metrics.gap
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
		y: (root.height - height) / 2
		width: root.artworkSize
		height: width
		radius: root.metrics.artRadius
		source: root.media.artUrl || ""
		noteColor: root.theme.textMuted
	}
	Column {
		x: root.contentX
		y: root.compact ? 24 : 32
		width: root.width - x - root.metrics.padding
		spacing: 6
		Text {
			objectName: "mediaTitle"
			width: parent.width
			text: root.media.title || "Now Playing"
			textFormat: Text.PlainText
			elide: Text.ElideRight
			color: root.theme.text
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Fonts.px(19)
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
			font.pixelSize: Fonts.px(14)
		}
	}
	Row {
		x: root.contentX + (root.width - root.contentX - root.metrics.padding - width) / 2
		anchors.bottom: parent.bottom
		anchors.bottomMargin: root.compact ? 20 : 28
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
			iconWidth: 26
			iconHeight: 13
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
			iconSize: 30
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
			iconWidth: 26
			iconHeight: 13
			onActivated: root.nextRequested()
			Accessible.name: "Next track"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.nextRequested()
		}
	}
}
