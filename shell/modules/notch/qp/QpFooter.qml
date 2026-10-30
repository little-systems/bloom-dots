import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens
import "../../../common/render"

// .qp-footer: the "More … settings" link under a panel. No transition.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string text: ""

	signal clicked()

	width: label.implicitWidth + Tokens.qp.footer.padH * 2
	height: Math.ceil(label.implicitHeight) + Tokens.qp.footer.padV * 2

	Text {
		id: label
		objectName: "label"
		anchors.centerIn: parent
		text: root.text
		color: pointer.hovered ? root.theme.text : root.theme.textMuted
		font.family: Fonts.family
		font.pixelSize: Tokens.qp.footer.text
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
