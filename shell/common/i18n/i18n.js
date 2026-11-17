.pragma library

// Bloom's i18next behaviour (src/i18n at 63a9bf5) for QML, which has no
// i18next or Intl.PluralRules: English is complete; a translation counts only
// when it is nonempty with English's placeholders; anything else falls back to
// English per message; an unknown key is returned as is.

var LOCALES = [
	{ code: "en", nativeName: "English" },
	{ code: "ru", nativeName: "Русский" },
	{ code: "fr", nativeName: "Français" },
	{ code: "es", nativeName: "Español" },
	{ code: "pt-BR", nativeName: "Português (Brasil)" },
	{ code: "pt-PT", nativeName: "Português (Portugal)" }
];

function matchLocale(language) {
	var normalized = String(language).trim().replace(/\..*$/, "").replace(/@.*$/, "").replace(/_/g, "-").toLowerCase();
	if (!normalized)
		return undefined;
	var exact = LOCALES.filter(function (l) { return l.code.toLowerCase() === normalized; })[0];
	if (exact)
		return exact.code;
	var base = normalized.split("-")[0];
	// A bare "pt" (no region) is European Portuguese, as the spec says.
	if (base === "pt")
		return "pt-PT";
	var loose = LOCALES.filter(function (l) { return l.code.toLowerCase() === base; })[0];
	return loose ? loose.code : undefined;
}

// "system" follows LC_ALL, LC_MESSAGES, then LANG, as gettext does.
function resolveLanguage(setting, env) {
	if (setting && setting !== "system")
		return matchLocale(setting) || "en";
	env = env || {};
	var names = ["LC_ALL", "LC_MESSAGES", "LANG"];
	for (var i = 0; i < names.length; i++) {
		var value = env[names[i]];
		if (value && value !== "C" && value !== "POSIX")
			return matchLocale(value) || "en";
	}
	return "en";
}

// CLDR cardinal rules for Bloom's six languages (i integer digits, v fraction digits).
function pluralCategory(lang, n) {
	var value = Math.abs(Number(n));
	var integer = Math.floor(value);
	var fraction = value !== integer;
	switch (lang) {
	case "ru": {
		if (fraction)
			return "other";
		var mod10 = integer % 10, mod100 = integer % 100;
		if (mod10 === 1 && mod100 !== 11)
			return "one";
		if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
			return "few";
		return "many";
	}
	case "fr":
	case "pt-BR":
		return integer <= 1 ? "one" : "other";
	default:
		// en, es, pt-PT: one is exactly 1.
		return value === 1 && !fraction ? "one" : "other";
	}
}

function placeholders(message) {
	var found = {};
	var pattern = /\{\{\s*(\w+)\s*\}\}/g;
	var match;
	while ((match = pattern.exec(message)) !== null)
		found[match[1]] = true;
	return Object.keys(found).sort().join(",");
}

function entry(catalog, key) {
	var parts = key.split(".");
	var node = catalog;
	for (var i = 0; i < parts.length; i++) {
		if (node === null || typeof node !== "object" || !Object.prototype.hasOwnProperty.call(node, parts[i]))
			return undefined;
		node = node[parts[i]];
	}
	return typeof node === "string" ? node : undefined;
}

// A message in `lang` that is valid against English's, or undefined.
function lookup(catalogs, lang, key) {
	var english = entry(catalogs.en || {}, key);
	if (lang === "en")
		return english;
	var value = entry(catalogs[lang] || {}, key);
	if (typeof value !== "string" || value.trim() === "")
		return undefined;
	var reference = english !== undefined ? english : entry(catalogs.en || {}, key.replace(/_(zero|one|two|few|many)$/, "_other"));
	if (reference === undefined || placeholders(value) !== placeholders(reference))
		return undefined;
	return value;
}

function format(message, params) {
	params = params || {};
	return message.replace(/\{\{\s*(\w+)\s*\}\}/g, function (whole, name) {
		return Object.prototype.hasOwnProperty.call(params, name) && params[name] !== undefined && params[name] !== null
			? String(params[name]) : whole;
	});
}

function pluralMessage(catalogs, lang, key, count) {
	var category = pluralCategory(lang, count);
	var message = lookup(catalogs, lang, key + "_" + category);
	if (message === undefined && category !== "other")
		message = lookup(catalogs, lang, key + "_other");
	return message;
}

function translate(catalogs, lang, key, params) {
	var hasCount = params && typeof params.count === "number";
	var message;
	if (hasCount) {
		message = pluralMessage(catalogs, lang, key, params.count);
		if (message === undefined && lang !== "en")
			message = pluralMessage(catalogs, "en", key, params.count);
	}
	if (message === undefined)
		message = lookup(catalogs, lang, key);
	if (message === undefined && lang !== "en")
		message = lookup(catalogs, "en", key);
	return message === undefined ? key : format(message, params);
}
