import QtQuick
import QtQuick.Controls as Controls
import "../common"
import "../common/i18n"
import "../common/render"

Column {
	id: root
	required property QtObject theme
	required property var store
	property var backend
	property string setupAgent: ""
	property string previewAgent: "claude"
	property string previewKind: "ready"
	property Item popup
	readonly property bool alertsEnabled: store.values["bloom-agent-alerts-enabled"] !== false
	readonly property var names: ({ claude: "Claude Code", codex: "Codex", opencode: "OpenCode" })
	readonly property var logos: ({ claude: "claude.svg",
		codex: theme.isLight ? "codex-light.svg" : "codex.svg",
		opencode: theme.isLight ? "opencode-light.svg" : "opencode.svg" })

	function label(key, params) { return I18n.t("agentIntegrations." + key, params); }
	Component.onCompleted: backend?.request("status")
	Timer {
		interval: 3000
		repeat: true
		running: root.backend?.integrations.some(row => row.installed && row.verifiedAt == null) ?? false
		onTriggered: if (!root.backend.error) root.backend.request("status")
	}

	component IntegrationButton: Controls.Button {
		id: button
		hoverEnabled: true
		opacity: enabled ? 1 : 0.45
		horizontalPadding: 10
		verticalPadding: 7
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(11)
		contentItem: Text {
			text: button.text
			font: button.font
			color: root.theme.text
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
		}
		background: Rectangle {
			radius: 7
			border.width: 1
			border.color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
			color: Qt.rgba(0.5, 0.5, 0.5, button.hovered || button.activeFocus ? 0.18 : 0.08)
		}
		HoverHandler { cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
	}

	SGroupLabel { theme: root.theme; text: I18n.t("integrations.agents"); above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "bell"; label: I18n.t("agentIntegrations.title")
			desc: root.label("description"); divider: false
			SToggle {
				objectName: "agentAlertsToggle"; theme: root.theme
				accessibleName: root.label("toggleLabel"); checked: root.alertsEnabled
				onToggled: value => root.store.set("bloom-agent-alerts-enabled", value)
			}
		}
	}
	SGroupLabel { theme: root.theme; text: root.label("previewLabel") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "bell"; label: I18n.t("agentIntegrations.test"); divider: false
			Row {
				spacing: 6
				SSelect {
					theme: root.theme; popup: root.popup; accessibleName: root.label("previewAgent")
					options: Object.keys(root.names).map(key => ({ value: key, label: root.names[key] }))
					value: root.previewAgent; onActivated: value => root.previewAgent = value
				}
				SSelect {
					theme: root.theme; popup: root.popup; accessibleName: root.label("previewEvent")
					options: ["thinking", "reading", "editing", "running", "working", "ready", "attention", "error"].map(key => ({
						value: key, label: I18n.t("agentActivity." + key) }))
					value: root.previewKind; onActivated: value => root.previewKind = value
				}
				IntegrationButton {
					objectName: "testAgentNotch"
					text: root.label("test")
					enabled: root.alertsEnabled && !!root.backend && !root.backend.busy
					onClicked: root.backend.request("test", root.previewAgent, root.previewKind)
				}
			}
		}
	}
	SGroupLabel { theme: root.theme; text: root.label("connectGroup") }
	SGroup {
		theme: root.theme
		Repeater {
			model: root.backend?.integrations ?? []
			SRow {
				id: agentRow
				required property var modelData
				readonly property string agent: modelData.agent
				readonly property bool awaiting: modelData.installed && !modelData.needsUpdate && modelData.verifiedAt == null
				objectName: "integration-" + agent
				theme: root.theme
				icon: ""
				iconSource: Object.prototype.hasOwnProperty.call(root.logos, agent) ? "../assets/agents/" + root.logos[agent] : ""
				label: root.names[agent] ?? ""
				desc: root.label(modelData.needsUpdate ? (agent === "opencode" ? "updateOpenCode" : "updateActivity")
					: modelData.installed ? (awaiting ? "awaiting" : "connected")
					: agent === "opencode" ? "plugin" : agent === "codex" ? "codexApproval" : "hooks")
				Row {
					spacing: 6
					IntegrationButton {
						objectName: "help-" + agentRow.agent
						visible: agentRow.awaiting
						text: root.label("help")
						onClicked: root.setupAgent = root.setupAgent === agentRow.agent ? "" : agentRow.agent
					}
					IntegrationButton {
						objectName: "configure-" + agentRow.agent
						enabled: !root.backend.busy
						text: root.label(agentRow.modelData.needsUpdate ? "update"
							: agentRow.modelData.installed ? "disconnect" : agentRow.agent === "codex" ? "setup" : "connect")
						onClicked: {
							const connect = agentRow.modelData.needsUpdate || !agentRow.modelData.installed;
							root.setupAgent = connect ? agentRow.agent : "";
							root.backend.request(connect ? "connect" : "disconnect", agentRow.agent);
						}
					}
				}
			}
		}
	}
	// Bloom's .agent-setup: verify a connection in two steps.
	Item { width: 1; height: setup.visible ? 14 : 0 }
	Rectangle {
		id: setup
		objectName: "setupPanel"
		readonly property string name: root.names[root.setupAgent] ?? ""
		visible: root.setupAgent !== ""
		width: parent.width
		height: visible ? setupColumn.implicitHeight + 32 : 0
		radius: 12
		border.width: 1
		border.color: Qt.rgba(0.5, 0.5, 0.5, 0.18)
		color: Qt.rgba(0.5, 0.5, 0.5, 0.035)
		Accessible.name: root.label("setupLabel", { agent: setup.name })

		component Step: Row {
			id: step
			property int number
			property bool current: false
			property string title
			property string detail
			property string titleName
			property string detailName
			property alias action: actionSlot.data
			width: parent.width
			spacing: 10
			Rectangle {
				width: 22
				height: 22
				radius: 11
				color: "transparent"
				border.width: 1
				border.color: step.current ? "#d0ab6f" : Qt.rgba(0.5, 0.5, 0.5, 0.3)
				Text {
					anchors.centerIn: parent
					text: String(step.number)
					color: step.current ? "#d0ab6f" : root.theme.textMuted
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(10)
				}
			}
			Column {
				width: step.width - 32 - actionSlot.width - (actionSlot.width > 0 ? 10 : 0)
				spacing: 4
				Text {
					objectName: step.titleName
					width: parent.width
					text: step.title
					wrapMode: Text.WordWrap
					color: root.theme.text
					font.family: Fonts.uiFor(Font.DemiBold)
					font.weight: Font.DemiBold
					font.pixelSize: Fonts.px(11)
				}
				Text {
					objectName: step.detailName
					width: parent.width
					text: step.detail
					wrapMode: Text.WordWrap
					color: root.theme.textMuted
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(11)
					lineHeight: 1.55
				}
			}
			Item {
				id: actionSlot
				width: childrenRect.width
				height: childrenRect.height
			}
		}

		Column {
			id: setupColumn
			x: 16
			y: 16
			width: parent.width - 32
			spacing: 4
			Text {
				objectName: "setupTitle"
				text: root.label("verify", { agent: setup.name })
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.weight: Font.DemiBold
				font.pixelSize: Fonts.px(12)
			}
			Text {
				width: parent.width
				text: root.label("verifyDescription")
				wrapMode: Text.WordWrap
				color: root.theme.textMuted
				font.family: Fonts.ui
				font.pixelSize: Fonts.px(11)
				lineHeight: 1.55
			}
			Item { width: 1; height: 14 }
			Step {
				number: 1
				current: true
				titleName: "setupStep1"
				detailName: "setupStep1Desc"
				title: root.setupAgent === "codex" ? root.label("allowHooks") : root.label("restart", { agent: setup.name })
				detail: root.setupAgent === "codex" ? root.label("reviewHooks")
					: root.setupAgent === "opencode" ? root.label("restartOpenCode") : root.label("restartDescription")
			}
			Item { width: 1; height: 14 }
			Step {
				number: 2
				titleName: "setupStep2"
				detailName: "setupStep2Desc"
				title: root.label("sendPrompt")
				detail: root.label("watch")
				action: IntegrationButton {
					objectName: "setupClose"
					text: root.label("close")
					onClicked: root.setupAgent = ""
				}
			}
		}
	}

	component Note: Text {
		width: parent.width - 8
		x: 4
		topPadding: 12
		bottomPadding: 0
		wrapMode: Text.WordWrap
		textFormat: Text.PlainText
		color: root.theme.text
		opacity: 0.65
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(11)
		lineHeight: 1.6
	}
	Note {
		text: root.backend?.busy && !root.backend?.integrations.length ? root.label("loading") : I18n.t("linux.agents.configurationNote")
	}
	Note {
		objectName: "activityNote"
		text: root.label("activityNote")
		bottomPadding: 12
	}

	component Message: Rectangle {
		id: message
		property string text
		property color ink: root.theme.text
		property string labelName
		visible: message.text !== ""
		width: parent.width
		height: visible ? messageText.implicitHeight + 20 : 0
		radius: 8
		color: Qt.rgba(0.5, 0.5, 0.5, 0.08)
		Text {
			id: messageText
			objectName: message.labelName
			x: 12
			y: 10
			width: parent.width - 24
			text: message.text
			visible: message.visible
			wrapMode: Text.WordWrap
			textFormat: Text.PlainText
			color: message.ink
			font.family: Fonts.ui
			font.pixelSize: Fonts.px(11)
			lineHeight: 1.6
		}
	}
	Message {
		labelName: "integrationMessage"
		text: root.backend?.message === "preview" ? I18n.t("linux.agents.previewSent")
			: root.backend?.message === "disconnected" ? root.label("disconnected", { agent: root.names[root.backend.messageAgent] ?? "" }) : ""
	}
	Item { width: 1; height: root.backend?.message && root.backend?.error ? 8 : 0 }
	Message {
		labelName: "integrationError"
		ink: "#e77f7f"
		text: root.backend?.error ?? ""
	}
}
