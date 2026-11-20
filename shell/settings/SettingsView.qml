import QtQuick
import "../common"
import "../common/render"
import "../common/i18n"
import "../common/tokens.js" as Tokens
import "../modules/notch/qp"
import "."
import "search.js" as Search

// Bloom's settings window: title bar, sidebar and the active tab. Pure:
// `store` holds the values, and settings-app.qml does the system work.
Rectangle {
	id: root

	property QtObject theme: QtObject {
		property color bg: Qt.rgba(18 / 255, 18 / 255, 20 / 255, 0.5)
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
		property color scrollbarThumb: Qt.rgba(1, 1, 1, 0.1)
	}
	required property var store
	// This process's text follows bloom-language live (the shell binds its own).
	Binding { target: I18n; property: "setting"; value: root.store.values["bloom-language"] ?? "system" }
	property string tab: "general"
	property bool autostart: false
	property string version: ""
	property string exportLabel: I18n.t("settings.about.export")
	property string importLabel: I18n.t("settings.about.import")
	property var cityResults: []
	property var drives: []
	property var sys
	property var net
	property var bt
	property var agentIntegrations
	signal cheatsheetRequested()
	signal setupRequested()

	property string saveError: ""
	signal errorDismissed()
	property string query: ""
	readonly property var _hits: Search.find(root.query, key => I18n.t(key))
	signal cityQueried(string text)
	signal addFolderRequested()
	signal closeRequested()
	signal dragRequested()
	signal autostartToggled(bool enabled)
	signal resetConfirmed()
	signal restartRequested()
	signal quitRequested()
	signal exportRequested()
	signal linkRequested(url link)
	signal importRequested()
	signal colorRequested()

	readonly property var _groups: [
		{ label: I18n.t("settings.groups.system"), tabs: [
			{ id: "display", label: I18n.t("settings.groups.display"), icon: "monitor", copy: I18n.t("linux.settings.screensResolutionScaleAndBrightness") },
			{ id: "sound", label: I18n.t("linux.settings.sound"), icon: "volume-2", copy: I18n.t("linux.settings.whereSoundPlaysAndWhichMicrophoneListens") },
			{ id: "power", label: I18n.t("linux.settings.power"), icon: "gauge", copy: I18n.t("linux.settings.powerModeAndBattery") },
			{ id: "storage", label: I18n.t("linux.settings.storage"), icon: "hard-drive", copy: I18n.t("linux.settings.howFullYourDisksAre") },
		] },
		{ label: I18n.t("linux.settings.connections"), tabs: [
			{ id: "network", label: I18n.t("linux.settings.network"), icon: "wifi", copy: I18n.t("linux.settings.wiFiSavedNetworksAndVpn") },
			{ id: "bluetooth", label: I18n.t("notch.commandCenter.bluetooth"), icon: "bluetooth", copy: I18n.t("linux.settings.pairAndManageDevices") }
		] },
		{ label: I18n.t("ui.dockExtras.desktop"), tabs: [
			{ id: "input", label: I18n.t("linux.settings.input"), icon: "keyboard", copy: I18n.t("linux.settings.keyboardTouchpadAndMouse") },
			{ id: "hyprland", label: I18n.t("settings.dock.iconWindows"), icon: "layout-grid", copy: I18n.t("linux.settings.gapsBordersCornersAndEffects") },
			{ id: "apps", label: I18n.t("linux.settings.apps"), icon: "app-window", copy: I18n.t("linux.settings.defaultsStartupAppsAndEverythingInstalled") },
			{ id: "ai", label: I18n.t("linux.settings.ai"), icon: "sparkles", copy: I18n.t("linux.settings.geminiChatInSpotlight") },
			{ id: "time", label: I18n.t("linux.settings.time"), icon: "clock", copy: I18n.t("linux.settings.timeZoneAndClockSync") },
			{ id: "updates", label: I18n.t("linux.settings.updates"), icon: "package", copy: I18n.t("linux.settings.keepTheSystemCurrent") }
		] },
		{ label: I18n.t("settings.dock.iconBloom"), tabs: [
			{ id: "general", label: I18n.t("settings.tabs.general"), icon: "settings", copy: I18n.t("ui.settings.theEssentialsForHowBloomStartsAndRuns") },
			{ id: "appearance", label: I18n.t("settings.tabs.appearance"), icon: "palette", copy: I18n.t("ui.settings.makeEverySurfaceFeelAtHomeOnYourDesktop") },
			{ id: "notch", label: I18n.t("settings.tabs.notch"), icon: "panel-top", copy: I18n.t("ui.settings.chooseWhatAppearsAtTheTopOfYourScreen") },
			{ id: "dock", label: I18n.t("settings.tabs.dock"), icon: "monitor", copy: I18n.t("ui.settings.shapeTheTaskbarReplacementAroundYourWorkflow") },
			{ id: "overlays", label: I18n.t("settings.tabs.overlays"), icon: "layers", copy: I18n.t("ui.settings.keepQuickControlsVisibleOnlyWhenYouNeedThem") },
			{ id: "integrations", label: I18n.t("settings.tabs.integrations"), icon: "bell", copy: I18n.t("integrations.agentsDescription") },
			{ id: "about", label: I18n.t("settings.tabs.about"), icon: "info", copy: I18n.t("linux.settings.bloomYourSystemAndSettingsData") }
		] }
	]
	readonly property var _tabs: root._groups.reduce((all, g) => all.concat(g.tabs), [])
	readonly property var _active: root._tabs.find(t => t.id === root.tab)
	readonly property bool _system: ["general", "appearance", "notch", "dock", "overlays", "integrations", "about"].indexOf(root.tab) < 0

	OpeningMotion { id: pageEntrance; initial: 1; target: 1 }
	onTabChanged: {
		page.contentY = 0;
		pageEntrance.jump(Render.macMotion && !Render.reduceMotion ? 0 : 1);
	}

	function _open(hit) {
		root.tab = hit.tab;
		searchField.text = "";
	}
	function _step(delta) {
		const at = root._tabs.findIndex(t => t.id === root.tab);
		root.tab = root._tabs[(at + delta + root._tabs.length) % root._tabs.length].id;
	}
	TypingGuard { id: hoverGuard }

	Keys.onPressed: event => {
		if (!(event.modifiers & Qt.ControlModifier)) return;
		if (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown) root._step(1);
		else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp) root._step(-1);
		else return;
		event.accepted = true;
	}
	function _scroll(by) {
		page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, page.contentY + by));
	}
	Keys.onReleased: event => {
		if (event.modifiers & Qt.ControlModifier) return;
		if (event.key === Qt.Key_PageDown) root._scroll(page.height * 0.9);
		else if (event.key === Qt.Key_PageUp) root._scroll(-page.height * 0.9);
	}
	Keys.onEscapePressed: {
		if (confirm.visible) confirm.visible = false;
		else root.closeRequested();
	}
	focus: true

	radius: Tokens.settings.window.radius
	color: root.theme.bg
	border.width: 1
	border.color: root.theme.border
	clip: true

	Item {
		id: titleBar
		x: 1
		y: 1
		width: parent.width - 2
		height: Tokens.settings.title.paddingTop + Tokens.settings.title.close + Tokens.settings.title.paddingBottom

		// cursor: default — the title bar moves the window
		MouseArea {
			anchors.fill: parent
			onPressed: root.dragRequested()
		}
		Text {
			objectName: "title"
			x: Tokens.settings.title.paddingH
			anchors.verticalCenter: closeButton.verticalCenter
			text: I18n.t("settings.title")
			color: root.theme.textMuted
			font.family: Fonts.uiFor(Font.Bold)
			font.pixelSize: Fonts.px(Tokens.settings.title.size)
			font.weight: Font.Bold
			font.letterSpacing: -0.1
			font.capitalization: Font.AllUppercase
		}
		Rectangle {
			id: closeButton
			objectName: "close"
			activeFocusOnTab: true
			Accessible.role: Accessible.Button
			Accessible.name: I18n.t("settings.closeTitle")
			Keys.onSpacePressed: root.closeRequested()
			Keys.onReturnPressed: root.closeRequested()
			SFocusRing {}
			x: parent.width - width - Tokens.settings.title.paddingH
			y: Tokens.settings.title.paddingTop
			width: Tokens.settings.title.close
			height: width
			radius: width / 2
			color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
			Behavior on color { ColorAnimation { duration: 120 } }
			SvgIcon {
				anchors.centerIn: parent
				name: "x"
				size: Tokens.settings.title.closeIcon
				strokeWidth: 1.5
				color: root.theme.text
			}
			HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
			TapHandler { onTapped: root.closeRequested() }
		}
	}

	Rectangle {
		id: sidebar
		x: 1
		y: titleBar.y + titleBar.height
		width: Tokens.settings.sidebar.width
		height: parent.height - y - 1
		color: Qt.rgba(1, 1, 1, 0.015)

		Rectangle {
			x: parent.width - 1
			width: 1
			height: parent.height
			color: root.theme.border
		}
		Flickable {
			id: sideFlick
			anchors.fill: parent
			anchors.rightMargin: 1
			contentHeight: sideColumn.implicitHeight + 2 * Tokens.settings.sidebar.paddingV
			interactive: false // QpScroll scrolls it
			boundsBehavior: Flickable.StopAtBounds
			clip: true

		Column {
			id: sideColumn
			x: Tokens.settings.sidebar.paddingH
			y: Tokens.settings.sidebar.paddingV
			width: parent.width - 2 * Tokens.settings.sidebar.paddingH
			spacing: Tokens.settings.sidebar.gap

			Column {
				leftPadding: Tokens.settings.sidebar.intro.h
				topPadding: Tokens.settings.sidebar.intro.top
				bottomPadding: Tokens.settings.sidebar.intro.bottom
				spacing: Tokens.settings.sidebar.intro.gap

				Text {
					text: I18n.t("settings.dock.iconBloom")
					color: root.theme.text
					font.family: Fonts.uiFor(Font.Bold)
					font.pixelSize: Fonts.px(Tokens.settings.sidebar.intro.title)
					font.weight: Font.Bold
					font.letterSpacing: -0.6
					height: Fonts.px(24)
					lineHeight: Fonts.px(24)
					lineHeightMode: Text.FixedHeight
				}
				Text {
					text: I18n.t("ui.settings.makeItYours")
					color: root.theme.textMuted
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(Tokens.settings.sidebar.intro.sub)
					height: Fonts.px(16)
					lineHeight: Fonts.px(16)
					lineHeightMode: Text.FixedHeight
				}
			}
			SField {
				id: searchField
				objectName: "settingsSearch"
				width: parent.width
				theme: root.theme
				placeholder: I18n.t("linux.settings.findASetting")
				accessibleName: I18n.t("linux.settings.findASetting")
				onTextChanged: root.query = text
				onEdited: hoverGuard.typed()
				onAccepted: if (root._hits.length) root._open(root._hits[0])
			}
			Item { width: 1; height: 10 }
			Text {
				objectName: "noHits"
				visible: root.query !== "" && root._hits.length === 0
				leftPadding: 12
				topPadding: 8
				text: I18n.t("linux.settings.nothingFound")
				color: root.theme.textMuted
				font.family: Fonts.ui
				font.pixelSize: Fonts.px(14)
			}
			Repeater {
				model: root._hits
				delegate: Rectangle {
					id: hit
					required property var modelData
					objectName: "hit:" + hit.modelData.label
					width: parent.width
					height: 40
					radius: Tokens.settings.tab.radius
					color: hitHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
					activeFocusOnTab: true
					Accessible.role: Accessible.Button
					Accessible.name: hit.modelData.label
					Keys.onReturnPressed: root._open(hit.modelData)
					SFocusRing { inset: 0 }
					Column {
						x: Tokens.settings.tab.paddingH
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 2 * x
						Text {
							width: parent.width
							text: hit.modelData.label
							elide: Text.ElideRight
							color: root.theme.text
							font.family: Fonts.uiFor(Font.Medium)
							font.pixelSize: Fonts.px(14)
							font.weight: Font.Medium
						}
						Text {
							text: root._tabs.find(t => t.id === hit.modelData.tab)?.label ?? ""
							color: root.theme.textMuted
							font.family: Fonts.ui
							font.pixelSize: Fonts.px(12)
						}
					}
					HoverHandler { id: hitHover; enabled: !hoverGuard.typing; cursorShape: Qt.PointingHandCursor }
					TapHandler { onTapped: root._open(hit.modelData) }
				}
			}
			Repeater {
				model: root.query === "" ? root._groups : []
				delegate: Column {
					id: tabGroup
					required property var modelData
					required property int index
					width: parent.width
					spacing: Tokens.settings.sidebar.gap

					Text {
						leftPadding: Tokens.settings.tab.paddingH
						topPadding: tabGroup.index === 0 ? 0 : 16
						bottomPadding: 4
						text: tabGroup.modelData.label
						color: root.theme.textMuted
						font.family: Fonts.uiFor(Font.DemiBold)
						font.pixelSize: Fonts.px(12)
						font.weight: Font.DemiBold
						font.capitalization: Font.AllUppercase
						font.letterSpacing: 0.5
					}
					Repeater {
						model: tabGroup.modelData.tabs
						delegate: Rectangle {
							id: tabItem
							required property var modelData
							readonly property bool active: tabItem.modelData.id === root.tab
							objectName: "tab:" + tabItem.modelData.id
					activeFocusOnTab: true
					Accessible.role: Accessible.PageTab
					Accessible.name: tabItem.modelData.label
					Accessible.selected: tabItem.active
					Keys.onSpacePressed: root.tab = tabItem.modelData.id
					Keys.onReturnPressed: root.tab = tabItem.modelData.id
					SFocusRing { inset: 0 }
							width: parent.width
							height: Tokens.settings.tab.height
							radius: Tokens.settings.tab.radius
							color: tabItem.active ? Qt.rgba(1, 1, 1, 0.08) : tabHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
							Behavior on color { ColorAnimation { duration: Tokens.settings.tab.ms } }

							Row {
								x: Tokens.settings.tab.paddingH
								height: parent.height
								spacing: Tokens.settings.tab.gap
								opacity: tabItem.active || tabHover.hovered ? 1 : Tokens.settings.tab.idleOpacity

								Item {
									width: Tokens.settings.tab.icon
									height: width
									anchors.verticalCenter: parent.verticalCenter
									SvgIcon {
										anchors.centerIn: parent
										name: tabItem.modelData.icon
										size: Tokens.settings.tab.glyph
										strokeWidth: 1.5
										color: tabItem.active || tabHover.hovered ? root.theme.text : root.theme.textMuted
									}
								}
								Text {
									anchors.verticalCenter: parent.verticalCenter
									text: tabItem.modelData.label
									color: root.theme.text
									font.family: Fonts.uiFor(tabItem.active ? Font.DemiBold : Font.Medium)
									font.pixelSize: Fonts.px(Tokens.settings.tab.text)
									font.weight: tabItem.active ? Font.DemiBold : Font.Medium
								}
							}
							HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
							TapHandler { onTapped: root.tab = tabItem.modelData.id }
						}

					}
				}
			}
		}
		}
		QpScroll { flickable: sideFlick }
		ScrollThumb { objectName: "sideThumb"; flickable: sideFlick; thumbColor: root.theme.scrollbarThumb }
	}

	Item {
		id: content
		x: sidebar.x + sidebar.width
		y: sidebar.y
		width: parent.width - x - 1
		height: sidebar.height

		QpScroll { flickable: page }
		ScrollThumb { objectName: "pageThumb"; flickable: page; thumbColor: root.theme.scrollbarThumb }

		Flickable {
			id: page
			objectName: "page"
			anchors.fill: parent
			contentWidth: width
			contentHeight: pageColumn.implicitHeight + Tokens.settings.content.top + Tokens.settings.content.bottom
			interactive: false // QpScroll scrolls it
			boundsBehavior: Flickable.StopAtBounds
			clip: true

			Column {
				id: pageColumn
				opacity: pageEntrance.progress
				transform: Translate { y: pageEntrance.rise }
				x: Tokens.settings.content.h
				y: Tokens.settings.content.top
				width: parent.width - 2 * Tokens.settings.content.h

				// Bloom's .settings-save-error, for anything that didn't take effect.
				Rectangle {
					objectName: "errorBanner"
					readonly property string message: root.saveError || (root.sys ? root.sys.lastError : "") || ""
					visible: message !== ""
					width: parent.width
					height: visible ? errorText.implicitHeight + 22 : 0
					radius: 10
					color: Qt.rgba(239 / 255, 96 / 255, 96 / 255, 0.12)
					border.width: 1
					border.color: Qt.rgba(239 / 255, 96 / 255, 96 / 255, 0.45)
					Accessible.role: Accessible.AlertMessage
					Accessible.name: message

					Text {
						id: errorText
						objectName: "errorText"
						x: 12
						y: 11
						width: parent.width - 48
						text: parent.message
						textFormat: Text.PlainText
						wrapMode: Text.Wrap
						color: root.theme.text
						font.family: Fonts.ui
						font.pixelSize: Fonts.px(14)
					}
					SvgIcon {
						x: parent.width - width - 12
						anchors.verticalCenter: parent.verticalCenter
						name: "x"
						size: 14
						color: root.theme.text
						TapHandler {
							onTapped: {
								root.errorDismissed();
								if (root.sys) root.sys.clearError();
							}
						}
						HoverHandler { cursorShape: Qt.PointingHandCursor }
					}
				}
				Column {
					width: parent.width
					leftPadding: Tokens.settings.heading.h
					topPadding: Tokens.settings.heading.top
					bottomPadding: Tokens.settings.heading.bottom
					spacing: Tokens.settings.heading.titleGap

					Text {
						objectName: "heading"
						text: root._active.label
						color: root.theme.text
						font.family: Fonts.uiFor(Font.Bold)
						font.pixelSize: Fonts.px(Tokens.settings.heading.title)
						font.weight: 680
						font.letterSpacing: -0.8
						height: Fonts.px(34)
						lineHeight: Fonts.px(34)
						lineHeightMode: Text.FixedHeight
					}
					Text {
						objectName: "copy"
						text: root._active.copy
						color: root.theme.textMuted
						font.family: Fonts.ui
						font.pixelSize: Fonts.px(Tokens.settings.heading.sub)
						height: Fonts.px(18)
						lineHeight: Fonts.px(18)
						lineHeightMode: Text.FixedHeight
					}
				}
				Loader {
					width: parent.width
					// A Loader keeps its last height when it goes inactive.
					height: active && item ? item.implicitHeight : 0
					active: root._system && root.sys !== undefined && root.tab !== "network" && root.tab !== "bluetooth"
					sourceComponent: SystemPages {
						theme: root.theme; popup: selectPopup; sys: root.sys; store: root.store; page: root.tab
						onCheatsheetRequested: root.cheatsheetRequested()
					}
				}
				Loader {
					objectName: "connection"
					width: parent.width
					height: active && item ? item.implicitHeight : 0
					active: (root.tab === "network" || root.tab === "bluetooth") && root.net !== undefined
					sourceComponent: ConnectionPages { theme: root.theme; net: root.net; bt: root.bt; sys: root.sys; accent: root.theme.accent ?? "#007aff"; page: root.tab }
				}
				Loader {
					width: parent.width
					height: item ? item.implicitHeight : 0
					sourceComponent: ({ general: generalTab, appearance: appearanceTab, notch: notchTab, dock: dockTab, overlays: overlaysTab, integrations: integrationsTab, about: aboutTab })[root.tab] ?? null
				}
			}
		}
	}

	Component {
		id: generalTab
		GeneralTab {
			theme: root.theme; store: root.store; popup: selectPopup; autostart: root.autostart
			onAutostartToggled: value => root.autostartToggled(value)
			onResetRequested: confirm.visible = true
			onRestartRequested: root.restartRequested()
			onQuitRequested: root.quitRequested()
			onSetupRequested: root.setupRequested()
		}
	}
	Component {
		id: appearanceTab
		AppearanceTab { theme: root.theme; store: root.store; popup: selectPopup; onColorRequested: root.colorRequested() }
	}
	Component {
		id: notchTab
		NotchTab { theme: root.theme; store: root.store; popup: selectPopup; cityResults: root.cityResults; onCityQueried: text => root.cityQueried(text) }
	}
	Component {
		id: dockTab
		DockTab { theme: root.theme; accent: root.theme.accent ?? "#007aff"; store: root.store; popup: selectPopup; drives: root.drives; onAddFolderRequested: root.addFolderRequested() }
	}
	Component {
		id: overlaysTab
		OverlaysTab { theme: root.theme; store: root.store }
	}
	Component {
		id: integrationsTab
		IntegrationsTab { theme: root.theme; store: root.store; popup: selectPopup; backend: root.agentIntegrations }
	}
	Component {
		id: aboutTab
		AboutTab {
			theme: root.theme; version: root.version; osInfo: root.sys?.osInfo ?? ({}); distroLogo: root.sys?.distroLogo ?? ""; kernel: root.sys?.kernel ?? ""; architecture: root.sys?.architecture ?? ""; hostname: root.sys?.hostname ?? ""; cpu: root.sys?.cpu ?? ""; memory: root.sys?.memory ?? ""; exportLabel: root.exportLabel; importLabel: root.importLabel
			onExportRequested: root.exportRequested()
			onLinkRequested: link => root.linkRequested(link)
			onImportRequested: root.importRequested()
		}
	}

	// Bloom asks through a native dialog; here it's a card over the window.
	Rectangle {
		id: confirm
		objectName: "confirm"
		anchors.fill: parent
		visible: false
		radius: root.radius
		color: Qt.rgba(0, 0, 0, 0.5)

		// cursor: default — the dimmed window behind the question
		MouseArea { anchors.fill: parent }
		Rectangle {
			anchors.centerIn: parent
			width: 340
			height: confirmColumn.implicitHeight + 36
			radius: 12
			color: root.theme.bgExpanded
			border.width: 1
			border.color: root.theme.border

			Column {
				id: confirmColumn
				x: 18
				y: 18
				width: parent.width - 36
				spacing: 8

				Text {
					text: I18n.t("settings.dialogs.resetTitle")
					color: root.theme.text
					font.family: Fonts.uiFor(Font.DemiBold)
					font.pixelSize: Fonts.px(16)
					font.weight: Font.DemiBold
				}
				Text {
					width: parent.width
					text: I18n.t("linux.settings.allSettingsReturnToTheirDefaultsAndBloom")
					wrapMode: Text.Wrap
					color: root.theme.textMuted
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(14)
				}
				Row {
					anchors.right: parent.right
					topPadding: 6
					spacing: 8
					Repeater {
						model: [{ id: "confirmCancel", label: I18n.t("common.cancel") }, { id: "confirmOk", label: I18n.t("settings.dialogs.resetConfirm") }]
						delegate: Rectangle {
							id: confirmButton
							required property var modelData
							readonly property bool ok: confirmButton.modelData.id === "confirmOk"
							objectName: confirmButton.modelData.id
							activeFocusOnTab: true
							Accessible.role: Accessible.Button
							Accessible.name: confirmButton.modelData.label
							Keys.onSpacePressed: tap.tapped(null, Qt.LeftButton)
							Keys.onReturnPressed: tap.tapped(null, Qt.LeftButton)
							SFocusRing {}
							width: confirmText.implicitWidth + 24
							height: 28
							radius: 7
							color: confirmButton.ok ? Tokens.settings.danger : root.theme.groupBg
							Text {
								id: confirmText
								anchors.centerIn: parent
								text: confirmButton.modelData.label
								color: confirmButton.ok ? "white" : root.theme.text
								font.family: Fonts.uiFor(Font.Medium)
								font.pixelSize: Fonts.px(14)
								font.weight: Font.Medium
							}
							HoverHandler { cursorShape: Qt.PointingHandCursor }
							TapHandler {
								id: tap
								onTapped: {
									confirm.visible = false;
									if (confirmButton.ok) root.resetConfirmed();
								}
							}
						}
					}
				}
			}
		}
	}

	SPopup {
		id: selectPopup
		objectName: "selectPopup"
		theme: root.theme
	}
}
