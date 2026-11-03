#!/usr/bin/env bash
# The real secure lock surface, private compositor and fixture media/PAM only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
    [[ "${CI:-}" == true ]] && { echo 'sway required in CI' >&2; exit 1; }
    echo 'skipped: sway is not installed'
    exit 0
fi
bloom_env
start_sway
H="$TEST_TMP/harness"
mkdir -p "$H" "$TEST_TMP/pam" "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$ROOT/shell/assets" "$H/"
cp "$ROOT/tests/integration/lock-media-harness.qml" "$H/shell.qml"
printf 'auth required pam_deny.so\n' > "$TEST_TMP/pam/bloom-test"
printf '{"bloom-weather-enabled":false,"bloom-lock-media-enabled":true}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
printf '#!/bin/sh\necho "{\"keyboards\":[]}"\n' > "$TEST_TMP/bin/hyprctl"
chmod +x "$TEST_TMP/bin/hyprctl"
export BLOOM_TEST_PAM="$TEST_TMP/pam" PATH="$TEST_TMP/bin:$PATH"
qs --no-color -p "$H" > "$TEST_TMP/shell.log" 2>&1 &
SHELL_PID=$!
call() { qs --no-color ipc -p "$H" call lockmedia "$@"; }
matches() { call state | jq -e "$1" >/dev/null; }
wait_for 'fixture ready' matches '.locked == false'
call transport next >/dev/null
wait_for 'transport ignored outside the lock' matches '.skips == 0'
call lock >/dev/null
wait_for 'secure surface with media' matches '.secure and .locked and .available'
call transport next >/dev/null
call transport toggle >/dev/null
wait_for 'media controls leave the session locked' matches '.secure and .locked and (.playing | not) and .skips == 1'
pass 'transport works only inside the secure locked session'
call transport toggle >/dev/null
if [[ -n "${BLOOM_LOCK_MEDIA_SCREENSHOT:-}" ]]; then
    sleep 0.7
    grim -o HEADLESS-1 "$BLOOM_LOCK_MEDIA_SCREENSHOT"
fi
call enabled false >/dev/null
wait_for 'privacy switch hides lock media' matches '(.available | not) and .secure'
call transport next >/dev/null
wait_for 'disabled transport refuses actions' matches '.skips == 1'
pass 'privacy switch removes media and blocks its transport'
if grep -E 'WARN|ERROR' "$TEST_TMP/shell.log" | grep -vE 'textinput|pipewire|wl_keyboard.leave'; then fail 'lock media logged an unexpected warning'; fi
