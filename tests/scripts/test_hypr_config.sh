#!/usr/bin/env bash
# Bloom's Hyprland files: what the lock screen needs from the compositor, and
# (where Hyprland is installed) that both files load.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
grep -q 'session_lock_xray = true' "$ROOT/hypr/bloom.lua" || fail "the lock can't fade over the desktop (no xray): it goes black"
grep -q 'allow_session_lock_restore = true' "$ROOT/hypr/bloom.lua" || fail "a crashed lock screen can't take the lock back"
echo "ok - the lock fades over the live desktop and survives a crash"
if ! command -v Hyprland >/dev/null; then
	echo "skipped: Hyprland is not installed"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/config/hypr/custom"
printf 'dofile("%s/hypr/desktop.lua")\ndofile("%s/hypr/bloom.lua")\n' "$ROOT" "$ROOT" > "$T/hyprland.lua"
XDG_CONFIG_HOME="$T/config" Hyprland --verify-config -c "$T/hyprland.lua" 2>&1 | grep -q '^config ok$' || fail "Hyprland rejects Bloom's config"
echo "ok - Hyprland accepts Bloom's desktop and integration"
