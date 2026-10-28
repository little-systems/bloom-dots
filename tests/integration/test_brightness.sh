#!/usr/bin/env bash
# Fake brightnessctl and isolated XDG state; never writes to real backlight.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$TEST_TMP/bin" "$TEST_TMP/harness"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$TEST_TMP/harness/"
cp "$ROOT/tests/integration/brightness-harness.qml" "$TEST_TMP/harness/shell.qml"
printf '50\n' >"$TEST_TMP/percent"
export BLOOM_TEST_BRIGHTNESS_STATE="$TEST_TMP/percent"
export BLOOM_TEST_BRIGHTNESS_LOG="$TEST_TMP/brightness.log"
cat >"$TEST_TMP/bin/brightnessctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$BLOOM_TEST_BRIGHTNESS_LOG"
if [ "$4" = set ]; then
  printf '%s\n' "${5%%%}" >"$BLOOM_TEST_BRIGHTNESS_STATE"
fi
percent=$(cat "$BLOOM_TEST_BRIGHTNESS_STATE")
current=$((1666 * percent / 100))
printf 'intel_backlight,backlight,%s,%s%%,1666\n' "$current" "$percent"
SH
chmod +x "$TEST_TMP/bin/brightnessctl"
export PATH="$TEST_TMP/bin:$PATH"
if ! timeout 6 qs --no-color -p "$TEST_TMP/harness" >"$TEST_TMP/shell.log" 2>&1; then
	fail "brightness harness did not complete"
fi
log_has 'RESULT initial=intel_backlight:50' || fail "initial brightness was not read"
log_has 'RESULT after=60' || fail "set did not read back actual brightness"
grep -Fxq -- '-m -c backlight info' "$TEST_TMP/brightness.log" || fail "discovery argv differed"
grep -Fxq -- '-m -d intel_backlight set 60%' "$TEST_TMP/brightness.log" || fail "set argv differed"
pass "brightness uses validated device and exact argv, then reads back"
