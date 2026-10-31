import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// Bloom's classic player (App.tsx compact-premium-layout): large album art
// beside the title, artist, visualizer, controls and volume. Clicking the art
// switches to the compact layout.
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
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal setVolume(real v)
	signal openMixer()
	signal switchLayout()

	readonly property var _c: Tokens.music.classic
	// One device pixel: Chromium draws the art's 0.5 px border that thick,
	// outside the 96 px of art (content-box). The owner sets 1 / scale.
	property real hairline: 1
	readonly property real _frame: root._c.art + 2 * root.hairline

	Row {
		anchors.verticalCenter: parent.verticalCenter
		spacing: root._c.gap

		PressArea {
			objectName: "bigArt"
			anchors.verticalCenter: parent.verticalCenter
			width: root._frame
			height: root._frame
			hoverScale: 1.05
			tapScale: 0.95
			onClicked: root.switchLayout()

			RectangularShadow {
				anchors.fill: parent
				offset.y: 4
				blur: 16
				radius: root._c.artRadius
				color: Qt.rgba(0, 0, 0, 0.4)
			}

			// box-shadow 0 0 0 0.5px rgba(255, 255, 255, 0.08): a ring outside.
			Rectangle {
				anchors.fill: parent
				anchors.margins: -0.5
				radius: root._c.artRadius + 0.5
				color: "transparent"
				border.width: 0.5
				border.color: Qt.rgba(1, 1, 1, 0.08)
			}

			AlbumArt {
				anchors.fill: parent
				anchors.margins: root.hairline
				source: root.media.artUrl
				radius: root._c.artRadius - root.hairline
				noteScale: 32 / root._c.art
				noteColor: Qt.rgba(1, 1, 1, 0.65)
				placeholderTop: Qt.rgba(1, 1, 1, 0.08)
				placeholderBottom: Qt.rgba(1, 1, 1, 0.02)
			}

			Rectangle {
				anchors.fill: parent
				radius: root._c.artRadius
				color: "transparent"
				border.width: root.hairline
				border.color: Qt.rgba(1, 1, 1, 0.1)
			}
		}

		Column {
			anchors.verticalCenter: parent.verticalCenter
			width: root.width - root._frame - root._c.gap
			spacing: root._c.columnGap

			Item {
				width: parent.width
				height: trackInfo.height

				Column {
					id: trackInfo
					width: parent.width - 30 - 12
					spacing: 1

					// .premium-title-wrap: a 20 px line whose strut sets the
					// 14.5 px title 2 px down.
					Item {
						width: parent.width
						height: 20

						TitleMarquee {
							y: 2
							width: parent.width
							text: root.media.title
							color: root.textColor
							pixelSize: 14.5
							weight: Font.DemiBold
							letterSpacing: -0.15
						}
					}

					Text {
						objectName: "artist"
						width: parent.width
						elide: Text.ElideRight
						text: root.media.artist
						color: root.textMuted
						font.family: Fonts.familyFor(Font.Normal)
						font.pixelSize: Fonts.px(12)
						font.weight: Font.Normal
					}
				}

				Item {
					anchors.right: parent.right
					y: 4
					width: 30
					height: root._c.vizHeight

					HoverHandler { id: vizHover }

					Visualizer {
						anchors.horizontalCenter: parent.horizontalCenter
						visible: root.visualizer
						active: visible && root.visible
						playing: root.media.isPlaying
						levels: root.levels
						barHeight: root._c.vizHeight
						color: root.textColor
						opacity: vizHover.hovered && root.mixerAvailable ? 0 : 0.8
						Behavior on opacity { NumberAnimation { duration: 200 } }
					}

					PressArea {
						objectName: "mixerButton"
						visible: root.mixerAvailable
						width: 20
						height: 20
						opacity: vizHover.hovered ? 1 : 0
						Behavior on opacity { NumberAnimation { duration: 200 } }
						onClicked: root.openMixer()

						SvgIcon {
							anchors.centerIn: parent
							name: "sf-headphones"
							size: 20
							color: root.textColor
							opacity: 0.5
						}
					}
				}
			}

			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: root._c.controlsGap

				SkipButton {
					objectName: "prevButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: false
					color: root.textColor
					onActivated: root.previousTrack()
				}

				PlayButton {
					objectName: "playButton"
					anchors.verticalCenter: parent.verticalCenter
					playing: root.media.isPlaying
					box: root._c.playBox
					iconSize: root._c.playIcon
					color: root.textColor
					hoverScale: 1.2
					stiffness: 400
					damping: 25
					onClicked: root.togglePlay()
				}

				SkipButton {
					objectName: "nextButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: true
					color: root.textColor
					onActivated: root.nextTrack()
				}
			}

			VolumeRow {
				width: parent.width
				height: root._c.volumeRow
				volume: root.muted ? 0 : root.volume
				trackHeight: root._c.track
				trackHoverHeight: root._c.track
				color: root.textColor
				onMoved: v => root.setVolume(v)
			}
		}
	}
}
