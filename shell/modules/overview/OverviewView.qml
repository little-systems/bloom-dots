import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "overview.js" as Logic

// The workspace overview: the launcher's card holding a search field over a
// 4 × 2 grid of workspaces, each with its windows where they sit. Click a
// window or workspace to go there, drag a window to move it, type to find
// one, walk the grid with the arrows. Pure: OverviewWindow.qml binds the
// services and live previews (`captureComponent`, per window).
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property var clients: []
	property var monitor: ({ x: 0, y: 0, width: 1920, height: 1080, scale: 1 })
	property int activeWorkspace: 1
	// (address) => a toplevel to capture, or null.
	property var toplevelFor: null
	property Component captureComponent: null
	property int selectedIndex: 0

	signal workspaceChosen(int id)
	signal windowChosen(string address)
	signal windowMoved(string address, int workspace)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	readonly property var workspaces: Logic.page(root.activeWorkspace)
	readonly property var _groups: Logic.byWorkspace(root.clients)
	readonly property var _matches: Logic.matches(root.clients, field.text)
	readonly property bool _searching: field.text !== ""
	readonly property real _cellHeight: Math.round(Tokens.overview.cell * (root.monitor.height / root.monitor.width))
	property bool _open: false

	function open() {
		field.text = "";
		root.selectedIndex = Math.max(0, root.workspaces.indexOf(root.activeWorkspace));
		root._open = true;
		enter.jump(0);
		field.forceActiveFocus();
	}
	function close() { root._open = false; }
	function _key(event) {
		const arrows = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down" };
		if (event.key === Qt.Key_Escape) root.dismissed();
		else if (arrows[event.key] && !(root._searching && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)))
			root.selectedIndex = Logic.step(root.selectedIndex, arrows[event.key]);
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			if (root._matches.length) root.windowChosen(root._matches[0].address);
			else root.workspaceChosen(root.workspaces[root.selectedIndex]);
		} else return;
		event.accepted = true;
	}
	// The workspace under a point in the view's coordinates, or 0.
	function _workspaceAt(x, y) {
		for (let i = 0; i < cells.count; i++) {
			const cell = cells.itemAt(i);
			const p = cell.mapFromItem(root, x, y);
			if (cell.contains(p)) return cell.workspace;
		}
		return 0;
	}

	Spring {
		id: enter
		stiffness: Tokens.morph.stiffness
		damping: Tokens.morph.damping
		mass: Tokens.morph.mass
		initial: 0
		target: root._open ? 1 : 0
	}

	// cursor: default — a click on the screen around the card dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	RectangularShadow {
		anchors.fill: card
		visible: card.visible
		opacity: card.opacity
		scale: card.scale
		offset.y: 12
		blur: Tokens.dock.popup.shadow.blur
		radius: Tokens.launcher.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}

	readonly property real _morph: Tokens.morph.from + (1 - Tokens.morph.from) * Math.max(0, Math.min(1.02, enter.value))
	Rectangle {
		id: card
		objectName: "card"
		anchors.centerIn: parent
		width: (grid.width + 2 * Tokens.overview.padding) * root._morph
		height: (fieldBox.height + grid.height + 2 * Tokens.overview.padding + Tokens.overview.gap) * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		visible: opacity > 0
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Rectangle {
			id: fieldBox
			x: Tokens.overview.padding
			y: Tokens.overview.padding
			width: grid.width
			height: Tokens.launcher.field.height
			radius: Tokens.launcher.field.radius
			color: root.theme.groupBg

			SvgIcon {
				id: glass
				name: "search"
				size: Tokens.launcher.field.icon
				color: root.theme.textMuted
				x: Tokens.launcher.field.paddingH
				anchors.verticalCenter: parent.verticalCenter
			}
			TextInput {
				id: field
				objectName: "field"
				x: glass.x + glass.width + Tokens.launcher.field.gap
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - x - Tokens.launcher.field.paddingH
				color: root.theme.text
				selectionColor: root.accent
				clip: true
				font.family: Fonts.family
				font.pixelSize: Tokens.launcher.field.size
				Keys.onPressed: event => root._key(event)

				Text {
					visible: field.text === ""
					text: "Find a window"
					color: root.theme.textMuted
					font: field.font
				}
			}
		}

		Grid {
			id: grid
			x: Tokens.overview.padding
			y: fieldBox.y + fieldBox.height + Tokens.overview.gap
			columns: Logic.COLUMNS
			spacing: Tokens.overview.gap

			Repeater {
				id: cells
				model: root.workspaces

				Rectangle {
					id: cell
					required property int modelData
					required property int index
					readonly property int workspace: cell.modelData
					readonly property bool active: cell.workspace === root.activeWorkspace
					readonly property bool selected: cell.index === root.selectedIndex
					readonly property bool dropTarget: ghost.visible && ghost.over === cell.workspace

					objectName: "workspace:" + cell.workspace
					width: Tokens.overview.cell
					height: root._cellHeight
					radius: Tokens.overview.radius
					clip: true
					color: cell.selected || cell.dropTarget || cellHover.hovered
						? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha) : root.theme.groupBg
					border.width: cell.active ? 1 : 0
					border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedEdgeAlpha)

					HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
					TapHandler { onTapped: root.workspaceChosen(cell.workspace) }

					Repeater {
						model: root._groups[cell.workspace] ?? []

						Rectangle {
							id: thumb
							required property var modelData
							readonly property var box: Logic.windowRect(thumb.modelData, root.monitor, cell.width, cell.height)
							readonly property var toplevel: root.toplevelFor ? root.toplevelFor(thumb.modelData.address) : null

							objectName: "window:" + thumb.modelData.address
							x: thumb.box.x
							y: thumb.box.y
							width: thumb.box.width
							height: thumb.box.height
							radius: Tokens.overview.windowRadius
							clip: true
							color: root.theme.groupBg
							border.width: 1
							border.color: root.theme.border
							opacity: !root._searching || root._matches.some(m => m.address === thumb.modelData.address) ? 1 : Tokens.overview.dimmed

							Text {
								anchors.centerIn: parent
								text: (thumb.modelData.class || "?").charAt(0).toUpperCase()
								color: root.theme.textMuted
								font.family: Fonts.familyFor(Font.DemiBold)
								font.pixelSize: 14
								font.weight: Font.DemiBold
							}
							Loader {
								anchors.fill: parent
								active: root.shown && !!root.captureComponent && !!thumb.toplevel
								sourceComponent: root.captureComponent
								onLoaded: item.captureSource = thumb.toplevel
							}
							MouseArea {
								id: drag
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								preventStealing: true
								property point start
								property bool dragging: false
								function viewPoint(mouse) { return mapToItem(root, mouse.x, mouse.y); }
								onPressed: mouse => { drag.start = Qt.point(mouse.x, mouse.y); drag.dragging = false; }
								onPositionChanged: mouse => {
									if (!pressed) return;
									if (!drag.dragging && Math.hypot(mouse.x - drag.start.x, mouse.y - drag.start.y) > Tokens.overview.dragThreshold) {
										drag.dragging = true;
										ghost.width = thumb.width;
										ghost.height = thumb.height;
										ghost.title = (thumb.modelData.class || "?").charAt(0).toUpperCase();
										ghost.visible = true;
									}
									if (drag.dragging) {
										const p = drag.viewPoint(mouse);
										ghost.x = p.x - ghost.width / 2;
										ghost.y = p.y - ghost.height / 2;
										ghost.over = root._workspaceAt(p.x, p.y);
									}
								}
								onReleased: mouse => {
									if (drag.dragging) {
										const p = drag.viewPoint(mouse);
										const to = root._workspaceAt(p.x, p.y);
										ghost.visible = false;
										drag.dragging = false;
										if (to && to !== cell.workspace) root.windowMoved(thumb.modelData.address, to);
									} else if (Math.hypot(mouse.x - drag.start.x, mouse.y - drag.start.y) <= Tokens.overview.dragThreshold) {
										root.windowChosen(thumb.modelData.address);
									}
								}
							}
						}
					}

					// Above the windows: one can cover the whole cell.
					Rectangle {
						objectName: "frame"
						anchors.fill: parent
						radius: Tokens.overview.radius
						color: "transparent"
						border.width: cell.active || cell.selected || cell.dropTarget ? 2 : 0
						border.color: root.accent
					}
					Rectangle {
						objectName: "number"
						x: Tokens.overview.label.x - 2
						y: Tokens.overview.label.y - 1
						width: numberText.implicitWidth + 10
						height: numberText.implicitHeight + 2
						radius: 6
						color: Qt.rgba(0, 0, 0, 0.55)

						Text {
							id: numberText
							anchors.centerIn: parent
							text: cell.workspace
							color: cell.active ? "white" : Qt.rgba(1, 1, 1, 0.7)
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Tokens.overview.label.size
							font.weight: Font.DemiBold
						}
					}
				}
			}
		}
	}

	// The window being dragged, above the cells that clip it.
	Rectangle {
		id: ghost
		objectName: "ghost"
		property int over: 0
		property string title: ""
		visible: false
		z: 2
		radius: Tokens.overview.windowRadius
		color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha)
		border.width: 1
		border.color: root.accent

		Text {
			anchors.centerIn: parent
			text: ghost.title
			color: root.theme.text
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: 14
			font.weight: Font.DemiBold
		}
	}
}
