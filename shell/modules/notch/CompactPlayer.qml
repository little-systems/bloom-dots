import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/media.js" as Fmt
import "../../common/render"

// Bloom's compact player (CompactMediaPlayer.tsx): small art, title and
// visualizer; a progress bar with seek when the track has a length; side
// buttons for the volume row and the audio output; the volume row slides open.
Item {
	id: root

	property var media: ({ title: "", artist: "", artUrl: "", isPlaying: false, lengthMs: 0, canSeek: false })
	property real positionMs: 0
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property bool visualizer: true
	property real volume: 0
	property bool muted: false
	property bool mixerAvailable: false
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.5)
	property bool volumeExpanded: false
	readonly property bool hasProgress: root.media.lengthMs > 0

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal setVolume(real v)
	signal openMixer()
	signal switchLayout()
	signal seekTo(real ms)

	readonly property var _c: Tokens.music.compact
	property bool _seeking: false
	property real _seekMs: 0
	readonly property real _shownMs: Math.min(root._seeking ? root._seekMs : root.positionMs, root.media.lengthMs || Infinity)

	Column {
		x: root._c.padding
		y: root._c.padding
		width: root.width - 2 * root._c.padding

		Row {
			width: parent.width
			height: root._c.art + root._c.infoBelow
			spacing: root._c.infoGap

			PressArea {
				width: root._c.art
				height: root._c.art
				tapScale: 1
				onClicked: root.switchLayout()

				RectangularShadow {
					anchors.fill: parent
					offset.y: 2
					blur: 8
					radius: root._c.artRadius
					color: Qt.rgba(0, 0, 0, 0.3)
				}

				AlbumArt {
					anchors.fill: parent
					source: root.media.artUrl
					radius: root._c.artRadius
					noteScale: 22 / root._c.art
					noteColor: Qt.rgba(1, 1, 1, 0.4)
					placeholderTop: Qt.rgba(1, 1, 1, 0.08)
					placeholderBottom: Qt.rgba(1, 1, 1, 0.08)
				}
			}

			// .cmp-track: the title's 20 px line (its strut sets the title 2 px
			// down), 1 px, then the artist. CSS's line-height: 1.2 is a box of
			// 1.2 × the font size with the glyphs centred in it; Qt's
			// lineHeight scales the font's own line instead, so each text is
			// placed in its CSS box by hand.
			Item {
				width: parent.width - root._c.art - (root.visualizer ? 30 + root._c.infoGap : 0) - root._c.infoGap
				height: 20 + 1 + 12 * 1.2
				y: (root._c.art - height) / 2

				TitleMarquee {
					y: 2 + (15 * 1.2 - implicitHeight) / 2
					width: parent.width
					text: root.media.title
					color: root.textColor
					pixelSize: 15
					weight: Font.DemiBold
					letterSpacing: -0.2
				}

				Text {
					objectName: "artist"
					y: 21 + (12 * 1.2 - implicitHeight) / 2
					width: parent.width
					elide: Text.ElideRight
					text: root.media.artist
					color: root.textMuted
					font.family: Fonts.familyFor(Font.Normal)
					font.pixelSize: 12
					font.weight: Font.Normal
				}
			}

			// .cmp-visualizer: 30 px, its bars centred.
			Item {
				visible: root.visualizer
				width: 30
				height: root._c.art

				Visualizer {
					anchors.centerIn: parent
					visible: root.visualizer
					active: visible && root.visible
					opacity: 0.7
					playing: root.media.isPlaying
					levels: root.levels
					barHeight: root._c.vizHeight
					color: root.textColor
				}
			}
		}

		// .cmp-row-progress: 3 px above and below a 14 px line.
		Row {
			objectName: "progressRow"
			visible: root.hasProgress
			width: parent.width
			height: visible ? 2 * root._c.progressPad + 14 : 0
			spacing: root._c.progressGap

			// min-width: 30px; a longer time widens its box.
			Text {
				id: elapsed
				objectName: "elapsed"
				width: Math.max(root._c.timeWidth, implicitWidth)
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignHCenter
				text: Fmt.formatTime(root._shownMs)
				color: root.textMuted
				font.family: Fonts.familyFor(Font.Medium)
				font.pixelSize: root._c.time
				font.weight: Font.Medium
				font.features: { "tnum": 1 }
			}

			Item {
				objectName: "progressBar"
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - elapsed.width - remaining.width - 2 * root._c.progressGap
				height: 12

				HoverHandler { id: barHover }

				Rectangle {
					objectName: "progressTrack"
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					height: barHover.hovered ? root._c.barHover : root._c.bar
					radius: 2
					color: Qt.rgba(1, 1, 1, 0.15)

					Rectangle {
						height: parent.height
						radius: 2
						color: root.textColor
						width: root.media.lengthMs > 0 ? parent.width * Math.min(1, root._shownMs / root.media.lengthMs) : 0
					}
				}

				// Bloom .cmp-seek { cursor: pointer }
				MouseArea {
					anchors.fill: parent
					cursorShape: root.media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
					enabled: root.media.canSeek
					function at(mx) { return Math.max(0, Math.min(1, mx / width)) * root.media.lengthMs; }
					onPressed: mouse => { root._seeking = true; root._seekMs = at(mouse.x); }
					onPositionChanged: mouse => { if (pressed) root._seekMs = at(mouse.x); }
					onReleased: mouse => {
						root._seekMs = at(mouse.x);
						root.seekTo(root._seekMs);
						root._seeking = false;
					}
				}
			}

			Text {
				id: remaining
				objectName: "remaining"
				width: Math.max(root._c.timeWidth, implicitWidth)
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignHCenter
				text: Fmt.formatRemaining(root._shownMs, root.media.lengthMs)
				color: root.textMuted
				font.family: Fonts.familyFor(Font.Medium)
				font.pixelSize: root._c.time
				font.weight: Font.Medium
				font.features: { "tnum": 1 }
			}
		}

		Item {
			width: parent.width
			height: root._c.controlsAbove + root._c.playBox

			PressArea {
				objectName: "speakerButton"
				x: 0
				y: root._c.controlsAbove + (root._c.playBox - height) / 2
				width: root._c.sideIcon + 2 * root._c.buttonPadding
				height: width
				opacity: hovered ? 0.8 : 0.5
				onClicked: root.volumeExpanded = !root.volumeExpanded

				SvgIcon {
					anchors.centerIn: parent
					name: root.volume === 0 || root.muted ? "sf-speaker.slash.fill" : "sf-speaker.wave.2.fill"
					size: root._c.sideIcon
					color: root.textColor
				}
			}

			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				y: root._c.controlsAbove
				spacing: root._c.mainGap

				SkipButton {
					objectName: "prevButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: false
					iconWidth: root._c.skipIcon
					iconHeight: root._c.skipIcon / 2
					boxWidth: root._c.skipBox
					boxHeight: root._c.skipBox
					padding: root._c.buttonPadding
					hoverScale: 1
					stiffness: 550
					damping: 30
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onActivated: root.previousTrack()
				}

				PlayButton {
					objectName: "playButton"
					playing: root.media.isPlaying
					box: root._c.playBox
					iconSize: root._c.playIcon
					swapScale: 0.7
					swapMs: 120
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onClicked: root.togglePlay()
				}

				SkipButton {
					objectName: "nextButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: true
					iconWidth: root._c.skipIcon
					iconHeight: root._c.skipIcon / 2
					boxWidth: root._c.skipBox
					boxHeight: root._c.skipBox
					padding: root._c.buttonPadding
					hoverScale: 1
					stiffness: 550
					damping: 30
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onActivated: root.nextTrack()
				}
			}

			PressArea {
				objectName: "mixerButton"
				visible: root.mixerAvailable
				anchors.right: parent.right
				y: root._c.controlsAbove + (root._c.playBox - height) / 2
				width: root._c.sideIcon + 2 * root._c.buttonPadding
				height: width
				opacity: hovered ? 0.8 : 0.5
				onClicked: root.openMixer()

				SvgIcon {
					anchors.centerIn: parent
					name: "sf-headphones"
					size: root._c.sideIcon
					color: root.textColor
				}
			}
		}

		Item {
			width: parent.width
			height: volumeSpring.value
			clip: true
			opacity: volumeOpacity.value

			Spring { id: volumeSpring; stiffness: 500; damping: 30; initial: 0; target: root.volumeExpanded ? root._c.volumeHeight : 0 }
			Spring { id: volumeOpacity; stiffness: 500; damping: 30; initial: 0; target: root.volumeExpanded ? 1 : 0 }

			VolumeRow {
				y: 6
				width: parent.width
				volume: root.muted ? 0 : root.volume
				trackHeight: root._c.volumeTrack
				trackHoverHeight: root._c.volumeTrackHover
				color: root.textColor
				onMoved: v => root.setVolume(v)
			}
		}
	}
}
