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
export BLOOM_TEST_BRIGHTNESS_EVENT="$TEST_TMP/event"
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
cat >"$TEST_TMP/bin/udevadm" <<'SH'
#!/bin/sh
printf 'udevadm %s\n' "$*" >>"$BLOOM_TEST_BRIGHTNESS_LOG"
while [ ! -e "$BLOOM_TEST_BRIGHTNESS_EVENT" ]; do sleep 0.05; done
printf 'KERNEL[1.0] change /devices/backlight/intel_backlight (backlight)\n'
sleep 10
SH
chmod +x "$TEST_TMP/bin/brightnessctl" "$TEST_TMP/bin/udevadm"
export PATH="$TEST_TMP/bin:$PATH"
(
	for _ in $(seq 1 160); do
		if grep -q 'RESULT after=60' "$TEST_TMP/shell.log" 2>/dev/null; then break; fi
		sleep 0.05
	done
	printf '80\n' >"$TEST_TMP/percent"
	touch "$BLOOM_TEST_BRIGHTNESS_EVENT"
) &
if ! timeout 10 qs --no-color -p "$TEST_TMP/harness" >"$TEST_TMP/shell.log" 2>&1; then
	fail "brightness harness did not complete"
fi
log_has 'RESULT initial=intel_backlight:50' || fail "initial brightness was not read"
log_has 'RESULT after=60' || fail "set did not read back actual brightness"
log_has 'RESULT external=80' || fail "external change did not arrive by udev event"
grep -Fxq -- '-m -c backlight info' "$TEST_TMP/brightness.log" || fail "discovery argv differed"
grep -Fxq -- '-m -d intel_backlight set 60%' "$TEST_TMP/brightness.log" || fail "set argv differed"
grep -Fxq -- 'udevadm monitor --kernel --subsystem-match=backlight' "$TEST_TMP/brightness.log" || fail "monitor argv differed"
[[ "$(grep -Fxc -- '-m -c backlight info' "$TEST_TMP/brightness.log")" == 3 ]] || fail "brightness polled while hidden"
pass "brightness reads initial, write-back, and udev event without hidden polling"
