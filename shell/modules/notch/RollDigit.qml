import QtQuick
import "../../common/tokens.js" as Tokens

// Bloom's RollDigit (App.tsx): an odometer digit. On a change the old digit
// rolls up and out while the new one rolls in from below with a 3D tilt.
// Qt has no perspective, so rotateX(a) draws as a vertical squash, cos(a)
// (the 2B flip ruling).
Item {
	id: root

	property string value: ""
	property bool compact: false
	property color color: "white"

	readonly property var _size: root.compact ? Tokens.timer.compact : Tokens.timer.digit
	readonly property real _travel: root.height * Tokens.timer.roll.travel

	width: root._size.width
	height: root._size.height
	clip: true

	component Num: Text {
		property real angle: 0
		readonly property real tilt: Math.cos(angle * Math.PI / 180)

		width: root.width
		height: root.height
		horizontalAlignment: Text.AlignHCenter
		verticalAlignment: Text.AlignVCenter
		color: root.color
		font.family: Tokens.type.family
		font.pixelSize: root._size.text
		font.weight: Font.DemiBold
		font.letterSpacing: Tokens.timer.digit.tracking
		font.features: {
			"tnum": 1
		}
		transform: Scale {
			origin.y: root.height / 2
			yScale: tilt
		}
	}

	Num {
		id: leaving
		objectName: "leaving"
		visible: false
	}

	Num {
		id: current
		objectName: "current"
		text: root.value
	}

	property string _shown: ""
	Component.onCompleted: root._shown = root.value

	onValueChanged: {
		const before = root._shown;
		root._shown = root.value;
		roll.stop();
		if (before === "" || !root.visible) {
			current.y = 0;
			current.opacity = 1;
			current.angle = 0;
			leaving.visible = false;
			return;
		}
		leaving.text = before;
		leaving.visible = true;
		current.y = root._travel;
		current.opacity = 0;
		current.angle = -Tokens.timer.roll.angle;
		roll.start();
	}

	ParallelAnimation {
		id: roll

		readonly property var curve: Tokens.timer.roll.ease.concat([1, 1])

		NumberAnimation { target: current; property: "y"; to: 0; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }
		NumberAnimation { target: current; property: "opacity"; to: 1; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }
		NumberAnimation { target: current; property: "angle"; to: 0; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }
		NumberAnimation { target: leaving; property: "y"; from: 0; to: -root._travel; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }
		NumberAnimation { target: leaving; property: "opacity"; from: 1; to: 0; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }
		NumberAnimation { target: leaving; property: "angle"; from: 0; to: Tokens.timer.roll.angle; duration: Tokens.timer.roll.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: roll.curve }

		onFinished: leaving.visible = false
	}
}
