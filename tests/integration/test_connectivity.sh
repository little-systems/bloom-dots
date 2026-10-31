#!/usr/bin/env bash
# The Wi-Fi and Bluetooth panels' services against fake nmcli, busctl,
# dbus-monitor and the agent session: nothing reaches the real NetworkManager or
# BlueZ. Covers Bloom's network list, connect errors and Forget, and
# Bluetooth discovery, pairing with a passkey prompt, and Remove.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":[],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
export FAKE="$TEST_TMP/fake"
mkdir -p "$FAKE"
printf 'Home:802-11-wireless\nWired:802-3-ethernet\n' > "$FAKE/saved"

cat > "$TEST_TMP/bin/nmcli" <<'FAKE_NMCLI'
#!/bin/sh
echo "$*" >> "$FAKE/nmcli.log"
case "$*" in
	monitor) sleep 600 ;;
	*"general status"*) echo "enabled:connected" ;;
	*"connection show"*) cat "$FAKE/saved" ;;
	*"device wifi list"*) printf ' :Home:40:WPA2\n*:Office:30:WPA2 WPA3\n :Cafe:80:WPA2\n :Free:60:--\n :Corp:70:WPA2 802.1X\n' ;;
	*"device wifi connect Cafe"*) echo "Error: Connection activation failed: Secrets were required, but not provided." >&2; exit 4 ;;
	*"connection delete id Home"*) printf 'Wired:802-3-ethernet\n' > "$FAKE/saved" ;;
esac
FAKE_NMCLI

cat > "$TEST_TMP/bin/busctl" <<'FAKE_BUSCTL'
#!/bin/sh
echo "$*" >> "$FAKE/busctl.log"
case "$*" in
	*GetManagedObjects*)
		paired=false; [ -e "$FAKE/paired" ] && paired=true
		discovering=false; [ -e "$FAKE/scanning" ] && discovering=true
		mouse='"/org/bluez/hci0/dev_11":{"org.bluez.Device1":{"Name":{"data":"Old Mouse"},"Address":{"data":"11:11:11:11:11:11"},"Paired":{"data":true},"Icon":{"data":"input-mouse"}}},'
		[ -e "$FAKE/removed" ] && mouse=""
		printf '{"type":"a{oa{sa{sv}}}","data":[{"/org/bluez/hci0":{"org.bluez.Adapter1":{"Powered":{"data":true},"Discovering":{"data":%s}}},%s"/org/bluez/hci0/dev_22":{"org.bluez.Device1":{"Name":{"data":"Buds"},"Address":{"data":"22:22:22:22:22:22"},"Paired":{"data":%s},"Icon":{"data":"audio-headset"}}}}]}\n' "$discovering" "$mouse" "$paired"
		;;
	*RemoveDevice*) touch "$FAKE/removed" ;;
esac
FAKE_BUSCTL

# BlueZ signals its changes; the fake signals every half second.
cat > "$TEST_TMP/bin/dbus-monitor" <<'FAKE_MONITOR'
#!/bin/sh
while :; do echo "signal time=1 sender=:1.5 -> destination=(null destination) path=/org/bluez/hci0; interface=org.freedesktop.DBus.Properties; member=PropertiesChanged"; sleep 0.5; done
FAKE_MONITOR

# The session the shell runs: scanning, then a passkey to confirm.
cat > "$TEST_TMP/bin/fake-agent" <<'FAKE_AGENT'
#!/bin/sh
echo '{"event": "ready"}'
while IFS= read -r line; do
	echo "$line" >> "$FAKE/agent.log"
	case "$line" in
		"scan on") touch "$FAKE/scanning" ;;
		"scan off") rm -f "$FAKE/scanning" ;;
		"pair /org/bluez/hci0/dev_22") echo '{"event": "prompt", "kind": "confirm", "pin": "123456"}' ;;
		"answer yes") touch "$FAKE/paired"; echo '{"event": "paired"}' ;;
	esac
