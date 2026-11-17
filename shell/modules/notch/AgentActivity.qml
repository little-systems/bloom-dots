import QtQuick
import QtQuick.Effects
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

	height: 36
	visible: opacity > 0
	opacity: entry ? 1 : 0
	Behavior on opacity { NumberAnimation { duration: Render.reduceMotion ? 0 : 150 } }

	AgentLogo {
		id: logo
		agent: root.entry?.agent ?? ""
		light: root.light
		working: root.working
		anchors.left: parent.left
		anchors.leftMargin: 16
		anchors.verticalCenter: parent.verticalCenter
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
		objectName: "status"
		// Working labels sit at 78% ink under the sweep (Bloom AgentAlert.css).
		color: root.entry?.kind === "attention" ? "#e9b873" : root.entry?.kind === "error" ? "#ef9292"
			: root.working ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.ink.a * 0.78) : root.ink
		font.family: Fonts.family
		font.pixelSize: Fonts.px(12)
		font.weight: Font.DemiBold
	}

	// A quiet light pass through the glyphs, with a rest between sweeps: the
	// gradient's bright centre travels from a quarter-width before the label
	// to a quarter-width after it during 16-66% of each period.
	Item {
		id: shimmer
		objectName: "shimmer"
		readonly property var sweep: Agents.shimmer(root.activity)
		readonly property int periodMs: shimmer.sweep.periodMs
		readonly property real span: Math.min(status.implicitWidth, status.width)
		property real progress: 1
		visible: root.working
		x: status.x
		y: status.y
		width: status.width
		height: status.height
		layer.enabled: shimmer.visible
		layer.textureSize: Render.texture(width, height)
		layer.effect: MultiEffect {
			maskEnabled: true
			maskSource: band
		}

		Text {
			anchors.fill: parent
			text: status.text
			textFormat: Text.PlainText
			elide: Text.ElideRight
			color: root.ink
			font: status.font
		}

		SequentialAnimation on progress {
			running: shimmer.visible && !Render.reduceMotion
			loops: Animation.Infinite
			onRunningChanged: if (!running) shimmer.progress = 1
			PropertyAction { value: 0 }
			PauseAnimation { duration: shimmer.periodMs * 0.16 }
			NumberAnimation { from: 0; to: 1; duration: shimmer.periodMs * 0.5; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
			PauseAnimation { duration: shimmer.periodMs * 0.34 }
		}
	}
	Item {
		id: band
		width: shimmer.width
		height: shimmer.height
		visible: false
		layer.enabled: true
		layer.textureSize: Render.texture(width, height)
		Rectangle {
			readonly property real centre: shimmer.span * (-0.25 + 1.5 * shimmer.progress)
			x: centre - width / 2
			width: Math.max(1, shimmer.span * shimmer.sweep.half * 2)
			height: parent.height
			gradient: Gradient {
				orientation: Gradient.Horizontal
				GradientStop { position: 0; color: "transparent" }
				GradientStop { position: 0.5; color: "black" }
				GradientStop { position: 1; color: "transparent" }
			}
		}
	}

	Text {
		id: elapsed
		objectName: "elapsed"
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
		font.features: { "tnum": 1 }
	}
}
