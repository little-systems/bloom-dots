#!/usr/bin/env bash
# A machine without a backlight never exposes an interactive brightness rail.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cat >"$TEST_TMP/bin/brightnessctl" <<'SH'
#!/bin/sh
exit 1
SH
cat >"$TEST_TMP/bin/udevadm" <<'SH'
#!/bin/sh
sleep 10
SH
chmod +x "$TEST_TMP/bin/brightnessctl" "$TEST_TMP/bin/udevadm"
export PATH="$TEST_TMP/bin:$PATH"
start_sway
printf '{"bloom-enabled-modules":["osd"]}' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
osd_ready() { [[ "$(ipc osd state | jq length)" == 2 ]]; }
wait_for 'OSD windows' osd_ready
assert_eq "$(ipc osd showBrightness)" 'backlight unavailable' 'unavailable brightness'
[[ "$(ipc osd state | jq -r '.[] | select(.edge=="right") | .shown')" == false ]] || fail 'brightness rail appeared without hardware'
assert_eq "$(ipc osd showVolume)" 'ok' 'volume still available'
pass 'missing backlight hides brightness interaction without affecting volume'
