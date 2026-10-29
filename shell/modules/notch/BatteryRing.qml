import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// Bloom's DeviceBatteryRing (App.tsx, .device-alert-battery): a 28 px ring,
// stroke 2.6 with round caps, the level in the middle. Green, red when low
// and not charging; a new level sweeps over 0.6 s.
Item {
	id: root

	property int level: 0
	property bool charging: false
	property color textColor: "white"
	readonly property bool low: root.level <= 20 && !root.charging

	property real _shown: root.level
	Behavior on _shown {
		NumberAnimation {
			duration: Tokens.alert.ring.ms
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
	}
	on_ShownChanged: ring.requestPaint()
	onLowChanged: ring.requestPaint()

	width: Tokens.alert.ring.size
	height: Tokens.alert.ring.size

	Canvas {
		id: ring
		anchors.fill: parent
		onPaint: {
			const ctx = getContext("2d");
			ctx.clearRect(0, 0, width, height);
			ctx.lineWidth = Tokens.alert.ring.stroke;
			ctx.strokeStyle = `rgba(255,255,255,${Tokens.alert.ring.track})`;
			ctx.beginPath();
			ctx.arc(14, 14, 10.5, 0, Math.PI * 2);
			ctx.stroke();
			const share = Math.max(0, Math.min(100, root._shown)) / 100;
			if (share <= 0)
				return;
			ctx.lineCap = "round";
			ctx.strokeStyle = root.low ? Tokens.bh.red : Tokens.bh.green;
			ctx.beginPath();
			ctx.arc(14, 14, 10.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * share);
			ctx.stroke();
		}
	}

	FracText {
		anchors.centerIn: parent
		text: root.level
		color: root.textColor
		font.family: Tokens.type.family
		font.weight: Font.DemiBold
		pixelSize: Tokens.alert.ring.text
	}
}
