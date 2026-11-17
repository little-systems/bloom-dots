import QtQuick
import "../../common/render"

// Bloom's fixed vendor assets. Agent values never become paths.
Item {
	id: root
	property string agent: ""
	property bool light: false
	property bool working: false
	width: 20
	height: 22
	readonly property var logos: ({
		claude: "claude.svg",
		codex: root.light ? "codex-light.svg" : "codex.svg",
		opencode: root.light ? "opencode-light.svg" : "opencode.svg"
	})

	Image {
		width: Math.min(20, root.width)
		height: Math.min(20, root.height)
		sourceSize: Render.texture(width, height)
		anchors.centerIn: parent
		fillMode: Image.PreserveAspectFit
		source: Object.prototype.hasOwnProperty.call(root.logos, root.agent ?? "") ? Qt.resolvedUrl("../../assets/agents/" + root.logos[root.agent]) : ""
	}
	RotationAnimation on rotation {
		running: root.working && root.agent !== "opencode" && !Render.reduceMotion
		from: 0
		to: 360
		duration: 3600
		loops: Animation.Infinite
		onRunningChanged: if (!running) root.rotation = 0
	}
	SequentialAnimation on opacity {
		running: root.working && root.agent === "opencode" && !Render.reduceMotion
		loops: Animation.Infinite
		NumberAnimation { to: 0.65; duration: 1500; easing.type: Easing.InOutSine }
		NumberAnimation { to: 1; duration: 1500; easing.type: Easing.InOutSine }
		onRunningChanged: if (!running) root.opacity = 1
	}
}
