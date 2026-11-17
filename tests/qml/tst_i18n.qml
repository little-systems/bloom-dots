import QtQuick
import QtTest
import "../../shell/common/i18n/i18n.js" as Logic
import "../../shell/common/i18n"

// Bloom's i18next behaviour (src/i18n at 63a9bf5): English is complete,
// partial catalogs fall back per message, placeholders must match English.
TestCase {
	name: "I18n"

	readonly property var fixture: ({
		en: { ui: { hello: "Hello", greet: "Hi {{name}}", files_one: "{{count}} file", files_other: "{{count}} files", empty: "Empty" },
			linux: { only: "Linux only" } },
		ru: { ui: { hello: "Привет", greet: "Привет, {{who}}", files_one: "{{count}} файл", files_few: "{{count}} файла",
			files_many: "{{count}} файлов", files_other: "{{count}} файла", empty: "" } },
		fr: { ui: {} }
	})

	function test_resolveLanguage() {
		compare(Logic.resolveLanguage("system", { LANG: "ru_RU.UTF-8" }), "ru");
		compare(Logic.resolveLanguage("system", { LC_ALL: "pt_BR.UTF-8", LANG: "en_US.UTF-8" }), "pt-BR");
		compare(Logic.resolveLanguage("system", { LC_MESSAGES: "fr_FR.UTF-8", LANG: "en_US.UTF-8" }), "fr");
		compare(Logic.resolveLanguage("system", { LANG: "pt" }), "pt-PT");
		compare(Logic.resolveLanguage("system", { LANG: "de_DE.UTF-8" }), "en");
		compare(Logic.resolveLanguage("system", {}), "en");
		compare(Logic.resolveLanguage("fr", {}), "fr");
		compare(Logic.resolveLanguage("klingon", {}), "en");
	}

	function test_pluralCategories() {
		const ru = n => Logic.pluralCategory("ru", n);
		compare([1, 2, 5, 21, 22, 11, 12, 14, 25, 111].map(ru), ["one", "few", "many", "one", "few", "many", "many", "many", "many", "many"]);
		compare(ru(1.5), "other");
		compare([0, 1, 2].map(n => Logic.pluralCategory("fr", n)), ["one", "one", "other"]);
		compare([0, 1, 2].map(n => Logic.pluralCategory("pt-BR", n)), ["one", "one", "other"]);
		compare([0, 1, 2].map(n => Logic.pluralCategory("pt-PT", n)), ["other", "one", "other"]);
		compare([0, 1, 2].map(n => Logic.pluralCategory("en", n)), ["other", "one", "other"]);
		compare([0, 1, 2].map(n => Logic.pluralCategory("es", n)), ["other", "one", "other"]);
	}

	function test_translate() {
		const t = (lang, key, params) => Logic.translate(fixture, lang, key, params);
		compare(t("ru", "ui.hello"), "Привет");
		compare(t("fr", "ui.hello"), "Hello", "missing in fr: English");
		compare(t("ru", "ui.empty"), "Empty", "an empty translation counts as missing");
		compare(t("ru", "ui.greet", { name: "Dhanush" }), "Hi Dhanush", "wrong placeholders: English");
		compare(t("en", "ui.greet", {}), "Hi {{name}}", "an unknown placeholder stays as written");
		compare(t("ru", "linux.only"), "Linux only", "Linux overlay, English fallback");
		compare(t("ru", "ui.nope"), "ui.nope", "an unknown key is returned as is");
	}

	function test_plurals() {
		const c = (lang, n) => Logic.translate(fixture, lang, "ui.files", { count: n });
		compare(c("en", 1), "1 file");
		compare(c("en", 3), "3 files");
		compare(c("ru", 1), "1 файл");
		compare(c("ru", 3), "3 файла");
		compare(c("ru", 5), "5 файлов");
		compare(c("fr", 0), "0 files", "no French forms: English, by English's rule");
	}

	function test_singleton() {
		I18n.environment = { LANG: "ru_RU.UTF-8" };
		I18n.setting = "system";
		compare(I18n.language, "ru");
		I18n.setting = "en";
		compare(I18n.language, "en");
		compare(I18n.t("unknown.key"), "unknown.key");
		verify(I18n.t("ui.onboarding.welcomeToBloom").length > 0);
		I18n.setting = "ru";
		verify(I18n.t("ui.onboarding.welcomeToBloom") !== "ui.onboarding.welcomeToBloom");
		compare(I18n.tCount("nothing.here", 2), "nothing.here");
		I18n.setting = "system";
	}
}
