import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "../modules/notch/qp"
import "."

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
	property string tab: "general"
	property bool autostart: false
	property string version: ""
	property string exportLabel: "Export Settings"
	property string importLabel: "Import Settings"
	property var cityResults: []
	property var drives: []
	property var apps: []

	signal cityQueried(string text)
	signal addFolderRequested()
	signal closeRequested()
	signal dragRequested()
	signal autostartToggled(bool enabled)
	signal resetConfirmed()
	signal restartRequested()
	signal quitRequested()
	signal exportRequested()
	signal importRequested()
	signal colorRequested()

	readonly property var _tabs: [
		{ id: "general", label: "General", icon: "settings", copy: "The essentials for how Bloom starts and runs." },
		{ id: "appearance", label: "Appearance", icon: "palette", copy: "Make every surface feel at home on your desktop." },
		{ id: "notch", label: "Notch", icon: "panel-top", copy: "Choose what appears at the top of your screen." },
		{ id: "dock", label: "Dock", icon: "monitor", copy: "Shape the taskbar replacement around your workflow." },
		{ id: "overlays", label: "Overlays", icon: "layers", copy: "Keep quick controls visible only when you need them." },
		{ id: "about", label: "About", icon: "info", copy: "Version, updates and your settings data." }
	]
	readonly property var _active: root._tabs.find(t => t.id === root.tab)

	onTabChanged: page.contentY = 0

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
			text: "Settings"
			color: root.theme.textMuted
			font.family: Fonts.familyFor(Font.Bold)
			font.pixelSize: Tokens.settings.title.size
			font.weight: Font.Bold
			font.letterSpacing: -0.1
			font.capitalization: Font.AllUppercase
		}
		Rectangle {
			id: closeButton
			objectName: "close"
			x: parent.width - width - Tokens.settings.title.paddingH
			y: Tokens.settings.title.paddingTop
			width: Tokens.settings.title.close
			height: width
			radius: width / 2
			scale: closeHover.hovered ? 1.05 : 1
			color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
			Behavior on color { ColorAnimation { duration: 200 } }
			Behavior on scale { NumberAnimation { duration: 200 } }
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
		Column {
			x: Tokens.settings.sidebar.paddingH
			y: Tokens.settings.sidebar.paddingV
			width: parent.width - 2 * Tokens.settings.sidebar.paddingH - 1
			spacing: Tokens.settings.sidebar.gap

			Column {
				leftPadding: Tokens.settings.sidebar.intro.h
				topPadding: Tokens.settings.sidebar.intro.top
				bottomPadding: Tokens.settings.sidebar.intro.bottom
				spacing: Tokens.settings.sidebar.intro.gap

				Text {
					text: "Bloom"
					color: root.theme.text
					font.family: Fonts.familyFor(Font.Bold)
					font.pixelSize: Tokens.settings.sidebar.intro.title
					font.weight: Font.Bold
					font.letterSpacing: -0.6
					height: 20
					lineHeight: 20
					lineHeightMode: Text.FixedHeight
				}
				Text {
					text: "Make it yours"
					color: root.theme.textMuted
					font.family: Fonts.family
					font.pixelSize: Tokens.settings.sidebar.intro.sub
					height: 12
					lineHeight: 12
					lineHeightMode: Text.FixedHeight
				}
			}
			Repeater {
				model: root._tabs
				delegate: Rectangle {
					id: tabItem
					required property var modelData
					readonly property bool active: tabItem.modelData.id === root.tab
					objectName: "tab:" + tabItem.modelData.id
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
							font.family: Fonts.familyFor(tabItem.active ? Font.DemiBold : Font.Medium)
							font.pixelSize: Tokens.settings.tab.text
							font.weight: tabItem.active ? Font.DemiBold : Font.Medium
						}
					}
					HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
					TapHandler { onTapped: root.tab = tabItem.modelData.id }
				}
			}
		}
	}

	Item {
		id: content
		x: sidebar.x + sidebar.width
		y: sidebar.y
		width: parent.width - x - 1
		height: sidebar.height

		QpScroll { flickable: page }

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
				x: Tokens.settings.content.h
				y: Tokens.settings.content.top
				width: parent.width - 2 * Tokens.settings.content.h

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
						font.family: Fonts.familyFor(Font.Bold)
						font.pixelSize: Tokens.settings.heading.title
						font.weight: 680
						font.letterSpacing: -0.8
						height: 28.6
						lineHeight: 28.6
						lineHeightMode: Text.FixedHeight
					}
					Text {
						objectName: "copy"
						text: root._active.copy
						color: root.theme.textMuted
						font.family: Fonts.family
						font.pixelSize: Tokens.settings.heading.sub
						height: 16.8
						lineHeight: 16.8
						lineHeightMode: Text.FixedHeight
					}
				}
				FeaturePreview {
					theme: root.theme
					store: root.store
					tab: root.tab
					autostart: root.autostart
					apps: root.apps
				}
				Item { width: 1; height: previewGap.visible ? 19 : 0; id: previewGap; visible: root.tab !== "about" }
				Loader {
					width: parent.width
					sourceComponent: ({ general: generalTab, appearance: appearanceTab, notch: notchTab, dock: dockTab, overlays: overlaysTab, about: aboutTab })[root.tab] ?? null
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
		id: aboutTab
		AboutTab {
			theme: root.theme; version: root.version; exportLabel: root.exportLabel; importLabel: root.importLabel
			onExportRequested: root.exportRequested()
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
					text: "Reset Bloom to Defaults"
					color: root.theme.text
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: 14
					font.weight: Font.DemiBold
				}
				Text {
					width: parent.width
					text: "All settings return to their defaults and Bloom restarts. Your enabled surfaces stay as they are."
					wrapMode: Text.Wrap
					color: root.theme.textMuted
					font.family: Fonts.family
					font.pixelSize: 12
				}
				Row {
					anchors.right: parent.right
					topPadding: 6
					spacing: 8
					Repeater {
						model: [{ id: "confirmCancel", label: "Cancel" }, { id: "confirmOk", label: "Reset and Restart" }]
						delegate: Rectangle {
							id: confirmButton
							required property var modelData
							readonly property bool ok: confirmButton.modelData.id === "confirmOk"
							objectName: confirmButton.modelData.id
							width: confirmText.implicitWidth + 24
							height: 28
							radius: 7
							color: confirmButton.ok ? Tokens.settings.danger : root.theme.groupBg
							Text {
								id: confirmText
								anchors.centerIn: parent
								text: confirmButton.modelData.label
								color: confirmButton.ok ? "white" : root.theme.text
								font.family: Fonts.familyFor(Font.Medium)
								font.pixelSize: 12
								font.weight: Font.Medium
							}
							HoverHandler { cursorShape: Qt.PointingHandCursor }
							TapHandler {
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
