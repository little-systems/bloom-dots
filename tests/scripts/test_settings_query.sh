#!/usr/bin/env bash
# settings-query.sh against throwaway folders, never the real autostart.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
Q="$ROOT/shell/scripts/settings-query.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
export XDG_CONFIG_HOME="$T/config" XDG_DATA_HOME="$T/data" BLOOM_XDG_AUTOSTART="$T/sys" BLOOM_XDG_APPS="$T/apps"
mkdir -p "$T/sys" "$T/apps"
printf '[Desktop Entry]\nName=Thing\nExec=thing\n' > "$T/sys/thing.desktop"
[[ "$(sh "$Q" autostart-list)" == $'thing\tThing\ton' ]] || fail "not listed as on"
sh "$Q" autostart-set thing off
[[ "$(sh "$Q" autostart-list)" == $'thing\tThing\toff' ]] || fail "not turned off"
grep -q '^Name=Thing' "$T/sys/thing.desktop" && ! grep -q Hidden "$T/sys/thing.desktop" || fail "the system file changed"
sh "$Q" autostart-set thing on
[[ "$(sh "$Q" autostart-list)" == $'thing\tThing\ton' ]] || fail "not turned back on"
if sh "$Q" autostart-set '../evil' off; then fail "a bad id was accepted"; fi
echo "ok - startup apps turn on and off through a user override"
printf '[Desktop Entry]\nName=Viewer\nMimeType=image/png;text/plain;\n' > "$T/apps/viewer.desktop"
[[ "$(sh "$Q" mime-apps image/png)" == $'viewer.desktop\tViewer' ]] || fail "no app for the type"
[[ -z "$(sh "$Q" mime-apps video/mp4)" ]] || fail "wrong app for the type"
echo "ok - apps are found by the types they open"
