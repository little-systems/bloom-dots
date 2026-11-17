import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common/render"
import "../../common/screens.js" as Screens
import "../../common/tokens.js" as Tokens
import "layout.js" as Layout

// The first-run guide on the focused screen: a full-screen overlay whose input
// region is the card (+20 px) and its arrow (+4 px), so the desktop around it
// stays usable (Bloom Onboarding.tsx measureElements). The card keeps its size
// and moves between the Island, the centre and the Dock with a transform.
PanelWindow {
	id: win
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
	readonly property var place: Layout.place(card.page.anchor, win.width, win.height, win.uiScale)
	readonly property var arrowPlace: Layout.arrow(card.page.anchor, win.width, win.height, win.uiScale)
	readonly property var motion: Tokens.onboarding.motion

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusiveZone: -1
	visible: targetScreen && Onboarding.opened
	WlrLayershell.namespace: "bloom:onboarding"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Onboarding.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	mask: Region {
		item: cardHit
		Region { item: card.anchorPlacement && card.page.anchor !== "center" ? arrowHit : null }
	}

	// The card appears where its page is, then moves with Bloom's 0.36 s ease.
	// The window loads when the guide opens (shell.qml), so it starts at page 1.
	property bool _placed: false
	Component.onCompleted: {
		card.forceActiveFocus();
		if (win.targetScreen)
			Onboarding.reveal = card.reveal;
		win._placed = true;
	}

	OnboardingCard {
		id: card
		store: Settings
		reducedMotion: Render.reduceMotion
		light: Theme.isLight
		panelOverride: Theme.mode === "adaptive" || Theme.mode === "custom" ? Theme.bg : "transparent"
		anchorPlacement: win.arrowPlace
		scale: win.place.scale
		transformOrigin: Item.TopLeft
		x: win.place.x
		y: win.place.y
		Behavior on x {
			enabled: win._placed && !Render.reduceMotion
			NumberAnimation { duration: win.motion.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: win.motion.moveEase.concat([1, 1]) }
		}
		Behavior on y {
			enabled: win._placed && !Render.reduceMotion
			NumberAnimation { duration: win.motion.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: win.motion.moveEase.concat([1, 1]) }
		}
		onRevealChanged: if (win.targetScreen) Onboarding.reveal = card.reveal
		onCloseRequested: Onboarding.close()
	}

	Item {
		id: cardHit
		x: card.x - 20
		y: card.y - 20
		width: card.width * card.scale + 40
		height: card.height * card.scale + 40
	}
	Item {
		id: arrowHit
		readonly property var a: card.anchorPlacement
		x: card.x + (a ? a.x : 0) * card.scale - 4
		y: card.y + (a ? a.y : 0) * card.scale - 4
		width: (a ? a.width : 0) * card.scale + 8
		height: (a ? a.height : 0) * card.scale + 8
	}
}
