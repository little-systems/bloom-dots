#!/usr/bin/env bash
# The launcher through the real shell, with fake tools on PATH: each prefix
# gives its results and Enter does its action. Nothing reaches the real
# clipboard, browser or apps.
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
mkdir -p "$XDG_CONFIG_HOME/bloom/actions" "$TEST_TMP/bin" "$XDG_RUNTIME_DIR"
printf '{"bloom-enabled-modules":["launcher"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
export FAKE="$TEST_TMP/fake"
mkdir -p "$FAKE"
printf '#!/bin/sh\ntouch "%s/action-ran"\n' "$FAKE" > "$XDG_CONFIG_HOME/bloom/actions/backup"
chmod +x "$XDG_CONFIG_HOME/bloom/actions/backup"
cat > "$TEST_TMP/bin/qalc" <<'F'
#!/bin/sh
echo "4"
F
cat > "$TEST_TMP/bin/cliphist" <<'F'
#!/bin/sh
case "$1" in
	list) printf '12\thello there\n11\tother\n' ;;
	decode) cat > "$FAKE/decoded" ;;
esac
F
cat > "$TEST_TMP/bin/wl-copy" <<'F'
#!/bin/sh
cat > /dev/null
echo "$*" >> "$FAKE/copied"
F
cat > "$TEST_TMP/bin/xdg-open" <<'F'
#!/bin/sh
echo "$1" >> "$FAKE/opened"
F
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
start_shell
results() { ipc launcher state | jq -c '[.results[].name]'; }
assert_eq "$(ipc launcher toggle)" "ok" "open"
opened() { ipc launcher state | jq -e .opened >/dev/null; }
wait_for "the launcher open" opened
ipc launcher search '=2+2' >/dev/null
calc_done() { [[ "$(results)" == '["4"]' ]]; }
wait_for "the calculator's answer" calc_done
assert_eq "$(ipc launcher accept 0)" "ok" "copy the answer"
wait_for "the answer copied" grep -q -- "-- 4" "$FAKE/copied"
pass "= calculates and Enter copies the answer, closing the launcher"
assert_eq "$(ipc launcher state | jq .opened)" "false" "closed after acting"
ipc launcher toggle >/dev/null
ipc launcher search ';hello' >/dev/null
clip_done() { [[ "$(results)" == '["hello there"]' ]]; }
wait_for "clipboard history filtered" clip_done
ipc launcher accept 0 >/dev/null
wait_for "the entry decoded" grep -q "^12" "$FAKE/decoded"
pass "; searches the clipboard and Enter restores an entry"
ipc launcher toggle >/dev/null
ipc launcher search '? arch wiki' >/dev/null
ipc launcher accept 0 >/dev/null
wait_for "Google opened" grep -q "google.com/search?q=arch%20wiki" "$FAKE/opened"
pass "? searches the web"
ipc launcher toggle >/dev/null
ipc launcher search '!back' >/dev/null
action_done() { [[ "$(results)" == '["backup"]' ]]; }
wait_for "the user action listed" action_done
ipc launcher accept 0 >/dev/null
wait_for "the action run" test -e "$FAKE/action-ran"
pass "! lists and runs the user's actions"
ipc launcher toggle >/dev/null
ipc launcher search ':grinning' >/dev/null
assert_eq "$(ipc launcher state | jq -r '.results[0].id')" "😀" "emoji by name"
ipc launcher close >/dev/null
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
