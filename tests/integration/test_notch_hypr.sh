#!/usr/bin/env bash
# A stale HYPRLAND_INSTANCE_SIGNATURE (Hyprland restarted, or the shell runs
# elsewhere) must not flood the log: hyprctl fails, smart mode treats that as
# "not overlapped", and the shell warns once and backs off.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
start_sway
export HYPRLAND_INSTANCE_SIGNATURE="bloom-test-stale-signature"

mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false, "bloom-notch-mode": "smart" }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state_is() { [[ "$(ipc notch state | jq -c '.[0] | {hidden, overlapped}')" == "$1" ]]; }
wait_for "smart mode to settle" state_is '{"hidden":false,"overlapped":false}'
sleep 4
warnings="$(grep -cE '^ *WARN.*bloom hypr' "$TEST_TMP/shell.log" || true)"
(( warnings <= 1 )) || fail "expected at most one hypr warning, got $warnings"
# Quickshell itself notes the missing socket once; nothing may repeat.
repeated="$(grep -E '^ *(WARN|ERROR)' "$TEST_TMP/shell.log" | sort | uniq -d || true)"
[[ -z "$repeated" ]] || fail "repeated log lines: $repeated"
pass "a stale Hyprland signature warns at most once and smart mode stays usable"
