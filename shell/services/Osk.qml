pragma Singleton
import QtQuick
import Quickshell
import "../modules/osk/osk.js" as Logic

// The on-screen keyboard. Modifiers latch for the next key, as on a phone.
Singleton {
	id: root

	property bool opened: false
	property var held: []

	function toggle() { root.opened = !root.opened; }
	function press(key) {
		if (key.modifier) {
			root.held = root.held.indexOf(key.modifier) >= 0 ? root.held.filter(m => m !== key.modifier) : root.held.concat([key.modifier]);
			return;
		}
		Quickshell.execDetached(Logic.command(key, root.held));
		root.held = [];
	}
}
