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
# A 2.4 GHz mouse receiver: a boot keyboard interface and a mouse
# interface; it counts as the mouse (owner, 2026-10-29: USB input devices).
usb 1-3 removable "Wireless Device"
input() { # input <n> <usb id> <iface> <protocol> [mouse]
	local i; i="$(iface "$2" "$3")"
	echo 03 > "$i/bInterfaceClass"; echo 01 > "$i/bInterfaceSubClass"; echo "$4" > "$i/bInterfaceProtocol"
	mkdir -p "$i/0003:3151:3020.000E/input/input$1" "$FAKE/sys/class/input"
	ln -s "$i/0003:3151:3020.000E/input/input$1" "$FAKE/sys/class/input/input$1"
	[[ "${5:-}" == mouse ]] && mkdir -p "$i/0003:3151:3020.000E/input/input$1/mouse0"
	return 0
}
echo YICHIP > "$FAKE/sys/devices/pci0000:00/usb1/1-3/manufacturer"
echo Generic > "$FAKE/sys/devices/pci0000:00/usb1/1-2/manufacturer"
input 32 1-3 0 01
input 33 1-3 1 02 mouse
# A USB keyboard.
usb 1-7 removable "USB Keyboard"
input 40 1-7 0 01
# The headset's media keys look like a keyboard; it stays audio.
input 26 1-2 3 00
# A mouse without the boot protocol: its mouse handler says it.
usb 1-9 removable "Gaming Mouse"
input 50 1-9 0 00 mouse

# A phone in file-transfer mode (interface class 06, MTP/PTP).
usb 1-10 removable "Pixel 8"
i="$(iface 1-10 0)"; echo 06 > "$i/bInterfaceClass"
# A gamepad: its input has a joystick handler.
usb 1-11 removable "Xbox Wireless Controller"
input 60 1-11 0 00
mkdir -p "$(readlink -f "$FAKE/sys/class/input/input60")/js0"
# A printer (interface class 07).
usb 1-12 removable "LaserJet M110"
i="$(iface 1-12 0)"; echo 07 > "$i/bInterfaceClass"
# A Bluetooth or Wi-Fi dongle (interface class e0).
usb 1-13 removable "TP-Link Adapter"
i="$(iface 1-13 0)"; echo e0 > "$i/bInterfaceClass"
# A hub (device class 09).
usb 1-14 removable "USB2.0 Hub"
echo 09 > "$FAKE/sys/devices/pci0000:00/usb1/1-14/bDeviceClass"
# Anything else still counts, by its name.
usb 1-15 removable "Smart Card Reader"
i="$(iface 1-15 0)"; echo 0b > "$i/bInterfaceClass"
# A root hub never does.
mkdir -p "$FAKE/sys/devices/pci0000:00/usb1"
echo 1d6b > "$FAKE/sys/devices/pci0000:00/usb1/idVendor"
echo unknown > "$FAKE/sys/devices/pci0000:00/usb1/removable"
ln -s "$FAKE/sys/devices/pci0000:00/usb1" "$FAKE/sys/bus/usb/devices/usb1"

got="$(BLOOM_SYSFS="$FAKE" sh "$SCRIPT")"
want="$(printf '%s\n' \
	$'1-10\tphone\tPixel 8' \
	$'1-11\tgamepad\tXbox Wireless Controller' \
	$'1-12\tprinter\tLaserJet M110' \
	$'1-13\twireless\tTP-Link Adapter' \
	$'1-14\thub\tUSB2.0 Hub' \
	$'1-15\tother\tSmart Card Reader' \
	$'1-2\taudio-out\tAB13X USB Audio' \
	$'1-3\tmouse\tYICHIP Wireless Device' \
	$'1-4\taudio-in\tYeti Stereo Microphone' \
	$'1-5\tdisk\tSanDisk Cruzer Blade' \
	$'1-6\tcamera\tHD Pro Webcam C920' \
	$'1-7\tkeyboard\tUSB Keyboard' \
	$'1-9\tmouse\tGaming Mouse')"
if [[ "$got" != "$want" ]]; then
	echo "FAIL: usb-devices.sh"
	echo "--- got"; echo "$got"
	echo "--- want"; echo "$want"
	exit 1
fi
echo "ok - every external USB device, one per device, by its most telling kind"

# No devices: no output, success.
EMPTY="$(mktemp -d)"
out="$(BLOOM_SYSFS="$EMPTY" sh "$SCRIPT")"
rm -rf "$EMPTY"
[[ -z "$out" ]] || { echo "FAIL: empty sysfs printed: $out"; exit 1; }
echo "ok - an empty sysfs lists nothing"
