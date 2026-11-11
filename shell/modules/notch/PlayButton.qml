import QtQuick
import "../../common"

// Play/pause with Bloom's icon swap: the old icon fades and shrinks, then the
// new one grows in (AnimatePresence "wait").
PressArea {
	id: root

	property bool playing: false
	property real box: 44
	property real iconSize: 26
	property color color: "white"
	property real swapScale: 0.8
	property int swapMs: 150
	readonly property bool shownPlaying: root._shown

	property bool _shown: root.playing
	implicitWidth: root.box
	implicitHeight: root.box
	tapScale: 0.95

	onPlayingChanged: swap.restart()
	// A disappearing MPRIS player can unload the button mid-swap.
	Component.onDestruction: swap.stop()

	SequentialAnimation {
		id: swap
		ParallelAnimation {
			NumberAnimation { target: icon; property: "opacity"; to: 0; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			NumberAnimation { target: icon; property: "scale"; to: root.swapScale; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
		ScriptAction { script: root._shown = root.playing }
		ParallelAnimation {
			NumberAnimation { target: icon; property: "opacity"; to: 1; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			NumberAnimation { target: icon; property: "scale"; to: 1; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
	}

	SvgIcon {
		id: icon
		anchors.centerIn: parent
		// Bloom nudges the play glyph 1 px right to centre its mass.
		anchors.horizontalCenterOffset: root._shown ? 0 : 1
		name: root._shown ? "sf-pause.fill" : "sf-play.fill"
		size: root.iconSize
		color: root.color
	}
}
