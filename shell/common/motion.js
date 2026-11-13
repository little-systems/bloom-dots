// When Bloom's Reduce Motion reaches Hyprland. Plain JS (shared with tests).

// Hyprland reloads (and hypr/bloom.lua rereads the setting) only when the
// value really changes: not at shell start, not when settings first load.
function reloadNeeded(previous, next) {
	return previous !== undefined && previous !== next;
}
