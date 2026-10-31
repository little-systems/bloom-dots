#!/usr/bin/env bash
# The cheatsheet through the real shell, with a fake hyprctl: it reads binds
# from a fixture, never the real session.
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
printf '{"bloom-enabled-modules":["cheatsheet"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/hyprctl" <<'SH'
#!/bin/sh
echo '[{"modmask":64,"key":"L","description":"Session: Lock"},{"modmask":64,"key":"Q","description":"Window: Close"},{"modmask":64,"key":"Y","description":""}]'
SH
chmod +x "$TEST_TMP/bin/hyprctl"
export PATH="$TEST_TMP/bin:$PATH"
start_shell
assert_eq "$(ipc cheatsheet toggle)" "ok" "open"
has_groups() { ipc cheatsheet state | jq -e '.opened and .groups == 2 and .binds == 2' >/dev/null; }
wait_for "the binds to load" has_groups
pass "opening reads the live binds"
assert_eq "$(ipc cheatsheet close)" "ok" "close"
assert_eq "$(ipc cheatsheet state | jq .opened)" "false" "closed"
pass "it closes"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
