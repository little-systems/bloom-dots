#!/usr/bin/env bash
# The overview through the real shell, with a fake hyprctl on PATH: opening,
# and the move dispatch. Nothing reaches the owner's real windows.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":["overview"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
export FAKE="$TEST_TMP/fake"
mkdir -p "$FAKE"
cat > "$TEST_TMP/bin/hyprctl" <<'F'
#!/bin/sh
echo "$*" >> "$FAKE/hyprctl.log"
[ "$1" = "-j" ] && echo "[]"
exit 0
F
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
start_shell
assert_eq "$(ipc overview toggle)" "ok" "open"
assert_eq "$(ipc overview state | jq .opened)" "true" "opened"
assert_eq "$(ipc overview move 0x55ab 4)" "ok" "move a window"
wait_for "the move dispatched" grep -q 'dispatch hl.dsp.window.move({ workspace = 4, follow = false, window = "address:0x55ab" })' "$FAKE/hyprctl.log"
pass "a drag's move dispatches without following the window"
assert_eq "$(ipc overview move 'x; bad' 4)" "invalid" "a bad address is refused"
assert_eq "$(ipc overview close)" "ok" "close"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
