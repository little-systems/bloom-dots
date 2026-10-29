#!/bin/sh
# Lists the external USB devices for Bloom's device alerts and Connected
# devices: one line per device, "<usb id>\t<kind>\t<name>", as its most
# telling kind. Bloom's src-tauri/src/usb.rs covers cameras, audio, drives
# and microphones; the owner asked for every device (2026-10-29), so phones,
# gamepads, mice, keyboards, printers, wireless adapters, hubs and anything
# else count too. Kinds, most telling first:
#   camera audio-out disk audio-in phone gamepad mouse keyboard printer
#   wireless hub other
# The computer's own devices (sysfs removable = fixed: a built-in camera,
# the Bluetooth adapter) and root hubs never count, as Bloom leaves out the
# machine's container. Reads sysfs and /proc/asound only; BLOOM_SYSFS
# prefixes both for tests.
S="${BLOOM_SYSFS:-}"

# The USB device a sysfs path belongs to: the nearest parent with an idVendor.
usb_of() {
	p=$(readlink -f "$1" 2>/dev/null) || return 1
	while [ -n "$p" ] && [ "$p" != "/" ]; do
		[ -f "$p/idVendor" ] && { echo "$p"; return 0; }
		p=$(dirname "$p")
	done
	return 1
}

# The USB interface a sysfs path belongs to: the nearest parent with a class.
iface_of() {
	p=$(readlink -f "$1" 2>/dev/null) || return 1
	while [ -n "$p" ] && [ "$p" != "/" ]; do
		[ -f "$p/bInterfaceClass" ] && { echo "$p"; return 0; }
		[ -f "$p/idVendor" ] && return 1
		p=$(dirname "$p")
	done
	return 1
}

trim() { tr -s ' \t' ' ' | sed 's/^ //; s/ $//'; }

# emit <rank> <path> <kind> <name>
emit() {
	u=$(usb_of "$2") || return 0
	case "$(basename "$u")" in usb*) return 0 ;; esac
	[ "$(cat "$u/removable" 2>/dev/null)" = fixed ] && return 0
	name=$4
	if [ -z "$name" ]; then
		name=$(cat "$u/product" 2>/dev/null | trim)
		# "Wireless Device" by YICHIP reads as "YICHIP Wireless Device";
		# a maker of "Generic" (or one already named) adds nothing.
		maker=$(cat "$u/manufacturer" 2>/dev/null | trim)
		case "$maker" in
		"" | Generic | generic) ;;
		*) case "$name" in *"$maker"*) ;; *) name="$maker $name" ;; esac ;;
		esac
	fi
	printf '%s\t%s\t%s\t%s\n' "$1" "$(basename "$u")" "$3" "$name"
}

{
	for v in "$S"/sys/class/video4linux/*; do
		[ -e "$v/device" ] || continue
		# "EasyCamera: EasyCamera" names the camera once.
		emit 0 "$v/device" camera "$(sed 's/:.*//' "$v/name" 2>/dev/null | trim)"
	done
	for c in "$S"/sys/class/sound/card*; do
		[ -e "$c/device" ] || continue
		n=${c##*card}
		if ls -d "$S/proc/asound/card$n"/pcm*p >/dev/null 2>&1; then
			emit 1 "$c/device" audio-out ""
		elif ls -d "$S/proc/asound/card$n"/pcm*c >/dev/null 2>&1; then
			emit 3 "$c/device" audio-in ""
		fi
	done
	for b in "$S"/sys/block/*; do
		[ -e "$b/device" ] || continue
		emit 2 "$b/device" disk "$(cat "$b/device/vendor" "$b/device/model" 2>/dev/null | tr '\n' ' ' | trim)"
	done
	# Input devices: a joystick handler is a gamepad; a mouse handler or the
	# HID boot mouse protocol a mouse; the boot keyboard protocol a keyboard.
	for i in "$S"/sys/class/input/input*; do
		[ -e "$i" ] || continue
		real=$(readlink -f "$i")
		proto=$(cat "$(iface_of "$real" || echo /nonexistent)/bInterfaceProtocol" 2>/dev/null)
		if ls -d "$real"/js* >/dev/null 2>&1; then
			emit 5 "$real" gamepad ""
		elif ls -d "$real"/mouse* >/dev/null 2>&1 || [ "$proto" = 02 ]; then
			emit 6 "$real" mouse ""
		elif [ "$proto" = 01 ]; then
			emit 7 "$real" keyboard ""
		fi
	done
	# Every external device by its interfaces, so nothing is left out.
	for d in "$S"/sys/bus/usb/devices/*; do
		case "$(basename "$d")" in *:*) continue ;; esac
		[ -f "$d/idVendor" ] || continue
		real=$(readlink -f "$d")
		for i in "$real"/*:*; do
			case "$(cat "$i/bInterfaceClass" 2>/dev/null)" in
			06) emit 4 "$real" phone "" ;;
			07) emit 8 "$real" printer "" ;;
			e0) emit 9 "$real" wireless "" ;;
			esac
		done
		[ "$(cat "$real/bDeviceClass" 2>/dev/null)" = 09 ] && emit 10 "$real" hub ""
		emit 11 "$real" other ""
	done
} | sort -t "$(printf '\t')" -k2,2 -k1,1n | awk -F '\t' '!seen[$2]++ { print $2 "\t" $3 "\t" $4 }'
