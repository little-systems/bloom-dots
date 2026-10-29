import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "notch.js" as Logic
import "calendar.js" as Calendar

// Bloom's notch time (App.tsx .time-center): the clock, or the Pomodoro
// timer while one runs or has finished, flipping between them on a 600/30
// spring (rotateX drawn as a cos squash, the 2B ruling). A finished timer is
// red with a bell, pops, then beats. While a tool panel is open the arrows
// sit 4 px outside the 60 px box. The box is the click target.
Item {
	id: root

	property date now: new Date()
	property bool use24h: false
	// The timer shows while it runs or has finished (Bloom: timerSeconds > 0
	// || isTimerFinished); `timerSeconds` is the time left.
	property bool timerActive: false
	property int timerSeconds: 0
	property bool timerFinished: false
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property bool arrows: false

	signal clicked()
	signal previous()
	signal next()

	// The width of the text on show (for what sits beside it).
	readonly property real textWidth: root.timerActive ? timerRow.implicitWidth : clockLabel.implicitWidth

	width: Tokens.clock.box.minWidth
	height: Tokens.clock.box.height
	scale: pointer.pressed ? Tokens.clock.pressScale : 1

	Behavior on scale {
		NumberAnimation {
			duration: Tokens.clock.pressMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
	}

	// .time-flip-container:hover .time { color: textMuted }, 0.2 s ease.
	property color _timeColor: pointer.hovered ? root.textMuted : root.textColor
	Behavior on _timeColor {
		ColorAnimation {
			duration: Tokens.clock.colorMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
	}

	Spring {
		id: flip
		stiffness: Tokens.clock.flip.stiffness
		damping: Tokens.clock.flip.damping
		initial: root.timerActive ? 1 : 0
		target: root.timerActive ? 1 : 0
	}

	Text {
		id: clockLabel
		objectName: "clockText"
		readonly property real tilt: Math.cos(flip.value * Math.PI / 2)
		anchors.centerIn: parent
		text: Logic.clockText(root.now, root.use24h)
		color: root._timeColor
		opacity: 1 - flip.value
		visible: opacity > 0
		font.family: Tokens.type.family
		font.pixelSize: Tokens.type.clock.size
		font.weight: Font.Medium
		font.letterSpacing: Tokens.type.clock.tracking
		transform: Scale {
			origin.y: 8
			yScale: Math.max(0, clockLabel.tilt)
		}
	}

	Row {
		id: timerRow
		objectName: "timerRow"
		readonly property real tilt: Math.cos((1 - flip.value) * Math.PI / 2)
		anchors.centerIn: parent
		spacing: Tokens.clock.timerGap
		opacity: flip.value
		visible: opacity > 0
		transform: Scale {
			origin.x: timerRow.width / 2
			origin.y: timerRow.height / 2
			yScale: Math.max(0, timerRow.tilt)
		}

		SvgIcon {
			id: bell
			objectName: "bell"
			visible: root.timerFinished
			anchors.verticalCenter: parent.verticalCenter
			name: "bell-ring"
			size: Tokens.clock.bell.size
			strokeWidth: Tokens.clock.bell.stroke
			color: Tokens.clock.red
			transform: Rotation {
				id: bellTurn
				origin.x: bell.width / 2
				origin.y: bell.height * Tokens.clock.bell.originY
			}
		}

		Text {
			objectName: "timerText"
			anchors.verticalCenter: parent.verticalCenter
			text: Calendar.clockText(root.timerSeconds)
			// .timer-finished { color: #ff453a !important }
			color: root.timerFinished ? Tokens.clock.red : root._timeColor
			font.family: Tokens.type.family
			font.pixelSize: Tokens.type.clock.size
			font.weight: Font.Medium
			font.letterSpacing: Tokens.type.clock.tracking
		}
	}

	// timer-pop (0.65 s, once) then timer-heartbeat (1.9 s, repeating); each
	// keyframe segment eased as CSS does.
	onTimerFinishedChanged: {
		pop.stop();
		heartbeat.stop();
		wiggle.stop();
		timerRow.scale = 1;
		bellTurn.angle = 0;
		if (root.timerFinished) {
			pop.start();
			wiggle.start();
		}
	}
	Component.onCompleted: if (root.timerFinished) { pop.start(); wiggle.start(); }

	SequentialAnimation {
		id: pop
		objectName: "pop"

		readonly property var curve: Tokens.clock.pop.ease.concat([1, 1])

		NumberAnimation { target: timerRow; property: "scale"; to: Tokens.clock.pop.scales[1]; duration: Tokens.clock.pop.ms * 0.35; easing.type: Easing.BezierSpline; easing.bezierCurve: pop.curve }
		NumberAnimation { target: timerRow; property: "scale"; to: Tokens.clock.pop.scales[2]; duration: Tokens.clock.pop.ms * 0.35; easing.type: Easing.BezierSpline; easing.bezierCurve: pop.curve }
		NumberAnimation { target: timerRow; property: "scale"; to: 1; duration: Tokens.clock.pop.ms * 0.30; easing.type: Easing.BezierSpline; easing.bezierCurve: pop.curve }

		onFinished: if (root.timerFinished) heartbeat.start()
	}

	SequentialAnimation {
		id: heartbeat
		objectName: "heartbeat"
		loops: Animation.Infinite
		// Nothing to see on a hidden notch; don't draw frames for it.
		paused: running && !root.visible

		NumberAnimation { target: timerRow; property: "scale"; to: Tokens.clock.heartbeat.scale; duration: Tokens.clock.heartbeat.ms / 2; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: timerRow; property: "scale"; to: 1; duration: Tokens.clock.heartbeat.ms / 2; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
	}

	// bell-wiggle: 0.85 s ease-in-out, 3 times.
	SequentialAnimation {
		id: wiggle
		objectName: "wiggle"
		loops: Tokens.clock.bell.loops

		readonly property real step: Tokens.clock.bell.ms * 0.15

		NumberAnimation { target: bellTurn; property: "angle"; to: -16; duration: wiggle.step; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: bellTurn; property: "angle"; to: 13; duration: wiggle.step; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: bellTurn; property: "angle"; to: -10; duration: wiggle.step; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: bellTurn; property: "angle"; to: 7; duration: wiggle.step; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: bellTurn; property: "angle"; to: -4; duration: wiggle.step; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
		NumberAnimation { target: bellTurn; property: "angle"; to: 0; duration: Tokens.clock.bell.ms * 0.25; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
	}

	// .panel-arrow: 18 px, 4 px outside the box, textMuted (hover text,
	// 0.15 s); they slide 4 px in as they appear (framer, 0.15 s).
	component Arrow: Item {
		id: arrow
		required property bool forward
		property real offset: root.arrows ? 0 : (arrow.forward ? -4 : 4)
		readonly property alias glyph: arrowGlyph
		signal activated()

		x: arrow.forward ? root.width + 4 : -4 - 18
		y: (root.height - height) / 2
		width: 18
		height: 18
		opacity: root.arrows ? 1 : 0
		visible: opacity > 0
		transform: Translate {
			x: arrow.offset
		}

		Behavior on opacity {
			NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
		}
		Behavior on offset {
			NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1]) }
		}

		SvgIcon {
			id: arrowGlyph
			objectName: arrow.forward ? "nextGlyph" : "prevGlyph"
			anchors.centerIn: parent
			name: arrow.forward ? "chevron-right" : "chevron-left"
			size: 12
			strokeWidth: 2.5
			color: arrowPointer.hovered ? root.textColor : root.textMuted

			Behavior on color {
				ColorAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] }
			}
		}

		PointerArea {
			id: arrowPointer
			anchors.fill: parent
			enabled: root.arrows
			onClicked: arrow.activated()
		}
	}

	Arrow {
		objectName: "arrowPrev"
		forward: false
		onActivated: root.previous()
	}

	Arrow {
		objectName: "arrowNext"
		forward: true
		onActivated: root.next()
	}
}
