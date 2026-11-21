#!/usr/bin/env bash
# A test's headless sway stops when the test exits, even when the test puts a
# fake systemctl first on PATH (test_session.sh records power actions that way).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
record="$(mktemp)"
trap 'rm -f "$record"' EXIT
bash -c '
	set -euo pipefail
	source "$1/tests/integration/lib.sh"
	bloom_env
	start_sway
	printf "%s\n%s\n" "${SWAY_UNIT:-}" "${SWAY_PID:-}" > "$2"
	mkdir -p "$TEST_TMP/bin"
	printf "#!/bin/sh\nexit 0\n" > "$TEST_TMP/bin/systemctl"
	chmod +x "$TEST_TMP/bin/systemctl"
	export PATH="$TEST_TMP/bin:$PATH"
' _ "$ROOT" "$record"
unit="$(sed -n 1p "$record")"
pid="$(sed -n 2p "$record")"
if [[ -n "$unit" ]] && systemctl --user is-active --quiet "$unit"; then
	systemctl --user stop "$unit" || true
	echo "FAIL: $unit still running after the test exited" >&2
	exit 1
fi
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
	kill "$pid" || true
	echo "FAIL: sway $pid still running after the test exited" >&2
	exit 1
fi
echo "ok - sway stops even with a fake systemctl on PATH"
