import QtQuick
import QtTest
import "../../shell/modules/launcher/launcher.js" as Launcher

TestCase {
	name: "LauncherRules"

	// The owner's prefixes (2026-10-31); anything else searches apps.
	function test_prefixes() {
		compare(Launcher.parse("firefox"), { mode: "apps", term: "firefox" });
		compare(Launcher.parse(""), { mode: "apps", term: "" });
		compare(Launcher.parse(";pass"), { mode: "clipboard", term: "pass" });
		compare(Launcher.parse(": smile"), { mode: "emoji", term: "smile" });
		compare(Launcher.parse("=2+2"), { mode: "calc", term: "2+2" });
		compare(Launcher.parse(">ls -la"), { mode: "command", term: "ls -la" });
		compare(Launcher.parse("? arch wiki"), { mode: "web", term: "arch wiki" });
		compare(Launcher.parse("!backup"), { mode: "actions", term: "backup" });
		compare(Launcher.parse("  firefox "), { mode: "apps", term: "firefox" });
	}

	// Best match first: whole name, start, word start, inside, then letters
	// in order; ties by name; a miss is left out.
	function test_ranking() {
		const apps = ["Files", "Firefox", "LibreOffice Writer", "Fire Drill", "Wine File", "Zed"].map(name => ({ id: name, name }));
		const names = term => Launcher.rank(apps, term).map(a => a.name);
		compare(names("firefox"), ["Firefox"]);
		compare(names("fi"), ["Files", "Fire Drill", "Firefox", "Wine File", "LibreOffice Writer"]);
		compare(names("file"), ["Files", "Wine File"]);
		compare(names("lw"), ["LibreOffice Writer"]);
		compare(names("qqq"), []);
		compare(names("").length, 6, "no term lists everything");
		compare(names("FIRE"), ["Fire Drill", "Firefox", "LibreOffice Writer"], "any case; letters in order come last");
	}

	function test_webUrl() {
		compare(Launcher.webUrl("arch wiki & more"), "https://www.google.com/search?q=arch%20wiki%20%26%20more");
	}

	// `cliphist list`: "<id>\t<preview>"; a binary entry stays listed.
	function test_clipboardEntries() {
		const got = Launcher.clipEntries("12\thello there\n11\t[[ binary data 3 KiB png 10x10 ]]\n\nbad line\n");
		compare(got.map(e => ({ id: e.id, text: e.text, raw: e.raw })), [{ id: "12", text: "hello there", raw: "12\thello there" },
			{ id: "11", text: "[[ binary data 3 KiB png 10x10 ]]", raw: "11\t[[ binary data 3 KiB png 10x10 ]]" }]);
		compare(Launcher.filterClips(got, "HELLO").length, 1);
		compare(Launcher.filterClips(got, "").length, 2);
	}

	function test_emoji() {
		const got = Launcher.emoji("grinning");
		verify(got.length > 0);
		compare(got[0].glyph, "😀");
		compare(got[0].name, "Grinning face");
		compare(Launcher.emoji("").length, 60, "a first page with no term");
		compare(Launcher.emoji("nosuchemojiatall").length, 0);
	}

	// What each mode shows besides apps.
	function test_singleRows() {
		compare(Launcher.commandRow("ls -la"), [{ id: "command", name: "ls -la", sub: "Run this command", icon: "", glyph: ">", action: { kind: "command", value: "ls -la" } }]);
		compare(Launcher.commandRow(""), []);
		const web = Launcher.webRow("arch")[0];
		compare(web.sub, "Search Google");
		compare(web.action, { kind: "url", value: "https://www.google.com/search?q=arch" });
		const calc = Launcher.calcRow("2+2", "4")[0];
		compare(calc.name, "4");
		compare(calc.sub, "2+2 · Enter copies it");
		compare(calc.action, { kind: "copy", value: "4" });
		compare(Launcher.calcRow("2+", ""), []);
	}
}
