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
	readonly property real artworkSize: metrics.art
	readonly property real contentX: art.x + art.width + metrics.gap
	signal previousRequested()
	signal toggleRequested()
	signal nextRequested()
	signal seekRequested(real ms)
	signal volumeRequested(real value)
	function stamp(ms) { const seconds = Math.max(0, Math.floor((ms || 0) / 1000)); return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0"); }

	readonly property var metrics: Tokens.lock.media
	height: metrics.height
	radius: metrics.radius
	color: root.theme.bgExpanded
	border.width: 1
	border.color: root.theme.border

	AlbumArt {
		id: art
		x: root.metrics.padding
		y: root.metrics.padding
		width: root.artworkSize
		height: width
		radius: root.metrics.artRadius
		source: root.media.artUrl || ""
		noteColor: root.theme.textMuted
	}
	Column {
		x: root.contentX
		y: 17
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
		x: root.metrics.padding
		anchors.bottom: parent.bottom
		anchors.bottomMargin: 8
		spacing: 12
		SkipButton {
			objectName: "mediaPrevious"
			hoverScale: 1.12
			tapScale: 0.92
			enabled: root.media.canPrevious === true
			opacity: enabled ? 0.9 : 0.3
			forward: false
			color: root.theme.text
			boxWidth: root.metrics.button
			boxHeight: root.metrics.button
			padding: 0
			iconWidth: 24
			iconHeight: 16
			onActivated: root.previousRequested()
			Accessible.name: "Previous track"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.previousRequested()
		}
		PlayButton {
			objectName: "mediaToggle"
			hoverScale: 1.12
			tapScale: 0.92
			stiffness: 400
			damping: 25
			enabled: root.media.canToggle === true
			opacity: enabled ? 1 : 0.3
			playing: root.media.isPlaying === true
			color: root.theme.text
			box: root.metrics.button
			iconSize: 20
			onClicked: root.toggleRequested()
			Accessible.name: playing ? "Pause" : "Play"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.toggleRequested()
		}
		SkipButton {
			objectName: "mediaNext"
			hoverScale: 1.12
			tapScale: 0.92
			enabled: root.media.canNext === true
			opacity: enabled ? 0.9 : 0.3
			forward: true
			color: root.theme.text
			boxWidth: root.metrics.button
			boxHeight: root.metrics.button
			padding: 0
			iconWidth: 24
			iconHeight: 16
			onActivated: root.nextRequested()
			Accessible.name: "Next track"
			Accessible.role: Accessible.Button
			Accessible.onPressAction: if (enabled) root.nextRequested()
		}
	}
	Row {
		x: root.metrics.padding
		y: 69
		width: parent.width - 2 * x
		height: 18
		spacing: 8
		Text {
			width: 32
			text: root.stamp(root.media.positionMs)
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Fonts.px(10)
			anchors.verticalCenter: parent.verticalCenter
		}
		Item {
			width: parent.width - 80
			height: 18
			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width
				height: 3
				radius: 1.5
				color: root.theme.border
				Rectangle {
					width: parent.width * Math.max(0, Math.min(1, (root.media.positionMs || 0) / (root.media.lengthMs || 1)))
					height: parent.height
					radius: parent.radius
					color: root.theme.text
				}
			}
			MouseArea {
				objectName: "mediaSeek"
				anchors.fill: parent
				enabled: root.media.canSeek === true && root.media.lengthMs > 0
				cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
				onReleased: mouse => root.seekRequested(Math.max(0, Math.min(1, mouse.x / width)) * root.media.lengthMs)
			}
		}
		Text {
			width: 32
			text: root.stamp(root.media.lengthMs)
			color: root.theme.textMuted
			horizontalAlignment: Text.AlignRight
			font.family: Fonts.family
			font.pixelSize: Fonts.px(10)
			anchors.verticalCenter: parent.verticalCenter
		}
	}
	VolumeRow {
		objectName: "mediaVolume"
		anchors.right: parent.right
		anchors.rightMargin: root.metrics.padding
		y: root.height - 34
		width: 132
		volume: root.media.volume || 0
		enabled: root.media.canVolume === true
		opacity: enabled ? 1 : 0.35
		color: root.theme.text
		trackHeight: 3
		onMoved: value => root.volumeRequested(value)
	}

}
