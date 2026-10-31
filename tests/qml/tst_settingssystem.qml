import QtTest
import "../../shell/settings/system.js" as Sys

TestCase {
	name: "SettingsSystem"

	function test_modes() {
		compare(Sys.modes({ availableModes: ["1920x1080@60.05Hz"] }), [{ value: "1920x1080@60.05Hz", label: "1920x1080 · 60.05 Hz" }]);
		compare(Sys.currentMode({ width: 1920, height: 1080, refreshRate: 60.052 }), "1920x1080@60.05Hz");
	}
	function test_monitorLine() {
		compare(Sys.monitorLine({ name: "eDP-1", x: 1920, y: 0 }, "1920x1080@60.05Hz", 1.5), 'hl.monitor({ output = "eDP-1", mode = "1920x1080@60.05", position = "1920x0", scale = 1.5 })');
	}
	function test_disks() {
		const text = "Mounted on Size Used\n/ 200 100\n/boot 10 1\n/home 500 400\n/run/user/1000 5 0\n";
		compare(Sys.parseDisks(text).map(d => d.path), ["/home", "/"]);
		compare(Sys.gigabytes(1e11), "100 GB");
		compare(Sys.gigabytes(2.5e9), "2.5 GB");
	}
	function test_hyprConfig() {
		compare(Sys.hyprConfig(Sys.withOption({}, "input.touchpad.natural_scroll", false)), "hl.config({ input = { touchpad = { natural_scroll = false } } })");
		const o = Sys.withOption(Sys.withOption({}, "general.gaps_in", 4), "general.gaps_out", 8);
		compare(o, { general: { gaps_in: 4, gaps_out: 8 } });
		compare(Sys.option(o, "general.gaps_in", 0), 4);
		compare(Sys.option(o, "input.x", 7), 7);
	}
	function test_hyprFile() {
		compare(Sys.hyprFile({}, []), "-- Written by Bloom Settings. Delete this file to undo everything in it.\n");
		verify(Sys.hyprFile({ general: { gaps_in: 1 } }, ["hl.monitor({})"]).endsWith("hl.config({ general = { gaps_in = 1 } })\nhl.monitor({})\n"));
	}
	function test_appName() {
		compare(Sys.appName("org.mozilla.firefox.desktop"), "firefox");
		compare(Sys.appName(""), "Not set");
	}

	function test_liveOptions() {
		const o = Sys.parseOptions("general.gaps_in|css gap data: 4 4 4 4\ninput.repeat_rate|int: 35\ninput.sensitivity|float: -0.200000\nanimations.enabled|bool: true\ndecoration.blur.enabled|bool: false\nnoise");
		compare(o, { "general.gaps_in": 4, "input.repeat_rate": 35, "input.sensitivity": -0.2, "animations.enabled": true, "decoration.blur.enabled": false });
	}
}
