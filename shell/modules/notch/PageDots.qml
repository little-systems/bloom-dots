import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// The workspace pulse's page dots: one per workspace on this monitor, the
// active one stretched into a pill that springs between positions.
Row {
	id: root
	objectName: "page-dots"

	property var ids: []
	property int active: 0
	property color color: "white"
	// Inside a PulseItem the dots are an effect's hidden source, so their own
	// `visible` is always false; the pulse says when they are on screen.
	property bool animate: true
	readonly property int count: dots.count

	spacing: Tokens.pulse.pageDot.gap

	Repeater {
		id: dots
		model: root.ids

		Rectangle {
			id: dot
			required property int modelData
			readonly property bool current: dot.modelData === root.active
			height: Tokens.pulse.pageDot.size
			width: widthSpring.value
			radius: height / 2
			color: root.color
			opacity: dot.current ? 1 : Tokens.pulse.pageDot.idleOpacity
			Behavior on opacity { NumberAnimation { duration: 200 } }

			Spring {
				id: widthSpring
				autoRun: root.animate
				stiffness: 500
				damping: 30
				target: dot.current ? Tokens.pulse.pageDot.activeWidth : Tokens.pulse.pageDot.size
			}
		}
	}
}
