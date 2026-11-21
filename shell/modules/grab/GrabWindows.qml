import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import "."
import "grab.js" as Logic
import "../../common/tokens.js" as Tokens

// The grab handle for floating windows (owner's request: apps like Spotify
// draw no title bar to drag), Hyprland only. One click-through layer per
// screen takes the pointer only in the handle's zone on the focused floating
// window's top edge; dragging it moves the window. Hyprland's window list is
// refreshed on its events, and every pollMs while a floating window is
// focused, since moving one (Super + drag) sends no event.
Scope {
	id: root

	readonly property var windows: Hyprland.toplevels.values.map(t => t.lastIpcObject).filter(Boolean)
	readonly property bool tracking: root.windows.some(w => w.focusHistoryID === 0 && w.floating)

	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (["activewindowv2", "changefloatingmode", "fullscreen", "movewindowv2", "openwindow", "closewindow", "workspacev2", "focusedmonv2"].indexOf(event.name) >= 0)
				soon.restart();
		}
	}

	Timer {
		id: soon
		interval: 30
		onTriggered: Hyprland.refreshToplevels()
	}

	Timer {
		interval: Tokens.grab.pollMs
		repeat: true
		running: root.tracking
		onTriggered: Hyprland.refreshToplevels()
	}

	Component.onCompleted: Hyprland.refreshToplevels()

	IpcHandler {
		target: "grab"
		function state(): string {
			return JSON.stringify(screens.instances.map(w => ({ screen: w.modelData.name, window: w.target ? w.target.address : null,
				zone: w.zone, visible: w.visible, dragging: w.dragging })));
		}
	}

	Variants {
		id: screens
		model: Quickshell.screens

		PanelWindow {
			id: win
			required property var modelData
			readonly property var monitor: Hyprland.monitorFor(modelData)
			readonly property var target: win.monitor ? Logic.target(root.windows, win.monitor.id) : null
			readonly property var bounds: win.monitor ? { x: win.monitor.x, y: win.monitor.y, width: win.monitor.width, height: win.monitor.height, scale: win.monitor.scale } : null

			// While dragging, where the window is going, ahead of Hyprland's list.
			property var _dragAt: null
			property var _start: null
			property point _pressedAt
			property var _pending: null
			property string _address: ""
			readonly property bool dragging: handle.dragging

			readonly property var geometry: win.target ? {
				x: win._dragAt ? win._dragAt.x : win.target.at[0],
				y: win._dragAt ? win._dragAt.y : win.target.at[1],
				width: win.target.size[0],
				height: win.target.size[1]
			} : null
			readonly property var zone: win.geometry && win.bounds ? Logic.zone(win.geometry, win.bounds, Tokens.grab) : null

			screen: modelData
			anchors.top: true
			anchors.bottom: true
			anchors.left: true
			anchors.right: true
			color: "transparent"
			exclusiveZone: -1
			visible: win.zone !== null
			mask: Region { item: handle }
			WlrLayershell.namespace: "bloom:grab"
			WlrLayershell.layer: WlrLayer.Top
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

			// A refresh after the drop has the window where it went.
			onTargetChanged: if (!handle.dragging) win._dragAt = null

			GrabHandle {
				id: handle
				theme: Theme
				x: win.zone ? win.zone.x : 0
				y: win.zone ? win.zone.y : 0
				width: win.zone ? win.zone.width : 0
				height: win.zone ? win.zone.height : 0

				onGrabbed: at => {
					if (!win.target) return;
					win._address = win.target.address;
					win._start = { x: win.geometry.x, y: win.geometry.y };
					win._pressedAt = at;
					Hyprland.dispatch("hl.dsp.window.bring_to_top()");
				}
				onDragged: at => {
					if (!win._start || !win.target) return;
					win._dragAt = Logic.moved(win._start, win._pressedAt, at, { width: win.target.size[0], height: win.target.size[1] }, win.bounds, Tokens.grab);
					win._pending = win._dragAt;
					if (!mover.running) mover.start();
				}
				onDropped: {
					win._send();
					win._start = null;
					Hyprland.refreshToplevels();
				}
			}

			function _send() {
				if (!win._pending) return;
				const command = Logic.dispatch(win._address, win._pending);
				win._pending = null;
				if (command) Hyprland.dispatch(command);
			}

			// At most one move a frame, the latest.
			Timer {
				id: mover
				interval: Tokens.grab.moveMs
				repeat: true
				onTriggered: {
					if (win._pending) win._send();
					else stop();
				}
			}
		}
	}
}
