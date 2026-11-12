#!/usr/bin/env bash
# idle.py: Bloom's hypridle config from the three idle settings, then hypridle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/bin" "$T/run"
chmod 700 "$T/run"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/args"\ncat "$2" > "%s/config"\n' "$T" "$T" > "$T/bin/hypridle"
chmod +x "$T/bin/hypridle"
export PATH="$T/bin:/usr/bin:/bin" XDG_RUNTIME_DIR="$T/run"
idle() { python3 "$ROOT/shell/scripts/idle.py" "$@"; }

idle 5 10 15
[[ "$(head -1 "$T/args")" == -c && "$(sed -n 2p "$T/args")" == "$T/run/bloom/hypridle.conf" ]] || fail "hypridle not started with Bloom's config"
config="$(cat "$T/config")"
for timeout in 300 600 900; do grep -q "timeout = $timeout$" <<<"$config" || fail "missing timeout $timeout"; done
grep -q 'lock_cmd = qs -c bloom ipc call lock lock' <<<"$config" || fail "lock-session doesn't reach Bloom's lock"
grep -q 'before_sleep_cmd = loginctl lock-session' <<<"$config" || fail "no lock before sleep"
grep -q 'on-timeout = loginctl lock-session' <<<"$config" || fail "idle doesn't lock"
grep -q 'on-timeout = systemctl suspend' <<<"$config" || fail "idle doesn't sleep"
grep -q 'dpms({ action = "disable" })' <<<"$config" || fail "idle doesn't turn the screen off"
[[ "$(stat -c %a "$T/run/bloom")" == 700 ]] || fail "config folder is not private"
echo "ok - locks, turns the screen off and sleeps after the chosen minutes"

idle 0 0 30
config="$(cat "$T/config")"
[[ "$(grep -c '^listener' <<<"$config")" == 1 ]] && grep -q "timeout = 1800$" <<<"$config" || fail "Never still adds a listener"
grep -q 'before_sleep_cmd = loginctl lock-session' <<<"$config" || fail "lock before sleep depends on the idle lock"
echo "ok - Never leaves that step out; sleep still locks first"

for bad in "-1 10 15" "5 x 15" "5 10" "5 10 99999"; do
	# shellcheck disable=SC2086
	if idle $bad 2>/dev/null; then fail "accepted: $bad"; fi
done
echo "ok - refuses bad minutes"
