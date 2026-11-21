pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../common/tokens.js" as Tokens
import "../modules/switcher/switcher.js" as Logic

// The Alt + Tab switcher's state. Hyprland's alt-tab.lua does the switching
// and sends what to draw: `open` when Alt + Tab starts a cycle, `select` as Tab
// steps, `hide` when Alt is released or Esc cancels. The card is revealed only
// once Alt has been held revealMs, so a quick tap never flashes it. A clicked
// tile is focused from here; alt-tab.lua then leaves the focus alone.
Singleton {
	id: root

	property var addresses: []
	property int index: 0
	property bool active: false
	property bool revealed: false

	function open(list, index) {
		root.addresses = Logic.parse(list);
		root.index = Logic.clamp(index, root.addresses.length);
		root.active = root.addresses.length > 0;
		root.revealed = false;
		if (root.active) reveal.restart();
		return "ok";
	}

	function select(index) {
		if (!root.active) return "idle";
		root.index = Logic.clamp(index, root.addresses.length);
		return "ok";
	}

	function hide() {
		reveal.stop();
		root.active = false;
		root.revealed = false;
		return "ok";
	}

	function choose(index) {
		const address = root.addresses[index];
		root.hide();
		if (!address) return "invalid";
		// Bringing a tiled window to the top changes nothing, so every choice gets it.
		focus.command = ["sh", "-c", 'hyprctl dispatch "$1" && hyprctl dispatch "$2"', "sh",
			'hl.dsp.focus({ window = "address:' + address + '" })', "hl.dsp.window.bring_to_top()"];
		focus.running = true;
		return "ok";
	}

	Timer {
		id: reveal
		interval: Tokens.switcher.revealMs
		onTriggered: root.revealed = root.active
	}

	Process { id: focus }
}
