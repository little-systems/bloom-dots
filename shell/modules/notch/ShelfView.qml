import QtQuick
import QtQuick.Shapes
import "../../common"
import "../../common/render"
import "shelf.js" as Logic

// Bloom's shelf (App.tsx .shelf-content, App.css .shelf-*): a row of tiles,
// each a 104 × 84 preview (a picture, a text's opening line, or the file's
// type icon; a file manager's thumbnail when ShelfState found one) over its caption, with a remove button on hover; a dashed
// drop target when empty, and Bloom's notice line. Tiles keep their place
// on Bloom's layout spring (520/38/0.7): a new one springs in from 0.82, a
// removed one leaves the row at once and fades where it was (popLayout).
// Pure: ShelfPanel.qml binds the shelf service.
Item {
	id: root

	property QtObject theme: QtObject {
		property color text: "white"
	}
	// ShelfState items, newest first: { kind: "file" | "text", value, id }.
	property var items: []
	// By path: { kind: "folder" | "text" | "file" | "missing", text }.
	property var previews: ({})
	// Ids just added: these tiles spring in.
	property var newIds: []
	property string notice: ""

	signal removeRequested(int index)
	signal activated(int index)
	signal filesDropped(var paths)
	signal textDropped(string text)

	readonly property real _tileWidth: 116
	readonly property real _gap: 8
	readonly property real _step: root._tileWidth + root._gap
	readonly property bool _overflowing: root.items.length * root._step - root._gap > row.width
	readonly property var _easeOut: [0, 0, 0.58, 1, 1, 1]
	readonly property var _ease: [0.25, 0.1, 0.25, 1, 1, 1]

	function _collapse(text) { return String(text || "").replace(/\s+/g, " ").trim(); }
	function _slot(id) { return root.items.findIndex(i => i.id === id); }

	// The tiles, by id: a removed one stays (leaving) until it has faded.
	ListModel { id: tiles }
	function _sync() {
		const ids = root.items.map(i => i.id);
		for (let i = tiles.count - 1; i >= 0; i--) {
			const entry = tiles.get(i);
			if (!ids.includes(entry.uid) && !entry.leaving) tiles.setProperty(i, "leaving", true);
		}
		for (const item of root.items) {
			let found = false;
			for (let i = 0; i < tiles.count; i++) if (tiles.get(i).uid === item.id) found = true;
			if (!found) tiles.append({ uid: item.id, leaving: false });
		}
	}
	function _drop(uid) {
		for (let i = 0; i < tiles.count; i++) if (tiles.get(i).uid === uid) { tiles.remove(i); return; }
	}
	onItemsChanged: root._sync()
	Component.onCompleted: root._sync()

	DropArea {
		anchors.fill: parent
		onDropped: drop => {
			if (drop.urls.length) {
				const paths = drop.urls.map(u => Logic.filePath(u.toString())).filter(p => p);
				if (paths.length) root.filesDropped(paths);
			} else if (drop.text) {
				root.textDropped(drop.text);
			}
		}
	}

	// .shelf-content padding 12px 14px.
	Item {
		id: row
		x: 14
		y: 12
		width: root.width - 28
		height: root.height - 24

		// .shelf-empty: the drop target, at 0.55 opacity with its border.
		Item {
			objectName: "empty"
			anchors.fill: parent
			visible: root.items.length === 0
			opacity: 0.55

			Shape {
				objectName: "dashedBorder"
				anchors.fill: parent
				preferredRendererType: Shape.CurveRenderer
				ShapePath {
					strokeColor: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.25)
					strokeWidth: 1
					strokeStyle: ShapePath.DashLine
					dashPattern: [3, 3]
					fillColor: "transparent"
					PathRectangle { x: 0.5; y: 0.5; width: row.width - 1; height: row.height - 1; radius: 12 }
				}
			}
			Text {
				objectName: "label"
				anchors.centerIn: parent
				text: "Drop files or selected text here"
				color: root.theme.text
				font.family: Fonts.family
				font.pixelSize: 12
			}
		}

		Flickable {
			id: strip
			anchors.fill: parent
			clip: true
			contentWidth: Math.max(width, root.items.length * root._step - root._gap)
			contentHeight: height
			flickableDirection: Flickable.HorizontalFlick
			boundsBehavior: Flickable.StopAtBounds
			interactive: root._overflowing

			Repeater {
				model: tiles

				delegate: Item {
					id: tile
					required property string uid
					required property bool leaving
					readonly property var item: root.items.find(i => i.id === tile.uid) ?? tile._last
					property var _last: null
					onItemChanged: if (tile.item) tile._last = tile.item
					readonly property int slot: tile.leaving ? -1 : root._slot(tile.uid)
					readonly property var preview: tile.item && tile.item.kind === "file" ? root.previews[tile.item.value] : undefined
					readonly property bool textual: !!tile.item && (tile.item.kind === "text" || (!!tile.preview && tile.preview.kind === "text" && !thumb.shown))
					readonly property bool fresh: root.newIds.includes(tile.uid)

					objectName: "tile:" + tile.uid
					width: root._tileWidth
					height: root._overflowing ? row.height - 10 : row.height
					x: xSpring.value
					transformOrigin: Item.Center

					// Bloom's layout spring; a leaving tile stays where it was.
					Spring {
						id: xSpring
						stiffness: 520; damping: 38; mass: 0.7
						initial: Math.max(0, tile.slot) * root._step
						target: tile.slot >= 0 ? tile.slot * root._step : xSpring.value
					}
					Spring {
						id: enter
						stiffness: 520; damping: 38; mass: 0.7
						initial: tile.fresh ? 0 : 1
						target: 1
					}
					property real leaveProgress: 0
					NumberAnimation on leaveProgress {
						running: tile.leaving
						to: 1
						duration: 160
						easing.type: Easing.BezierSpline
						easing.bezierCurve: root._easeOut
						onFinished: root._drop(tile.uid)
					}
					// Enter: opacity 0 → 1, scale 0.82 → 1; exit: back to 0 / 0.82.
					opacity: Math.max(0, Math.min(1, enter.value)) * (1 - tile.leaveProgress)
					scale: (0.82 + 0.18 * enter.value) - 0.18 * tile.leaveProgress

					HoverHandler { id: hover; enabled: !tile.leaving }

					// .shelf-tile
					Rectangle {
						anchors.fill: parent
						radius: 12
						color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, hover.hovered ? 0.12 : 0.06)
					}

					// .shelf-tile-preview
					Rectangle {
						id: previewBox
						objectName: "preview"
						x: 6
						y: 6
						width: 104
						height: 84
						radius: 8
						clip: true
						opacity: 0.85
						color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, tile.textual ? 0.075 : 0.05)

						// .is-text: box-shadow inset 2px 0 0 (a line down the left).
						Rectangle {
							visible: tile.textual
							width: 2
							height: parent.height
							color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.16)
						}

						// A text, or a text file's opening: its type icon and one
						// line (the notch is nowrap), breaks collapsed.
						SvgIcon {
							objectName: "textIcon"
							visible: tile.textual
							x: 8
							y: 7
							name: tile.item && tile.item.kind === "text" ? "type" : tile.item ? Logic.typeIcon(tile.item.value, false) : "type"
							size: 11
							strokeWidth: 2
							color: root.theme.text
							opacity: 0.4
						}
						Item {
							visible: tile.textual
							x: 8
							y: 22
							width: 88
							height: 56
							clip: true

							Text {
								objectName: "body"
								width: parent.width
								height: parent.height
								text: !tile.item ? "" : tile.item.kind === "text" ? root._collapse(tile.item.value) : root._collapse(tile.preview ? tile.preview.text : "")
								wrapMode: Text.NoWrap
								elide: Text.ElideNone
								color: root.theme.text
								opacity: 0.9
								font.family: Fonts.family
								font.pixelSize: 10
								lineHeight: 1.45
								lineHeightMode: Text.ProportionalHeight
							}
						}

						// .shelf-tile-placeholder: the type icon once the preview
						// is known and has no picture.
						SvgIcon {
							objectName: "typeIcon"
							visible: !tile.textual && !!tile.preview && !thumb.shown
							anchors.centerIn: parent
							anchors.alignWhenCentered: false
							name: tile.item ? Logic.typeIcon(tile.item.value, !!tile.preview && tile.preview.kind === "folder") : "file"
							size: 26
							strokeWidth: 1.75
							color: root.theme.text
						}

						// A picture: the image itself, or a file manager's thumbnail.
						Image {
							id: thumb
							readonly property bool shown: status === Image.Ready
							anchors.fill: parent
							source: !tile.item || tile.item.kind !== "file" ? ""
								: Logic.isImage(tile.item.value) ? Logic.fileUrl(tile.item.value)
								: tile.preview && tile.preview.thumb ? tile.preview.thumb : ""
							sourceSize: Qt.size(256, 256)
							fillMode: Image.PreserveAspectCrop
							asynchronous: true
							opacity: 0
							onStatusChanged: if (status === Image.Ready) thumbIn.restart()
							NumberAnimation {
								id: thumbIn
								target: thumb; property: "opacity"; from: 0; to: 1; duration: 220
								easing.type: Easing.BezierSpline; easing.bezierCurve: root._ease
							}
						}
					}

					// .shelf-tile-name
					Text {
						objectName: "caption"
						x: 6
						y: 94
						width: 104
						text: tile.item ? Logic.tileName(tile.item) : ""
						elide: Text.ElideRight
						color: root.theme.text
						opacity: 0.85
						font.family: Fonts.family
						font.pixelSize: 11
					}

					// Opens (or copies) on click; dragging carries it out.
					Item {
						id: dragProxy
						width: tile.width
						height: tile.height
						Drag.active: tileArea.drag.active
						Drag.dragType: Drag.Automatic
						Drag.supportedActions: Qt.CopyAction
						Drag.mimeData: !tile.item ? ({}) : tile.item.kind === "file"
							? ({ "text/uri-list": Logic.fileUrl(tile.item.value) }) : ({ "text/plain": tile.item.value })
					}
					MouseArea {
						id: tileArea
						anchors.fill: parent
						enabled: !tile.leaving
						cursorShape: Qt.PointingHandCursor
						drag.target: dragProxy
						onClicked: if (tile.slot >= 0) root.activated(tile.slot)
						onReleased: { dragProxy.x = 0; dragProxy.y = 0; }
					}

					// .shelf-tile-remove: shows while the tile is hovered.
					Rectangle {
						objectName: "remove"
						x: tile.width - 4 - width
						y: 4
						width: 18
						height: 18
						radius: 9
						color: Qt.rgba(0, 0, 0, 0.55)
						opacity: hover.hovered ? 1 : 0
						Behavior on opacity {
							NumberAnimation { duration: 120; easing.type: Easing.BezierSpline; easing.bezierCurve: root._ease }
						}

						SvgIcon {
							anchors.centerIn: parent
							name: "x"
							size: 11
							strokeWidth: 2.5
							color: "white"
						}
						MouseArea {
							anchors.fill: parent
							enabled: hover.hovered && !tile.leaving
							cursorShape: Qt.PointingHandCursor
							onClicked: if (tile.slot >= 0) root.removeRequested(tile.slot)
						}
					}
				}
			}
		}

		// The row's scrollbar once it overflows (5 px, Bloom's colours).
		Rectangle {
			objectName: "scrollbar"
			visible: root._overflowing && root.items.length > 0
			y: row.height - height
			width: row.width
			height: 5
			radius: 3
			color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, 0.08)

			Rectangle {
				x: strip.visibleArea.xPosition * parent.width
				width: strip.visibleArea.widthRatio * parent.width
				height: parent.height
				radius: 3
				color: Qt.rgba(root.theme.text.r, root.theme.text.g, root.theme.text.b, barHover.hovered ? 0.55 : 0.35)
				HoverHandler { id: barHover }
			}
		}
	}

	// Bloom turns the wheel into the row's sideways scroll, and the shelf
	// never switches panels on it.
	WheelHandler {
		target: null
		onWheel: event => {
			const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.x || event.angleDelta.y) / 1.2;
			strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - delta));
		}
	}

	// .shelf-notice: rises into place over 0.15 s.
	Rectangle {
		id: noticeBox
		objectName: "notice"
		visible: root.notice !== ""
		anchors.horizontalCenter: parent.horizontalCenter
		y: root.height - 10 - height + noticeBox.rise
		width: noticeLabel.implicitWidth + 24
		height: noticeLabel.implicitHeight + 10
		radius: height / 2
		color: Qt.rgba(0, 0, 0, 0.75)
		z: 3
		property real rise: 0

		Text {
			id: noticeLabel
			objectName: "label"
			anchors.centerIn: parent
			text: root.notice
			color: "white"
			font.family: Fonts.family
			font.pixelSize: 11
		}
		ParallelAnimation {
			id: noticeIn
			NumberAnimation { target: noticeBox; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: root._ease }
			NumberAnimation { target: noticeBox; property: "rise"; from: 4; to: 0; duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: root._ease }
		}
	}
	onNoticeChanged: if (root.notice !== "") noticeIn.restart()
}
