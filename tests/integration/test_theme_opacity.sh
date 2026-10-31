#!/usr/bin/env bash
# The opacity setting reaches the real notch, its panels, the OSD and Spotlight,
# live. On a black
# output a white surface reads as its own alpha.
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
mkdir -p "$XDG_CONFIG_HOME/bloom"
S="$XDG_CONFIG_HOME/bloom/settings.json"
write() { printf '{"bloom-enabled-modules":["notch","osd","launcher"],"bloom-weather-enabled":false,"bloom-theme-mode":"light","bloom-theme-opacity":%s,"bloom-scale":1}\n' "$1" > "$S"; }
write 0.3
start_shell
pixel() {
	grim -t ppm -g "$1 1x1" - | python3 -c "import sys; d = sys.stdin.buffer.read(); print(d[-3])"
}
# The collapsed pill, left of its centred clock.
near() { local v; v="$(pixel "$1")"; (( v > $2 - 15 && v < $2 + 15 )); }
wait_for "the notch at 30%" near "900,10" 76
pass "the notch starts at the set opacity"
write 0.8
wait_for "the notch at 80%" near "900,10" 204
pass "changing it applies live"

# The left HUD, at its edge beside the bar. The right HUD shares OsdCard but
# needs a backlight, which the test compositor lacks.
hud() { ipc osd showVolume >/dev/null; near "4,540" "$1"; }
wait_for "the volume HUD at 80%" hud 204
pass "the volume HUD starts at the set opacity"
write 0.3
wait_for "the volume HUD at 30%" hud 76
pass "the volume HUD follows it live"

# Expanded surfaces use the same opacity, not a solider one. They're white over
# black here, so a pixel reads as alpha: 0.8 reads about 204 (light's expanded
# surface is a touch off white, hence the wider window below).
write 0.5
assert_eq "$(ipc notch openPanel command-center)" "ok" "open a panel"
wide() { local v; v="$(pixel "$1")"; (( v > 100 && v < 145 )); }
wait_for "the open panel at 50%" wide "850,30"
pass "notch panels follow the opacity"
ipc notch closePanel >/dev/null
assert_eq "$(ipc launcher toggle)" "ok" "open Spotlight"
wait_for "Spotlight at 50%" wide "700,245"
ipc launcher close >/dev/null
pass "Spotlight follows the opacity"
