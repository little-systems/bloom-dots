#!/usr/bin/env bash
# Drive the real notch with fake, event-driven USB and headphone jack sources.
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
cat > "$TEST_TMP/bin/udevadm" <<'FAKE_UDEV'
#!/bin/sh
sleep 1
printf 'UDEV add\nACTION=add\nDEVTYPE=usb_device\nID_MODEL=Test_USB_Drive\n\n'
sleep 10
FAKE_UDEV
cat > "$TEST_TMP/bin/pactl" <<'FAKE_PACTL'
#!/bin/sh
case "$1" in
	subscribe)
		while [ ! -e "$BLOOM_USB_OBSERVED" ]; do sleep 0.1; done
		sleep 1
		touch "$BLOOM_FAKE_JACK"
		printf "Event 'change' on sink #53\n"
		sleep 10
		;;
	list)
		if [ -e "$BLOOM_FAKE_JACK" ]; then port=headphones; else port=speaker; fi
		printf 'Sink #53\n  Active Port: analog-output-%s\n' "$port"
		;;
esac
FAKE_PACTL
chmod +x "$TEST_TMP/bin/udevadm" "$TEST_TMP/bin/pactl"
export BLOOM_UDEVADM="$TEST_TMP/bin/udevadm" BLOOM_PACTL="$TEST_TMP/bin/pactl" BLOOM_FAKE_JACK="$TEST_TMP/jack" BLOOM_USB_OBSERVED="$TEST_TMP/usb-observed"
start_shell

usb_alert() { ipc notch state | jq -e '.[0].deviceAlert.kind == "usb" and .[0].deviceAlert.detail == "Test USB Drive"' >/dev/null; }
jack_alert() { ipc notch state | jq -e '.[0].deviceAlert.title == "Headphones connected"' >/dev/null; }
WAIT_S=6 wait_for "USB alert" usb_alert
pass "USB event opens a transient device alert"
touch "$BLOOM_USB_OBSERVED"
WAIT_S=8 wait_for "headphone jack alert" jack_alert
pass "headphone port change opens a transient alert"