done
FAKE_AGENT
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH" BLOOM_BT_AGENT="$TEST_TMP/bin/fake-agent"
start_shell

# ---- Wi-Fi ----
assert_eq "$(ipc wifi hold true)" "ok" "hold the network service"
listed() { ipc wifi state | jq -e '[.networks[] | [.ssid, .security, .saved, .connected]] == [["Office","wpa3",false,true],["Home","wpa2",true,false],["Cafe","wpa2",false,false],["Corp","enterprise",false,false],["Free","open",false,false]]' >/dev/null; }
wait_for "networks in Bloom's order with security and saved state" listed
pass "networks list connected, saved, then by signal, with Bloom's security labels"
assert_eq "$(ipc wifi connect Cafe)" "ok" "connect to a secured network without a password"
needs_password() { ipc wifi state | jq -e '.error == {"ssid":"Cafe","code":"password-required"} and .busy == ""' >/dev/null; }
wait_for "the password-required error" needs_password
pass "a secured network without a password fails as password-required"
assert_eq "$(ipc wifi forget Home)" "ok" "forget a saved network"
forgotten() { ipc wifi state | jq -e '[.networks[] | select(.saved)] == []' >/dev/null; }
wait_for "Home no longer saved" forgotten
grep -qx -- "-t --escape yes -f NAME,TYPE connection show" "$FAKE/nmcli.log" || fail "saved profiles read"
grep -q "connection delete id Home" "$FAKE/nmcli.log" || fail "forget deletes the profile"
pass "Forget deletes the profile"

# ---- Bluetooth ----
assert_eq "$(ipc bluetooth hold true)" "ok" "hold the Bluetooth service"
assert_eq "$(ipc bluetooth discover true)" "ok" "look for devices"
nearby() { ipc bluetooth state | jq -e '.discovering and ([.nearby[].name] == ["Buds"]) and ([.paired[].name] == ["Old Mouse"])' >/dev/null; }
wait_for "Buds nearby while discovering" nearby
grep -qx "scan on" "$FAKE/agent.log" || fail "the session scans"
pass "discovery runs in the agent session"
assert_eq "$(ipc bluetooth pair /org/bluez/hci0/dev_22)" "ok" "pair Buds"
asks() { ipc bluetooth state | jq -e '.prompt == {"id":"/org/bluez/hci0/dev_22","kind":"confirm","pin":"123456"}' >/dev/null; }
wait_for "the passkey confirmation" asks
pass "the agent's passkey prompt reaches the panel"
assert_eq "$(ipc bluetooth respond true '')" "ok" "confirm the passkey"
paired() { ipc bluetooth state | jq -e '.pairing == "" and .prompt == null and .error == null and ([.paired[].name] | index("Buds")) != null' >/dev/null; }
wait_for "Buds paired" paired
grep -qx "answer yes" "$FAKE/agent.log" || fail "the answer reaches the agent"
pass "confirming the passkey pairs the device"
assert_eq "$(ipc bluetooth discover false)" "ok" "stop looking"
assert_eq "$(ipc bluetooth unpair /org/bluez/hci0/dev_11)" "ok" "remove the old mouse"
removed() { ipc bluetooth state | jq -e '[.paired[].name] == ["Buds"]' >/dev/null; }
wait_for "the mouse removed" removed
grep -q "org.bluez.Adapter1 RemoveDevice o /org/bluez/hci0/dev_11" "$FAKE/busctl.log" || fail "Remove calls RemoveDevice"
pass "Remove forgets the pairing"
assert_eq "$(ipc bluetooth discover true)" "ok" "look again"
wait_for "the session looking" pgrep -f "$TEST_TMP/bin/fake-agent"
pkill -f "$TEST_TMP/bin/fake-agent"
session_lost() { ipc bluetooth state | jq -e '.lookFailed' >/dev/null; }
wait_for "the lost session reported" session_lost
pass "a session that dies is reported, not waited on for ever"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -v textinput; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
