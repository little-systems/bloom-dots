pragma Singleton
import QtQuick
import "i18n.js" as Logic
import "catalogs.js" as Catalogs

// The shell's and Settings' text, in bloom-language. shell.qml and
// settings-app.qml set `setting` (bloom-language) and `environment` (the
// locale variables); bindings that call t() follow `language` live.
QtObject {
	id: root

	property string setting: "system"
	property var environment: ({})
	readonly property string language: Logic.resolveLanguage(root.setting, root.environment)
	readonly property var locales: Logic.LOCALES

	function t(key, params) { return Logic.translate(Catalogs.catalogs, root.language, key, params); }
	function tCount(key, count, params) {
		return Logic.translate(Catalogs.catalogs, root.language, key, Object.assign({}, params || {}, { count: count }));
	}
}
