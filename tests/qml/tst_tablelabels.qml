import QtQuick
import QtTest
import "../../shell/common/i18n"
import "../../shell/modules/notch/device-art.js" as Art
import "../../shell/settings/system.js" as Sys

// Labels kept in JS tables are shown through I18n: every entry names a key
// that exists in English, so other languages can translate it.
TestCase {
	name: "TableLabels"

	function test_deviceLooksAndDefaultAppsHaveKeys() {
		const tables = { "device looks": Art.DEVICE_LOOKS.concat(Art.WIRED_DEVICE_LOOKS), "default apps": Sys.DEFAULTS };
		for (const name in tables)
			for (const entry of tables[name]) {
				verify(typeof entry.key === "string" && entry.key !== "", name + ": " + JSON.stringify(entry));
				verify(I18n.t(entry.key) !== entry.key, name + ": " + entry.key + " is missing from English");
			}
		compare(I18n.t(Art.DEVICE_LOOKS[2].key), "Stem buds");
		compare(I18n.t(Sys.DEFAULTS[0].key), "Web browser");
	}
}
