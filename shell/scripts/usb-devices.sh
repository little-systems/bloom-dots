#!/bin/sh
# Lists the external USB devices Bloom's device alerts and Connected devices
# know (Bloom src-tauri/src/usb.rs): cameras, audio outputs, disks and
# microphones. One line per device, as its most telling interface (a webcam's
# microphone is the webcam): "<usb id>\t<class>\t<name>". The computer's own
# devices (sysfs removable = fixed: a built-in camera or card reader) are left
# out, as Bloom leaves out the machine's container. Reads sysfs and
# /proc/asound only; BLOOM_SYSFS prefixes both for tests.
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

trim() { tr -s ' \t' ' ' | sed 's/^ //; s/ $//'; }

# emit <rank> <path> <class> <name>
emit() {
	u=$(usb_of "$2") || return 0
	[ "$(cat "$u/removable" 2>/dev/null)" = fixed ] && return 0
	name=$4
	[ -n "$name" ] || name=$(cat "$u/product" 2>/dev/null | trim)
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
} | sort -t "$(printf '\t')" -k2,2 -k1,1n | awk -F '\t' '!seen[$2]++ { print $2 "\t" $3 "\t" $4 }'
