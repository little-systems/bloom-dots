import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// Bloom's MixerTile (Overlay.tsx, .volume-mixer-*): an app's volume bar over
// its logo; a click on the logo mutes it, and the logo flashes the
// percentage while the volume changes.
Item {
	id: root

	property var session: ({ id: 0, name: "", icon: "", volume: 0, muted: false })
	property QtObject theme
	property color track: Qt.rgba(1, 1, 1, 0.2)

	signal volumeChosen(real volume)
	signal muteToggled()

	readonly property int _percent: Math.round((root.session.muted ? 0 : root.session.volume) * 100)
	property bool _flash: false
	property int _last: -1
	on_PercentChanged: {
		if (root._last >= 0 && root._last !== root._percent) {
			root._flash = true;
			flashTimer.restart();
		}
		root._last = root._percent;
	}
	Component.onCompleted: root._last = root._percent
	Timer { id: flashTimer; interval: Tokens.osd.percentMs; onTriggered: root._flash = false }

	// Scrolling an app's tile changes its volume, 5 % a notch.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.NoButton
		onWheel: wheel => {
			const px = wheel.pixelDelta.y;
			const notches = px !== 0 ? px / 100 : wheel.angleDelta.y / 120;
			root.volumeChosen(Math.max(0, Math.min(1, root.session.volume + notches * 0.05)));
			wheel.accepted = true;
		}
	}

	Rectangle {
		id: bar
		objectName: "tileBar"
		anchors.horizontalCenter: parent.horizontalCenter
		width: Tokens.osd.bar.width
		height: Math.max(Tokens.osd.mixer.barMin, root.height - Tokens.osd.action.top - Tokens.osd.action.height)
		radius: Tokens.osd.bar.radius
		color: root.track
		clip: true

		Spring {
			id: fillS
			stiffness: Tokens.osd.fill.stiffness
			damping: Tokens.osd.fill.damping
			initial: root._percent / 100
			target: root._percent / 100
		}

		Rectangle {
			anchors.bottom: parent.bottom
			width: parent.width
			height: parent.height * Math.max(0, fillS.value)
			radius: parent.radius
			color: root.theme.text
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			preventStealing: true
			function choose(y) { root.volumeChosen(Math.max(0, Math.min(1, (height - y) / height))); }
			onPressed: mouse => choose(mouse.y)
			onPositionChanged: mouse => { if (pressed) choose(mouse.y); }
		}
	}

	Item {
		id: action
		objectName: "tileAction"
		anchors.bottom: parent.bottom
		width: parent.width
		height: Tokens.osd.action.height
		scale: pointer.pressed ? Tokens.osd.mixer.pressScale : 1

		Item {
			objectName: "logo"
			anchors.centerIn: parent
			width: Tokens.osd.mixer.icon
			height: Tokens.osd.mixer.icon
			opacity: root._flash ? 0 : root.session.muted ? Tokens.osd.mixer.mutedOpacity : 1
			Behavior on opacity { NumberAnimation { duration: Tokens.osd.action.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }

			Image {
				id: icon
				anchors.fill: parent
				source: root.session.icon || ""
				sourceSize: Qt.size(Tokens.osd.mixer.icon * 2, Tokens.osd.mixer.icon * 2)
				fillMode: Image.PreserveAspectFit
				visible: status === Image.Ready
			}

			// .volume-mixer-action-fallback: the app's initial.
			Rectangle {
				anchors.fill: parent
				visible: !icon.visible
				radius: Tokens.osd.mixer.iconRadius
				color: root.theme.border

				Text {
					objectName: "fallback"
					anchors.centerIn: parent
					text: (root.session.name || "?").charAt(0).toUpperCase()
					color: root.theme.text
					font.family: Tokens.type.family
					font.pixelSize: Tokens.osd.mixer.fallbackText
					font.weight: Font.Bold
				}
			}
		}

		Text {
			anchors.centerIn: parent
			text: root._percent + "%"
			color: root.theme.text
			opacity: root._flash ? 1 : 0
			font.family: Tokens.type.family
			font.pixelSize: Tokens.osd.mixer.percentText
			font.weight: Font.Bold
			font.letterSpacing: Tokens.osd.action.tracking
			font.features: { "tnum": 1 }
			Behavior on opacity { NumberAnimation { duration: Tokens.osd.action.ms; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
		}

		PointerArea {
			id: pointer
			anchors.fill: parent
			onClicked: root.muteToggled()
		}
	}
}
