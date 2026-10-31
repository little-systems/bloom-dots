import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's .settings-slider: a thin track with a round thumb, snapping to steps.
Item {
	id: root
	activeFocusOnTab: true
	Accessible.role: Accessible.Slider
	Accessible.name: root.accessibleName
	property string accessibleName: ""
	function _nudge(steps) {
		const next = root.value + steps * root.step;
		root.moved(Math.round(Math.max(root.from, Math.min(root.to, next)) * 1000) / 1000);
	}
	Keys.onLeftPressed: root._nudge(-1)
	Keys.onDownPressed: root._nudge(-1)
	Keys.onRightPressed: root._nudge(1)
	Keys.onUpPressed: root._nudge(1)
	Keys.onPressed: event => {
		if (event.key === Qt.Key_Home) root.moved(root.from);
		else if (event.key === Qt.Key_End) root.moved(root.to);
		else return;
		event.accepted = true;
	}
	SFocusRing { radius: 8 }
	property QtObject theme
	property real from: 0
	property real to: 1
	property real step: 0.1
	property real value: 0
	signal moved(real value)

	width: Tokens.settings.slider.width
	height: Tokens.settings.slider.thumb
	readonly property real _fraction: (root.value - root.from) / (root.to - root.from)

	function _fromX(x) {
		const travel = root.width - Tokens.settings.slider.thumb;
		const fraction = Math.max(0, Math.min(1, (x - Tokens.settings.slider.thumb / 2) / travel));
		const stepped = Math.round(fraction * (root.to - root.from) / root.step) * root.step + root.from;
		return Math.round(Math.min(root.to, stepped) * 1000) / 1000;
	}

	Rectangle {
		y: (parent.height - height) / 2
		width: parent.width
		height: Tokens.settings.slider.track
		radius: height / 2
		color: root.theme.scrollbarThumb
	}
	Rectangle {
		objectName: "thumb"
		x: root._fraction * (root.width - width)
		width: Tokens.settings.slider.thumb
		height: width
		radius: width / 2
		color: root.theme.text
	}
	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onPressed: mouse => root.moved(root._fromX(mouse.x))
		onPositionChanged: mouse => { if (pressed) root.moved(root._fromX(mouse.x)); }
	}
}
