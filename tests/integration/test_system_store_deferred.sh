#!/usr/bin/env bash
# Settings defers SystemStore's queries until its window is up.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
H="$TEST_TMP/harness"
mkdir -p "$H" "$XDG_CONFIG_HOME/bloom"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$ROOT/shell/settings" "$ROOT/shell/scripts" "$H/"
cp "$ROOT/tests/integration/system-store-deferred-harness.qml" "$H/shell.qml"
printf '{"bloom-weather-enabled":false}' > "$XDG_CONFIG_HOME/bloom/settings.json"
timeout 15 qs --no-color -p "$H" > "$TEST_TMP/shell.log" 2>&1 || fail 'the deferred store never started'
log_has 'RESULT idle=true' || fail 'a store told not to auto-start queried anyway'
log_has 'RESULT started=true' || fail 'start() did not run the queries'
pass 'SystemStore waits for start() when auto-start is off'
