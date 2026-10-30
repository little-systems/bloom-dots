import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "qp"
import "../../common/render"

// .cc-pill-tile: a Command Center tile (icon circle, title, status) with an
// optional chevron that opens its detail panel. An active tile inverts to
// `text` and keeps that on hover.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string title: ""
	property string status: ""
	required property string icon
	// The Wi-Fi icon dims when the radio is off or not connected.
	property real glyphOpacity: 1
	property bool active: false
	property bool hasMore: false

	signal clicked()
	signal rightClicked()
	signal moreClicked()

	readonly property bool _pressed: pointer.pressed || (moreLoader.item?.pressed ?? false)
	// :hover lifts by half a pixel; :active replaces it with the press scale.
	readonly property real lift: liftValue
	property real liftValue: pointer.hovered && !root._pressed ? Tokens.cc.tile.hoverLift : 0

	scale: root._pressed ? Tokens.cc.tile.pressScale : 1
	transform: Translate {
		y: root.liftValue
	}

	Behavior on liftValue {
		NumberAnimation {
			duration: Tokens.cc.tile.ms
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
		}
	}

	Behavior on scale {
		NumberAnimation {
			duration: Tokens.cc.tile.ms
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
		}
	}

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.cc.tile.radius
		border.width: 1
		border.color: root.active ? root.theme.text : root.theme.border
		color: root.active ? root.theme.text : pointer.hovered ? root.theme.border : root.theme.groupBg

		Behavior on color {
			ColorAnimation {
				duration: Tokens.cc.tile.ms
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
			}
		}
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
		onRightClicked: root.rightClicked()
	}

	// 1 px border + 8 px padding on each side.
	readonly property real _inset: 1 + Tokens.cc.tile.padH

	Rectangle {
		id: iconCircle
		objectName: "iconCircle"
		x: root._inset
		anchors.verticalCenter: parent.verticalCenter
		width: Tokens.cc.tileIcon.size
		height: Tokens.cc.tileIcon.size
		radius: width / 2
		color: root.theme.groupBg

		SvgIcon {
			objectName: "glyph"
			anchors.centerIn: parent
			name: root.icon
			size: Tokens.cc.tileIcon.glyph
			strokeWidth: 2.5
			opacity: root.glyphOpacity
			color: root.active ? root.theme.bgExpanded : root.theme.text

			Behavior on color {
				ColorAnimation {
					duration: Tokens.cc.tile.ms
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
				}
			}
		}
	}

	Column {
		id: info
		x: iconCircle.x + iconCircle.width + Tokens.cc.tile.gap
		anchors.verticalCenter: parent.verticalCenter
		// Shrinks to its text, up to the room before the chevron.
		readonly property real room: (root.hasMore ? root.width - root._inset - Tokens.cc.more.size - Tokens.cc.tile.gap : root.width - root._inset) - x
		width: Math.max(0, Math.min(Math.max(title.implicitWidth, status.implicitWidth), room))

		FracText {
			id: title
			objectName: "title"
			width: parent.width
			height: Tokens.cc.title * Tokens.cc.lineHeight
			verticalAlignment: Text.AlignVCenter
			text: root.title
			color: root.active ? root.theme.bgExpanded : root.theme.text
			elide: Text.ElideRight
			maximumLineCount: 1
			font.family: Fonts.familyFor(Font.DemiBold)
			font.weight: Font.DemiBold
			pixelSize: Tokens.cc.title
		}

		FracText {
			id: status
			objectName: "status"
			width: parent.width
			height: Tokens.cc.status * Tokens.cc.lineHeight
			verticalAlignment: Text.AlignVCenter
			text: root.status
			color: root.active ? root.theme.bgExpanded : root.theme.textMuted
			elide: Text.ElideRight
			maximumLineCount: 1
			font.family: Fonts.familyFor(Font.Medium)
			font.weight: Font.Medium
			pixelSize: Tokens.cc.status
		}
	}

	Loader {
		id: moreLoader
		active: root.hasMore
		x: root.width - root._inset - Tokens.cc.more.size
		anchors.verticalCenter: parent.verticalCenter

		sourceComponent: Item {
			objectName: "more"
			readonly property bool pressed: morePointer.pressed
			width: Tokens.cc.more.size
			height: Tokens.cc.more.size
			opacity: morePointer.hovered ? 1 : Tokens.cc.more.opacity

			Behavior on opacity {
				NumberAnimation {
					duration: Tokens.qp.hoverMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
				}
			}

			Rectangle {
				objectName: "moreBackground"
				anchors.fill: parent
				radius: Tokens.cc.more.radius
				color: morePointer.hovered ? root.theme.groupBg : "transparent"

				Behavior on color {
					ColorAnimation {
						duration: Tokens.qp.hoverMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
					}
				}
			}

			SvgIcon {
				objectName: "moreGlyph"
				anchors.centerIn: parent
				name: "chevron-right"
				size: Tokens.cc.more.glyph
				color: root.active ? root.theme.bgExpanded : root.theme.text
			}

			PointerArea {
				id: morePointer
				anchors.fill: parent
				onClicked: root.moreClicked()
			}
		}
	}
}
