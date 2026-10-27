#!/usr/bin/env bash
# SNI adapter against an isolated D-Bus and a fake item, never the user's tray.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$TEST_TMP/harness"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$TEST_TMP/harness/"
cp "$ROOT/tests/integration/dock-tray-harness.qml" "$TEST_TMP/harness/shell.qml"

dbus-run-session --config-file="$ROOT/tests/integration/dbus-session.conf" -- bash -c '
  python "$1" >"$2/fake.log" 2>&1 &
  fake_pid=$!
  timeout 10 qs --no-color -p "$2/harness" >"$2/shell.log" 2>&1
  rc=$?
  kill "$fake_pid" 2>/dev/null || true
  wait "$fake_pid" 2>/dev/null || true
  exit "$rc"
' bash "$ROOT/tests/integration/fake_sni.py" "$TEST_TMP" || fail "isolated tray adapter did not finish"
log_has 'RESULT tray=org.example.BloomTest' || fail "fake SNI item was not projected"
log_has 'RESULT activate=ok' || fail "activate was not dispatched"
log_has 'RESULT secondary=ok' || fail "secondary activation was not dispatched"
log_has 'RESULT passive-hidden' || fail "Passive SNI item remained in the dock"
log_has 'RESULT cleared' || fail "adapter did not clear its handles on teardown"
log_has 'RESULT menu=ok' || fail "native menu handle was not used"
log_has 'RESULT only-menu=ok' || fail "only-menu activation did not display its menu"
log_has 'RESULT displays=12,34;56,78' || fail "native menu coordinates were not forwarded"
grep -Fxq 'FAKE activated' "$TEST_TMP/fake.log" || fail "fake item did not receive activation"
grep -Fxq 'FAKE secondary' "$TEST_TMP/fake.log" || fail "fake item did not receive secondary activation"
pass "lazy SNI adapter projects a fake item and clears it on teardown"
