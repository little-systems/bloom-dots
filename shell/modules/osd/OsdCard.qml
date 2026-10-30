import QtQuick
import QtQuick.Effects
import "../../common"
import "."
import "../../common/tokens.js" as Tokens
import "../../common/spring.js" as SpringMath
import "../../common/render"

// Bloom's volume (left edge) and brightness (right edge) HUDs: Overlay.tsx
// VolumeNotch, BrightnessNotch and MixerTile, Overlay.css. Drawn at 1x; the
// window scales it. Pure: values come in, choices go out as signals.
Item {
	id: root

	property string edge: "left"
	property QtObject theme: QtObject {
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color bg: Qt.rgba(0, 0, 0, 0.8)
		property color border: Qt.rgba(1, 1, 1, 0.1)
		property color groupBg: Qt.rgba(1, 1, 1, 0.04)
	}
	property bool light: false
	property bool shown: false
	// 0..1: the volume or the brightness.
	property real value: 0
	property bool muted: false
	property bool mixerOpen: false
	// The mixer's apps: { id, name, icon (a URL or ""), volume, muted }.
	property var sessions: []

	// Drawn, coming or going: the window's input mask follows it.
	readonly property bool onScreen: card.visible

	signal valueChosen(real value)

	// A wheel notch (120 units) is 5 % (owner, 2026-10-29); touchpads scroll
	// by pixels, 100 px a notch.
	function _wheelValue(from, wheel) {
		const px = wheel.pixelDelta.y;
		const notches = px !== 0 ? px / 100 : wheel.angleDelta.y / 120;
		return Math.max(0, Math.min(1, from + notches * 0.05));
	}
	signal mixerToggled()
	signal sessionVolumeChosen(var id, real volume)
	signal sessionMuteToggled(var id)

	// The action's icon and percentage swap: 0.16 s CSS ease.
	component Swap: NumberAnimation {
		duration: Tokens.osd.action.ms
		easing.type: Easing.BezierSpline
		easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
	}

	readonly property bool _left: root.edge === "left"
	readonly property int _columns: root.sessions.length === 0 ? Tokens.osd.mixer.emptyColumns : Math.min(root.sessions.length, Tokens.osd.mixer.maxColumns)
	readonly property real mixerWidth: Tokens.osd.mixer.pad.side * 2 + root._columns * Tokens.osd.mixer.column + (root._columns - 1) * Tokens.osd.mixer.gap
	readonly property color _track: root.light ? Qt.rgba(0, 0, 0, Tokens.osd.bar.trackLight) : Qt.rgba(1, 1, 1, Tokens.osd.bar.track)
	readonly property var _cssEase: [0.25, 0.1, 0.25, 1, 1, 1]

	// Bloom flashes the percentage in place of the icon for 1.2 s whenever
	// the volume changes, and as the card appears.
	property bool showingPercent: false
	function _flash() {
		if (!root._left) return;
		root.showingPercent = true;
		percentTimer.restart();
	}
	onValueChanged: root._flash()
	onMutedChanged: root._flash()
	Timer { id: percentTimer; interval: Tokens.osd.percentMs; onTriggered: root.showingPercent = false }

	width: surface.width
	height: surface.height

	// ---- Entrance and exit (the wrapper's motion) ----

	// Shown: a 450/25/0.7 spring on scale, opacity and blur from the edge.
	// Hidden: 0.2 s out to scaleX 0, scaleY 0.8 (or, with the mixer open,
	// 64 px back into the edge), as one surface.
	Spring { id: sxS; stiffness: Tokens.osd.enter.stiffness; damping: Tokens.osd.enter.damping; mass: Tokens.osd.enter.mass; initial: 0; target: 1; autoRun: root.shown }
	Spring { id: syS; stiffness: Tokens.osd.enter.stiffness; damping: Tokens.osd.enter.damping; mass: Tokens.osd.enter.mass; initial: Tokens.osd.enter.scaleYFrom; target: 1; autoRun: root.shown }
	Spring { id: opS; stiffness: Tokens.osd.enter.stiffness; damping: Tokens.osd.enter.damping; mass: Tokens.osd.enter.mass; initial: 0; target: 1; autoRun: root.shown }
	Spring { id: blS; stiffness: Tokens.osd.enter.stiffness; damping: Tokens.osd.enter.damping; mass: Tokens.osd.enter.mass; initial: Tokens.osd.enter.blur; target: 0; autoRun: root.shown }
	property real _exitX: 0

	onShownChanged: {
		if (root.shown) {
			leave.stop();
			root._exitX = 0;
			// Back from the edge, as framer replays the initial state on mount.
			sxS.jump(0);
			syS.jump(Tokens.osd.enter.scaleYFrom);
			opS.jump(0);
			blS.jump(Tokens.osd.enter.blur);
			sxS.target = 1; syS.target = 1; opS.target = 1; blS.target = 0;
			sxS.settled = false; syS.settled = false; opS.settled = false; blS.settled = false;
			contentIn.restart();
			root._flash();
		} else {
			leaveMixer.running = false;
			if (root.mixerOpen) leaveMixer.restart();
			else leave.restart();
			contentOut.restart();
		}
	}

	ParallelAnimation {
		id: leave
		readonly property var curve: Tokens.osd.exit.ease.concat([1, 1])
		NumberAnimation { target: sxS; property: "value"; to: 0; duration: Tokens.osd.exit.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leave.curve }
		NumberAnimation { target: syS; property: "value"; to: Tokens.osd.exit.scaleY; duration: Tokens.osd.exit.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leave.curve }
		NumberAnimation { target: opS; property: "value"; to: 0; duration: Tokens.osd.exit.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leave.curve }
		NumberAnimation { target: blS; property: "value"; to: Tokens.osd.exit.blur; duration: Tokens.osd.exit.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leave.curve }
	}

	ParallelAnimation {
		id: leaveMixer
		readonly property var curve: Tokens.osd.exit.ease.concat([1, 1])
		NumberAnimation { target: root; property: "_exitX"; to: Tokens.osd.exitMixer.x; duration: Tokens.osd.exitMixer.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leaveMixer.curve }
		NumberAnimation { target: opS; property: "value"; to: 0; duration: Tokens.osd.exitMixer.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leaveMixer.curve }
		NumberAnimation { target: blS; property: "value"; to: Tokens.osd.exitMixer.blur; duration: Tokens.osd.exitMixer.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: leaveMixer.curve }
	}

	Item {
		id: card
		objectName: "motion"
		readonly property real sx: sxS.value
		width: surface.width
		height: surface.height
		opacity: Math.max(0, Math.min(1, opS.value))
		visible: opacity > 0
		transform: [
			Scale {
				origin.x: root._left ? 0 : card.width
				origin.y: card.height / 2
				xScale: Math.max(0, sxS.value)
				yScale: Math.max(0, syS.value)
			},
			Translate {
				x: root._left ? root._exitX : -root._exitX
			}
		]
		// filter: blur(), only while it moves.
		layer.enabled: blS.value > 0.05
		layer.textureSize: Render.texture(width, height)
		layer.effect: MultiEffect {
			blurEnabled: true
			blurMax: 24
			blur: Math.min(1, blS.value / 24)
		}

		// .volume-notch: 42 px, wider with the mixer (a 0.35 s spring, no bounce).
		property real cardWidth: Tokens.osd.card.width + (root.mixerOpen ? root.mixerWidth : 0)
		readonly property var _widthSpring: SpringMath.springFromDuration(Tokens.osd.mixer.widthSpring.duration, Tokens.osd.mixer.widthSpring.bounce)
		Spring {
			id: widthS
			stiffness: card._widthSpring.stiffness
			damping: card._widthSpring.damping
			initial: Tokens.osd.card.width
			target: card.cardWidth
		}

		EdgeSurface {
			id: surface
			edge: root.edge
			pillWidth: widthS.value
			pillHeight: Tokens.osd.card.height
			farRadius: Tokens.osd.card.radius
			flares: root.shown
			color: root.theme.bg
		}

		Item {
			id: box
			objectName: "card"
			x: surface.pillRect.x
			y: surface.pillRect.y
			width: surface.pillRect.width
			height: surface.pillRect.height
			clip: true

			// Scrolling the card changes the value (Bloom has no wheel here).
			MouseArea {
				anchors.fill: parent
				acceptedButtons: Qt.NoButton
				onWheel: wheel => {
					root.valueChosen(root._wheelValue(root.value, wheel));
					wheel.accepted = true;
				}
			}

			// .volume-notch-content-group: slides in 10 px from the edge.
			Item {
				id: content
				x: root._left ? 0 : box.width - width
				width: Tokens.osd.card.width
				height: box.height
				property real slide: 0
				transform: Translate { x: root._left ? content.slide : -content.slide }

				ParallelAnimation {
					id: contentIn
					NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: Tokens.osd.content.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
					NumberAnimation { target: content; property: "slide"; from: -Tokens.osd.content.x; to: 0; duration: Tokens.osd.content.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
				}
				ParallelAnimation {
					id: contentOut
					NumberAnimation { target: content; property: "opacity"; to: 0; duration: Tokens.osd.content.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
					NumberAnimation { target: content; property: "slide"; to: -Tokens.osd.content.exitX; duration: Tokens.osd.content.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
				}

				Rectangle {
					id: bar
					objectName: "bar"
					x: (parent.width - width) / 2
					y: root._left ? Tokens.osd.volumePad.top : Tokens.osd.brightnessPad + Tokens.osd.brightnessBar.top
					width: Tokens.osd.bar.width
					height: root._left
						? Tokens.osd.card.height - Tokens.osd.volumePad.top - Tokens.osd.volumePad.bottom - Tokens.osd.action.top - Tokens.osd.action.height
						: Tokens.osd.brightnessBar.height
					radius: Tokens.osd.bar.radius
					color: root._track
					clip: true

					Spring {
						id: fillS
						stiffness: Tokens.osd.fill.stiffness
						damping: Tokens.osd.fill.damping
						initial: root.muted && root._left ? 0 : root.value
						target: root.muted && root._left ? 0 : Math.max(0, Math.min(1, root.value))
					}

					Rectangle {
						objectName: "fill"
						anchors.bottom: parent.bottom
						width: parent.width
						height: parent.height * Math.max(0, fillS.value)
						radius: parent.radius
						color: root.theme.text
					}

					MouseArea {
						objectName: "barPointer"
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						preventStealing: true
						function choose(y) { root.valueChosen(Math.max(0, Math.min(1, (height - y) / height))); }
						onPressed: mouse => choose(mouse.y)
						onPositionChanged: mouse => { if (pressed) choose(mouse.y); }
					}
				}

				// .volume-notch-action: the speaker, the mixer icon on hover or
				// open, or the percentage after a change.
				Item {
					id: action
					objectName: "action"
					visible: root._left
					y: bar.y + bar.height + Tokens.osd.action.top
					width: parent.width
					height: Tokens.osd.action.height

					SvgIcon {
						objectName: "speaker"
						anchors.centerIn: parent
						name: root.muted ? "sf-speaker.slash.fill" : "sf-speaker.wave.2.fill"
						size: Tokens.osd.action.icon
						color: root.theme.text
						readonly property bool away: root.showingPercent || actionPointer.hovered || root.mixerOpen
						opacity: away ? 0 : Tokens.osd.action.iconOpacity
						scale: !root.showingPercent && actionPointer.hovered ? Tokens.osd.action.mixerFrom : 1
						Behavior on opacity { Swap {} }
						Behavior on scale { Swap {} }
					}

					SvgIcon {
						objectName: "mixerIcon"
						anchors.centerIn: parent
						name: "sf-slider.horizontal.3"
						size: Tokens.osd.action.icon
						color: root.theme.text
						readonly property bool on: !root.showingPercent && (actionPointer.hovered || root.mixerOpen)
						opacity: on ? 1 : 0
						scale: on ? 1 : Tokens.osd.action.mixerFrom
						Behavior on opacity { Swap {} }
						Behavior on scale { Swap {} }
					}

					Text {
						objectName: "percent"
						anchors.centerIn: parent
						text: (root.muted ? 0 : Math.round(root.value * 100)) + "%"
						color: root.theme.text
						opacity: root.showingPercent ? 1 : 0
						font.family: Fonts.familyFor(Font.Bold)
						font.pixelSize: Tokens.osd.action.text
						font.weight: Font.Bold
						font.letterSpacing: Tokens.osd.action.tracking
						Behavior on opacity { Swap {} }
					}

					PointerArea {
						id: actionPointer
						anchors.fill: parent
						onClicked: root.mixerToggled()
					}
				}

				// The brightness card's sun turns with the level (200/25).
				Item {
					id: sun
					objectName: "sun"
					visible: !root._left
					x: (parent.width - width) / 2
					y: bar.y + bar.height + Tokens.osd.sun.top
					width: Tokens.osd.sun.size
					height: Tokens.osd.sun.size
					rotation: sunS.value

					Spring {
						id: sunS
						stiffness: Tokens.osd.sunSpring.stiffness
						damping: Tokens.osd.sunSpring.damping
						initial: root.value * Tokens.osd.sun.turn
						target: root.value * Tokens.osd.sun.turn
					}

					SvgIcon {
						objectName: "sunGlyph"
						anchors.fill: parent
						name: "bloom-sun"
						size: Tokens.osd.sun.size
						strokeWidth: 2.5
						color: root.theme.text
					}
				}
			}

			// .volume-mixer-panel: beside the card, a column per app (44 px).
			Loader {
				id: mixerLoader
				x: Tokens.osd.card.width
				active: root._left && (root.mixerOpen || mixerOut.running)
				readonly property bool open: root.mixerOpen

				sourceComponent: Item {
					id: mixer
					objectName: "mixer"
					width: root.mixerWidth
					height: box.height
					property real slide: 0
					opacity: 0
					transform: Translate { x: mixer.slide }
					Component.onCompleted: mixerIn.start()

					// Enters on framer's default 0.3 s tween; leaves 18 px back.
					NumberAnimation { id: mixerIn; target: mixer; property: "opacity"; to: 1; duration: Tokens.easing.framerDefaultMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerDefault.concat([1, 1]) }

					Text {
						objectName: "mixerEmpty"
						visible: root.sessions.length === 0
						anchors.centerIn: parent
						width: parent.width - Tokens.osd.mixer.pad.side * 2
						horizontalAlignment: Text.AlignHCenter
						wrapMode: Text.Wrap
						text: "No apps with audio"
						color: root.theme.textMuted
						font.family: Fonts.familyFor(Font.Medium)
						font.pixelSize: Tokens.osd.mixer.empty
						font.weight: Font.Medium
					}

					Flickable {
						id: list
						x: Tokens.osd.mixer.pad.side
						y: Tokens.osd.mixer.pad.top
						width: parent.width - Tokens.osd.mixer.pad.side * 2
						height: parent.height - Tokens.osd.mixer.pad.top - Tokens.osd.mixer.pad.bottom
						contentHeight: grid.height
						clip: true
						interactive: contentHeight > height
						boundsBehavior: Flickable.StopAtBounds

						Grid {
							id: grid
							columns: root._columns
							spacing: Tokens.osd.mixer.gap
							readonly property int rows: Math.ceil(root.sessions.length / root._columns)
							// Rows share the height down to 70 px, then the list scrolls.
							readonly property real rowHeight: Math.max(Tokens.osd.mixer.rowMin, (list.height - (rows - 1) * Tokens.osd.mixer.gap) / Math.max(1, rows))

							Repeater {
								model: root.sessions

								MixerTile {
									required property var modelData
									objectName: "tile-" + modelData.id
									width: Tokens.osd.mixer.column
									height: grid.rowHeight
									session: modelData
									theme: root.theme
									track: root._track
									onVolumeChosen: v => root.sessionVolumeChosen(modelData.id, v)
									onMuteToggled: root.sessionMuteToggled(modelData.id)
								}
							}
						}
					}
				}
			}

			ParallelAnimation {
				id: mixerOut
				readonly property var curve: Tokens.osd.exit.ease.concat([1, 1])
				NumberAnimation { target: mixerLoader.item; property: "slide"; to: Tokens.osd.mixer.exitX; duration: Tokens.osd.mixer.exitXMs; easing.type: Easing.BezierSpline; easing.bezierCurve: mixerOut.curve }
				SequentialAnimation {
					PauseAnimation { duration: Tokens.osd.mixer.exitOpacityDelay }
					NumberAnimation { target: mixerLoader.item; property: "opacity"; to: 0; duration: Tokens.osd.mixer.exitOpacityMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
				}
			}
			Connections {
				target: mixerLoader
				function onOpenChanged() { if (!mixerLoader.open && root.shown) mixerOut.restart(); }
			}
		}
	}
}
