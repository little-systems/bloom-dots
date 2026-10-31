#!/usr/bin/env bash
# Running-app order survives a shell restart. No real Hyprland or app actions.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
unset HYPRLAND_INSTANCE_SIGNATURE
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$HARNESS/"
cp "$ROOT/tests/integration/dock-order-harness.qml" "$HARNESS/shell.qml"
for check in 0 1; do
	if ! BLOOM_DOCK_ORDER_CHECK="$check" timeout 15 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1; then
		fail "running-app order was not retained (phase $check)"
	fi
	log_has 'RESULT dock-order=["class:second","class:first"]' || fail 'wrong running order'
done
jq -e '.order == ["class:second","class:first"]' "$XDG_STATE_HOME/bloom/dock.json" >/dev/null
pass 'running-app order is saved and restored after a shell restart'
