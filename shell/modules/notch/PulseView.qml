import QtQuick
import "../../common/tokens.js" as Tokens
import "pulses.js" as Pulses
import "../../common/render"

// Bloom's pulse slot in the collapsed row (AnimatePresence mode="wait"): the
// view on screen leaves before the next one enters, 300 ms each way.
// `standardOpacity` is the normal row's share of the same swap.
Item {
	id: root

	property string kind: ""
	property var battery: ({ level: 0, charging: false, pluggedIn: false, threshold: 20 })
	property bool updateAvailable: false
	property color textColor: "white"

	readonly property string wantedKey: Pulses.viewKey(root.kind)
	readonly property string shownKey: root._shown
	property string _shown: ""
	property bool _leaving: false
	property real standardOpacity: root._shown === "" && !root._leaving ? 1 : 0
	Behavior on standardOpacity {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	// The kind the battery view shows. A leaving view keeps it (framer
	// freezes an exiting element), so a low-battery pulse doesn't turn into
	// "On Battery" as it fades.
	property string _kindShown: ""
	function _syncKind() {
		// From `kind` itself: onKindChanged can run before wantedKey updates.
		if (!root._leaving && Pulses.viewKey(root.kind) === root._shown)
			root._kindShown = root.kind;
	}
	onKindChanged: root._syncKind()

	function _advance() {
		if (root._leaving || root.wantedKey === root._shown)
			return;
		root._leaving = true;
		leave.restart();
	}
	onWantedKeyChanged: root._advance()

	Timer {
		id: leave
		interval: Tokens.pulse.fadeMs
		onTriggered: {
			root._shown = root.wantedKey;
			root._leaving = false;
			root._syncKind();
			root._advance();
		}
	}

	component Label: Text {
		objectName: "pulse-label"
		font.family: Fonts.familyFor(Font.DemiBold)
		font.pixelSize: Fonts.px(Tokens.pulse.labelSize)
		font.weight: Font.DemiBold
		color: root.textColor
		elide: Text.ElideRight
	}

	PulseItem {
		objectName: "pulse-battery"
		anchors.fill: parent
		present: root._shown === "battery" && !root._leaving

		Row {
			anchors.centerIn: parent
			spacing: Tokens.pulse.gap
			UpdateArrow {
				anchors.verticalCenter: parent.verticalCenter
				visible: root.updateAvailable
			}
			BatteryIcon {
				anchors.verticalCenter: parent.verticalCenter
				level: root.battery.level
				charging: root.battery.charging
				threshold: root.battery.threshold
				color: root.textColor
			}
			Label {
				anchors.verticalCenter: parent.verticalCenter
				text: Pulses.batteryLabel(root._kindShown === "low" ? "low" : "power", root.battery)
				color: root._kindShown === "low" ? Tokens.status.red : root.textColor
			}
		}
	}

	PulseItem {
		objectName: "pulse-update"
		anchors.fill: parent
		present: root._shown === "update" && !root._leaving

		Row {
			anchors.centerIn: parent
			spacing: Tokens.pulse.gap
			UpdateArrow { anchors.verticalCenter: parent.verticalCenter }
			Label {
				anchors.verticalCenter: parent.verticalCenter
				text: "Update Available"
				color: Tokens.status.green
			}
		}
	}
}
