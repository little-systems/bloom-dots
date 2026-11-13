#!/usr/bin/env bash
# Bloom's terminal (terminal/): bloom.bash starts the prompt and shows
# fastfetch once per kitty window; the configs load in the real tools.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/bin"
printf '#!/bin/sh\necho "omp $*" >> "%s/calls"\necho "PS1=prompt"\n' "$T" > "$T/bin/oh-my-posh"
printf '#!/bin/sh\necho "fastfetch $*" >> "%s/calls"\n' "$T" > "$T/bin/fastfetch"
chmod +x "$T/bin/"*
shell() { env -i HOME="$T" PATH="$T/bin:/usr/bin:/bin" "$@" bash --norc --noprofile -i -c ". '$ROOT/terminal/bloom.bash'; ${NESTED:-true}" >/dev/null 2>&1; }

shell KITTY_WINDOW_ID=3
grep -qx "omp init bash --config $ROOT/terminal/bloom.omp.json" "$T/calls" || fail "the prompt didn't start with Bloom's theme"
grep -q "^fastfetch --config $ROOT/terminal/fastfetch.jsonc --logo $ROOT/terminal/bloom-logo.png --logo-type kitty-direct" "$T/calls" || fail "fastfetch didn't show Bloom's layout and logo"
echo "ok - a new kitty window gets Bloom's prompt and fastfetch with the logo"

: > "$T/calls"
NESTED=". '$ROOT/terminal/bloom.bash'" shell KITTY_WINDOW_ID=3 BLOOM_FASTFETCH_WINDOW=3
if grep -q '^fastfetch' "$T/calls"; then fail "fastfetch ran again in the same window"; fi
: > "$T/calls"
shell
if grep -q '^fastfetch' "$T/calls"; then fail "fastfetch ran outside kitty"; fi
grep -q '^omp' "$T/calls" || fail "the prompt needs kitty"
echo "ok - fastfetch shows once per kitty window and never outside kitty"

: > "$T/calls"
env -i HOME="$T" PATH="$T/bin:/usr/bin:/bin" KITTY_WINDOW_ID=4 bash --norc --noprofile -c ". '$ROOT/terminal/bloom.bash'"
[[ ! -s "$T/calls" ]] || fail "a script (non-interactive shell) ran Bloom's terminal"
echo "ok - scripts are left alone"

: > "$T/calls"
NESTED="fastfetch --pipe" shell KITTY_WINDOW_ID=5 BLOOM_FASTFETCH_WINDOW=5
grep -qx "fastfetch --config $ROOT/terminal/fastfetch.jsonc --logo $ROOT/terminal/bloom-logo.png --logo-type kitty-direct --pipe" "$T/calls" || fail "typing fastfetch in kitty didn't use Bloom's layout and logo"
: > "$T/calls"
NESTED="fastfetch" shell
grep -qx "fastfetch --config $ROOT/terminal/fastfetch.jsonc" "$T/calls" || fail "typing fastfetch outside kitty didn't use Bloom's layout"
echo "ok - typing fastfetch shows Bloom's layout"

: > "$T/calls"
mkdir -p "$T/.config/fastfetch" && : > "$T/.config/fastfetch/config.jsonc"
NESTED="fastfetch --pipe" shell KITTY_WINDOW_ID=5 BLOOM_FASTFETCH_WINDOW=5
grep -qx "fastfetch --pipe" "$T/calls" || fail "typing fastfetch ignored the user's own fastfetch config"
rm -r "$T/.config"
echo "ok - a fastfetch config of your own wins"

