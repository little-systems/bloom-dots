#!/usr/bin/env bash
# Owner: the default task manager opens from the dock, Ctrl+Shift+Esc and the
# Command Center, all through TaskManager.open(). Stub apps in a throwaway
# data dir stand in for Mission Center.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
APPS="$TEST_TMP/data/applications"
mkdir -p "$APPS" "$XDG_CONFIG_HOME/bloom"
export XDG_DATA_HOME="$TEST_TMP/data" XDG_DATA_DIRS="$TEST_TMP/data"
stub() {
	printf '[Desktop Entry]\nType=Application\nName=%s\nExec=/bin/sh -c "echo %s >> %s/opened"\nCategories=System;Monitor;\n' "$2" "$1" "$TEST_TMP" > "$APPS/$1.desktop"
}
stub stub-monitor "Stub Monitor"
printf '{"bloom-enabled-modules":[],"bloom-weather-enabled":false,"bloom-task-manager":"stub-monitor"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

opened() { [[ "$(tail -1 "$TEST_TMP/opened" 2>/dev/null)" == "$1" ]]; }
known() { ipc taskmanager state | jq -e --arg id "$1" '.chosen == $id' >/dev/null; }
wait_for "the stub to be found" known stub-monitor
assert_eq "$(ipc taskmanager open)" "ok" "open"
wait_for "the chosen task manager to open" opened stub-monitor
pass "the chosen task manager opens"

ipc settings set bloom-task-manager '"gone.app"' >/dev/null
wait_for "the fallback to be chosen" known stub-monitor
rm -f "$TEST_TMP/opened"
assert_eq "$(ipc taskmanager open)" "ok" "open with a missing choice"
wait_for "an installed task manager to open instead" opened stub-monitor
pass "a missing choice falls back to an installed task manager"

rm "$APPS/stub-monitor.desktop"
wait_for "the stub to be gone" known ""
assert_eq "$(ipc taskmanager open)" "none" "nothing to open"
pass "with no task manager installed it says so"
