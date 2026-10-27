import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// One dock app (Bloom Dock.tsx .dock-icon-wrapper): the tile and image that
// lift on hover and sink on press, a text tooltip, and one dot per window.
// `present` false plays framer's exit; the dock drops the slot afterwards.
Item {
	id: root

	property string name: ""
	property string iconSource: ""
	property int windows: 0
	property bool backgroundDot: false
	property bool present: true
	// Bloom: running (unpinned) apps leave with a 120 ms tween and no delay.
	property bool quickExit: false
	property bool dragging: false
	property bool anyDragging: false
	property bool iconOnly: false
	property bool light: false
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"

	signal clicked()
	signal middleClicked()

	readonly property bool hovered: hover.hovered
	readonly property bool pressed: tap.pressed
	property bool shown: false

	implicitWidth: Tokens.dock.iconBox
	implicitHeight: Tokens.dock.iconBox

	// Entry and exit both wait 150 ms (Bloom's transition delay), then the
	// scale springs 400/25 and the opacity fades over 150 ms.
	Component.onCompleted: if (root.present) delay.restart()
	onPresentChanged: {
		if (!root.present && root.quickExit) {
			delay.stop();
			root._quickScale = entrySpring.value;
			root._quick = true;
			entrySpring.jump(0);
			root.shown = false;
			quickAnim.restart();
			return;
		}
		if (root.present) {
			quickAnim.stop();
			root._quick = false;
		}
		delay.restart();
	}
	property bool _quick: false
	property real _quickScale: 1
	NumberAnimation {
		id: quickAnim
		target: root
		property: "_quickScale"
		to: 0
		duration: Tokens.dock.quickExitMs
		easing.type: Easing.BezierSpline
		easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
	}
	Timer {
		id: delay
		interval: Tokens.dock.entry.delayMs
		onTriggered: root.shown = root.present
	}

	HoverHandler { id: hover }
	TapHandler {
		id: tap
		acceptedButtons: Qt.LeftButton
		onTapped: root.clicked()
	}
	TapHandler {
		acceptedButtons: Qt.MiddleButton
		onTapped: root.middleClicked()
	}

	Item {
		id: presence
		anchors.fill: parent
		opacity: root.shown ? (root.dragging ? Tokens.dock.drag.opacity : 1) : 0
		Behavior on opacity {
			NumberAnimation { duration: root._quick ? Tokens.dock.quickExitMs : Tokens.dock.entry.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
		scale: root._quick ? root._quickScale : entrySpring.value

		Spring {
			id: entrySpring
			stiffness: Tokens.springs.itemEntry.stiffness
			damping: Tokens.springs.itemEntry.damping
			initial: 0
			target: root.shown ? 1 : 0
		}

		Item {
			id: lift
			objectName: "dock-lift"
			width: parent.width
			height: parent.height
			y: liftY.value
			scale: liftScale.value

			Spring {
				id: liftY
				stiffness: Tokens.springs.hoverY.stiffness
				damping: Tokens.springs.hoverY.damping
				restSpeed: Tokens.springs.hoverY.restSpeed
				initial: 0
				target: root.dragging ? Tokens.dock.drag.y : (root.hovered && root.shown ? Tokens.dock.hover.y : 0)
			}
			Spring {
				id: liftScale
				stiffness: Tokens.springs.hoverScale.stiffness
				damping: Tokens.springs.hoverScale.damping
				restSpeed: Tokens.springs.hoverScale.restSpeed
				initial: 1
				target: root.pressed && !root.dragging ? Tokens.dock.tapScale : root.dragging ? Tokens.dock.drag.scale : root.hovered && root.shown ? Tokens.dock.hover.scale : 1
			}

			RectangularShadow {
				anchors.fill: tile
				visible: tile.visible
				offset.y: 4
				blur: 12
				radius: tile.radius
				color: Qt.rgba(0, 0, 0, 0.1)
			}

			Rectangle {
				id: tile
				objectName: "dock-tile"
				anchors.fill: parent
				visible: !root.iconOnly
				radius: Tokens.dock.iconRadius
				// Bloom's 135° gradient, vertical (a QML Gradient is not angled).
				gradient: Gradient {
					GradientStop { position: 0; color: root.light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.2) }
					GradientStop { position: 1; color: root.light ? Qt.rgba(0, 0, 0, 0.01) : Qt.rgba(1, 1, 1, 0.05) }
				}
			}

			Image {
				id: image
				objectName: "dock-image"
				anchors.centerIn: parent
				width: root.iconOnly ? Tokens.dock.iconOnlyImage : Tokens.dock.iconImage
				height: width
				sourceSize: Qt.size(width * 2, height * 2)
				source: root.iconSource
				visible: root.iconSource !== "" && image.status !== Image.Error
				fillMode: Image.PreserveAspectFit
				smooth: true
				asynchronous: true
			}

			Text {
				objectName: "dock-fallback"
				anchors.centerIn: parent
				visible: !image.visible
				text: root.name.slice(0, 1).toUpperCase()
				color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.fallback.opacity)
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.fallback.size
				font.weight: Font.DemiBold
			}
		}

		// Dots stay put while the icon lifts (Bloom: siblings of .dock-icon).
		Row {
			anchors.horizontalCenter: parent.horizontalCenter
			y: parent.height + Tokens.dock.dot.offset - Tokens.dock.dot.size
			spacing: Tokens.dock.dot.gap

			Repeater {
				objectName: "dock-dots"
				model: root.windows > 0 ? Dock.dotCount(root.windows) : (root.backgroundDot ? 1 : 0)

				Item {
					width: Tokens.dock.dot.size
					height: Tokens.dock.dot.size

					RectangularShadow {
						anchors.fill: parent
						radius: width / 2
						blur: root.light ? Tokens.dock.dot.glowLight : Tokens.dock.dot.glow
						color: root.backgroundDot && root.windows === 0 ? "#8b8b8b" : root.light ? root.textColor : Qt.rgba(1, 1, 1, 0.8)
					}
					Rectangle {
						anchors.fill: parent
						radius: width / 2
						color: root.backgroundDot && root.windows === 0 ? "#8b8b8b" : root.light ? root.textColor : "white"
					}
				}
			}
		}
	}

	// Bloom .tooltip: 36 px above, fades and rises 4 px with CSS `ease`.
	Rectangle {
		id: tip
		objectName: "dock-tooltip"
		readonly property bool showing: root.hovered && root.shown && !root.anyDragging
		x: (root.width - width) / 2
		y: -Tokens.dock.tooltip.offset
		z: 1
		width: label.implicitWidth + 2 * Tokens.dock.tooltip.paddingH
		height: label.implicitHeight + 2 * Tokens.dock.tooltip.paddingV
		radius: Tokens.dock.tooltip.radius
		color: root.tooltipBg
		border.width: root.light ? 1 : 0
		border.color: root.tooltipBorder
		opacity: tip.showing ? 1 : 0
		transform: [
			Scale {
				origin.x: tip.width / 2
				origin.y: tip.height / 2
				xScale: tip.showing ? 1 : Tokens.dock.tooltip.from
				yScale: xScale
				Behavior on xScale { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
			},
			Translate {
				y: tip.showing ? 0 : Tokens.dock.tooltip.slide
				Behavior on y { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
			}
		]
		Behavior on opacity {
			NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] }
		}

		Text {
			id: label
			anchors.centerIn: parent
			text: root.name
			color: root.tooltipText
			font.family: Tokens.type.family
			font.pixelSize: Tokens.dock.tooltip.size
		}
	}
}
