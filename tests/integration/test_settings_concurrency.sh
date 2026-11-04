#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$TEST_TMP/harness" "$XDG_CONFIG_HOME/bloom"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$TEST_TMP/harness/"
cp "$ROOT/tests/integration/settings-concurrency-harness.qml" "$TEST_TMP/harness/shell.qml"
printf '{"bloom-theme-mode":"dark"}' > "$XDG_CONFIG_HOME/bloom/settings.json"
if ! timeout 15 qs --no-color -p "$TEST_TMP/harness" > "$TEST_TMP/shell.log" 2>&1; then fail 'a setting overwrote an editor change'; fi
log_has 'RESULT external-edit-preserved=true' || fail 'missing committed outcome'
pass 'an editor change made after cache load survives a settings write'

# Two independently loaded QML processes commit from the same cached base.
cp "$ROOT/tests/integration/settings-writer-harness.qml" "$TEST_TMP/harness/shell.qml"
cp -r "$TEST_TMP/harness" "$TEST_TMP/harness-b"
printf '{"owner-extra":"keep"}' > "$XDG_CONFIG_HOME/bloom/settings.json"
export BLOOM_WRITER_GATE="$TEST_TMP/release"
BLOOM_WRITER_ROLE=a qs --no-color -p "$TEST_TMP/harness" > "$TEST_TMP/a.log" 2>&1 &
a_pid=$!
BLOOM_WRITER_ROLE=b qs --no-color -p "$TEST_TMP/harness-b" > "$TEST_TMP/b.log" 2>&1 &
b_pid=$!
trap 'kill "$a_pid" "$b_pid" 2>/dev/null || true; bloom_cleanup' EXIT
wait_for 'first process cached settings' grep -q 'READY a' "$TEST_TMP/a.log"
wait_for 'second process cached settings' grep -q 'READY b' "$TEST_TMP/b.log"
printf go > "$BLOOM_WRITER_GATE"
wait "$a_pid" || fail 'first settings writer failed'
wait "$b_pid" || fail 'second settings writer failed'
jq -e '."owner-extra" == "keep" and ."bloom-weather-city" == "Concurrent City" and ."bloom-theme-opacity" == 0.7' "$XDG_CONFIG_HOME/bloom/settings.json" >/dev/null || fail 'a simultaneous QML write was lost'
pass 'independent QML processes preserve both committed changes and unknown keys'
cp "$ROOT/tests/integration/settings-burst-harness.qml" "$TEST_TMP/harness/shell.qml"
if ! timeout 15 qs --no-color -p "$TEST_TMP/harness" > "$TEST_TMP/shell.log" 2>&1; then fail 'rapid local edits failed'; fi
log_has 'RESULT burst-committed=true' || fail 'missing burst commit result'
pass 'rapid local scalar edits commit in order without false conflicts'
