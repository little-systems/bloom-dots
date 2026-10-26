import QtQuick
import QtTest
import "../../shell/services/updates.js" as Updates

TestCase {
	name: "UpdatesParse"

	function test_parse() {
		const some = Updates.parse(0, "fuzzel 1.15.0-1 -> 1.15.0-2\njdk-openjdk 27.0.1-1 -> 27.0.1-2\n");
		verify(some.ok);
		compare(some.count, 2);
		compare(some.packages, ["fuzzel", "jdk-openjdk"]);
		const none = Updates.parse(2, "");
		verify(none.ok);
		compare(none.count, 0);
		verify(!Updates.parse(1, "").ok, "offline or a broken mirror");
		verify(!Updates.parse(15, "a 1 -> 2\n").ok, "killed by the watchdog");
		const missing = Updates.parse(127, "");
		verify(!missing.ok);
		verify(missing.missing, "checkupdates is not installed");
		compare(Updates.parse(0, "\n").count, 0, "blank output");
	}

	// Pulse when new updates appear, not every hour that some are pending.
	function test_rose() {
		verify(Updates.rose(0, 7), "the first check that finds updates");
		verify(Updates.rose(7, 9), "more arrived");
		verify(!Updates.rose(7, 7), "the same updates an hour later");
		verify(!Updates.rose(9, 2), "after a partial upgrade");
	}
}
