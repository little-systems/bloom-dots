import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's .settings-select. `popup` is the window-wide host that draws the list
// above the page, as a native select's list sits above it.
Rectangle {
	id: root
	activeFocusOnTab: true
	Accessible.role: Accessible.ComboBox
	Accessible.name: root.accessibleName
	Accessible.description: root._label
	property string accessibleName: ""
	function _open() { root.popup.show(root, root.options, value => root.activated(value), root.value); }
	Keys.onSpacePressed: root._open()
	Keys.onReturnPressed: root._open()
	SFocusRing {}
	property QtObject theme
	property Item popup
	// [{ value, label }]
	property var options: []
	property string value: ""
	signal activated(string value)

	readonly property string _label: (root.options.find(o => o.value === root.value) || { label: root.value }).label

	width: Math.max(Tokens.settings.select.minWidth, label.implicitWidth + 2 * Tokens.settings.select.paddingH + 2)
	height: 21.6
	radius: Tokens.settings.select.radius
	color: hover.hovered ? root.theme.border : root.theme.groupBg
	border.width: 1
	border.color: root.theme.border

	Text {
		id: label
		objectName: "selectLabel"
		anchors.centerIn: parent
		text: root._label
		color: root.theme.text
		font.family: Fonts.ui
		font.pixelSize: Tokens.settings.select.size
	}
	HoverHandler {
		id: hover
		cursorShape: Qt.PointingHandCursor
	}
	TapHandler {
		onTapped: root._open()
	}
}
