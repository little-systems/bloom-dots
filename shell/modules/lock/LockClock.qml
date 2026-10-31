import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "lock.js" as Lock

// An analog clock on a slowly turning nine-lobed face, then the date and a
// "Locked" tag. Pure: the time comes in from outside.
Item {
	id: root

	property QtObject theme
	property color accent: "#007aff"
	property date time: new Date()
	property bool turning: true

	readonly property real _size: Tokens.lock.clock.size
	readonly property var _hands: Lock.hands(root.time)

	width: root._size
	height: root._size + Tokens.lock.clock.tag.top + Tokens.lock.clock.tag.height

	Canvas {
		id: face
		objectName: "face"
		width: root._size
		height: root._size
		onPaint: {
			const ctx = getContext("2d");
			ctx.reset();
			ctx.beginPath();
			Lock.cookie(width, Tokens.lock.clock.sides, Tokens.lock.clock.depth).forEach((p, i) => {
				if (i === 0) ctx.moveTo(p.x, p.y);
				else ctx.lineTo(p.x, p.y);
			});
			ctx.closePath();
			ctx.fillStyle = root.theme.bgExpanded;
			ctx.fill();
			ctx.lineWidth = 1;
			ctx.strokeStyle = root.theme.border;
			ctx.stroke();
		}
		RotationAnimator on rotation {
			from: 0
			to: 360
			duration: Tokens.lock.clock.turnMs
			loops: Animation.Infinite
			running: root.turning
		}
	}

	Repeater {
		model: 12
		delegate: Rectangle {
			required property int index
			readonly property real angle: index * 30 * Math.PI / 180
			readonly property real orbit: root._size / 2 * Tokens.lock.clock.mark.orbit
			width: Tokens.lock.clock.mark.size
			height: width
			radius: width / 2
			x: root._size / 2 + orbit * Math.sin(angle) - width / 2
			y: root._size / 2 - orbit * Math.cos(angle) - height / 2
			color: root.theme.textMuted
			opacity: 0.6
		}
	}

	// The date sits at three o'clock, as a bubble.
	Rectangle {
		objectName: "date"
		readonly property string text: root.time.getDate().toString()
		width: Tokens.lock.clock.date.size
		height: width
		radius: width / 2
		x: root._size * 0.72 - width / 2
		y: root._size / 2 - height / 2
		color: root.theme.groupBg

		Text {
			anchors.centerIn: parent
			text: parent.text
			color: root.theme.text
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Tokens.lock.clock.date.text
			font.weight: Font.DemiBold
		}
	}

	Item {
		objectName: "hourHand"
		readonly property real angle: root._hands.hour
		width: root._size
		height: root._size
		rotation: angle
		Rectangle {
			x: (parent.width - width) / 2
			y: parent.height / 2 - height + width / 2
			width: Tokens.lock.clock.hour.width
			height: root._size / 2 * Tokens.lock.clock.hour.length
			radius: width / 2
			color: root.theme.text
			antialiasing: true
		}
	}
	Item {
		objectName: "minuteHand"
		readonly property real angle: root._hands.minute
		width: root._size
		height: root._size
		rotation: angle
		Rectangle {
			x: (parent.width - width) / 2
			y: parent.height / 2 - height + width / 2
			width: Tokens.lock.clock.minute.width
			height: root._size / 2 * Tokens.lock.clock.minute.length
			radius: width / 2
			color: root.theme.textMuted
			antialiasing: true
		}
	}
	Item {
		objectName: "secondHand"
		readonly property real angle: root._hands.second
		width: root._size
		height: root._size
		rotation: angle
		Rectangle {
			x: (parent.width - width) / 2
			y: parent.height / 2 - root._size / 2 * Tokens.lock.clock.second.orbit - height / 2
			width: Tokens.lock.clock.second.size
			height: width
			radius: width / 2
			color: root.accent
			antialiasing: true
		}
	}

	Rectangle {
		objectName: "lockedTag"
		x: (root.width - width) / 2
		y: root._size + Tokens.lock.clock.tag.top
		width: tagRow.width + 2 * Tokens.lock.clock.tag.paddingH
		height: Tokens.lock.clock.tag.height
		radius: height / 2
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border

		Row {
			id: tagRow
			anchors.centerIn: parent
			spacing: Tokens.lock.clock.tag.gap

			SvgIcon {
				name: "lock"
				size: Tokens.lock.clock.tag.icon
				color: root.theme.text
				anchors.verticalCenter: parent.verticalCenter
			}
			Text {
				text: "Locked"
				color: root.theme.text
				font.family: Fonts.familyFor(Font.Medium)
				font.pixelSize: Tokens.lock.clock.tag.text
				font.weight: Font.Medium
				anchors.verticalCenter: parent.verticalCenter
			}
		}
	}
}
