import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "logic.js" as Logic
import "../common/i18n"

// Bloom's DockTab, in Linux terms: Trash for the Recycle Bin, Super+Alt+Number
// for Win+Number, the dock's workspaces for Task View. There's no Start button
// here, so Start Menu Icon stays out.
Column {
	id: root
	property QtObject theme
	property color accent: "#007aff"
	property var store
	property Item popup
	property var drives: []
	signal addFolderRequested()

	readonly property var _v: root.store.values
	readonly property var _modules: root._v["bloom-enabled-modules"]
	readonly property bool _dock: root._modules.indexOf("dock") >= 0
	readonly property string _mode: root._v["bloom-dock-mode"]
	readonly property bool _fixed: root._mode === "fixed"
	readonly property int _delay: root._v["bloom-dock-edge-delay"]
	readonly property string _extras: root._v["bloom-dock-extras-position"]
	readonly property bool _drives: root._v["bloom-dock-extras-drives"]
	readonly property var _hidden: Logic.parseList(root._v["bloom-dock-extras-hidden-drives"])
	readonly property var _folders: Logic.folderList(root._v["bloom-dock-extras-folders"])
	readonly property var _custom: Logic.parseList(root._v["bloom-dock-extras-custom-folders"])
	function set(key, value) { root.store.set(key, value); }

	width: parent.width

	SGroupLabel { theme: root.theme; text: I18n.t("settings.tabs.dock"); above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "monitor"; label: I18n.t("settings.dock.enabled"); desc: I18n.t("linux.settings.showTheDockAtTheBottomOfThe"); divider: root._dock
			SToggle { accessibleName: I18n.t("settings.dock.enabled"); objectName: "dock"; theme: root.theme; checked: root._dock; onToggled: value => root.set("bloom-enabled-modules", Logic.toggled(root._modules, "dock")) }
		}
		Column {
			objectName: "dockRows"
			visible: root._dock
			width: parent.width

			SRow {
				theme: root.theme; icon: root._fixed ? "eye-off" : "eye"; label: I18n.t("settings.dock.behavior"); desc: I18n.t("settings.dock.behaviorDesc")
				SSelect { accessibleName: I18n.t("settings.dock.behavior");
					objectName: "dockMode"; theme: root.theme; popup: root.popup; value: root._mode
					options: [{ value: "fixed", label: I18n.t("common.behavior.fixed") }, { value: "smart", label: I18n.t("common.behavior.smart") }, { value: "peek", label: I18n.t("common.behavior.peek") }]
					onActivated: value => root.set("bloom-dock-mode", value)
				}
			}
			SRow {
				objectName: "dockPeek"
				visible: !root._fixed
				theme: root.theme; icon: "timer"; label: I18n.t("settings.notch.peekDelay")
				desc: root._delay === 0 ? I18n.t("ui.dockTab.revealInstantlyOnBottomEdgeContact") : I18n.t("ui.dockTab.restOnTheBottomEdgeForDockedgedelayMsToReveal", { dockEdgeDelay: root._delay })
				SSlider { theme: root.theme; from: 0; to: 800; step: 50; value: root._delay; onMoved: value => root.set("bloom-dock-edge-delay", value) }
			}
			SRow {
				theme: root.theme; icon: "eye"; label: I18n.t("settings.dock.previews"); desc: I18n.t("settings.dock.previewsDesc")
				SToggle { accessibleName: I18n.t("settings.dock.previews"); theme: root.theme; checked: root._v["bloom-dock-preview-enabled"]; onToggled: value => root.set("bloom-dock-preview-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "layers"; label: I18n.t("ui.dockTab.showBackgroundApps"); desc: I18n.t("ui.dockTab.keepAppsInTheDockWhenTheyCloseToThe")
				SToggle { objectName: "backgroundApps"; accessibleName: I18n.t("ui.dockTab.showBackgroundApps"); theme: root.theme; checked: root._v["bloom-dock-show-background-apps"]; onToggled: value => root.set("bloom-dock-show-background-apps", value) }
			}
			SRow {
				theme: root.theme; icon: "circle"; label: I18n.t("settings.dock.iconOnly"); desc: I18n.t("settings.dock.iconOnlyDesc")
				SToggle { accessibleName: I18n.t("settings.dock.iconOnly"); theme: root.theme; checked: root._v["bloom-dock-icon-only"]; onToggled: value => root.set("bloom-dock-icon-only", value) }
			}
			SRow {
				theme: root.theme; icon: "columns-2"; label: I18n.t("ui.dockTab.appSeparator"); desc: I18n.t("ui.dockTab.showADividerBeforeUnpinnedApps")
				SToggle { accessibleName: I18n.t("ui.dockTab.appSeparator"); theme: root.theme; checked: root._v["bloom-dock-separator-enabled"]; onToggled: value => root.set("bloom-dock-separator-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "layers"; label: I18n.t("linux.settings.workspaces"); desc: I18n.t("linux.settings.showThisScreenSWorkspacesInTheDock")
				SToggle { accessibleName: I18n.t("linux.settings.workspaces"); theme: root.theme; checked: root._v["bloom-dock-workspaces-enabled"]; onToggled: value => root.set("bloom-dock-workspaces-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: I18n.t("linux.settings.superAltNumberShortcuts"); desc: I18n.t("linux.settings.openPinnedAppsWithSuperAlt1Through")
				SToggle { accessibleName: I18n.t("linux.settings.superAltNumberShortcuts"); theme: root.theme; checked: root._v["bloom-dock-win-number-enabled"]; onToggled: value => root.set("bloom-dock-win-number-enabled", value) }
			}
			SRow {
				objectName: "dockAdaptive"
				visible: root._fixed
				theme: root.theme; icon: "maximize-2"; label: I18n.t("settings.dock.adaptive"); desc: I18n.t("settings.dock.adaptiveDesc")
				SToggle { accessibleName: I18n.t("settings.dock.adaptive"); theme: root.theme; checked: root._v["bloom-dock-adaptive"]; onToggled: value => root.set("bloom-dock-adaptive", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-panel-left"; label: I18n.t("ui.dockTab.dockExtras"); desc: I18n.t("linux.settings.showDrivesFoldersAndTheTrashBesideThe"); divider: false
				SSelect { accessibleName: I18n.t("ui.dockTab.dockExtras");
					objectName: "extras"; theme: root.theme; popup: root.popup; value: root._extras
					options: [{ value: "off", label: I18n.t("notch.commandCenter.off") }, { value: "left", label: I18n.t("common.left") }, { value: "right", label: I18n.t("common.right") }]
					onActivated: value => root.set("bloom-dock-extras-position", value)
				}
			}
			SDisclosure {
				visible: root._extras !== "off"
				theme: root.theme; summary: "Manage dock extras"; hint: "Drives, folders and Trash"
				SRow {
					theme: root.theme; icon: "hard-drive"; label: I18n.t("ui.dockTab.drives"); desc: I18n.t("ui.dockTab.fixedRemovableAndConnectedNetworkDrives"); divider: !root._drives
					SToggle { accessibleName: I18n.t("ui.dockTab.drives"); theme: root.theme; checked: root._drives; onToggled: value => root.set("bloom-dock-extras-drives", value) }
				}
				Item {
					visible: root._drives && root.drives.length > 0
					width: parent.width
					height: visible ? driveFlow.height + 12 + 1 : 0
					Flow {
						id: driveFlow
						x: 14
						width: parent.width - 28
						spacing: 8
						Repeater {
							model: root.drives
							delegate: SChip {
								required property var modelData
								theme: root.theme; accent: root.accent
								objectName: "drive:" + modelData.id
								text: modelData.label
								active: root._hidden.indexOf(modelData.id) < 0
								onClicked: root.set("bloom-dock-extras-hidden-drives", JSON.stringify(Logic.toggled(root._hidden, modelData.id)))
							}
						}
					}
					Rectangle { x: 52; y: parent.height - 1; width: parent.width - x; height: 1; color: root.theme.border }
				}
				SRow {
					theme: root.theme; icon: "trash-2"; label: I18n.t("linux.settings.trash"); desc: I18n.t("linux.settings.showTheTrashInTheExtras")
					SToggle { accessibleName: I18n.t("linux.settings.trash"); theme: root.theme; checked: root._v["bloom-dock-extras-recycle-bin"]; onToggled: value => root.set("bloom-dock-extras-recycle-bin", value) }
				}
				SRow {
					theme: root.theme; icon: "folder-open"; label: I18n.t("ui.dockTab.specialFolders"); desc: I18n.t("ui.dockTab.pickTheFoldersThatAppearInTheExtras"); divider: false
				}
				Item {
					width: parent.width
					height: folderFlow.height + 10
					Flow {
						id: folderFlow
						x: Tokens.settings.row.inset
						width: parent.width - Tokens.settings.row.inset - 14
						spacing: 8
						Repeater {
							model: [{ id: "desktop", label: I18n.t("ui.dockExtras.desktop") }, { id: "documents", label: I18n.t("ui.dockExtras.documents") }, { id: "downloads", label: I18n.t("ui.dockExtras.downloads") }, { id: "pictures", label: I18n.t("ui.dockExtras.pictures") }, { id: "music", label: I18n.t("ui.dockExtras.music") }, { id: "videos", label: I18n.t("ui.dockExtras.videos") }]
							delegate: SChip {
								required property var modelData
								theme: root.theme; accent: root.accent
								objectName: "folder:" + modelData.id
								text: modelData.label
								active: root._folders.indexOf(modelData.id) >= 0
								onClicked: root.set("bloom-dock-extras-folders", Logic.toggled(root._folders, modelData.id).join(","))
							}
						}
					}
				}
				Rectangle { x: 52; width: parent.width - x; height: 1; color: root.theme.border }
				SRow {
					theme: root.theme; icon: "folder-plus"; label: I18n.t("ui.dockTab.customFolders"); desc: I18n.t("ui.dockTab.addAnyFolderToTheExtrasSection"); divider: false
				}
				Column {
					x: Tokens.settings.row.inset
					width: parent.width - Tokens.settings.row.inset - 14
					bottomPadding: 10
					spacing: 6
					Repeater {
						model: root._custom
						delegate: Item {
							id: custom
							required property var modelData
							width: parent.width
							height: 20
							Text {
								id: customName
								anchors.verticalCenter: parent.verticalCenter
								text: custom.modelData.name
								textFormat: Text.PlainText
								color: root.theme.text
								font.family: Fonts.uiFor(Font.Medium)
								font.pixelSize: Fonts.px(14)
								font.weight: Font.Medium
							}
							Text {
								x: customName.width + 8
								width: parent.width - x - 28
								anchors.verticalCenter: parent.verticalCenter
								text: custom.modelData.path
								textFormat: Text.PlainText
								elide: Text.ElideRight
								color: root.theme.textMuted
								opacity: 0.9
								font.family: Fonts.ui
								font.pixelSize: Fonts.px(13)
							}
							Rectangle {
								objectName: "removeFolder:" + custom.modelData.path
								x: parent.width - width
								anchors.verticalCenter: parent.verticalCenter
								width: 20
								height: 20
								radius: 6
								color: removeHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
								SvgIcon { anchors.centerIn: parent; name: "x"; size: 14; color: removeHover.hovered ? root.theme.text : root.theme.textMuted }
								HoverHandler { id: removeHover; cursorShape: Qt.PointingHandCursor }
								TapHandler { onTapped: root.set("bloom-dock-extras-custom-folders", JSON.stringify(root._custom.filter(f => f.path !== custom.modelData.path))) }
							}
						}
					}
					SChip {
						objectName: "addFolder"
						theme: root.theme; accent: root.accent
						icon: "plus"
						text: I18n.t("ui.dockTab.addFolder")
						onClicked: root.addFolderRequested()
					}
				}
			}
		}
	}
}
