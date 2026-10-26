#!/usr/bin/env bash
# Media follows the playing MPRIS player and controls it (fake players on a
# private session bus, so the owner's real players never interfere).
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	# A private bus that can't auto-start anything, and no route to the host
	# display or Hyprland, so nothing on it reaches the real session.
	exec env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE BLOOM_IN_DBUS=1 QT_NO_XDG_DESKTOP_PORTAL=1 \
		dbus-run-session --config-file="$(dirname "${BASH_SOURCE[0]}")/dbus-session.conf" -- bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

python3 "$ROOT/tests/integration/fake_mpris.py" idle --title "Idle Song" >"$TEST_TMP/idle.log" 2>&1 &
IDLE_PID=$!
python3 "$ROOT/tests/integration/fake_mpris.py" busy --playing --title "Busy Song" --length-s 200 >"$TEST_TMP/busy.log" 2>&1 &
BUSY_PID=$!
trap 'kill $IDLE_PID $BUSY_PID 2>/dev/null || true; bloom_cleanup' EXIT
wait_for "the fake players" grep -q READY "$TEST_TMP/busy.log"

HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$HARNESS/"
cp "$ROOT/tests/integration/media-harness.qml" "$HARNESS/shell.qml"

timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1 || fail "harness exited with an error"

# Review focus 1: the playing player wins over the paused one.
log_has "RESULT follows=Busy Song playing=true length=200000 canSeek=true" || fail "Media did not follow the playing player"
pass "Media follows the playing player"

grep -q "CALL SetPosition ('/org/bloom/fake/track/1', 42000000)" "$TEST_TMP/busy.log" || fail "seek not sent"
grep -q "CALL Next" "$TEST_TMP/busy.log" || fail "next not sent"
grep -q "CALL Pause" "$TEST_TMP/busy.log" || fail "toggle not sent"
log_has "RESULT after title=Busy Song (Next) playing=false position>=42=" || fail "state after control"
pass "seek, next and play/pause reach the player, and Media follows its state"

if grep -E '^ *(WARN|ERROR)' "$TEST_TMP/shell.log"; then fail "harness logged warnings"; fi
pass "no warnings"
