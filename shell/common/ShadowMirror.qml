import QtQuick

// A box's shadow drawn from another window, over the spot where the box is
// drawn: its scene rectangle, scale and fade, re-read whenever the box's
// window redraws. Both windows must share their on-screen origin. Lets a
// shadow live in a layer the compositor doesn't blur (see DockShadows.qml).
Item {
	id: root

	property Item target: null
	property vector2d offset
	property real blur: 0
	property color color: "black"
	readonly property alias shadow: shadow

	property real _scale: 1
	property real _radius: 0

	function sync() {
		const t = root.target;
		let alpha = 1;
		for (let i = t; i; i = i.parent) alpha *= i.opacity;
		if (!t || !t.visible || alpha <= 0 || t.width <= 0 || t.height <= 0 || !root.parent) {
			root.visible = false;
			return;
		}
		const r = t.mapToItem(null, 0, 0, t.width, t.height);
		const p = root.parent.mapFromItem(null, r.x, r.y);
		root.x = p.x;
		root.y = p.y;
		root.width = r.width;
		root.height = r.height;
		root._scale = r.width / t.width;
		root._radius = t["radius"] ?? 0;
		root.opacity = alpha;
		root.visible = true;
	}

	visible: false
	onTargetChanged: root.sync()
	Component.onCompleted: root.sync()

	Connections {
		target: root.target ? root.target.Window.window : null
		function onFrameSwapped() { root.sync(); }
	}

	BoxShadow {
		id: shadow
		anchors.fill: parent
		offset: Qt.vector2d(root.offset.x * root._scale, root.offset.y * root._scale)
		blur: root.blur * root._scale
		radius: root._radius * root._scale
		color: root.color
	}
}
