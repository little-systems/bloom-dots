#!/usr/bin/env bash
# Region tools (spec §3.4): pick a region or a window, then screenshot, annotate,
# read its text, translate it or record it.
# Usage: region.sh screenshot|annotate|ocr|translate|record|record-audio|record-screen|record-screen-audio|status
set -euo pipefail

action="${1:-}"
shots="${BLOOM_SCREENSHOT_DIR:-$(xdg-user-dir PICTURES)/Screenshots}"
videos="${BLOOM_RECORDING_DIR:-$(xdg-user-dir VIDEOS)}"
pidfile="${XDG_RUNTIME_DIR:?}/bloom-recording.pid"

tell() { notify-send -a Bloom "$@" || true; }

need() {
	local tool
	for tool in "$@"; do
		if ! command -v "$tool" >/dev/null; then
			tell "Region tools" "This needs $tool, which isn't installed."
			exit 1
		fi
	done
}

# The recorder is identified by PID plus its kernel start time (and name), so a
# PID reused after a crash is never signalled. Record: pid, start time, file.
start_time() { awk '{ print $22 }' "/proc/$1/stat" 2>/dev/null; }
recording() {
	[[ -f "$pidfile" ]] || return 1
	local pid start
	{ read -r pid; read -r start; } < "$pidfile" || true
	[[ "$pid" =~ ^[0-9]+$ && -n "$start" ]] || return 1
	[[ "$(cat "/proc/$pid/comm" 2>/dev/null)" == wf-recorder && "$(start_time "$pid")" == "$start" ]]
}

# Stop the recorder and wait until it has finished writing; report the truth.
stop_recording() {
	local pid start file
	{ read -r pid; read -r start; read -r file; } < "$pidfile" || true
	kill -INT "$pid"
	for _ in $(seq 1 100); do
		recording || break
		sleep 0.1
	done
	if recording; then
		tell "Recording" "The recorder is still finishing; run this again in a moment."
		exit 1
	fi
	rm -f "$pidfile"
	if [[ -s "$file" ]]; then
		tell "Recording saved" "$videos"
		exit 0
	fi
	tell "Recording failed" "The recorder stopped without saving a video."
	exit 1
}

# The selection, or nothing if it was cancelled. Visible windows are clickable.
select_region() {
	need slurp hyprctl jq
	pidof slurp >/dev/null && return 1
	hyprctl clients -j \
		| jq -r --argjson active "$(hyprctl monitors -j | jq '[.[]?.activeWorkspace.id]')" \
			'.[] | select(.mapped and (.hidden | not)) | select(($active | length) == 0 or (.workspace.id as $w | $active | index($w))) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
		| slurp 2>/dev/null
}

shot_name() { printf '%s/Screenshot_%s.png' "$shots" "$(date +%Y-%m-%d_%H.%M.%S)"; }

case "$action" in
	screenshot)
		need grim wl-copy
		region="$(select_region)" || exit 0
		mkdir -p "$shots"
		file="$(shot_name)"
		grim -g "$region" "$file.tmp"
		wl-copy --type image/png < "$file.tmp"
		mv "$file.tmp" "$file"
		tell "Screenshot copied" "$file"
		;;
	annotate)
		need grim
		region="$(select_region)" || exit 0
		if command -v satty >/dev/null; then
			grim -g "$region" - | satty --filename - --copy-command wl-copy
		else
			need swappy
			grim -g "$region" - | swappy -f -
		fi
		;;
	ocr)
		need grim tesseract wl-copy
		region="$(select_region)" || exit 0
		text="$(grim -g "$region" - | tesseract stdin stdout 2>/dev/null)"
		printf '%s' "$text" | wl-copy
		tell "Text copied" "$text"
		;;
	translate)
		need grim tesseract wl-copy trans
		region="$(select_region)" || exit 0
		text="$(grim -g "$region" - | tesseract stdin stdout 2>/dev/null)"
		[ -n "$text" ] || { tell "Translate" "No text found there."; exit 0; }
		if ! out="$(printf '%s' "$text" | trans -brief -no-autocorrect ":${BLOOM_TRANSLATE_TO:-en}" 2>/dev/null)" || [ -z "$out" ]; then
			tell "Translate" "Couldn't reach the translation service."
			exit 0
		fi
		printf '%s' "$out" | wl-copy
		tell "Translation copied" "$out"
		;;
	record | record-audio | record-screen | record-screen-audio)
		recording && stop_recording
		rm -f "$pidfile"
		need wf-recorder
		mkdir -p "$videos"
		args=()
		if [[ "$action" == record-screen* ]]; then
			need hyprctl jq
			output="$(hyprctl monitors -j | jq -er '.[] | select(.focused) | .name' | head -n 1)" || {
				tell "Recording" "Couldn't find the focused display."
				exit 1
			}
			args+=(-o "$output")
		else
			region="$(select_region)" || exit 0
			args+=(-g "$region")
		fi
		# Never reuse a name: an older file would hide a recording that failed.
		base="$videos/Recording_$(date +%Y-%m-%d_%H.%M.%S)"
		file="$base.mp4"
		n=2
		while [[ -e "$file" ]]; do file="${base}_$n.mp4"; n=$((n + 1)); done
		args+=(-f "$file")
		[[ "$action" == *-audio ]] && args+=(-a)
		setsid wf-recorder "${args[@]}" >/dev/null 2>&1 &
		pid=$!
		start=""
		for _ in $(seq 1 20); do start="$(start_time "$pid")"; [[ -n "$start" ]] && break; sleep 0.05; done
		printf '%s\n%s\n%s\n' "$pid" "$start" "$file" > "$pidfile.new" && mv -f "$pidfile.new" "$pidfile"
		tell "Recording" "Run this again to stop."
		;;
	status)
		if recording; then echo recording; else echo idle; fi
		;;
	*)
		printf 'usage: %s screenshot|annotate|ocr|translate|record|record-audio|record-screen|record-screen-audio|status\n' "$0" >&2
		exit 2
		;;
esac
