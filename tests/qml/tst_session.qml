import QtQuick
import QtTest
import "../../shell/modules/session/session.js" as Session

TestCase {
	name: "SessionRules"

	function test_actionsInOrder() {
		compare(Session.ACTIONS.map(a => a.id), ["lock", "logout", "suspend", "hibernate", "reboot", "shutdown", "firmware"]);
		compare(Session.ACTIONS.map(a => a.label), ["Lock", "Log out", "Suspend", "Hibernate", "Restart", "Shut down", "Firmware setup"]);
	}

	// Never a shell string: each is an argv, with the tools overridable.
	function test_commands() {
		compare(Session.command("suspend"), ["systemctl", "suspend"]);
		compare(Session.command("hibernate"), ["systemctl", "hibernate"]);
		compare(Session.command("reboot"), ["systemctl", "reboot"]);
		compare(Session.command("shutdown"), ["systemctl", "poweroff"]);
		compare(Session.command("firmware"), ["systemctl", "reboot", "--firmware-setup"]);
		compare(Session.command("logout"), ["hyprctl", "dispatch", "hl.dsp.exit()"]);
		compare(Session.command("nonsense"), null);
	}

	// Ending the session with work running asks first; sleeping doesn't end it.
	function test_warnings() {
		const busy = { pacman: true, downloads: 2 };
		compare(Session.warning("shutdown", busy), "pacman is running, and 2 downloads are in progress.");
		compare(Session.warning("reboot", { pacman: true, downloads: 0 }), "pacman is running.");
		compare(Session.warning("logout", { pacman: false, downloads: 1 }), "A download is in progress.");
		compare(Session.warning("shutdown", { pacman: false, downloads: 0 }), "");
		compare(Session.warning("suspend", busy), "pacman is running.", "a download survives a suspend; an upgrade shouldn't be paused");
		compare(Session.warning("lock", busy), "");
	}

	// busy-check output: "pacman" and one line per partial download.
	function test_busyParsing() {
		compare(Session.parseBusy("pacman\n/home/u/Downloads/a.iso.part\n/home/u/Downloads/b.crdownload\n"), { pacman: true, downloads: 2 });
		compare(Session.parseBusy(""), { pacman: false, downloads: 0 });
	}
}
