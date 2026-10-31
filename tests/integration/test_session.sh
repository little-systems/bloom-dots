#!/usr/bin/env bash
# The session menu through the real shell with fake systemctl and loginctl on
# PATH: nothing here can suspend, reboot or log out the real session.
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
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin" "$TEST_TMP/Downloads"
printf '{"bloom-enabled-modules":["session"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
export FAKE="$TEST_TMP/fake" BLOOM_PACMAN_LOCK="$TEST_TMP/db.lck" BLOOM_DOWNLOADS="$TEST_TMP/Downloads"
mkdir -p "$FAKE"
for tool in systemctl loginctl; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n' "$tool" "$FAKE" > "$TEST_TMP/bin/$tool"
done
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
start_shell
touch "$BLOOM_PACMAN_LOCK" "$TEST_TMP/Downloads/film.iso.part"
assert_eq "$(ipc session toggle)" "ok" "open"
seen() { ipc session state | jq -e '.opened and .busy.pacman and .busy.downloads == 1' >/dev/null; }
wait_for "pacman and the download noticed" seen
pass "opening checks what's running"
for pair in "suspend:systemctl suspend" "shutdown:systemctl poweroff" "firmware:systemctl reboot --firmware-setup" "lock:loginctl lock-session"; do
	assert_eq "$(ipc session run "${pair%%:*}")" "ok" "run ${pair%%:*}"
	wait_for "${pair#*:}" grep -qx "${pair#*:}" "$FAKE/calls"
done
assert_eq "$(ipc session state | jq .opened)" "false" "acting closes the menu"
pass "each action runs its command"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
