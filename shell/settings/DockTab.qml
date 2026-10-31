import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "logic.js" as Logic

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

	SGroupLabel { theme: root.theme; text: "Dock"; above: Tokens.settings.group.label.firstTop }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "monitor"; label: "Bloom Dock"; desc: "Show the dock at the bottom of the screen"; divider: root._dock
			SToggle { objectName: "dock"; theme: root.theme; checked: root._dock; onToggled: value => root.set("bloom-enabled-modules", Logic.toggled(root._modules, "dock")) }
		}
		Column {
			objectName: "dockRows"
			visible: root._dock
			width: parent.width

			SRow {
				theme: root.theme; icon: root._fixed ? "eye-off" : "eye"; label: "Behavior"; desc: "Choose how the dock appears"
				SSelect {
					objectName: "dockMode"; theme: root.theme; popup: root.popup; value: root._mode
					options: [{ value: "fixed", label: "Fixed" }, { value: "smart", label: "Smart" }, { value: "peek", label: "Peek" }]
					onActivated: value => root.set("bloom-dock-mode", value)
				}
			}
			SRow {
				objectName: "dockPeek"
				visible: !root._fixed; height: visible ? implicitHeight : 0; implicitHeight: 52
				theme: root.theme; icon: "timer"; label: "Peek Delay"
				desc: root._delay === 0 ? "Reveal instantly on bottom-edge contact" : "Rest on the bottom edge for " + root._delay + "ms to reveal"
				SSlider { theme: root.theme; from: 0; to: 800; step: 50; value: root._delay; onMoved: value => root.set("bloom-dock-edge-delay", value) }
			}
			SRow {
				theme: root.theme; icon: "eye"; label: "Show App Previews"; desc: "Show window thumbnails on hover"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-preview-enabled"]; onToggled: value => root.set("bloom-dock-preview-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "circle"; label: "Icon Only"; desc: "Remove icon background and padding"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-icon-only"]; onToggled: value => root.set("bloom-dock-icon-only", value) }
			}
			SRow {
				theme: root.theme; icon: "columns-2"; label: "App Separator"; desc: "Show a divider before unpinned apps"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-separator-enabled"]; onToggled: value => root.set("bloom-dock-separator-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "layers"; label: "Workspaces"; desc: "Show this screen's workspaces in the dock"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-workspaces-enabled"]; onToggled: value => root.set("bloom-dock-workspaces-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Super+Alt+Number Shortcuts"; desc: "Open pinned apps with Super+Alt+1 through 9"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-win-number-enabled"]; onToggled: value => root.set("bloom-dock-win-number-enabled", value) }
			}
			SRow {
				objectName: "dockAdaptive"
				visible: root._fixed; height: visible ? implicitHeight : 0; implicitHeight: 52
				theme: root.theme; icon: "maximize-2"; label: "Adaptive Mode"; desc: "Stretch to full width when a window is maximized"
				SToggle { theme: root.theme; checked: root._v["bloom-dock-adaptive"]; onToggled: value => root.set("bloom-dock-adaptive", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-panel-left"; label: "Dock Extras"; desc: "Show drives, folders and the Trash beside the apps"; divider: false
				SSelect {
					objectName: "extras"; theme: root.theme; popup: root.popup; value: root._extras
					options: [{ value: "off", label: "Off" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
					onActivated: value => root.set("bloom-dock-extras-position", value)
				}
			}
			SDisclosure {
				visible: root._extras !== "off"
				theme: root.theme; summary: "Manage dock extras"; hint: "Drives, folders and Trash"
				SRow {
					theme: root.theme; icon: "hard-drive"; label: "Drives"; desc: "Fixed, removable and connected network drives"; divider: !root._drives
					SToggle { theme: root.theme; checked: root._drives; onToggled: value => root.set("bloom-dock-extras-drives", value) }
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
					theme: root.theme; icon: "trash-2"; label: "Trash"; desc: "Show the Trash in the extras"
					SToggle { theme: root.theme; checked: root._v["bloom-dock-extras-recycle-bin"]; onToggled: value => root.set("bloom-dock-extras-recycle-bin", value) }
				}
				SRow {
					theme: root.theme; icon: "folder-open"; label: "Special Folders"; desc: "Pick the folders that appear in the extras"; divider: false
				}
				Item {
					width: parent.width
					height: folderFlow.height + 10
					Flow {
						id: folderFlow
						x: 54
						width: parent.width - 68
						spacing: 8
						Repeater {
							model: [{ id: "desktop", label: "Desktop" }, { id: "documents", label: "Documents" }, { id: "downloads", label: "Downloads" }, { id: "pictures", label: "Pictures" }, { id: "music", label: "Music" }, { id: "videos", label: "Videos" }]
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
					theme: root.theme; icon: "folder-plus"; label: "Custom Folders"; desc: "Add any folder to the extras section"; divider: false
				}
				Column {
					x: 54
					width: parent.width - 68
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
								font.family: Fonts.familyFor(Font.Medium)
								font.pixelSize: 12
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
								font.family: Fonts.family
								font.pixelSize: 11
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
						text: "Add Folder..."
						onClicked: root.addFolderRequested()
					}
				}
			}
		}
	}
}
