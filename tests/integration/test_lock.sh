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
python3 - "$TEST_TMP/wall.png" <<'PY'
import struct, sys, zlib
w, h = 64, 64
row = b"\0" + bytes((255, 0, 0)) * w
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * h)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
printf '{"bloom-weather-enabled":false,"bloom-lock-wallpaper":"%s"}\n' "$TEST_TMP/wall.png" > "$XDG_CONFIG_HOME/bloom/settings.json"
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
cat > "$TEST_TMP/bin/hyprctl" <<SH
#!/bin/sh
if [ "\$1" = dispatch ]; then echo "\$2" >> "$TEST_TMP/calls"; else cat "$TEST_TMP/devices.json"; fi
SH
chmod +x "$TEST_TMP/bin/hyprctl"
echo '{"keyboards":[{"capsLock":false,"main":true}]}' > "$TEST_TMP/devices.json"
# The power buttons must not reach the real machine either.
printf '#!/bin/sh\necho "systemctl $*" >> "%s/calls"\n' "$TEST_TMP" > "$TEST_TMP/bin/systemctl"
chmod +x "$TEST_TMP/bin/systemctl"
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
wait_for "the move to an empty workspace" grep -q 'workspace=2147483644' "$TEST_TMP/calls"
pass "locking moves the screen to an empty workspace"

# The surface must paint solidly: a translucent one leaks windows through
# session_lock_xray. A corner shows the wallpaper, dimmed, at full alpha.
wait_for "the backdrop to cover the screen" is .covered true
sleep 0.5
grim -t ppm -o HEADLESS-1 "$TEST_TMP/locked.ppm"
pixel() { python3 - "$TEST_TMP/locked.ppm" "$1" "$2" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
_, w, _, _, data = d.split(maxsplit=4)
i = (int(sys.argv[3]) * int(w) + int(sys.argv[2])) * 3
print(data[i], data[i + 1], data[i + 2])
PY
}
inside="$(pixel 40 40)"
read -r red green blue <<<"$inside"
(( red > 120 && green < 20 && blue < 20 )) || fail "the screen isn't the dimmed wallpaper: $inside"
pass "the backdrop is the wallpaper, blurred and dimmed"
# The screen corners stay rounded while locked (bloom-corners-enabled is on
# by default): the lock surface draws them, since it covers the corner layer.
assert_eq "$(state .corners)" "4" "the lock screen draws four corners"
assert_eq "$(pixel 0 0)" "0 0 0" "the screen's corner pixel is black"
pass "the lock screen keeps the rounded screen corners"

enter wrong
wait_for "the failure" is .message "Incorrect password"
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
wait_for "the blur to leave while still locked" is '.leaving and .locked' true
wait_for "the return to the workspace" grep -q 'workspace=3})' "$TEST_TMP/calls"
pass "unlocking returns to the saved workspace, even after a crash"
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

# The cover can't depend on the wallpaper: a missing one still hides the
# screen, in solid black, and promptly.
printf '{"bloom-weather-enabled":false,"bloom-lock-wallpaper":"%s"}\n' "$TEST_TMP/missing.png" > "$XDG_CONFIG_HOME/bloom/settings.json"
wait_for "the setting to load" is .wallpaper "$TEST_TMP/missing.png"
call lock >/dev/null
WAIT_S=2 wait_for "a missing wallpaper to still cover the screen" is .covered true
sleep 0.5
grim -t ppm -o HEADLESS-1 "$TEST_TMP/black.ppm"
corner="$(python3 - "$TEST_TMP/black.ppm" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
parts = d.split(maxsplit=4)
print(parts[4][0] + parts[4][1] + parts[4][2])
PY
)"
(( corner == 0 )) || fail "a missing wallpaper isn't solid black: $corner"
enter letmein
wait_for "the unlock" is .locked false
pass "a missing wallpaper still covers the screen"

if grep -F "letmein" "$TEST_TMP/shell.log"; then fail "the password reached the log"; fi
pass "the password never reaches the log"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "$ENV_ONLY_WARNINGS|missing.png"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
