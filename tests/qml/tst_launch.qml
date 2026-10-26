import QtQuick
import QtTest
import "../../shell/services/launch.js" as Launch

TestCase {
	name: "Launch"

	function test_unitName() {
		verify(/^app-bloom-org\.kde\.dolphin-[0-9a-z]+$/.test(Launch.unitName("org.kde.dolphin", 1792911167)));
		verify(/^app-bloom-weird_name_-[0-9a-z]+$/.test(Launch.unitName("weird name!", 7)), "unit names allow [A-Za-z0-9_.-] only");
	}

	function test_argv() {
		const a = Launch.argv(["firefox", "--new-window"], "app-bloom-firefox-1", false);
		compare(a.slice(0, 2), ["sh", "-c"]);
		compare(a.slice(3), ["sh", "app-bloom-firefox-1", "firefox", "--new-window"], "the command stays argv: no shell quoting of its words");
		verify(a[2].indexOf("systemd-run --user --scope --collect --quiet") >= 0);
		verify(a[2].indexOf('"$BLOOM_LAUNCH_SCOPE" != 0') >= 0, "tests opt out of systemd");
		compare(Launch.argv(["htop"], "u", true).slice(5), ["xdg-terminal-exec", "htop"]);
	}
}
