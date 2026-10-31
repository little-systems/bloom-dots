// Low-power mode (spec §6): forced on or off, or following the battery. Pure.
function isLow(mode, onBattery) {
	return mode === "on" || (mode === "auto" && onBattery);
}
