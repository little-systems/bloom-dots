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
# A fake sysfs: the laptop's own camera (removable = fixed) from the start;
# the fake udevadm plugs a USB drive in, then removes it when asked.
SYSFS="$TEST_TMP/sysfs"
mkdir -p "$SYSFS/sys/devices/usb1/1-8/1-8:1.0" "$SYSFS/sys/class/video4linux/video0"
echo 0c45 > "$SYSFS/sys/devices/usb1/1-8/idVendor"
echo fixed > "$SYSFS/sys/devices/usb1/1-8/removable"
echo "EasyCamera: EasyCamera" > "$SYSFS/sys/class/video4linux/video0/name"
ln -s "$SYSFS/sys/devices/usb1/1-8/1-8:1.0" "$SYSFS/sys/class/video4linux/video0/device"
cat > "$TEST_TMP/bin/udevadm" <<'FAKE_UDEV'
#!/bin/sh
d="$BLOOM_SYSFS/sys/devices/usb1/1-2"
sleep 2
mkdir -p "$d/1-2:1.0/host0/target0:0:0/0:0:0:0" "$BLOOM_SYSFS/sys/block/sdb"
echo 0781 > "$d/idVendor"
echo removable > "$d/removable"
echo "Test USB Drive" > "$d/1-2:1.0/host0/target0:0:0/0:0:0:0/model"
ln -s "$d/1-2:1.0/host0/target0:0:0/0:0:0:0" "$BLOOM_SYSFS/sys/block/sdb/device"
printf 'UDEV  [1.0] add      /devices/usb1/1-2 (usb)\nUDEV  [1.1] add      /devices/virtual/block/sdb (block)\n'
while [ ! -e "$BLOOM_USB_UNPLUG" ]; do sleep 0.1; done
rm -rf "$BLOOM_SYSFS/sys/block/sdb" "$d"
printf 'UDEV  [9.0] remove   /devices/usb1/1-2 (usb)\n'
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
export BLOOM_UDEVADM="$TEST_TMP/bin/udevadm" BLOOM_PACTL="$TEST_TMP/bin/pactl" BLOOM_FAKE_JACK="$TEST_TMP/jack" BLOOM_USB_OBSERVED="$TEST_TMP/usb-observed" BLOOM_SYSFS="$SYSFS" BLOOM_USB_UNPLUG="$TEST_TMP/usb-unplug"
start_shell

usb_alert() { ipc notch state | jq -e '.[0].deviceAlert.name == "Test USB Drive" and .[0].deviceAlert.art == "flash-drive" and .[0].deviceAlert.status == "Plugged in"' >/dev/null; }
jack_alert() { ipc notch state | jq -e '.[0].deviceAlert.name == "Headphones" and .[0].deviceAlert.status == "Plugged in"' >/dev/null; }
WAIT_S=8 wait_for "USB alert" usb_alert
pass "a USB drive plugged in opens a device alert; the built-in camera never does"
usb_removed() { ipc notch state | jq -e '.[0].deviceAlert.name == "Test USB Drive" and .[0].deviceAlert.status == "Unplugged" and .[0].deviceAlert.connected == false' >/dev/null; }
touch "$BLOOM_USB_UNPLUG"
WAIT_S=8 wait_for "USB removal alert" usb_removed
pass "removing it alerts too"
touch "$BLOOM_USB_OBSERVED"
WAIT_S=8 wait_for "headphone jack alert" jack_alert
pass "headphone port change opens a transient alert"
