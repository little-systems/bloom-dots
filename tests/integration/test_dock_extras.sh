#!/usr/bin/env bash
# Runs discovery/actions with fake executables and isolated XDG state only.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

mkdir -p "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/harness"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$TEST_TMP/harness/"
cp "$ROOT/tests/integration/dock-extras-harness.qml" "$TEST_TMP/harness/shell.qml"
printf '{"bloom-enabled-modules":["dock"],"bloom-dock-mode":"fixed","bloom-dock-extras-position":"left","bloom-dock-extras-folders":"downloads","bloom-dock-extras-recycle-bin":true}\n' >"$XDG_CONFIG_HOME/bloom/settings.json"

cat >"$TEST_TMP/bin/lsblk" <<'SH'
#!/bin/sh
if [ -f "$BLOOM_TEST_DRIVE_MARKER" ]; then
  printf '%s\n' '{"blockdevices":[{"path":"/dev/bloom-test1","uuid":"USB","label":"Fixture","fstype":"vfat","mountpoint":"/run/media/test/USB","rm":true,"hotplug":true,"type":"part"},{"path":"/dev/bloom-test2","uuid":"USB2","label":"Fixture2","fstype":"vfat","mountpoint":null,"rm":true,"hotplug":true,"type":"part"},{"path":"/dev/bloom-root","uuid":"ROOT","fstype":"ext4","mountpoint":"/","rm":false,"type":"part"}]}'
else
  printf '%s\n' '{"blockdevices":[{"path":"/dev/bloom-test1","uuid":"USB","label":"Fixture","fstype":"vfat","mountpoint":"/run/media/test/USB","rm":true,"hotplug":true,"type":"part"},{"path":"/dev/bloom-test2","uuid":"USB2","label":"Fixture2","fstype":"vfat","mountpoint":null,"rm":true,"hotplug":true,"type":"part"},{"path":"/dev/bloom-stale","uuid":"STALE","label":"Removed","fstype":"vfat","mountpoint":null,"rm":true,"hotplug":true,"type":"part"},{"path":"/dev/bloom-root","uuid":"ROOT","fstype":"ext4","mountpoint":"/","rm":false,"type":"part"}]}'
fi
SH
cat >"$TEST_TMP/bin/xdg-user-dir" <<SH
#!/bin/sh
printf '%s\\n' '$TEST_TMP/Downloads'
SH
cat >"$TEST_TMP/bin/gio" <<SH
#!/bin/sh
printf '%s\\n' "\$*" >>'$TEST_TMP/gio.log'
case "\$*" in
  'info -a trash::item-count trash:///') printf '%s\\n' 'trash::item-count: 2' ;;
  'info -a standard::type $TEST_TMP/Downloads') printf '%s\\n' 'standard::type: directory' ;;
esac
SH
cat >"$TEST_TMP/bin/udisksctl" <<SH
#!/bin/sh
printf '%s\\n' "\$*" >>'$TEST_TMP/udisks.log'
[ "\$1" = monitor ] && sleep 6
[ "\$1" = mount ] && printf '%s\\n' 'Mounted /dev/bloom-test2 at /run/media/test/My. USB2.'
exit 0
SH
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
export BLOOM_TEST_DRIVE_MARKER="$TEST_TMP/drive-removed"

if ! timeout 10 qs --no-color -p "$TEST_TMP/harness" >"$TEST_TMP/shell.log" 2>&1; then
	fail "dock extras harness did not complete"
fi
log_has 'RESULT items=drive:USB,drive:USB2,drive:STALE,folder:downloads,trash' || fail "expected fixture drives, Downloads and trash"
log_has 'RESULT missing=no such extra' || fail "unknown drive was not rejected"
log_has 'RESULT stale-toast=Drive is no longer available' || fail "stale drive was not rejected after a fresh scan"
log_has 'RESULT no-confirm=confirmation required' || fail "trash empty lacked confirmation gate"
log_has 'RESULT open=ok' || fail "fixture drive did not open"
grep -Fxq 'open /run/media/test/USB' "$TEST_TMP/gio.log" || fail "gio open did not receive the exact mount path"
grep -Fxq 'mount -b /dev/bloom-test2' "$TEST_TMP/udisks.log" || fail "unmounted drive did not mount by device argv"
grep -Fxq 'open /run/media/test/My. USB2' "$TEST_TMP/gio.log" || fail "mounted drive did not open the full returned path"
grep -Fxq 'unmount -b /dev/bloom-test1' "$TEST_TMP/udisks.log" || fail "eject did not unmount first"
grep -Fxq 'power-off -b /dev/bloom-test1' "$TEST_TMP/udisks.log" || fail "eject did not attempt power-off: $(cat "$TEST_TMP/udisks.log")"
grep -Fxq 'trash --empty' "$TEST_TMP/gio.log" || fail "confirmed empty did not reach fake gio"
pass "extras discovery and guarded actions use only fake commands and exact argv"

start_sway
start_shell
extras_visible() { ipc dock state | jq -e '.[0].keys == ["extra:drive:USB","extra:drive:USB2","extra:folder:downloads","extra:trash"]' >/dev/null; }
extras_gone() { ipc dock state | jq -e '.[0].keys == []' >/dev/null; }
wait_for "extras to appear in the real dock" extras_visible
ipc settings set bloom-dock-extras-position off >/dev/null
wait_for "extras setting to remove the tiles" extras_gone
pass "the real dock places extras and removes them when the setting turns off"
