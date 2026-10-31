#!/usr/bin/env bash
# Names the song playing on this machine with songrec. Usage: recognize-music.sh
set -uo pipefail

tell() { notify-send -a Bloom "$@" || true; }

for tool in songrec parec jq; do
	if ! command -v "$tool" >/dev/null; then
		tell "Music recognition" "This needs $tool, which isn't installed."
		exit 1
	fi
done
clip="$(mktemp --suffix=.wav)"
trap 'rm -f "$clip"' EXIT
tell "Listening" "Identifying what's playing…"
timeout "${BLOOM_LISTEN_SECONDS:-8}" parec -d @DEFAULT_SINK@.monitor --file-format=wav "$clip" 2>/dev/null
[ -s "$clip" ] || { tell "Music recognition" "Couldn't listen to the sound output."; exit 0; }
reply="$(timeout 30 songrec audio-file-to-recognized-song "$clip" 2>/dev/null)"
title="$(printf '%s' "$reply" | jq -r '.track.title // empty' 2>/dev/null)"
artist="$(printf '%s' "$reply" | jq -r '.track.subtitle // empty' 2>/dev/null)"
if [ -z "$title" ]; then
	tell "Music recognition" "Couldn't identify that song."
	exit 0
fi
tell "$title" "$artist"
