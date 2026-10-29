import QtQuick

// The 28 px circular meter used by Bloom's device connection notice.
Item {
	id: root
	property int level: 0
	property color textColor: "white"
	width: 28; height: 28
	onLevelChanged: ring.requestPaint()
	Canvas {
		id: ring; anchors.fill: parent
		onPaint: {
			const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
			ctx.lineWidth = 2.6; ctx.strokeStyle = "rgba(255,255,255,0.14)";
			ctx.beginPath(); ctx.arc(14, 14, 10.5, 0, Math.PI * 2); ctx.stroke();
			ctx.strokeStyle = root.level <= 20 ? "#ff453a" : "#32d74b";
			ctx.beginPath(); ctx.arc(14, 14, 10.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(100, root.level)) / 100); ctx.stroke();
		}
	}
	Text { anchors.centerIn: parent; text: root.level; color: root.textColor; font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold }
}
