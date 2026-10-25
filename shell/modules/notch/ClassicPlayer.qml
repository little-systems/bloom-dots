import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens

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

	Row {
		anchors.verticalCenter: parent.verticalCenter
		spacing: root._c.gap

		PressArea {
			objectName: "bigArt"
			width: root._c.art
			height: root._c.art
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

			AlbumArt {
				anchors.fill: parent
				source: root.media.artUrl
				radius: root._c.artRadius
				noteScale: 32 / root._c.art
				noteColor: Qt.rgba(1, 1, 1, 0.65)
				placeholderTop: Qt.rgba(1, 1, 1, 0.08)
				placeholderBottom: Qt.rgba(1, 1, 1, 0.02)
			}

			Rectangle {
				anchors.fill: parent
				radius: root._c.artRadius
				color: "transparent"
				border.width: 0.5
				border.color: Qt.rgba(1, 1, 1, 0.1)
			}
		}

		Column {
			anchors.verticalCenter: parent.verticalCenter
			width: root.width - root._c.art - root._c.gap
			spacing: root._c.columnGap

			Item {
				width: parent.width
				height: trackInfo.height

				Column {
					id: trackInfo
					width: parent.width - 30 - 12
					spacing: 1

					TitleMarquee {
						width: parent.width
						text: root.media.title
						color: root.textColor
						pixelSize: 14.5
						weight: Font.DemiBold
						letterSpacing: -0.15
					}

					Text {
						width: parent.width
						elide: Text.ElideRight
						text: root.media.artist
						color: root.textMuted
						font.family: Tokens.type.family
						font.pixelSize: 12
					}
				}

				Item {
					anchors.right: parent.right
					y: 4
					width: 30
					height: root._c.vizHeight

					HoverHandler { id: vizHover }

					Visualizer {
						visible: root.visualizer
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
