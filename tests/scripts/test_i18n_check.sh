#!/usr/bin/env bash
# tools/check-i18n.mjs: used keys exist in English, translations keep English's
# placeholders, plural sets are complete, and coverage is reported.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fixture() {
	rm -rf "$T/r"; mkdir -p "$T/r/shell/i18n/locales" "$T/r/shell/i18n/linux" "$T/r/shell/x"
	printf '%s' '{"ui":{"hi":"Hi {{name}}","n_one":"{{count}} item","n_other":"{{count}} items"}}' > "$T/r/shell/i18n/locales/en.json"
	printf '%s' "$1" > "$T/r/shell/i18n/locales/ru.json"
	printf '%s' '{"linux":{"only":"Linux"}}' > "$T/r/shell/i18n/linux/en.json"
	printf '%s\n' "Text { text: I18n.t(\"ui.hi\", { name: n }) }" "Text { text: I18n.tCount(\"ui.n\", 2) }" "Text { text: I18n.t(\"linux.only\") }" "$2" > "$T/r/shell/x/A.qml"
}
check() { node "$ROOT/tools/check-i18n.mjs" --check --root "$T/r"; }

fixture '{"ui":{"hi":"Привет, {{name}}","n_one":"{{count}} штука","n_few":"{{count}} штуки","n_many":"{{count}} штук","n_other":"{{count}} штуки"}}' ''
out="$(check)" || fail "a valid fixture fails"
grep -q 'ru: 2/3' <<<"$out" || fail "coverage not reported: $out"
echo "ok - a complete catalog passes with coverage"

fixture '{"ui":{}}' 'Text { text: I18n.t("ui.missing") }'
check >/dev/null 2>&1 && fail "a used key missing in English passes"
echo "ok - a used key missing in English fails"

fixture '{"ui":{"hi":"Привет, {{who}}"}}' ''
check >/dev/null 2>&1 && fail "a translation with other placeholders passes"
echo "ok - placeholders must match English's"

fixture '{"ui":{"n_one":"{{count}} штука","n_other":"{{count}} штуки"}}' ''
check >/dev/null 2>&1 && fail "an incomplete Russian plural set passes"
echo "ok - plural sets are complete per language"

fixture '{"ui":{}}' ''
out="$(check)" || fail "a partial catalog fails"
grep -q 'ru: 0/3' <<<"$out" || fail "partial coverage not reported"
echo "ok - partial catalogs are fine (English fallback)"

node "$ROOT/tools/check-i18n.mjs" --check >/dev/null || fail "the shipped catalogs fail"
echo "ok - the shipped catalogs pass"
