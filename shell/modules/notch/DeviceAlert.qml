import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// Bloom's device alert (App.tsx .device-alert): the device's art playing its
// connect or disconnect animation, its name and status, and its battery as a
// ring (or a ring per bud). It fills the pill, inside the notch's 12 px side
// padding, with its own padding 0 18 0 14 and gaps of 12. `alert` comes from
// Devices: { name, art, status, connected, battery, buds, runId }.
Item {
	id: root

	property var alert: null
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.55)

	signal clicked()

	// The last alert stays drawn while it fades out.
	property var _shown: null
	onAlertChanged: if (root.alert) root._shown = root.alert

	// Enters over 0.2 s (framer easeOut); leaves over 0.12 s.
	property real contentOpacity: root.alert ? 1 : 0
	Behavior on contentOpacity {
		NumberAnimation {
			duration: root.alert ? 200 : 120
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Tokens.easing.framerEaseOut.concat([1, 1])
		}
	}
	opacity: root.contentOpacity
	visible: root.contentOpacity > 0

	readonly property real _left: Tokens.sizes.padding + Tokens.alert.pad.left
	readonly property real _right: root.width - Tokens.sizes.padding - Tokens.alert.pad.right
	readonly property var _buds: root._shown?.connected && root._shown?.buds
		? ["left", "right", "case"].filter(k => Number.isInteger(root._shown.buds[k])) : []
	readonly property bool _ring: root._buds.length === 0 && !!root._shown?.connected && Number.isInteger(root._shown?.battery)

	// Made with the first alert, so an idle notch plays nothing.
	Loader {
		x: root._left
		y: (root.height - 60) / 2
		active: root._shown !== null

		sourceComponent: DeviceArt {
			objectName: "alertArt"
			width: 60
			height: 60
			art: root._shown?.art ?? "device"
			phase: root._shown?.connected === false ? "leave" : "play"
			runId: root._shown?.runId ?? 0
		}
	}

	Column {
		x: root._left + 60 + Tokens.alert.gap
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(0, (root._ring ? ring.x : root._buds.length ? budRow.x : root._right) - Tokens.alert.gap - x)
		spacing: 2

		FracText {
			objectName: "alertName"
			width: parent.width
			text: root._shown?.name ?? ""
			color: root.textColor
			elide: Text.ElideRight
			maximumLineCount: 1
			font.family: Fonts.familyFor(Font.DemiBold)
			font.weight: Font.DemiBold
			pixelSize: Tokens.alert.name
		}

		Text {
			objectName: "alertStatus"
			width: parent.width
			text: root._shown?.status ?? ""
			color: root.textMuted
			elide: Text.ElideRight
			font.family: Fonts.family
			font.pixelSize: Tokens.alert.status
		}
	}

	BatteryRing {
		id: ring
		objectName: "alertRing"
		visible: root._ring
		x: root._right - width
		anchors.verticalCenter: parent.verticalCenter
		level: root._shown?.battery ?? 0
		textColor: root.textColor
	}

	// .device-alert-buds: a ring per part, its label underneath.
	Row {
		id: budRow
		objectName: "alertBuds"
		visible: root._buds.length > 0
		x: root._right - width
		anchors.verticalCenter: parent.verticalCenter
		spacing: Tokens.alert.buds.gap

		Repeater {
			model: root._buds

			Column {
				required property string modelData
				objectName: "bud-" + modelData
				spacing: 2

				BatteryRing {
					objectName: "ring"
					level: root._shown?.buds?.[parent.modelData] ?? 0
					textColor: root.textColor
				}

				Text {
					objectName: "budLabel"
					anchors.horizontalCenter: parent.horizontalCenter
					text: parent.modelData === "case" ? "Case" : parent.modelData[0].toUpperCase()
					color: root.textMuted
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Tokens.alert.buds.label
					font.weight: Font.DemiBold
				}
			}
		}
	}

	PointerArea {
		objectName: "pointer"
		anchors.fill: parent
		enabled: root.alert !== null
		onClicked: root.clicked()
	}
}
