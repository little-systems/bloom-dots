// The session menu's rules (spec §4.2): its actions, their commands, and when
// a running pacman or download deserves a warning first. Pure.
var ACTIONS = [
	{ id: "lock", label: "Lock", icon: "lock" },
	{ id: "logout", label: "Log out", icon: "log-out" },
	{ id: "suspend", label: "Suspend", icon: "moon" },
	{ id: "hibernate", label: "Hibernate", icon: "hard-drive" },
	{ id: "reboot", label: "Restart", icon: "rotate-ccw" },
	{ id: "shutdown", label: "Shut down", icon: "power" },
	{ id: "firmware", label: "Firmware setup", icon: "cpu" }
];

function command(id) {
	return ({
		// Launch from Hyprland so stopping Bloom cannot kill the logout command.
		// Stop the shell before disconnecting Wayland. Development sessions can
		// still log out when the service is absent.
		logout: ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"systemctl --user stop bloom-shell.service; hyprctl dispatch 'hl.dsp.exit()'\")"],
		suspend: ["systemctl", "suspend"],
		hibernate: ["systemctl", "hibernate"],
		reboot: ["systemctl", "reboot"],
		shutdown: ["systemctl", "poweroff"],
		firmware: ["systemctl", "reboot", "--firmware-setup"]
	})[id] ?? null;
}

// Suspend and hibernate keep downloads; they shouldn't pause an upgrade.
function warning(id, busy) {
	if (id === "lock") return "";
	const sleeping = id === "suspend" || id === "hibernate";
	const n = sleeping ? 0 : busy.downloads;
	const downloads = n === 1 ? "a download is in progress" : n + " downloads are in progress";
	if (busy.pacman && n > 0) return "pacman is running, and " + downloads + ".";
	if (busy.pacman) return "pacman is running.";
	return n > 0 ? downloads.charAt(0).toUpperCase() + downloads.slice(1) + "." : "";
}

function parseBusy(text) {
	const lines = String(text || "").split("\n").filter(l => l);
	return { pacman: lines.includes("pacman"), downloads: lines.filter(l => l !== "pacman").length };
}
