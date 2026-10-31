import QtQuick
import "../common/render"
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
	property real displayFactor: root.from >= 0 && root.to <= 1 ? 100 : 1
	property string displaySuffix: displayFactor === 100 ? "%" : ""
	signal moved(real value)

	opacity: root.enabled ? 1 : 0.4
	width: Tokens.settings.slider.width + 8 + exact.width
	height: Math.max(Tokens.settings.control, Fonts.px(Tokens.settings.controlText) * 1.6)
	readonly property real _fraction: Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.00001, root.to - root.from)))

	function _fromX(x) {
		const travel = trackArea.width - Tokens.settings.slider.thumb;
		const fraction = Math.max(0, Math.min(1, (x - Tokens.settings.slider.thumb / 2) / travel));
		const stepped = Math.round(fraction * (root.to - root.from) / root.step) * root.step + root.from;
		return Math.round(Math.min(root.to, stepped) * 1000) / 1000;
	}

	Item {
		id: trackArea
		objectName: "sliderTrack"
		width: Tokens.settings.slider.width; height: root.height

	Rectangle {
		y: (parent.height - height) / 2
		width: trackArea.width
		height: Tokens.settings.slider.track
		radius: height / 2
		color: root.theme.scrollbarThumb
	}
	Rectangle {
		objectName: "thumb"
		x: root._fraction * (trackArea.width - width)
		y: (trackArea.height - height) / 2
		width: Tokens.settings.slider.thumb
		height: width
		radius: width / 2
		color: root.theme.text
	}
	MouseArea {
		anchors.fill: parent
		enabled: root.enabled
		cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
		onPressed: mouse => root.moved(root._fromX(mouse.x))
		onPositionChanged: mouse => { if (pressed) root.moved(root._fromX(mouse.x)); }
	}
	}
	SNumber {
		id: exact
		objectName: "exactValue"
		x: trackArea.width + 8
		theme: root.theme; from: root.from; to: root.to; value: root.value
		factor: root.displayFactor
		suffix: root.displaySuffix
		decimals: root.step >= 1 ? 0 : 3
		accessibleName: root.accessibleName || "Exact value"
		onEdited: value => root.moved(value)
	}
}