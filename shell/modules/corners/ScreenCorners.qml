import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common/tokens.js" as Tokens
import "../notch/notch.js" as NotchLogic

// One screen's rounded corners (bloom-corners-enabled): four small black
// corners, each its own click-through Overlay surface so nothing else of the
// screen is covered, hidden while a fullscreen window shows on this screen.
Scope {
	id: root
	required property var modelData

	readonly property int radius: Tokens.screenCorners.radius
	readonly property var _monitor: HyprState.monitors.find(m => m.name === root.modelData.name) ?? null
	readonly property bool fullscreen: root._monitor !== null && NotchLogic.fullscreenOn(HyprState.clients, root._monitor)
	readonly property bool shown: !root.fullscreen
	readonly property string _key: "corners:" + root.modelData.name

	function stateObject() {
		return { screen: root.modelData.name, corners: corners.instances.map(c => c.corner), shown: root.shown,
			radius: root.radius, clickThrough: corners.instances.every(c => c.clickThrough) };
	}

	Component.onCompleted: HyprState.hold(root._key, "events")
	Component.onDestruction: HyprState.hold(root._key, "")

	Variants {
		id: corners
		model: ["top-left", "top-right", "bottom-left", "bottom-right"]

		PanelWindow {
			id: win
			required property string modelData
			readonly property string corner: win.modelData
			readonly property bool top: win.corner.startsWith("top")
			readonly property bool left: win.corner.endsWith("left")
			readonly property bool clickThrough: true

			screen: root.modelData
			visible: root.shown
			anchors { top: win.top; bottom: !win.top; left: win.left; right: !win.left }
			implicitWidth: root.radius
			implicitHeight: root.radius
			color: "transparent"
			exclusionMode: ExclusionMode.Ignore
			WlrLayershell.namespace: "bloom:screen-corners"
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
			// An empty input region: clicks pass through to whatever is below.
			mask: Region {}

			// Black outside a quarter circle centred on the corner's inner point.
			Shape {
				anchors.fill: parent
				preferredRendererType: Shape.CurveRenderer
				ShapePath {
					strokeWidth: -1
					fillColor: "black"
					startX: win.left ? 0 : root.radius
					startY: win.top ? 0 : root.radius
					PathLine { x: win.left ? 0 : root.radius; y: win.top ? root.radius : 0 }
					PathArc {
						x: win.left ? root.radius : 0; y: win.top ? 0 : root.radius
						radiusX: root.radius; radiusY: root.radius
						direction: (win.left === win.top) ? PathArc.Clockwise : PathArc.Counterclockwise
					}
					PathLine { x: win.left ? 0 : root.radius; y: win.top ? 0 : root.radius }
				}
			}
		}
	}
}
