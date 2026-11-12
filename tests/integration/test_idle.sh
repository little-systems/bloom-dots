#!/usr/bin/env bash
# The lock module runs hypridle (a stub here) with the idle settings, and runs
# it again with new minutes when they change.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
cat > "$TEST_TMP/bin/hypridle" <<SH
#!/bin/sh
cp "\$2" "$TEST_TMP/hypridle.conf"
exec sleep 300
SH
chmod +x "$TEST_TMP/bin/hypridle"
export PATH="$TEST_TMP/bin:$PATH"
printf '{"bloom-enabled-modules":["lock"],"bloom-idle-lock":2}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
timeouts() { grep -o '^    timeout = [0-9]*' "$TEST_TMP/hypridle.conf" 2>/dev/null | tr '\n' ' '; }
started() { [[ "$(timeouts)" == "    timeout = 120     timeout = 600     timeout = 900 " ]]; }
wait_for "hypridle with the settings' minutes" started
pass "the lock module starts hypridle with the idle settings"
"$ROOT/bin/bloom" ipc settings set bloom-idle-lock 0 >/dev/null
restarted() { [[ "$(timeouts)" == "    timeout = 600     timeout = 900 " ]]; }
wait_for "hypridle with the new minutes" restarted
pass "a changed setting restarts it; Never drops that step"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "$ENV_ONLY_WARNINGS"; then fail "shell log has warnings"; fi
