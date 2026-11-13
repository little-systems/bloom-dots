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

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ROOT/terminal/bloom.omp.json" || fail "the prompt theme isn't valid JSON"
if command -v fastfetch >/dev/null; then
	out="$(fastfetch --config "$ROOT/terminal/fastfetch.jsonc" --logo-type none --pipe 2>&1)" || fail "fastfetch rejects Bloom's config: $out"
	grep -q 'Bloom for Linux' <<<"$out" || fail "fastfetch printed nothing useful: $out"
	echo "ok - fastfetch accepts Bloom's layout"
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
