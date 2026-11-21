#!/usr/bin/env bash
# A card's shadow stays outside it, like CSS box-shadow: a see-through card
# over a light window reads the same at its top and its bottom, with no dark
# band where the shadow would show through.
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
printf '{"bloom-enabled-modules":["cheatsheet"],"bloom-weather-enabled":false,"bloom-theme-opacity":"0.6","bloom-scale":1}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/hyprctl" <<'SH'
#!/bin/sh
echo '[{"modmask":64,"key":"L","description":"Session: Lock"},{"modmask":64,"key":"Q","description":"Window: Close"}]'
SH
chmod +x "$TEST_TMP/bin/hyprctl"
export PATH="$TEST_TMP/bin:$PATH"
"${QT_BIN:-/usr/lib/qt6/bin}/qml" "$ROOT/tests/integration/backdrop.qml" >"$TEST_TMP/backdrop.log" 2>&1 &
pixel() {
	grim -t ppm -g "$1 1x1" - | python3 -c "import sys; d = sys.stdin.buffer.read(); print(d[-3])"
}
light() { (( $(pixel "1800,1000") > 200 )); }
wait_for "the light backdrop" light
start_shell
assert_eq "$(ipc cheatsheet toggle)" "ok" "open"
has_groups() { ipc cheatsheet state | jq -e '.opened and .groups == 2' >/dev/null; }
wait_for "the binds to load" has_groups
sleep 1
# Two binds make a short card centred at 540: sample its right side, clear of
# text, just inside its top and bottom edges.
top="$(pixel "1400,500")"
bottom="$(pixel "1400,578")"
(( top - bottom <= 3 && bottom - top <= 3 )) || fail "card reads $top at its top but $bottom at its bottom"
pass "the shadow doesn't show through the card"
below="$(pixel "1400,600")"
(( below < 230 )) || fail "no shadow below the card ($below)"
pass "the shadow still falls below it"
