#!/usr/bin/env bash
# Real pointer input (a virtual pointer in headless sway, nothing touches the
# host) over the Bluetooth panel's long list: a mouse wheel and a touchpad
# both scroll it, and neither switches panels (Bloom's handleWheel leaves
# .qp-list alone).
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
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-music-mode-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/busctl" <<'FAKE_BUSCTL'
#!/bin/sh
case "$*" in *GetManagedObjects*)
	python3 -c "
import json
d = {'/org/bluez/hci0': {'org.bluez.Adapter1': {'Powered': {'data': True}}}}
for i in range(14):
	d['/org/bluez/hci0/dev_%d' % i] = {'org.bluez.Device1': {'Name': {'data': 'Device %d' % i}, 'Address': {'data': 'x'}, 'Paired': {'data': True}}}
print(json.dumps({'type': 'a{oa{sa{sv}}}', 'data': [d]}))"
	;;
esac
FAKE_BUSCTL
printf '#!/bin/sh\nsleep 600\n' > "$TEST_TMP/bin/dbus-monitor"
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
start_shell
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state() { ipc notch state | jq -r ".[0].$1"; }
for mode in wheel touch; do
	assert_eq "$(ipc notch openPanel bluetooth)" "ok" "open the panel"
	sleep 0.8
	python3 -I "$HERE/vpointer.py" 1920 1080 960 140 "$mode" 3 &
	vp=$!
	scrolled() { [[ "$(state panel)" == bluetooth ]] && (( $(state panelScroll | cut -d. -f1) > 20 )); }
	wait_for "$mode scrolling the list" scrolled
	wait "$vp"
	pass "$mode scrolls the list and stays on the panel"
	ipc notch closePanel >/dev/null
	sleep 0.6
done
# The Devices panel (a .qp-list too) and the shelf keep a touchpad's scrolls.
for panel in devices shelf; do
	assert_eq "$(ipc notch openPanel "$panel")" "ok" "open $panel"
	sleep 0.8
	python3 -I "$HERE/vpointer.py" 1920 1080 960 120 touch 3 &
	vp=$!
	# Mid-gesture: the client leaving ends the hover that holds the panel.
	sleep 2.8
	assert_eq "$(state panel)" "$panel" "a touchpad scroll stays on $panel"
	wait "$vp"
	ipc notch closePanel >/dev/null
	sleep 0.6
done
pass "the Devices panel and the shelf keep a touchpad scroll"
