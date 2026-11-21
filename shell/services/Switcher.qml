pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../common/tokens.js" as Tokens
import "../modules/switcher/switcher.js" as Logic

// The switcher card's state: Alt + Tab with floating windows (tiled ones get
// no card), and a held three-finger swipe.
// Hyprland's alt-tab.lua does the switching and sends what to draw: `open`
// with the whole state as Tab steps, `hide` when Alt is let go or Esc cancels;
// a held three-finger swipe sends `reveal` instead of its first `open`.
// Each message carries a rising seq and older ones are dropped, since every
// `bloom ipc` is its own process and they can land out of order. The card is
// revealed only once Alt has been held revealMs, so a quick tap never flashes
// it. A clicked tile is focused from here; alt-tab.lua then leaves the focus
// alone.
Singleton {
	id: root

	property var addresses: []
	property int index: 0
	property bool active: false
	property bool revealed: false
	property int _seq: 0
	property double _seqAt: 0

	function _take(seq) {
		const now = Date.now();
		if (!Logic.fresh(seq, root._seq, now - root._seqAt)) return false;
		root._seq = seq;
		root._seqAt = now;
		return true;
	}

	// `now`: show the card without the wait (a held swipe has waited already).
	function open(seq, list, index, now) {
		if (!root._take(seq)) return "stale";
		const starting = !root.active;
		root.addresses = Logic.parse(list);
		root.index = Logic.clamp(index, root.addresses.length);
		root.active = root.addresses.length > 0;
		if (!root.active) {
			root.revealed = false;
		} else if (now) {
			reveal.stop();
			root.revealed = true;
		} else if (starting) {
			reveal.restart();
		}
		return "ok";
	}

	function hide(seq) {
		if (!root._take(seq)) return "stale";
		root._close();
		return "ok";
	}

	function _close() {
		reveal.stop();
		root.active = false;
		root.revealed = false;
	}

	function choose(index) {
		const address = root.addresses[index];
		root._close();
		if (!address) return "invalid";
		// Every window on the card floats, so the choice comes to the front too.
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
