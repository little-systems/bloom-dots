#!/usr/bin/env bash
# Actual About metadata and file-dialog round trip; isolated XDG/compositor.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null || ! command -v wtype >/dev/null; then
    [[ "${CI:-}" == true ]] && { echo 'sway and wtype required in CI' >&2; exit 1; }
    echo 'skipped: compositor input tools unavailable'; exit 0
fi
bloom_env
start_sway
export HOME="$TEST_TMP/home"
mkdir -p "$XDG_CONFIG_HOME/bloom" "$HOME" "$TEST_TMP/exports"
printf '{"bloom-weather-enabled":false,"bloom-theme-mode":"dark"}' > "$XDG_CONFIG_HOME/bloom/settings.json"
cp -r "$ROOT/shell" "$TEST_TMP/harness"
cp "$ROOT/VERSION" "$TEST_TMP/VERSION"
APP="$TEST_TMP/harness/settings-app.qml"
# Reach native dialogs via the same handlers as the two About row signals.
# The public SettingsView test exercises the rows themselves.
python3 - "$APP" <<'PY'
import sys
p=sys.argv[1]
hook = """function probeExport(): string { app.openExport(); return "ok"; }
		function probeImport(): string { importDialog.open(); return "ok"; }
		function state(): string {"""
s=open(p).read().replace('function state(): string {', hook)
open(p,'w').write(s)
PY
BLOOM_SETTINGS_TAB=about qs --no-color -p "$APP" > "$TEST_TMP/shell.log" 2>&1 &
# Used by lib.sh cleanup.
# shellcheck disable=SC2034
SHELL_PID=$!
call() { qs --no-color ipc -p "$APP" call settingsapp "$@"; }
matches() { call state | jq -e "$1" >/dev/null; }
wait_for 'About system metadata' matches '.distribution.name != "" and .architecture != "" and .kernel != ""'
logo_known() { call state | jq -e 'if .distribution.logo != "" then .distroLogo != "" else true end' >/dev/null; }
wait_for 'installed distribution branding' logo_known
pass 'About reports detected distribution, original system logo, architecture and kernel'
if [[ -n "${BLOOM_ABOUT_SCREENSHOT:-}" ]]; then
    sleep 0.7
    grim -o HEADLESS-1 "$BLOOM_ABOUT_SCREENSHOT"
fi
# Dialogs open in the home folder; a bare name avoids racing the widget
# dialog's path completer while typing.
# coreutils only: CI's container has no cmp (diffutils).
same_file() { [[ -f "$1" && "$(sha256sum < "$1")" == "$(sha256sum < "$2")" ]]; }
NAME="export # café.json"
OUT="$HOME/$NAME"
dialog_focused() { local now; now="$(sway_focus)"; [[ -n "$now" && "$now" != "$before" ]]; }
# Every dialog, native or Qt's own, opens with the suggested name in a focused
# field: Enter alone saves it.
before="$(sway_focus || true)"
call probeExport >/dev/null
wait_for 'the export dialog takes keyboard focus' dialog_focused
# Keyboard focus reaches a new window shortly after the compositor reports it.
sleep 1
# End only moves the cursor; a lone first key to a new window can be dropped.
wtype -s 300 -k End -k Return
wait_for 'export to the suggested name completes' matches '.exportStatus == "Settings Exported"'
same_file "$HOME/bloom-settings.json" "$XDG_CONFIG_HOME/bloom/settings.json" || { find / -xdev -name bloom-settings.json -newer "$APP" 2>/dev/null >&2; fail "the suggested export name was not used"; }
pass 'Export opens with the suggested file name focused, so Enter saves it'
before="$(sway_focus || true)"
call probeExport >/dev/null
wait_for 'the export dialog takes keyboard focus' dialog_focused
# Keyboard focus reaches a new window shortly after the compositor reports it.
sleep 1
wtype -s 400 -M ctrl -k a -m ctrl "$NAME" -k Return
# The label already reads Exported; the file appears whole when the copy commits.
wait_for 'export to the typed path completes' test -s "$OUT"
wait_for 'export completes' matches '.exportStatus == "Settings Exported"'
same_file "$OUT" "$XDG_CONFIG_HOME/bloom/settings.json" || { find "$TEST_TMP" -name "*.json" -newer "$APP" -not -path "*/config/*" >&2; fail "export contents differ"; }
[[ "$(stat -c %a "$OUT")" == 600 ]] || fail 'export is not private'
pass 'Export Settings opens a real dialog and writes an acknowledged private copy'
printf '{"bloom-weather-enabled":false,"bloom-theme-mode":"light"}' > "$XDG_CONFIG_HOME/bloom/settings.json"
sleep 0.4
before="$(sway_focus || true)"
call probeImport >/dev/null
wait_for 'the import dialog takes keyboard focus' dialog_focused
# Keyboard focus reaches a new window shortly after the compositor reports it.
sleep 1
wtype -s 400 -M ctrl -k a -m ctrl "$NAME" -k Return
wait_for 'import completes' matches '.importStatus == "Settings Imported"'
jq -e '."bloom-theme-mode" == "dark"' "$XDG_CONFIG_HOME/bloom/settings.json" >/dev/null || fail 'import did not restore the exported value'
pass 'Import Settings opens a real dialog and commits the selected data'
if grep -E 'WARN|ERROR' "$TEST_TMP/shell.log" | grep -vE "$ENV_ONLY_WARNINGS"; then fail 'About logged unexpected warnings'; fi
