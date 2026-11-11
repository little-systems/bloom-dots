import QtQuick

// SDDM's entry point. Its context names (sddm, userModel, sessionModel,
// keyboard) are passed under other names so they can't bind to themselves.
Item {
	id: main
	readonly property var _api: sddm
	readonly property var _users: userModel
	readonly property var _sessions: sessionModel
	readonly property var _keyboard: keyboard

	BloomGreeter {
		anchors.fill: parent
		api: main._api
		userModel: main._users
		sessionModel: main._sessions
		keyboard: main._keyboard
	}
}
