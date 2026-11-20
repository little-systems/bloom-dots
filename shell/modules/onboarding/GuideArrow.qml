import QtQuick

// Bloom's hand-drawn guide arrow (Onboarding.tsx at 63a9bf5): viewBox 112×56,
// a curve "M104 48 C107 28 80 23 59 24 S23 23 9 7" drawn in 0.22 s
// (ease-in-out, after 0.08 s), then its head "M10 20 L9 7 L22 8" in 0.08 s
// (ease-out, at 0.3 s); stroke 1.6, round caps and joins.
Canvas {
	id: root

	property color color: "#d3d3d3"
	property bool reducedMotion: false
	// Points up-right instead (our notifications page, at the corner).
	property bool mirrored: false
	transform: Scale { origin.x: root.width / 2; xScale: root.mirrored ? -1 : 1 }
	property real _curve: 0
	property real _head: 0

	function play() {
		draw.stop();
		if (root.reducedMotion) {
			root._curve = 1;
			root._head = 1;
		} else {
			root._curve = 0;
			root._head = 0;
			draw.start();
		}
	}

	on_CurveChanged: requestPaint()
	on_HeadChanged: requestPaint()
	onColorChanged: requestPaint()
	onWidthChanged: requestPaint()
	onHeightChanged: requestPaint()

	SequentialAnimation {
		id: draw
		PauseAnimation { duration: 80 }
		NumberAnimation { target: root; property: "_curve"; from: 0; to: 1; duration: 220; easing.type: Easing.InOutQuad }
		NumberAnimation { target: root; property: "_head"; from: 0; to: 1; duration: 80; easing.type: Easing.OutQuad }
	}

	// The curve as points along its two cubic segments (the S segment's first
	// control reflects the previous second control about the join).
	readonly property var _points: {
		const cubic = (p0, p1, p2, p3, steps) => {
			const out = [];
			for (let i = 1; i <= steps; i++) {
				const t = i / steps, u = 1 - t;
				out.push([u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
					u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]]);
			}
			return out;
		};
		return [[104, 48]].concat(cubic([104, 48], [107, 28], [80, 23], [59, 24], 40), cubic([59, 24], [38, 25], [23, 23], [9, 7], 40));
	}
	readonly property var _headPoints: [[10, 20], [9, 7], [22, 8]]

	function _partial(points, progress) {
		if (progress <= 0)
			return [];
		const lengths = [0];
		for (let i = 1; i < points.length; i++)
			lengths.push(lengths[i - 1] + Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]));
		const goal = lengths[lengths.length - 1] * Math.min(1, progress);
		const out = [points[0]];
		for (let i = 1; i < points.length; i++) {
			if (lengths[i] <= goal) {
				out.push(points[i]);
				continue;
			}
			const f = (goal - lengths[i - 1]) / (lengths[i] - lengths[i - 1]);
			out.push([points[i - 1][0] + (points[i][0] - points[i - 1][0]) * f, points[i - 1][1] + (points[i][1] - points[i - 1][1]) * f]);
			break;
		}
		return out;
	}

	onPaint: {
		const ctx = getContext("2d");
		ctx.reset();
		const sx = root.width / 112, sy = root.height / 56;
		ctx.lineWidth = 1.6 * Math.min(sx, sy);
		ctx.lineCap = "round";
		ctx.lineJoin = "round";
		ctx.strokeStyle = root.color;
		for (const line of [root._partial(root._points, root._curve), root._partial(root._headPoints, root._head)]) {
			if (line.length < 2)
				continue;
			ctx.beginPath();
			ctx.moveTo(line[0][0] * sx, line[0][1] * sy);
			for (let i = 1; i < line.length; i++)
				ctx.lineTo(line[i][0] * sx, line[i][1] * sy);
			ctx.stroke();
		}
	}
}
