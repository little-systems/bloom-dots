import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "preview.js" as Preview

// Bloom's FeaturePreview: a folding card that shows the tab's surfaces with
// your settings applied. It jumps to the scene a changed setting affects, and
// everything in it is a sample: nothing here touches the system.
Rectangle {
	id: root
	property QtObject theme
	property var store
	required property string tab
	property bool autostart: false
	property var apps: []
	property bool expanded: false
	property string feature: Preview.firstFeature(root.tab)
	property int replay: 0
	// A copy, not a binding: it has to lag one change behind to spot the key.
	property var _seen: ({})
	Component.onCompleted: root._seen = root.store.values

	readonly property var _choices: Preview.FEATURES[root.tab] ?? []
	readonly property var _selected: root._choices.find(c => c.id === root.feature) ?? root._choices[0]
	readonly property string _scene: root._selected ? root._selected.id : ""

	visible: root._choices.length > 0
	objectName: "featurePreview"
	width: parent.width
	height: visible ? column.implicitHeight + 24 + 2 : 0
	radius: 14
	color: root.theme.groupBg
	border.width: 1
	border.color: root.theme.border

	onTabChanged: {
		root.feature = Preview.firstFeature(root.tab);
		root.replay++;
	}
	Connections {
		target: root.store
		function onValuesChanged() {
			const values = root.store.values;
			const key = Object.keys(values).find(k => JSON.stringify(values[k]) !== JSON.stringify(root._seen[k]));
			root._seen = values;
			if (!key) return;
			const scene = Preview.sceneFor(root.tab, key);
			if (scene && scene !== root.feature) {
				root.feature = scene;
				root.replay++;
			}
		}
	}

	Column {
		id: column
		x: 13
		y: 13
		width: parent.width - 26

		Item {
			width: parent.width
			height: 27 + (root.expanded ? 10 : 0)

			Text {
				y: 2
				x: 2
				text: "Preview"
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: 15
				font.weight: Font.DemiBold
				font.letterSpacing: -0.3
			}
			Row {
				x: parent.width - width - 2
				spacing: 4
				Repeater {
					model: root.expanded ? ["replay", "fold"] : ["fold"]
					delegate: Rectangle {
						id: action
						required property string modelData
						objectName: "preview:" + action.modelData
						width: 27
						height: 27
						radius: 7
						color: actionHover.hovered ? root.theme.border : "transparent"
						SvgIcon {
							anchors.centerIn: parent
							name: action.modelData === "replay" ? "rotate-ccw" : "chevron-down"
							size: action.modelData === "replay" ? 14 : 16
							rotation: action.modelData === "fold" && !root.expanded ? -90 : 0
							color: actionHover.hovered ? root.theme.text : root.theme.textMuted
						}
						HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
						TapHandler {
							onTapped: {
								if (action.modelData === "replay") root.replay++;
								else root.expanded = !root.expanded;
							}
						}
					}
				}
			}
		}

		Row {
			visible: root.expanded && root._choices.length > 1
			bottomPadding: 10
			spacing: 4
			Repeater {
				model: root._choices
				delegate: Rectangle {
					id: choice
					required property var modelData
					readonly property bool active: root._scene === choice.modelData.id
					objectName: "scene:" + choice.modelData.id
					width: choiceText.implicitWidth + 22
					height: choiceText.implicitHeight + 12
					radius: 7
					color: choice.active || choiceHover.hovered ? root.theme.border : "transparent"
					Text {
						id: choiceText
						anchors.centerIn: parent
						text: choice.modelData.label
						color: choice.active || choiceHover.hovered ? root.theme.text : root.theme.textMuted
						font.family: Fonts.ui
						font.pixelSize: 11
					}
					HoverHandler { id: choiceHover; cursorShape: Qt.PointingHandCursor }
					TapHandler {
						onTapped: {
							root.feature = choice.modelData.id;
							root.replay++;
						}
					}
				}
			}
		}

		Rectangle {
			id: stage
			objectName: "previewStage"
			visible: root.expanded
			readonly property bool player: root._scene === "music"
			width: parent.width
			height: stage.player ? 190 : 150
			radius: 10
			color: Qt.tint("#20232d", Qt.rgba(root.theme.bg.r, root.theme.bg.g, root.theme.bg.b, 0.38))
			border.width: 1
			border.color: Qt.rgba(1, 1, 1, 0.09)
			clip: true

			HoverHandler { id: stageHover }

			// A replay is a fresh scene, as Bloom's keyed stage remounts.
			Repeater {
				model: root.expanded && root._scene !== "" ? [root._scene + "-" + root.replay] : []
				delegate: Item {
					anchors.fill: parent
					Loader {
						anchors.fill: parent
						active: root.tab === "general" || root.tab === "notch" || root.tab === "appearance"
						sourceComponent: NotchPreview { theme: root.theme; values: root.store.values; feature: root._scene; runId: root.replay; revealed: stageHover.hovered }
					}
					Loader {
						anchors.fill: parent
						active: root.tab === "appearance" || root.tab === "dock"
						sourceComponent: DockPreview { theme: root.theme; values: root.store.values; apps: root.apps; revealed: stageHover.hovered }
					}
					Loader {
						anchors.fill: parent
						active: root.tab === "overlays"
						sourceComponent: OverlayPreview { theme: root.theme; values: root.store.values; feature: root._scene }
					}
				}
			}
		}

		Text {
			objectName: "previewCaption"
			visible: root.expanded
			width: parent.width
			topPadding: 9
			leftPadding: 2
			rightPadding: 2
			text: root._selected ? Preview.description(root._scene, root.store.values, root.autostart, root.store.values["bloom-enabled-modules"].indexOf("dock") >= 0, root._selected.description) : ""
			wrapMode: Text.Wrap
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: 11
		}
	}
}
