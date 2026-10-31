#!/usr/bin/env bash
# Low-power mode follows its setting live, through the real shell.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$XDG_CONFIG_HOME/bloom"
S="$XDG_CONFIG_HOME/bloom/settings.json"
printf '{"bloom-enabled-modules":[],"bloom-weather-enabled":false}\n' > "$S"
start_shell
assert_eq "$(ipc performance state | jq -c .)" '{"mode":"off","lowPower":false}' "off by default"
printf '{"bloom-enabled-modules":[],"bloom-weather-enabled":false,"bloom-low-power":"on"}\n' > "$S"
is_on() { ipc performance state | jq -e .lowPower >/dev/null; }
wait_for "low power to turn on" is_on
pass "forcing it on applies live"
