// Place transient surfaces on Hyprland's focused monitor, or the first
// Quickshell screen when running on another compositor.
function isTarget(screen, monitors, screens) {
	const focused = (monitors || []).find(m => m.focused)?.name;
	return screen?.name === (focused || screens?.[0]?.name);
}
