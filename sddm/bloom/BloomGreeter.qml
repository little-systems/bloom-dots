import QtQuick
import "shell/modules/lock"

// The Bloom login screen: the lock screen's own backdrop and view, driven by
// SDDM's models and actions. The wallpaper, colours and scale come from
// /var/lib/bloom/login/State.qml, which Bloom rewrites when the wallpaper
// changes; without it the shipped wallpaper and the dark palette are used.
Item {
	id: root

	property var api: null
	property var userModel: null
	property var sessionModel: null
	property var keyboard: null
	property url stateUrl: "file:///var/lib/bloom/login/State.qml"
	property int userIndex: root.userModel && root.userModel.lastIndex >= 0 ? root.userModel.lastIndex : 0
	property int sessionIndex: root.sessionModel && root.sessionModel.lastIndex >= 0 ? root.sessionModel.lastIndex : 0
	property var _users: []
	property var _sessions: []
	readonly property QtObject _state: loginState.status === Loader.Ready ? loginState.item : null
	readonly property real _scale: root._state && root._state.scale > 0 ? root._state.scale : 1

	function _names(instantiator) {
		const names = [];
		for (let i = 0; i < instantiator.count; i++) {
			const entry = instantiator.objectAt(i);
			if (entry) names.push(entry.name);
		}
		return names;
	}

	Loader { id: loginState; source: root.stateUrl }
	Instantiator {
		id: users
		model: root.userModel
		delegate: QtObject { required property string name }
		onObjectAdded: root._users = root._names(users)
		onObjectRemoved: root._users = root._names(users)
	}
	Instantiator {
		id: sessions
		model: root.sessionModel
		delegate: QtObject { required property string name }
		onObjectAdded: root._sessions = root._names(sessions)
		onObjectRemoved: root._sessions = root._names(sessions)
	}
	Timer {
		interval: 1000
		running: true
		repeat: true
		onTriggered: view.time = new Date()
	}
	Connections {
		target: root.api
		ignoreUnknownSignals: true
		function onLoginFailed() {
			view.busy = false;
			view.message = "Wrong password";
			view.messageIsError = true;
			view.shake();
			view.focusField();
		}
		function onLoginSucceeded() { view.leaving = true; }
	}

	LockBackdrop {
		anchors.fill: parent
		source: root._state && root._state.wallpaper ? root._state.wallpaper : Qt.resolvedUrl("default-wallpaper.jpg")
		zoom: root._state && root._state.zoom > 0 ? root._state.zoom : 1
		shown: true
	}

	LockView {
		id: view
		width: root.width / root._scale
		height: root.height / root._scale
		scale: root._scale
		transformOrigin: Item.TopLeft
		theme: root._state || defaultTheme
		accent: root._state ? root._state.accent : "#007aff"
		user: root._users[root.userIndex] || ""
		clockTag: root.api && root.api.hostName ? root.api.hostName : "Welcome"
		clockTagIcon: "monitor"
		users: root._users
		sessions: root._sessions
		sessionIndex: root.sessionIndex
		layout: root.keyboard && root.keyboard.layouts && root.keyboard.layouts.length > 1
			? root.keyboard.layouts[root.keyboard.currentLayout].shortName : ""
		capsLock: root.keyboard ? root.keyboard.capsLock === true : false
		onUserStepped: step => {
			root.userIndex = (root.userIndex + step + root._users.length) % root._users.length;
			view.message = "";
			view.messageIsError = false;
			view.focusField();
		}
		onSessionStepped: {
			root.sessionIndex = (root.sessionIndex + 1) % root._sessions.length;
			view.focusField();
		}
		onSubmitted: response => {
			view.busy = true;
			view.message = "";
			view.messageIsError = false;
			root.api.login(root._users[root.userIndex], response, root.sessionIndex);
		}
		onSuspendRequested: root.api.suspend()
		onShutdownRequested: root.api.powerOff()
		onRebootRequested: root.api.reboot()
		Component.onCompleted: view.focusField()
	}

	QtObject {
		id: defaultTheme
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
}
