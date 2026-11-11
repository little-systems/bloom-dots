#!/usr/bin/env bash
# login-state.py into a private folder: the login screen's wallpaper and colours.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'chmod -R u+w "$T"; rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/login" "$T/bin"
export BLOOM_LOGIN_DIR="$T/login" PATH="$T/bin:/usr/bin:/bin"
state() { python3 "$ROOT/shell/scripts/login-state.py"; }
printf 'JPEG1' > "$T/one.jpg"
printf 'PNG2' > "$T/two.png"

printf '{"wallpaper":"%s","accent":"#ff8800","bgExpanded":"#eb000000","text":"#ffffff","textMuted":"#99ffffff","border":"#1fffffff","groupBg":"#0fffffff","scale":1.15,"zoom":1}' "$T/one.jpg" | state
qml="$T/login/State.qml"
[[ -f "$qml" ]] || fail "no State.qml"
grep -q 'property color accent: "#ff8800"' "$qml" || fail "accent missing"
grep -q 'property real scale: 1.15' "$qml" || fail "scale missing"
name="$(sed -n 's/.*property url wallpaper: "\(wallpaper-[0-9a-f]*\.jpg\)".*/\1/p' "$qml")"
[[ -n "$name" && "$(cat "$T/login/$name")" == JPEG1 ]] || fail "wallpaper not copied"
[[ "$(stat -c %a "$T/login/$name")" == 644 && "$(stat -c %a "$qml")" == 644 ]] || fail "the greeter can't read the files"
echo "ok - copies the wallpaper and writes the colours"

printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/two.png" | state
[[ "$(find "$T/login" -name 'wallpaper-*' | wc -l)" == 1 ]] || fail "the old wallpaper was kept"
grep -q 'wallpaper-[0-9a-f]*\.png' "$qml" || fail "new wallpaper not referenced"
echo "ok - replaces the previous wallpaper"

printf '{"wallpaper":"%s","accent":"red\\" } Item { x","scale":"9e9"}' "$T/two.png" | state
grep -q 'accent' "$qml" && fail "an invalid colour reached the QML"
grep -q 'Item' "$qml" && fail "text was injected into the QML"
grep -q 'property real scale' "$qml" && fail "an out-of-range scale was kept"
echo "ok - only valid colours and numbers reach the login screen"

printf 'VIDEO' > "$T/clip.mp4"
before="$(grep wallpaper "$qml")"
printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/clip.mp4" | state
[[ "$(grep wallpaper "$qml")" == "$before" ]] || fail "a video without ffmpeg replaced the wallpaper"
printf '#!/bin/sh\nfor last; do :; done\nprintf FRAME > "$last"\n' > "$T/bin/ffmpeg"
chmod +x "$T/bin/ffmpeg"
printf '{"wallpaper":"%s","accent":"#00ff00"}' "$T/clip.mp4" | state
name="$(sed -n 's/.*property url wallpaper: "\(wallpaper-[0-9a-f]*\.jpg\)".*/\1/p' "$qml")"
[[ "$(cat "$T/login/$name")" == FRAME ]] || fail "a video wallpaper gives no still frame"
echo "ok - a video wallpaper contributes a still frame"

chmod 555 "$T/login"
out="$(printf '{"wallpaper":"%s"}' "$T/one.jpg" | state 2>&1)" || fail "an unwritable folder is an error"
[[ -z "$out" ]] || fail "an unwritable folder printed: $out"
rm -rf "$T/missing"
BLOOM_LOGIN_DIR="$T/missing" state <<<'{}' || fail "a missing folder is an error"
echo "ok - quiet when the login folder isn't there or isn't writable"
