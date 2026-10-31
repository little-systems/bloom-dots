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

	readonly property bool locked: session.locked
	readonly property string _marker: Quickshell.env("XDG_RUNTIME_DIR") + "/bloom-locked-"
		+ (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || Quickshell.env("WAYLAND_DISPLAY") || "session")

	property date _now: new Date()
	property bool _busy: false
	property bool _capsLock: false
	property string _message: ""
	property bool _messageIsError: false
	property string _pamNotice: ""
	property string _pending: ""
	signal failed()

	function lock() {
		if (session.locked) return;
		root._setMessage("", false);
		// The marker goes first: a crash in between then errs towards locked.
		Quickshell.execDetached(["touch", root._marker]);
		root._now = new Date();
		session.locked = true;
	}
	function status() {
		return {
			enabled: true, locked: session.locked, secure: session.secure, busy: root._busy,
			capsLock: root._capsLock, message: root._message
		};
	}
	function submit(response) {
		if (root._busy) return;
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
	function _unlock() {
		root._pending = "";
		root._busy = false;
		root._setMessage("", false);
		session.locked = false;
		Quickshell.execDetached(["rm", "-f", root._marker]);
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

	// Left over from a crash: the compositor is still locked, so take it back.
	Process {
		running: true
		command: ["test", "-e", root._marker]
		onExited: code => { if (code === 0) root.lock(); }
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
			onStreamFinished: root._capsLock = Lock.capsLock(text)
		}
	}

	WlSessionLock {
		id: session

		WlSessionLockSurface {
			id: surface
			color: "black"
			readonly property real uiScale: Settings.values["bloom-scale"]

			LockView {
				id: view
				width: surface.width / surface.uiScale
				height: surface.height / surface.uiScale
				scale: surface.uiScale
				transformOrigin: Item.TopLeft
				theme: Theme
				user: Quickshell.env("USER")
				time: root._now
				clock24: Settings.values["bloom-time-format-24h"] === true
				busy: root._busy
				responseVisible: pam.responseVisible
				capsLock: root._capsLock
				message: root._message
				messageIsError: root._messageIsError
				onSubmitted: response => root.submit(response)
				Component.onCompleted: view.focusField()

				Connections {
					target: root
					function onFailed() { view.shake(); }
				}
			}
		}
	}
}