# The layout follows the window: the logo needs room, a narrow or short window
# gets the compact layout, and a tiny one stays quiet until asked.
: > "$T/calls"
shell KITTY_WINDOW_ID=6 COLUMNS=120 LINES=40
grep -q "^fastfetch --config $ROOT/terminal/fastfetch.jsonc --logo " "$T/calls" || fail "a roomy window didn't get the full layout"
: > "$T/calls"
shell KITTY_WINDOW_ID=6 COLUMNS=60 LINES=30
grep -qx "fastfetch --config $ROOT/terminal/fastfetch-compact.jsonc" "$T/calls" || fail "a narrow window didn't get the compact layout"
: > "$T/calls"
shell KITTY_WINDOW_ID=6 COLUMNS=120 LINES=16
grep -qx "fastfetch --config $ROOT/terminal/fastfetch-compact.jsonc" "$T/calls" || fail "a short window didn't get the compact layout"
: > "$T/calls"
shell KITTY_WINDOW_ID=6 COLUMNS=49 LINES=11
grep -qx "fastfetch --config $ROOT/terminal/fastfetch-compact.jsonc" "$T/calls" || fail "a 49x11 window didn't get the compact layout"
: > "$T/calls"
shell KITTY_WINDOW_ID=6 COLUMNS=30 LINES=10
if grep -q '^fastfetch' "$T/calls"; then fail "a tiny window showed fastfetch at startup"; fi
NESTED="fastfetch" shell KITTY_WINDOW_ID=6 BLOOM_FASTFETCH_WINDOW=6 COLUMNS=30 LINES=10
grep -qx "fastfetch --config $ROOT/terminal/fastfetch-compact.jsonc" "$T/calls" || fail "typing fastfetch in a tiny window showed nothing"
echo "ok - the layout fits the window"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ROOT/terminal/bloom.omp.json" || fail "the prompt theme isn't valid JSON"
if command -v fastfetch >/dev/null; then
	out="$(fastfetch --config "$ROOT/terminal/fastfetch.jsonc" --logo-type none --pipe 2>&1)" || fail "fastfetch rejects Bloom's config: $out"
	grep -q 'Bloom for Linux' <<<"$out" || fail "fastfetch printed nothing useful: $out"
	echo "ok - fastfetch accepts Bloom's layout"
	out="$(fastfetch --config "$ROOT/terminal/fastfetch-compact.jsonc" --pipe 2>&1)" || fail "fastfetch rejects the compact layout: $out"
	width="$(awk '{ if (length > w) w = length } END { print w + 0 }' <<<"$out")"
	(( $(wc -l <<<"$out") <= 8 && width <= 40 )) || fail "the compact layout doesn't fit 40x10 with the prompt ($(wc -l <<<"$out") lines, $width wide)"
	echo "ok - the compact layout fits a small window"

# kitty stretches the logo to the box the layout gives it. Bloom's kitty font
# (JetBrainsMono Nerd Font 11) has cells about 9 px wide and 20 px tall, so
# the square logo needs a box about 20/9 times wider in cells than it is tall.
read -r logo_w logo_h < <(sed 's|^[[:space:]]*//.*||' "$ROOT/terminal/fastfetch.jsonc" | python3 -c 'import json,sys; l=json.load(sys.stdin)["logo"]; print(l["width"], l["height"])')
python3 -c "import sys; w, h = $logo_w * 9, $logo_h * 20; sys.exit(abs(w - h) > 0.03 * h)" || fail "the logo box is ${logo_w}x${logo_h} cells, so kitty squashes the square logo"
echo "ok - the logo keeps its shape"
fi
if command -v oh-my-posh >/dev/null; then
	oh-my-posh print primary --config "$ROOT/terminal/bloom.omp.json" --shell bash >/dev/null || fail "Oh My Posh rejects Bloom's theme"
	echo "ok - Oh My Posh accepts Bloom's theme"
	git -C "$T" init -q -b bloom-branch
	prompt="$(cd "$T" && oh-my-posh print primary --config "$ROOT/terminal/bloom.omp.json" --shell bash)"
	[[ $prompt == *bloom-branch* ]] || fail "the prompt doesn't show the git branch"
	[[ $prompt != *$'\ue0a0'* ]] || fail "the git branch shows two branch icons"
	echo "ok - the git branch has one icon"
fi
