#!/usr/bin/env bash
# Dialog process lifecycle and results in a disposable compositor, no host changes.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
    [[ "${CI:-}" == true ]] && { echo 'sway required in CI' >&2; exit 1; }
    echo 'skipped: sway not installed'; exit 0
fi
bloom_env
start_sway
H="$TEST_TMP/harness"
mkdir -p "$H" "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/walls" "$TEST_TMP/custom folder"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$ROOT/shell/assets" "$H/"
cp "$ROOT/tests/integration/picker-dialog-harness.qml" "$H/shell.qml"
cp "$ROOT/shell/assets/bloom.png" "$TEST_TMP/walls/custom # café.png"
printf '{"bloom-weather-enabled":false,"bloom-wallpaper-dir":"%s"}' "$TEST_TMP/walls" > "$XDG_CONFIG_HOME/bloom/settings.json"
export BLOOM_WALLPAPER_PICKER="$TEST_TMP/picker" BLOOM_PICKER_TEST_DIR="$TEST_TMP"
cat > "$BLOOM_WALLPAPER_PICKER" <<'SH'
#!/bin/sh
sleep 0.3
if [ -f "$BLOOM_PICKER_TEST_DIR/cancel" ]; then exit 1; fi
if [ -f "$BLOOM_PICKER_TEST_DIR/unavailable" ]; then exit 127; fi
cat "$BLOOM_PICKER_TEST_DIR/result-$1"
SH
chmod +x "$BLOOM_WALLPAPER_PICKER"
printf '%s\n' "$TEST_TMP/walls/custom # café.png" > "$TEST_TMP/result-file"
printf '%s\n' "$TEST_TMP/custom folder" > "$TEST_TMP/result-folder"
qs --no-color -p "$H" > "$TEST_TMP/shell.log" 2>&1 &
# Used by the cleanup trap in lib.sh.
# shellcheck disable=SC2034
SHELL_PID=$!
call() { qs --no-color ipc -p "$H" call picker "$@"; }
matches() { call state | jq -e "$1" >/dev/null; }
wait_for 'picker ready' call state
call reveal >/dev/null
wait_for 'picker shown' matches '.visible and .opened'
call pickFile >/dev/null
wait_for 'overlay releases dialog input' matches '.dialog and (.visible | not)'
wait_for 'custom file applied and picker closed' matches '(.dialog | not) and (.opened | not) and (.path | endswith("custom # café.png"))'
call reveal >/dev/null
call pickFolder >/dev/null
wait_for 'custom folder returns to library' matches '(.dialog | not) and .visible and (.folder | endswith("custom folder"))'
pass 'custom file and folder selection preserve special filenames and release input'
touch "$TEST_TMP/cancel"
call pickFile >/dev/null
wait_for 'canceled dialog returns unchanged' matches '(.dialog | not) and .visible and .error == "" and (.path | endswith("custom # café.png"))'
rm "$TEST_TMP/cancel"
touch "$TEST_TMP/unavailable"
call pickFile >/dev/null
wait_for 'missing dialog reports recoverable error' matches '(.dialog | not) and .visible and (.error | contains("unavailable"))'
pass 'cancellation and missing dialog preserve wallpaper and restore the picker'
if grep -E 'WARN|ERROR' "$TEST_TMP/shell.log" | grep -vE "$ENV_ONLY_WARNINGS"; then fail 'picker logged unexpected warnings'; fi
