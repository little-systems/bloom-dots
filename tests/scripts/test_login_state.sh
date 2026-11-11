#!/usr/bin/env bash
# login-state.py into a private folder: the login screen's wallpaper and colours,
# as plain data (the greeter never runs anything from this group-writable folder).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'chmod -R u+w "$T"; rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/login" "$T/bin"
export BLOOM_LOGIN_DIR="$T/login" PATH="$T/bin:/usr/bin:/bin"
state() { python3 "$ROOT/shell/scripts/login-state.py"; }
field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$T/login/state.json" "$1"; }
printf 'JPEG1' > "$T/one.jpg"
printf 'PNG2' > "$T/two.png"

echo '// left by an older Bloom' > "$T/login/State.qml"
printf '{"wallpaper":"%s","accent":"#ff8800","bgExpanded":"#eb000000","text":"#ffffff","textMuted":"#99ffffff","border":"#1fffffff","groupBg":"#0fffffff","scale":1.15,"zoom":1}' "$T/one.jpg" | state
[[ -f "$T/login/state.json" && ! -e "$T/login/State.qml" ]] || fail "state.json missing or old State.qml kept"
[[ "$(field accent)" == "#ff8800" && "$(field scale)" == 1.15 ]] || fail "colours or scale missing"
name="$(field wallpaper)"
[[ "$name" =~ ^wallpaper-[0-9a-f]{12}\.jpg$ && "$(cat "$T/login/$name")" == JPEG1 ]] || fail "wallpaper not copied: $name"
[[ "$(stat -c %a "$T/login/$name")" == 644 && "$(stat -c %a "$T/login/state.json")" == 644 ]] || fail "the greeter can't read the files"
echo "ok - copies the wallpaper and writes the colours"

printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/two.png" | state
[[ "$(find "$T/login" -name 'wallpaper-*' | wc -l)" == 1 && "$(field wallpaper)" == *.png ]] || fail "the old wallpaper was kept"
echo "ok - replaces the previous wallpaper"

printf '{"wallpaper":"%s","accent":"red\\" } Item { x","scale":"9e9"}' "$T/two.png" | state
[[ -z "$(field accent)" && -z "$(field scale)" ]] || fail "invalid values were kept"
echo "ok - only valid colours and numbers are written"

printf 'VIDEO' > "$T/clip.mp4"
before="$(field wallpaper)"
printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/clip.mp4" | state
[[ "$(field wallpaper)" == "$before" ]] || fail "a video without ffmpeg replaced the wallpaper"
printf '#!/bin/sh\nfor last; do :; done\nprintf FRAME > "$last"\n' > "$T/bin/ffmpeg"
chmod +x "$T/bin/ffmpeg"
printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/clip.mp4" | state
[[ "$(cat "$T/login/$(field wallpaper)")" == FRAME ]] || fail "a video wallpaper gives no still frame"
echo "ok - a video wallpaper contributes a still frame"

chmod 555 "$T/login"
out="$(printf '{"wallpaper":"%s"}' "$T/one.jpg" | state 2>&1)" || fail "an unwritable folder is an error"
[[ -z "$out" ]] || fail "an unwritable folder printed: $out"
rm -rf "$T/missing"
BLOOM_LOGIN_DIR="$T/missing" state <<<'{}' || fail "a missing folder is an error"
echo "ok - quiet when the login folder isn't there or isn't writable"
