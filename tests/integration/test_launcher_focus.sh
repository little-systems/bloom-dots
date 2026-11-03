#!/usr/bin/env bash
# Opening and closing the launcher must not activate text input on another
# Wayland surface. Run on a disposable compositor, never the live session.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
command -v sway >/dev/null || { echo 'skipped: sway missing'; exit 0; }
bloom_env
export QT_QPA_PLATFORMTHEME=generic
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["launcher"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
for _ in {1..12}; do
	ipc launcher toggle >/dev/null
	sleep 0.08
	ipc launcher close >/dev/null
	sleep 0.08
done
sleep 0.5
if grep -E 'enableSurface.*has focus|WARN|ERROR' "$TEST_TMP/shell.log" | grep -v pipewire; then
	fail 'launcher focus changed on an unfocused Wayland surface'
fi
pass 'rapid launcher opening and closing has no focus warnings'
