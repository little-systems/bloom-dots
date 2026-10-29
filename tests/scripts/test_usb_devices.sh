#!/usr/bin/env bash
# shell/scripts/usb-devices.sh against a fake sysfs: external USB devices in
# Bloom's classes (camera, audio-out, disk, audio-in), one line per device as
# its most telling interface; the computer's own (removable = fixed) never.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/shell/scripts/usb-devices.sh"
FAKE="$(mktemp -d)"
trap 'rm -rf "$FAKE"' EXIT

usb() { # usb <id> <removable> <product>
	local d="$FAKE/sys/devices/pci0000:00/usb1/$1"
	mkdir -p "$d" "$FAKE/sys/bus/usb/devices"
	echo 1234 > "$d/idVendor"
	echo "$2" > "$d/removable"
	echo "$3" > "$d/product"
	ln -s "$d" "$FAKE/sys/bus/usb/devices/$1"
}
iface() { mkdir -p "$FAKE/sys/devices/pci0000:00/usb1/$1/$1:1.$2"; echo "$FAKE/sys/devices/pci0000:00/usb1/$1/$1:1.$2"; }

# The laptop's own camera: fixed.
usb 1-8 fixed EasyCamera
mkdir -p "$FAKE/sys/class/video4linux/video0"
echo "EasyCamera: EasyCamera" > "$FAKE/sys/class/video4linux/video0/name"
ln -s "$(iface 1-8 0)" "$FAKE/sys/class/video4linux/video0/device"
# A USB headset: playback and capture, one device.
usb 1-2 removable "AB13X USB Audio"
mkdir -p "$FAKE/sys/class/sound/card0" "$FAKE/proc/asound/card0/pcm0p" "$FAKE/proc/asound/card0/pcm0c"
echo Audio > "$FAKE/sys/class/sound/card0/id"
ln -s "$(iface 1-2 0)" "$FAKE/sys/class/sound/card0/device"
# A USB microphone: capture only.
usb 1-4 removable "Yeti Stereo Microphone"
mkdir -p "$FAKE/sys/class/sound/card2" "$FAKE/proc/asound/card2/pcm0c"
echo Microphone > "$FAKE/sys/class/sound/card2/id"
ln -s "$(iface 1-4 0)" "$FAKE/sys/class/sound/card2/device"
# A USB stick with a webcam-free disk.
usb 1-5 removable "Mass Storage"
SCSI="$(iface 1-5 0)/host0/target0:0:0/0:0:0:0"
mkdir -p "$SCSI" "$FAKE/sys/block/sdb"
echo "SanDisk " > "$SCSI/vendor"
echo "Cruzer Blade    " > "$SCSI/model"
ln -s "$SCSI" "$FAKE/sys/block/sdb/device"
# A webcam with a microphone: one device, reported as the camera.
usb 1-6 removable "C920 HD Pro Webcam"
mkdir -p "$FAKE/sys/class/video4linux/video2" "$FAKE/sys/class/sound/card3" "$FAKE/proc/asound/card3/pcm0c"
echo "HD Pro Webcam C920" > "$FAKE/sys/class/video4linux/video2/name"
ln -s "$(iface 1-6 0)" "$FAKE/sys/class/video4linux/video2/device"
ln -s "$(iface 1-6 2)" "$FAKE/sys/class/sound/card3/device"
# The built-in sound card: not USB.
mkdir -p "$FAKE/sys/devices/pci0000:00/0000:00:1f.3" "$FAKE/sys/class/sound/card1" "$FAKE/proc/asound/card1/pcm0p"
ln -s "$FAKE/sys/devices/pci0000:00/0000:00:1f.3" "$FAKE/sys/class/sound/card1/device"
# A receiver with no Bloom class: nothing.
usb 1-3 removable "Wireless Device"

got="$(BLOOM_SYSFS="$FAKE" sh "$SCRIPT")"
want="$(printf '1-2\taudio-out\tAB13X USB Audio\n1-4\taudio-in\tYeti Stereo Microphone\n1-5\tdisk\tSanDisk Cruzer Blade\n1-6\tcamera\tHD Pro Webcam C920')"
if [[ "$got" != "$want" ]]; then
	echo "FAIL: usb-devices.sh"
	echo "--- got"; echo "$got"
	echo "--- want"; echo "$want"
	exit 1
fi
echo "ok - external USB devices, one per device, as Bloom's classes"

# No devices: no output, success.
EMPTY="$(mktemp -d)"
out="$(BLOOM_SYSFS="$EMPTY" sh "$SCRIPT")"
rm -rf "$EMPTY"
[[ -z "$out" ]] || { echo "FAIL: empty sysfs printed: $out"; exit 1; }
echo "ok - an empty sysfs lists nothing"
