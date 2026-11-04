#!/usr/bin/env bash
# Exercise the real SystemStore setter with only a fake compositor backend.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
H="$TEST_TMP/harness"
mkdir -p "$H" "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$ROOT/shell/settings" "$ROOT/shell/scripts" "$H/"
cp "$ROOT/tests/integration/compositor-store-harness.qml" "$H/shell.qml"
printf '{"bloom-weather-enabled":false}' > "$XDG_CONFIG_HOME/bloom/settings.json"
export BLOOM_COMPOSITOR_TEST_VALUE="$TEST_TMP/gap"
printf 4 > "$BLOOM_COMPOSITOR_TEST_VALUE"
cat > "$TEST_TMP/bin/hyprctl" <<'SH'
#!/bin/sh
case "$1" in
    getoption) printf 'int: %s\n' "$(cat "$BLOOM_COMPOSITOR_TEST_VALUE")" ;;
    eval) printf 8 > "$BLOOM_COMPOSITOR_TEST_VALUE" ;;
    *) printf '[]\n' ;;
esac
SH
chmod +x "$TEST_TMP/bin/hyprctl"
PATH="$TEST_TMP/bin:$PATH" timeout 15 qs --no-color -p "$H" > "$TEST_TMP/shell.log" 2>&1 || fail 'SystemStore did not commit verified preferences'
log_has 'RESULT compositor-committed=true' || fail 'compositor commit not confirmed'
[[ ! -e "$XDG_STATE_HOME/bloom/hypr-settings.json" ]] || fail 'retired JSON file was written separately'
pass 'public SystemStore setter persists config and state in one canonical document'
