import QtQuick
import "../../common"

// framer-motion whileHover/whileTap: scales with a spring while hovered or
// pressed. The default is framer's own scale spring (550/30); Bloom's
// buttons that set a transition pass 400/25.
Item {
	id: root

	property real hoverScale: 1
	property real tapScale: 0.9
	property real stiffness: 550
	property real damping: 30
	readonly property bool hovered: hover.hovered

	signal clicked()
	signal rightClicked()

	scale: spring.value

	Spring {
		id: spring
		stiffness: root.stiffness
		damping: root.damping
		target: left.pressed ? root.tapScale : hover.hovered ? root.hoverScale : 1
		initial: 1
	}

	HoverHandler { id: hover }

	TapHandler {
		id: left
		acceptedButtons: Qt.LeftButton
		onTapped: root.clicked()
	}

	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: root.rightClicked()
	}
}
