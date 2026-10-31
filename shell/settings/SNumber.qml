import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// Exact values are independent of a slider's drag increments. Invalid input
// never reaches the store; blur reverts it, Enter commits and Escape cancels.
Rectangle {
	id: root
	property QtObject theme
	property real from: 0
	property real to: 1
	property real value: 0
	property real factor: 1
	property string suffix: ""
	property int decimals: 3
	property string accessibleName: "Value"
	property bool _editing: false
	property bool _invalid: false
	signal edited(real value)
	width: 62; height: Math.max(Tokens.settings.control, Fonts.px(Tokens.settings.controlText) * 1.6); radius: Tokens.settings.controlRadius
	color: root.theme.groupBg
	border.width: 1
	border.color: root._invalid ? "#ff453a" : input.activeFocus ? root.theme.textMuted : root.theme.border
	function formatted() { return String(Math.round(root.value * root.factor * 1000) / 1000); }
	function cancel() { root._editing = false; root._invalid = false; input.text = formatted(); input.focus = false; }
	function commit() {
		const text = input.text.trim();
		const number = Number(text);
		if (!text || !input.acceptableInput || !isFinite(number) || number < root.from * root.factor || number > root.to * root.factor) { root._invalid = true; return false; }
		root._editing = false; root._invalid = false;
		root.edited(Math.round(number / root.factor * 1000000) / 1000000);
		input.focus = false; input.text = formatted(); return true;
	}
	onValueChanged: if (!root._editing) input.text = formatted()
	TextInput {
		id: input
		objectName: "numberInput"
		x: 6; width: parent.width - 12 - unit.implicitWidth; height: parent.height
		text: root.formatted(); color: root.theme.text
		font.family: Fonts.ui; font.pixelSize: Fonts.px(Tokens.settings.controlText)
		verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignRight
		selectByMouse: true; activeFocusOnTab: true; clip: true; maximumLength: 16
		inputMethodHints: Qt.ImhFormattedNumbersOnly
		validator: DoubleValidator { bottom: root.from * root.factor; top: root.to * root.factor; decimals: root.decimals; locale: "C"; notation: DoubleValidator.StandardNotation }
		Accessible.name: root.accessibleName
		Accessible.description: root.from * root.factor + " to " + root.to * root.factor + root.suffix
		onActiveFocusChanged: {
			if (activeFocus) { root._editing = true; root._invalid = false; text = root.formatted(); selectAll(); }
			else if (root._editing && !root.commit()) root.cancel();
		}
		onTextEdited: root._invalid = false
		Keys.onReturnPressed: root.commit()
		Keys.onEnterPressed: root.commit()
		Keys.onEscapePressed: root.cancel()
	}
	Text { id: unit; anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter; text: root.suffix; color: root.theme.textMuted; font.family: Fonts.ui; font.pixelSize: Fonts.px(Tokens.settings.controlText - 1)}
}
