#!/usr/bin/env bash
# The lock on a real session-lock protocol in headless sway, real keystrokes
# through wtype, and a fixture PAM stack that knows only a fake password.
# Neither the real PAM services nor the real session are involved.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null || ! command -v wtype >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway and wtype are required in CI" >&2; exit 1; }
	echo "skipped: sway or wtype is not installed"
	exit 0
fi
bloom_env
start_sway
H="$TEST_TMP/harness"
mkdir -p "$H" "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/pam" "$TEST_TMP/bin"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$ROOT/shell/assets" "$H/"
cp "$ROOT/tests/integration/lock-harness.qml" "$H/shell.qml"
printf '{"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
export BLOOM_TEST_PAM="$TEST_TMP/pam"
# Shaped like Arch's stack: a wrong password ends in PAM_AUTH_ERR, not the
# system error pam_exec itself returns.
good_stack() {
	printf 'auth [success=1 default=ignore] pam_exec.so quiet expose_authtok %s\nauth requisite pam_deny.so\nauth required pam_permit.so\naccount required pam_permit.so\n' "$TEST_TMP/pam/check" > "$TEST_TMP/pam/bloom-test"
}
good_stack
cat > "$TEST_TMP/pam/check" <<'SH'
#!/bin/sh
read -r pw
[ "$pw" = "letmein" ]
SH
chmod +x "$TEST_TMP/pam/check"
# The Caps Lock poll must not reach the real compositor.
printf '#!/bin/sh\ncat "%s/devices.json"\n' "$TEST_TMP" > "$TEST_TMP/bin/hyprctl"
chmod +x "$TEST_TMP/bin/hyprctl"
echo '{"keyboards":[{"capsLock":false,"main":true}]}' > "$TEST_TMP/devices.json"
export PATH="$TEST_TMP/bin:$PATH"

launch() {
	qs --no-color -p "$H" >>"$TEST_TMP/shell.log" 2>&1 &
	SHELL_PID=$!
	wait_for "the harness to answer" call state
}
call() { qs --no-color ipc -p "$H" call lock "$@"; }
state() { call state | jq -r "$1"; }
is() { [[ "$(state "$1")" == "$2" ]]; }

# One wtype run: each run is a new virtual keyboard, whose first keys can land
# before its keymap does.
enter() { wtype -s 400 -d 30 "$1" -k Return; }

launch
assert_eq "$(state .locked)" "false" "starts unlocked"
call lock >/dev/null
wait_for "the compositor to confirm the lock" is .secure true
pass "locks through the session-lock protocol"

# The surface must paint: a transparent one would leak windows through xray.
sleep 0.5
grim -o HEADLESS-1 "$TEST_TMP/locked.png"
[[ -s "$TEST_TMP/locked.png" ]] || fail "no frame from the locked output"
pass "the locked output renders"

enter wrong
wait_for "the failure" is .message "That password didn't work"
assert_eq "$(state .locked)" "true" "a wrong password stays locked"
pass "a wrong password keeps it locked and says so"

# A broken PAM stack must not unlock, and isn't the owner's typing.
printf 'auth required pam_exec.so quiet %s/pam/missing\n' "$TEST_TMP" > "$TEST_TMP/pam/bloom-test"
enter letmein
wait_for "the PAM error" is .message "Couldn't check the password"
assert_eq "$(state .locked)" "true" "a PAM error stays locked"
good_stack
pass "a PAM error keeps it locked and says so"

echo '{"keyboards":[{"capsLock":true,"main":true}]}' > "$TEST_TMP/devices.json"
wait_for "the Caps Lock warning" is .capsLock true
echo '{"keyboards":[{"capsLock":false,"main":true}]}' > "$TEST_TMP/devices.json"
pass "Caps Lock is noticed"

# A crash leaves the compositor locked; the restarted shell takes it back.
kill -9 "$SHELL_PID"
wait "$SHELL_PID" 2>/dev/null || true
SHELL_PID=""
sleep 0.3
launch
wait_for "the lock to come back after a crash" is .secure true
pass "a crash doesn't unlock, and a restart relocks"

enter letmein
wait_for "the unlock" is .locked false
assert_eq "$(state .message)" "" "no message left behind"
pass "the right password unlocks"

# Unlocked cleanly, so a restart must not lock again.
kill "$SHELL_PID"
wait "$SHELL_PID" 2>/dev/null || true
SHELL_PID=""
launch
sleep 0.5
assert_eq "$(state .locked)" "false" "no marker after a clean unlock"
pass "a clean unlock leaves no marker"

if grep -F "letmein" "$TEST_TMP/shell.log"; then fail "the password reached the log"; fi
pass "the password never reaches the log"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire|wl_keyboard.leave"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
