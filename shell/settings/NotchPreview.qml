import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "../modules/notch"
import "logic.js" as Logic
import "preview.js" as Preview

// Bloom's NotchPreview: the real pill, with sample content, on the preview's
// spring. Player controls drive a sample track and never touch real media.
Item {
	id: root
	property QtObject theme
	property var values
	required property string feature
	property bool revealed: false
	property int runId: 0

	anchors.fill: parent

	property bool musicOpen: root.feature === "music"
	property string layout: root.values["bloom-media-layout"]
	property bool volumeOpen: false
	property int track: 0
	property bool playing: true
	property real position: 42
	property real volume: 0.65
	readonly property int duration: 200
	readonly property var _sample: Preview.TRACKS[root.track]
	readonly property var _media: ({ title: root._sample.title, artist: root._sample.artist, artUrl: "", isPlaying: root.playing, lengthMs: root.duration * 1000 })
	readonly property var _widgets: root.values["bloom-status-widgets"]
	readonly property bool _peek: root.feature === "resting" && root.values["bloom-notch-mode"] === "peek"
	readonly property bool _fixed: root.values["bloom-notch-mode"] === "fixed"
	readonly property bool _lowBattery: 15 <= root.values["bloom-low-battery-threshold"]
	readonly property bool _musicOff: root.feature === "music" && !root.values["bloom-music-mode-enabled"]
	readonly property real _targetWidth: Preview.pillWidth(root.feature, root.values, root._widgets.left.length + root._widgets.right.length, root.musicOpen, root.layout)
	readonly property real _targetHeight: Preview.pillHeight(root.feature, root.musicOpen, root.layout, root.volumeOpen)

	function _skip(step) {
		root.track = (root.track + step + Preview.TRACKS.length) % Preview.TRACKS.length;
		root.position = 0;
	}

	Timer {
		interval: 1000
		repeat: true
		running: root.feature === "music" && root.musicOpen && root.playing
		onTriggered: root.position = root.position >= root.duration ? 0 : root.position + 1
	}

	Spring { id: w; stiffness: 450; damping: 32; initial: 40; target: root._targetWidth }
	Spring { id: h; stiffness: 450; damping: 32; initial: 36; target: root._targetHeight }
	Spring { id: y; stiffness: 450; damping: 32; initial: root._fixed ? -12 : -80; target: root._peek && !root.revealed ? -27 : 0 }

	Text {
		objectName: "previewEmpty"
		visible: root._musicOff
		anchors.centerIn: parent
		text: "Music mode is off"
		color: root.theme.textMuted
		font.family: Fonts.family
		font.pixelSize: 12
	}

	Item {
		id: pill
		objectName: "previewPill"
		readonly property real targetWidth: root._targetWidth
		visible: !root._musicOff
		x: (root.width - width) / 2
		y: y.value
		width: Math.max(0, w.value)
		height: Math.max(0, h.value)
		clip: false

		EdgeSurface {
			x: 0
			y: 0
			edge: "top"
			pillWidth: pill.width
			pillHeight: pill.height
			color: root.theme.bgExpanded
		}
		HoverHandler { cursorShape: root.feature === "music" && !root.musicOpen ? Qt.PointingHandCursor : Qt.ArrowCursor }
		TapHandler {
			enabled: root.feature === "music" && !root.musicOpen
			onTapped: root.musicOpen = true
		}

		// Bloom's sides around .time-center: the clock stays centred.
		Item {
			visible: root.feature === "clock" || root.feature === "theme" || root.feature === "resting"
			anchors.fill: parent

			Row {
				id: timeRow
				anchors.centerIn: parent
				spacing: 5
				Text {
					objectName: "previewClock"
					text: Preview.clock(root.values["bloom-time-format-24h"])
					color: root.theme.text
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: 13
					font.weight: Font.DemiBold
					anchors.verticalCenter: parent.verticalCenter
				}
				Rectangle {
					objectName: "previewUpdateDot"
					visible: root.values["bloom-show-update-indicator"]
					width: 5
					height: 5
					radius: 2.5
					color: "#32d74b"
					anchors.verticalCenter: parent.verticalCenter
				}
			}
			Row {
				anchors.right: timeRow.left
				anchors.rightMargin: 8
				anchors.verticalCenter: parent.verticalCenter
				spacing: 8
				Repeater {
					model: root.feature === "resting" ? root._widgets.left.filter(id => id !== "weather" || root.values["bloom-weather-enabled"]) : []
					delegate: PreviewWidget { theme: root.theme; values: root.values; anchors.verticalCenter: parent.verticalCenter }
				}
			}
			Row {
				anchors.left: timeRow.right
				anchors.leftMargin: 8
				anchors.verticalCenter: parent.verticalCenter
				spacing: 8
				Repeater {
					model: root.feature === "resting" ? root._widgets.right.filter(id => id !== "weather" || root.values["bloom-weather-enabled"]) : []
					delegate: PreviewWidget { theme: root.theme; values: root.values; anchors.verticalCenter: parent.verticalCenter }
				}
			}
		}

		Row {
			visible: root.feature === "battery"
			anchors.centerIn: parent
			spacing: 6
			SvgIcon {
				name: "battery-warning"
				size: 16
				color: root._lowBattery ? "#ff453a" : root.theme.text
				anchors.verticalCenter: parent.verticalCenter
			}
			Text {
				objectName: "previewBattery"
				text: (root._lowBattery ? "Low Battery" : "On Battery") + " · 15%"
				color: root._lowBattery ? "#ff453a" : root.theme.text
				font.family: Fonts.familyFor(Font.Medium)
				font.pixelSize: 12
				font.weight: Font.Medium
				anchors.verticalCenter: parent.verticalCenter
			}
		}

		Row {
			visible: root.feature === "device"
			anchors.centerIn: parent
			spacing: 10
			DeviceArt {
				art: "flash-drive"
				runId: root.runId
				width: 60
				height: 60
				anchors.verticalCenter: parent.verticalCenter
			}
			Column {
				anchors.verticalCenter: parent.verticalCenter
				Text {
					text: "Flash drive"
					color: root.theme.text
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: 13
					font.weight: Font.DemiBold
				}
				Text {
					text: "Plugged in"
					color: root.theme.textMuted
					font.family: Fonts.family
					font.pixelSize: 11
				}
			}
		}

		// The collapsed music pill: bars, the clock, then the sample art.
		Item {
			visible: root.feature === "music" && !root.musicOpen
			anchors.fill: parent
			Row {
				x: 16
				anchors.verticalCenter: parent.verticalCenter
				spacing: 2
				Repeater {
					model: 5
					delegate: Rectangle {
						required property int index
						anchors.verticalCenter: parent.verticalCenter
						width: 2
						radius: 1
						height: 5 + [8, 3, 10, 5, 7][index]
						color: root.theme.accent ?? "#007aff"
					}
				}
			}
			Text {
				anchors.centerIn: parent
				text: Preview.clock(root.values["bloom-time-format-24h"])
				color: root.theme.text
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: 13
				font.weight: Font.DemiBold
			}
			Rectangle {
				objectName: "previewArt"
				x: parent.width - width - 14
				anchors.verticalCenter: parent.verticalCenter
				width: 20
				height: 20
				radius: 6
				color: root.theme.groupBg
				SvgIcon { anchors.centerIn: parent; name: "music"; size: 11; color: root.theme.textMuted }
			}
		}

		Loader {
			active: root.feature === "music" && root.musicOpen
			anchors.fill: parent
			sourceComponent: root.layout === "compact" ? compactPlayer : classicPlayer
		}
		Component {
			id: classicPlayer
			ClassicPlayer {
				anchors.fill: parent
				media: root._media
				positionMs: root.position * 1000
				volume: root.volume
				textColor: root.theme.text
				textMuted: root.theme.textMuted
				onTogglePlay: root.playing = !root.playing
				onPreviousTrack: root._skip(-1)
				onNextTrack: root._skip(1)
				onSetVolume: v => root.volume = v
				onSwitchLayout: root.layout = "compact"
			}
		}
		Component {
			id: compactPlayer
			CompactPlayer {
				anchors.fill: parent
				media: root._media
				positionMs: root.position * 1000
				volume: root.volume
				textColor: root.theme.text
				textMuted: root.theme.textMuted
				onTogglePlay: root.playing = !root.playing
				onPreviousTrack: root._skip(-1)
				onNextTrack: root._skip(1)
				onSetVolume: v => root.volume = v
				onSwitchLayout: root.layout = "classic"
			}
		}
	}

	Rectangle {
		objectName: "previewPlayerToggle"
		visible: root.feature === "music" && !root._musicOff
		x: parent.width - width - 9
		y: parent.height - height - 8
		width: toggleText.implicitWidth + 16
		height: 22
		radius: 11
		color: Qt.rgba(0, 0, 0, 0.5)
		Text {
			id: toggleText
			anchors.centerIn: parent
			text: root.musicOpen ? "Collapse notch" : "Open player"
			color: "white"
			font.family: Fonts.family
			font.pixelSize: 10
		}
		HoverHandler { cursorShape: Qt.PointingHandCursor }
		TapHandler {
			onTapped: {
				root.musicOpen = !root.musicOpen;
				root.volumeOpen = false;
			}
		}
	}
}
