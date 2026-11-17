import QtQuick
import "../../common"
import "../../common/i18n"
import "../../common/render"
import "../../services/agents.js" as Agents

Item {
	id: root

	property var entry: null
	property real now: 0
	property bool light: false
	property color ink: "white"
	property color mutedInk: "#999999"
	readonly property bool working: entry?.kind === "working"
	readonly property string activity: entry?.activity === "checking" ? "working" : entry?.activity ?? "thinking"
	readonly property string label: entry ? I18n.t("agentActivity." + (working ? activity : entry.kind)) : ""
	readonly property int desiredWidth: Agents.activityWidth(status.implicitWidth, elapsed.width)
	readonly property var logos: ({
		claude: "claude.svg",
		codex: light ? "codex-light.svg" : "codex.svg",
		opencode: light ? "opencode-light.svg" : "opencode.svg"
	})

	height: 36
	visible: opacity > 0
	opacity: entry ? 1 : 0
	Behavior on opacity { NumberAnimation { duration: Render.reduceMotion ? 0 : 150 } }

	Item {
		id: logo
		width: 20
		height: 22
		anchors.left: parent.left
		anchors.leftMargin: 16
		anchors.verticalCenter: parent.verticalCenter
		Image {
			width: 20
			height: 20
			sourceSize: Render.texture(width, height)
			anchors.centerIn: parent
			fillMode: Image.PreserveAspectFit
			source: Object.prototype.hasOwnProperty.call(root.logos, root.entry?.agent ?? "") ? Qt.resolvedUrl("../../assets/agents/" + root.logos[root.entry.agent]) : ""
		}
		RotationAnimation on rotation {
			running: root.working && root.entry?.agent !== "opencode" && !Render.reduceMotion
			from: 0
			to: 360
			duration: 3600
			loops: Animation.Infinite
			onRunningChanged: if (!running) logo.rotation = 0
		}
		SequentialAnimation on opacity {
			running: root.working && root.entry?.agent === "opencode" && !Render.reduceMotion
			loops: Animation.Infinite
			NumberAnimation { to: 0.65; duration: 1500; easing.type: Easing.InOutSine }
			NumberAnimation { to: 1; duration: 1500; easing.type: Easing.InOutSine }
			onRunningChanged: if (!running) logo.opacity = 1
		}
	}

	Text {
		id: status
		anchors.left: logo.right
		anchors.leftMargin: 8
		anchors.right: elapsed.left
		anchors.rightMargin: 24
		anchors.verticalCenter: parent.verticalCenter
		text: root.label
		textFormat: Text.PlainText
		elide: Text.ElideRight
		color: root.entry?.kind === "attention" ? "#e9b873" : root.entry?.kind === "error" ? "#ef9292" : root.ink
		font.family: Fonts.family
		font.pixelSize: Fonts.px(12)
		font.weight: Font.DemiBold
	}

	Text {
		id: elapsed
		width: Math.max(34, implicitWidth)
		anchors.right: parent.right
		anchors.rightMargin: 16
		anchors.verticalCenter: parent.verticalCenter
		horizontalAlignment: Text.AlignRight
		text: root.entry ? Agents.formatElapsed(root.entry.started, root.working ? root.now : root.entry.received) : ""
		color: root.mutedInk
		font.family: Fonts.family
		font.pixelSize: Fonts.px(12)
		font.weight: Font.Medium
	}
}
