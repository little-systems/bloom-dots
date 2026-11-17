# Translating Bloom for Linux

Bloom for Linux shares Bloom's language catalogs, so a translation made for
Bloom shows up here too, and the reverse.

- **Shared text** (most of Bloom: the Island, the Dock, Settings) lives in
  Bloom's catalogs. Contribute it to Bloom, following Bloom's
  [TRANSLATING.md](https://github.com/little-systems/bloom/blob/main/TRANSLATING.md).
  bloom-dots copies Bloom's catalogs with `node tools/sync-bloom-i18n.mjs
  <bloom checkout>` (the copied commit is in `shell/i18n/SOURCE`), then
  `node tools/gen-i18n.mjs`.
- **Linux-only text** lives here, in `shell/i18n/linux/<language>.json`, under
  the top-level `linux` key. `en.json` is complete; add your language's file
  with the messages you translate.

Languages: English, Русский, Français, Español, Português (Brasil) and
Português (Portugal). Choose one in Settings → General → Language (`System
default` follows `LC_ALL`, `LC_MESSAGES`, then `LANG`).

Rules (the same as Bloom's, checked by `node tools/check-i18n.mjs --check`):

- Catalogs are i18next JSON v4: nested keys, `{{name}}` placeholders, plurals as
  `key_one`, `key_other` (Russian: `_one`, `_few`, `_many`, `_other`).
- Keep exactly English's placeholders, and translate whole messages.
- Leave out what you haven't translated: anything missing or invalid uses
  English, message by message. Never copy English into another catalog.

In QML, text is `I18n.t("key", { name })` or `I18n.tCount("key", count)`; then
run `node tools/gen-i18n.mjs` and `node tools/check-i18n.mjs --check`.
