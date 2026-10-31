import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "lock.js" as Lock

// The session lock. The compositor holds it, so a crash here leaves the session
// locked; the marker tells the restarted shell to take it back. Only a PAM
// success unlocks. See docs/handover/phase6-lock-recovery.md.
Scope {
	id: root

	// The stack hyprlock already installs, so Bloom adds nothing to /etc/pam.d.
	property string pamConfig: "hyprlock"
	property string pamDir: "/etc/pam.d"
	// Off in tests: a software renderer can't keep up with it.
	property bool clockTurning: true
	property var monitors: HyprState.monitors

	readonly property bool locked: session.locked
	readonly property string _marker: Quickshell.env("XDG_RUNTIME_DIR") + "/bloom-locked-"
		+ (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || Quickshell.env("WAYLAND_DISPLAY") || "session")

	property date _now: new Date()
	property bool _busy: false
	property bool _capsLock: false
	property string _layout: ""
	property string _text: ""
	readonly property string _wallpaper: Settings.values["bloom-lock-wallpaper"] || Lock.wallpaperFrom(iiConfig.text())
	property string _message: ""
	property bool _messageIsError: false
	property string _pamNotice: ""
	property string _pending: ""
	property bool _leaving: false
	property bool _covered: false
	property var _saved: ({})
	signal failed()

	function lock() {
		if (session.locked) return;
		root._setMessage("", false);
		root._text = "";
		root._saved = Lock.saveWorkspaces(root.monitors);
		// The marker goes first: a crash in between then errs towards locked,
		// and it carries the way back to the workspaces.
		Quickshell.execDetached(["sh", "-c", 'umask 077; printf %s "$1" > "$2"', "sh", JSON.stringify(root._saved), root._marker]);
		root._engage();
		root._dispatch(Lock.leaveScript(root._saved));
	}
	function _engage() {
		root._now = new Date();
		root._covered = false;
		session.locked = true;
	}
	function _dispatch(script) {
		if (script !== "") Quickshell.execDetached(["sh", "-c", script]);
	}
	function status() {
		return {
			enabled: true, locked: session.locked, secure: session.secure, busy: root._busy,
			leaving: root._leaving, covered: root._covered, capsLock: root._capsLock, layout: root._layout, wallpaper: root._wallpaper, message: root._message
		};
	}
	function submit(response) {
		if (root._busy) return;
		root._text = "";
		root._setMessage("", false);
		root._pamNotice = "";
		root._busy = true;
		if (pam.active && pam.responseRequired) {
			pam.respond(response);
			return;
		}
		root._pending = response;
		if (!pam.start()) root._finish(Lock.failureText("error"));
	}
	function _setMessage(text, isError) {
		root._message = text;
		root._messageIsError = isError;
	}
	function _finish(text) {
		root._pending = "";
		root._busy = false;
		root._setMessage(text, true);
		root.failed();
	}
	// Authenticated: the blur fades off the empty workspace, the windows slide
	// back under it, and only then does the compositor unlock.
	function _unlock() {
		root._pending = "";
		root._setMessage("", false);
		root._leaving = true;
		returnTimer.start();
		unlockTimer.start();
	}
	Timer {
		id: returnTimer
		interval: Tokens.lock.leave.returnMs
		onTriggered: root._dispatch(Lock.returnScript(root._saved))
	}
	Timer {
		id: unlockTimer
		interval: Tokens.lock.leave.ms
		onTriggered: {
			session.locked = false;
			root._leaving = false;
			root._busy = false;
			root._saved = {};
			Quickshell.execDetached(["rm", "-f", root._marker]);
		}
	}

	PamContext {
		id: pam
		config: root.pamConfig
		configDirectory: root.pamDir
		onPamMessage: {
			if (pam.responseRequired) {
				if (root._pending !== "") {
					const response = root._pending;
					root._pending = "";
					pam.respond(response);
				} else {
					// A second question, such as an expired password.
					root._busy = false;
					root._setMessage(pam.message, false);
				}
			} else {
				root._pamNotice = pam.message;
			}
		}
		onCompleted: result => {
			if (result === PamResult.Success) root._unlock();
			else if (result === PamResult.Error) root._finish(Lock.failureText("error"));
			else root._finish(root._pamNotice || Lock.failureText(result === PamResult.MaxTries ? "maxtries" : "failed"));
		}
		onError: root._finish(Lock.failureText("error"))
	}

	FileView {
		id: iiConfig
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/illogical-impulse/config.json"
		printErrors: false
	}

	// An idle password doesn't stay on the screen.
	Timer {
		id: clearTimer
		interval: Tokens.lock.clearMs
		onTriggered: root._text = ""
	}

	// Left over from a crash: the compositor is still locked, so take it back.
	// The screens are already on their empty workspaces.
	Process {
		running: true
		command: ["cat", root._marker]
		stdout: StdioCollector { id: markerText }
		onExited: code => {
			if (code !== 0) return;
			root._saved = Lock.parseMarker(markerText.text);
			root._engage();
		}
	}

	Timer {
		interval: 1000
		repeat: true
		running: session.locked
		onTriggered: root._now = new Date()
	}
	Timer {
		interval: Tokens.lock.capsPollMs
		repeat: true
		running: session.locked
		triggeredOnStart: true
		onTriggered: capsProbe.running = true
	}
	Process {
		id: capsProbe
		command: ["hyprctl", "devices", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				const keyboard = Lock.keyboard(text);
				root._capsLock = keyboard.capsLock;
				root._layout = keyboard.layout;
			}
		}
	}

	WlSessionLock {
		id: session

		WlSessionLockSurface {
			id: surface
			// See-through only until the backdrop covers the screen, and after a
			// correct password.
			color: root._covered && !root._leaving ? "black" : "transparent"
			readonly property real uiScale: Settings.values["bloom-scale"]

			LockBackdrop {
				id: backdrop
				anchors.fill: parent
				source: root._wallpaper
				zoom: Lock.wallpaperZoomFrom(iiConfig.text())
				leaving: root._leaving
				onCovered: root._covered = true
			}

			LockView {
				id: view
				width: surface.width / surface.uiScale
				height: surface.height / surface.uiScale
				scale: surface.uiScale
				transformOrigin: Item.TopLeft
				theme: Theme
				user: Quickshell.env("USER")
				layout: root._layout
				leaving: root._leaving || !backdrop.shown
				time: root._now
				clockTurning: root.clockTurning && !Performance.lowPower
				text: root._text
				busy: root._busy
				responseVisible: pam.responseVisible
				capsLock: root._capsLock
				message: root._message
				messageIsError: root._messageIsError
				batteryAvailable: Battery.available
				batteryLevel: Battery.level
				batteryCharging: Battery.charging
				batteryLow: Battery.level <= Battery.threshold
				onTextEdited: text => {
					root._text = text;
					root._setMessage("", false);
					clearTimer.restart();
				}
				onSubmitted: response => root.submit(response)
				onSuspendRequested: Session.run("suspend")
				onShutdownRequested: Session.run("shutdown")
				onRebootRequested: Session.run("reboot")
				Component.onCompleted: view.focusField()

				Connections {
					target: root
					function onFailed() { view.shake(); }
				}
			}
		}
	}
}
