#!/usr/bin/env bash
# QML's XMLHttpRequest has no working timeout; Http must end a stalled request
# itself so a captive portal or dead network can't freeze callers.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# A server that accepts connections and never answers.
python3 -c '
import socket, sys, time
s = socket.socket(); s.bind(("127.0.0.1", 0)); s.listen(8)
print(s.getsockname()[1], flush=True)
conns = []
while True:
    c, _ = s.accept(); conns.append(c)
' >"$TEST_TMP/port" &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true; bloom_cleanup' EXIT
wait_for "the silent server" test -s "$TEST_TMP/port"

HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$HARNESS/"
cp "$ROOT/tests/integration/http-harness.qml" "$HARNESS/shell.qml"

if ! BLOOM_TEST_PORT="$(cat "$TEST_TMP/port")" timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1; then
	fail "a stalled request never finished"
fi
log_has "RESULT hang json=null" || fail "unexpected harness result"
log_has "calls=1" || fail "callback count"
grep -q "calls=2" "$TEST_TMP/shell.log" && fail "the callback ran twice"
ms="$(grep -o 'ms=[0-9]*' "$TEST_TMP/shell.log" | head -1 | cut -d= -f2)"
(( ms >= 400 && ms < 3000 )) || fail "timed out after ${ms} ms, expected about 500"
pass "a stalled request ends with null after its timeout, once"
