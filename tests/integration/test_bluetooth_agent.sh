#!/usr/bin/env bash
# shell/scripts/bluetooth-agent.py against a fake BlueZ on a private bus:
# registering as the agent, discovery, pairing by passkey confirmation and by
# PIN, a refusal, a timeout, then trusting and connecting. Nothing reaches the
# real Bluetooth.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(dbus-daemon --config-file="$HERE/dbus-session.conf" --fork --print-address=1 --print-pid=1 | {
	read -r address
	read -r pid
	printf 'BUS=%q\nBUS_PID=%q\n' "$address" "$pid"
})"
trap 'kill "$BUS_PID" 2>/dev/null || true; bloom_cleanup' EXIT
export DBUS_SESSION_BUS_ADDRESS="$BUS"

python3 "$HERE/fake_bluez.py" > "$TEST_TMP/bluez.log" 2>&1 &
FAKE_PID=$!
wait_for "the fake BlueZ" grep -q READY "$TEST_TMP/bluez.log"

coproc AGENT { BLOOM_BT_BUS="$BUS" python3 "$ROOT/shell/scripts/bluetooth-agent.py" 2>&1; }
send() { printf '%s\n' "$1" >&"${AGENT[1]}"; }
# The next event line, within 5 s.
event() { local line; read -r -t 5 line <&"${AGENT[0]}" || fail "no event after: $1"; printf '%s' "$line"; }

assert_eq "$(event "start")" '{"event": "ready"}' "registers as the agent, then is ready"
grep -q "CALL RegisterAgent /org/bluez ('/org/bloom/BluetoothAgent', 'KeyboardDisplay')" "$TEST_TMP/bluez.log" || fail "RegisterAgent KeyboardDisplay"
grep -q "CALL RequestDefaultAgent" "$TEST_TMP/bluez.log" || fail "RequestDefaultAgent"
pass "the agent registers as BlueZ's default"

send "scan on"
wait_for "StartDiscovery" grep -q "CALL StartDiscovery /org/bluez/hci0" "$TEST_TMP/bluez.log"
pass "scan on starts discovery on the adapter"

send "pair /org/bluez/hci0/dev_22"
assert_eq "$(event "pair dev_22")" '{"event": "prompt", "kind": "confirm", "pin": "123456"}' "the passkey to confirm"
send "answer yes"
assert_eq "$(event "answer yes")" '{"event": "paired"}' "confirmed: paired"
wait_for "trusted and connected" grep -q "CALL Connect /org/bluez/hci0/dev_22" "$TEST_TMP/bluez.log"
grep -q "CALL Set /org/bluez/hci0/dev_22 ('org.bluez.Device1', 'Trusted', <true>)" "$TEST_TMP/bluez.log" || fail "trusted"
pass "a confirmed passkey pairs, then the device is trusted and connected"

send "pair /org/bluez/hci0/dev_22"
event "pair again" >/dev/null
send "answer no"
assert_eq "$(event "answer no")" '{"event": "failed", "error": "org.bluez.Error.AuthenticationRejected"}' "declined"
pass "declining the passkey fails the pairing"

send "pair /org/bluez/hci0/dev_33"
assert_eq "$(event "pair dev_33")" '{"event": "prompt", "kind": "provide"}' "asks for the PIN"
send "pin 0000"
assert_eq "$(event "pin")" '{"event": "paired"}' "the right PIN pairs"
pass "a PIN typed in pairs"

send "pair /org/bluez/hci0/dev_44"
assert_eq "$(event "pair dev_44")" '{"event": "failed", "error": "org.bluez.Error.AuthenticationTimeout"}' "times out"
pass "a timeout is reported with BlueZ's error"

send "scan off"
wait_for "StopDiscovery" grep -q "CALL StopDiscovery /org/bluez/hci0" "$TEST_TMP/bluez.log"
kill "$FAKE_PID" 2>/dev/null || true
pass "scan off stops discovery"
