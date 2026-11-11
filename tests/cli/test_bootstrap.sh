#!/usr/bin/env bash
# A fresh Arch base has no Python: `bloom install` installs it before the
# Python installer runs (pacman as root, sudo pacman as a user).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
PY="$(command -v python3)"
mkdir -p "$T/bin"
for tool in bash env dirname readlink cat ln; do ln -s "$(command -v "$tool")" "$T/bin/$tool"; done
# pacman "installs" python3; sudo runs what it is given.
printf '#!/bin/sh\necho "pacman $*" >> "%s/calls"\nln -sf "%s" "%s/bin/python3"\n' "$T" "$PY" "$T" > "$T/bin/pacman"
printf '#!/bin/sh\necho "sudo $*" >> "%s/calls"\nexec "$@"\n' "$T" > "$T/bin/sudo"
chmod +x "$T/bin/pacman" "$T/bin/sudo"

out="$(PATH="$T/bin" bash "$ROOT/bin/bloom" install --help 2>&1)" || fail "install did not continue: $out"
grep -q "sudo pacman -S --needed --noconfirm python" "$T/calls" || fail "a user install didn't ask sudo for python: $(cat "$T/calls")"
[[ "$out" == *"Python"* && "$out" == *"usage"* ]] || fail "no explanation, or the installer didn't run: $out"
echo "ok - a user install installs Python through sudo, then runs"

rm -f "$T/bin/python3" "$T/calls"
PATH="$T/bin" BLOOM_AS_ROOT=1 bash "$ROOT/bin/bloom" install --help >/dev/null 2>&1 || fail "root install did not continue"
[[ "$(cat "$T/calls")" == "pacman -S --needed --noconfirm python" ]] || fail "root used: $(cat "$T/calls")"
echo "ok - as root (arch-chroot) pacman installs Python directly"
