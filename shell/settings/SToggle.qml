import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's iOS-style .toggle-switch.
Rectangle {
	id: root
	activeFocusOnTab: true
	Accessible.role: Accessible.CheckBox
	Accessible.name: root.accessibleName
	Accessible.checkable: true
	Accessible.checked: root.checked
	property string accessibleName: ""
	Keys.onSpacePressed: if (root.enabled) root.toggled(!root.checked)
	Keys.onReturnPressed: if (root.enabled) root.toggled(!root.checked)
	SFocusRing {}
	property QtObject theme
	property bool checked: false
	signal toggled(bool checked)

	width: Tokens.settings.toggle.width
	height: Tokens.settings.toggle.height
	radius: height / 2
	color: root.checked ? Tokens.settings.toggle.on : root.theme.groupBg
	border.width: 1
	border.color: root.checked ? Tokens.settings.toggle.on : root.theme.border
	Behavior on color {
		ColorAnimation { duration: Tokens.settings.toggle.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
	}

	Rectangle {
		objectName: "knob"
		x: 1 + Tokens.settings.toggle.inset + (root.checked ? Tokens.settings.toggle.travel : 0)
		y: 1 + Tokens.settings.toggle.inset
		width: Tokens.settings.toggle.knob
		height: width
		radius: width / 2
		color: "white"
		Behavior on x {
			NumberAnimation { duration: Tokens.settings.toggle.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
		}
	}
	opacity: root.enabled ? 1 : 0.4
	HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
	TapHandler { onTapped: root.toggled(!root.checked) }
}
