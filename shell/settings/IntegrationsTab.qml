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
	Text {
		visible: root.setupAgent !== ""
		width: parent.width
		topPadding: visible ? 12 : 0
		wrapMode: Text.WordWrap
		text: root.setupAgent ? I18n.t(({ claude: "linux.agents.setupClaude", codex: "linux.agents.setupCodex",
			opencode: "linux.agents.setupOpencode" })[root.setupAgent]) : ""
		textFormat: Text.PlainText
		color: root.theme.text
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(13)
	}
	Text {
		width: parent.width
		topPadding: 12
		wrapMode: Text.WordWrap
		textFormat: Text.PlainText
		text: root.backend?.error || (root.backend?.busy ? root.label("loading") : I18n.t("linux.agents.configurationNote"))
		color: root.theme.textMuted
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(13)
	}
}
