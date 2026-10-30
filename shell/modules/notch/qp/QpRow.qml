import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens
import "../../../common/render"

// .qp-row: a network or device. The main line is a button (icon circle, name,
// subline, an optional badge); an expanded row shows its actions below,
// indented to the text (.qp-row-actions padding 0 8 8 41).
Item {
	id: root

	property QtObject theme: QpTheme {}
	required property string icon
	property string name: ""
	property string sub: ""
	// A trailing icon, such as the lock on a secured network.
	property string badge: ""
	property bool badgeSpinning: false
	property bool active: false
	property bool expanded: false
	// .qp-row-main:disabled keeps the default cursor and takes no clicks.
	property bool clickable: true
	default property alias actions: actionColumn.data

	signal clicked()

	readonly property real _nameLine: Tokens.qp.text * Tokens.qp.row.lineHeight
	readonly property real _subLine: Tokens.qp.row.sub * Tokens.qp.row.lineHeight
	readonly property real _actionsHeight: root.expanded ? actionColumn.height + Tokens.qp.actions.bottom : 0

	height: main.height + root._actionsHeight

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.qp.row.radius
		color: root.expanded ? root.theme.groupBg : "transparent"

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}
	}

	// No transition on .qp-row-main: its hover is immediate.
	Rectangle {
		id: main
		objectName: "main"
		width: root.width
		height: Tokens.qp.row.padV * 2 + Math.max(Tokens.qp.row.icon, textColumn.height)
		radius: Tokens.qp.row.radius
		color: !root.expanded && pointer.hovered ? root.theme.groupBg : "transparent"

		Rectangle {
			id: iconCircle
			objectName: "icon"
			x: Tokens.qp.row.padH
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.qp.row.icon
			height: Tokens.qp.row.icon
			radius: width / 2
			color: root.active ? root.theme.text : root.theme.groupBg

			SvgIcon {
				objectName: "glyph"
				anchors.centerIn: parent
				name: root.icon
				size: Tokens.qp.row.glyph
				color: root.active ? root.theme.bgExpanded : root.theme.text
			}
		}

		Column {
			id: textColumn
			x: iconCircle.x + iconCircle.width + Tokens.qp.row.gap
			anchors.verticalCenter: parent.verticalCenter
			width: (badgeIcon.visible ? badgeIcon.x - Tokens.qp.row.gap : main.width - Tokens.qp.row.padH) - x

			Text {
				objectName: "name"
				width: parent.width
				height: root._nameLine
				lineHeightMode: Text.FixedHeight
				lineHeight: root._nameLine
				verticalAlignment: Text.AlignVCenter
				text: root.name
				color: root.theme.text
				elide: Text.ElideRight
				maximumLineCount: 1
				font.family: Fonts.familyFor(Font.DemiBold)
				font.pixelSize: Tokens.qp.text
				font.weight: Font.DemiBold
			}

			FracText {
				objectName: "sub"
				visible: root.sub !== ""
				width: parent.width
				height: root._subLine
				verticalAlignment: Text.AlignVCenter
				text: root.sub
				color: root.theme.textMuted
				elide: Text.ElideRight
				maximumLineCount: 1
				font.family: Fonts.family
				pixelSize: Tokens.qp.row.sub
			}
		}

		SvgIcon {
			id: badgeIcon
			objectName: "badge"
			visible: root.badge !== ""
			x: main.width - Tokens.qp.row.padH - width
			anchors.verticalCenter: parent.verticalCenter
			name: root.badge || "lock-keyhole"
			size: Tokens.qp.row.badge
			color: root.theme.textMuted

			// .qp-spin
			RotationAnimation on rotation {
				running: root.badgeSpinning && badgeIcon.visible
				loops: Animation.Infinite
				from: 0
				to: 360
				duration: Tokens.qp.spinMs
				onRunningChanged: if (!running) badgeIcon.rotation = 0
			}
		}

		PointerArea {
			id: pointer
			objectName: "pointer"
			anchors.fill: parent
			enabled: root.clickable
			onClicked: root.clicked()
		}
	}

	Column {
		id: actionColumn
		visible: root.expanded
		x: Tokens.qp.actions.left
		y: main.height
		width: root.width - Tokens.qp.actions.left - Tokens.qp.actions.side
		spacing: Tokens.qp.actions.gap
	}
}
