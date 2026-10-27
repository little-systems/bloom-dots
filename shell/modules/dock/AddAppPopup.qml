import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's Add App card (Dock.tsx AddAppPopup): a search field over Running
// and All apps, fused into the top of the dock. It rises with a scaleY
// spring from its bottom edge; keys move the selection.
Item {
	id: root

	property var apps: []
	property var running: []
	property var pinned: []
	property bool loading: false
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color border: Qt.rgba(1, 1, 1, 0.12)
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	property color accent: "#007aff"

	readonly property bool opened: root._open
	readonly property var sections: Dock.addAppSections(root.apps, root.running, root.pinned, root._query)
	readonly property var flat: root.sections.reduce((all, s) => all.concat(s.items), [])
	property int selectedIndex: 0

	signal pinRequested(string id)
	signal closed()

	property bool _open: false
	property string _query: ""

	width: Tokens.dock.popup.width
	height: Tokens.dock.popup.height
	visible: root._open || card.opacity > 0
	transformOrigin: Item.Bottom

	function open() {
		field.text = "";
		root._query = "";
		root.selectedIndex = 0;
		root._open = true;
		scaleSpring.jump(0);
		field.forceActiveFocus();
	}

	function close() {
		if (!root._open)
			return;
		root.forceActiveFocus();
		root._open = false;
		root.closed();
	}

	function _choose(item) {
		if (!item)
			return;
		if (root.pinned.indexOf(item.id) >= 0)
			root.close();
		else {
			root.pinRequested(item.id);
			root.close();
		}
	}

	function _handleKey(event) {
		if (event.key === Qt.Key_Escape) {
			root.close();
			event.accepted = true;
		} else if (event.key === Qt.Key_Down) {
			root.selectedIndex = Math.min(root.selectedIndex + 1, Math.max(0, root.flat.length - 1));
			event.accepted = true;
		} else if (event.key === Qt.Key_Up) {
			root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
			event.accepted = true;
		} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			root._choose(root.flat[root.selectedIndex]);
			event.accepted = true;
		}
	}

	onFlatChanged: root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, root.flat.length - 1))

	Timer {
		id: debounce
		interval: Tokens.dock.popup.debounceMs
		onTriggered: {
			root._query = field.text;
			root.selectedIndex = 0;
		}
	}

	// Enter: scaleY spring 300/28/0.9 from 0, opacity 0.15 s. Exit: both to 0
	// over 0.16 s easeIn.
	Spring {
		id: scaleSpring
		stiffness: Tokens.springs.popupScale.stiffness
		damping: Tokens.springs.popupScale.damping
		mass: Tokens.springs.popupScale.mass
		initial: 0
		target: root._open ? 1 : 0
		autoRun: root._open
	}
	property real _exitScale: 1
	NumberAnimation {
		id: exitAnim
		target: root
		property: "_exitScale"
		from: 1
		to: 0
		duration: Tokens.dock.popup.exitMs
		easing.type: Easing.BezierSpline
		easing.bezierCurve: [0.42, 0, 1, 1, 1, 1]
	}
	on_OpenChanged: if (!root._open) exitAnim.restart(); else root._exitScale = 1

	Rectangle {
		id: card
		anchors.fill: parent
		radius: Tokens.dock.popup.radius
		color: root.bg
		border.width: 1
		border.color: root.border
		clip: true
		opacity: root._open ? 1 : 0
		Behavior on opacity {
			NumberAnimation {
				duration: root._open ? Tokens.dock.popup.fadeMs : Tokens.dock.popup.exitMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: root._open ? [0, 0, 0.58, 1, 1, 1] : [0.42, 0, 1, 1, 1, 1]
			}
		}
		transform: Scale {
			origin.y: card.height
			yScale: root._open ? scaleSpring.value : scaleSpring.value * root._exitScale
		}

		Keys.onPressed: event => root._handleKey(event)

		Rectangle {
			id: searchRow
			x: Tokens.dock.popup.search.margin
			y: Tokens.dock.popup.search.margin
			width: parent.width - 2 * Tokens.dock.popup.search.margin
			height: field.implicitHeight + 2 * Tokens.dock.popup.search.paddingV
			radius: Tokens.dock.popup.search.radius
			color: root.groupBg

			SvgIcon {
				id: glass
				name: "search"
				size: Tokens.dock.popup.search.icon
				color: root.textMuted
				x: Tokens.dock.popup.search.paddingH
				anchors.verticalCenter: parent.verticalCenter
			}

			TextInput {
				id: field
				objectName: "addapp-search"
				x: glass.x + glass.width + Tokens.dock.popup.search.gap
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - x - Tokens.dock.popup.search.paddingH
				color: root.textColor
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.popup.search.size
				clip: true
				onTextChanged: debounce.restart()
				Keys.onPressed: event => root._handleKey(event)

				Text {
					visible: field.text === ""
					text: "Search apps..."
					color: root.textMuted
					font: field.font
				}
			}
		}

		Flickable {
			id: list
			x: Tokens.dock.popup.list.side
			y: searchRow.y + searchRow.height + Tokens.dock.popup.search.marginBottom + Tokens.dock.popup.list.top
			width: parent.width - 2 * Tokens.dock.popup.list.side
			height: parent.height - y - Tokens.dock.popup.list.bottom
			contentHeight: rows.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: rows
				width: list.width
				visible: !root.loading

				Repeater {
					model: root.sections
					delegate: Column {
						required property var modelData
						width: rows.width

						Text {
							visible: modelData.title !== null
							text: (modelData.title || "").toUpperCase()
							leftPadding: Tokens.dock.popup.label.side
							topPadding: Tokens.dock.popup.label.top
							bottomPadding: Tokens.dock.popup.label.bottom
							color: root.textMuted
							font.family: Tokens.type.family
							font.pixelSize: Tokens.dock.popup.label.size
							font.weight: Font.DemiBold
							font.letterSpacing: Tokens.dock.popup.label.tracking
						}

						Repeater {
							model: modelData.items
							delegate: Rectangle {
								id: row
								required property var modelData
								readonly property int index: root.flat.indexOf(row.modelData)
								readonly property bool selected: row.index === root.selectedIndex
								readonly property bool isPinned: root.pinned.indexOf(row.modelData.id) >= 0
								objectName: "addapp-row-" + row.modelData.id
								width: rows.width
								height: Tokens.dock.popup.row.height
								radius: Tokens.dock.popup.row.radius
								color: row.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha)
									: rowHover.hovered ? root.groupBg : "transparent"
								border.width: row.selected ? 1 : 0
								border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedEdgeAlpha)
								Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }

								HoverHandler {
									id: rowHover
									onHoveredChanged: if (rowHover.hovered) root.selectedIndex = row.index
								}
								TapHandler { onTapped: root._choose(row.modelData) }

								Rectangle {
									id: iconBox
									x: Tokens.dock.popup.row.paddingH
									anchors.verticalCenter: parent.verticalCenter
									width: Tokens.dock.popup.row.icon
									height: width
									radius: Tokens.dock.popup.row.iconRadius
									color: root.groupBg
									clip: true
									Image {
										id: rowImage
										anchors.fill: parent
										source: row.modelData.icon
										sourceSize: Qt.size(64, 64)
										asynchronous: true
										fillMode: Image.PreserveAspectFit
										opacity: status === Image.Ready ? 1 : 0
										Behavior on opacity { NumberAnimation { duration: 150 } }
									}
									Text {
										anchors.centerIn: parent
										visible: rowImage.status !== Image.Ready
										text: row.modelData.name.slice(0, 1)
										color: root.textMuted
										font.family: Tokens.type.family
										font.pixelSize: Tokens.dock.popup.row.initial
										font.weight: Font.DemiBold
									}
								}

								Text {
									x: iconBox.x + iconBox.width + Tokens.dock.popup.row.gap
									anchors.verticalCenter: parent.verticalCenter
									width: pinGlyph.x - x - Tokens.dock.popup.row.gap
									text: row.modelData.name
									elide: Text.ElideRight
									color: root.textColor
									font.family: Tokens.type.family
									font.pixelSize: Tokens.dock.popup.row.name
									font.weight: Font.Medium
								}

								Text {
									id: pinGlyph
									anchors.right: parent.right
									anchors.rightMargin: Tokens.dock.popup.row.paddingH
									anchors.verticalCenter: parent.verticalCenter
									width: Tokens.dock.popup.row.pin
									horizontalAlignment: Text.AlignHCenter
									text: row.isPinned ? "✓" : "+"
									color: row.isPinned ? root.accent : root.textMuted
									opacity: row.isPinned || row.selected || rowHover.hovered ? 1 : 0
									Behavior on opacity { NumberAnimation { duration: 150 } }
									font.pixelSize: Tokens.dock.popup.row.pinSize
									font.weight: Font.Medium
								}
							}
						}
					}
				}
			}

			Text {
				objectName: "addapp-empty"
				visible: !root.loading && root.flat.length === 0
				width: list.width
				padding: Tokens.dock.popup.empty.padding
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: root._query.trim() ? "No results" : "Running apps show up here — search to pin anything else"
				color: root.textMuted
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.popup.empty.size
				font.weight: Font.Medium
			}

			// Skeleton rows, pulsing only while the card is open and loading.
			Column {
				objectName: "addapp-skeleton"
				visible: root.loading
				width: list.width
				opacity: pulse.value
				QtObject {
					id: pulse
					property real value: 0.5
				}
				SequentialAnimation {
					running: root.loading && root._open
					loops: Animation.Infinite
					NumberAnimation { target: pulse; property: "value"; from: 0.5; to: 1; duration: Tokens.dock.popup.skeleton.pulseMs / 2; easing.type: Easing.InOutQuad }
					NumberAnimation { target: pulse; property: "value"; from: 1; to: 0.5; duration: Tokens.dock.popup.skeleton.pulseMs / 2; easing.type: Easing.InOutQuad }
				}
				Repeater {
					model: Tokens.dock.popup.skeleton.rows
					Item {
						width: list.width
						height: Tokens.dock.popup.row.height
						Rectangle { x: Tokens.dock.popup.row.paddingH; anchors.verticalCenter: parent.verticalCenter; width: Tokens.dock.popup.row.icon; height: width; radius: Tokens.dock.popup.row.iconRadius; color: root.groupBg }
						Rectangle { x: Tokens.dock.popup.row.paddingH + Tokens.dock.popup.row.icon + Tokens.dock.popup.row.gap; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - Tokens.dock.popup.row.paddingH; height: Tokens.dock.popup.skeleton.line; radius: height / 2; color: root.groupBg }
					}
				}
			}
		}
	}

	RectangularShadow {
		anchors.fill: card
		z: -1
		visible: card.opacity > 0
		offset.y: Tokens.dock.popup.shadow.y
		blur: Tokens.dock.popup.shadow.blur
		radius: card.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}
}
