#!/usr/bin/env bash
# Test suites that load Bloom's modules in-process must not write the real
# user's state (the private event log in particular). Run them against a
# sentinel home and fail if anything lands there.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home"
for suite in display_trial_cases compositor_store_cases retention_cases; do
	env -u XDG_STATE_HOME HOME="$T/home" python3 "$ROOT/tests/cli/$suite.py" > "$T/$suite.log" 2>&1 \
		|| { tail -20 "$T/$suite.log" >&2; echo "FAIL: $suite failed" >&2; exit 1; }
	if [[ -e "$T/home/.local/state/bloom" ]]; then
		find "$T/home/.local/state/bloom" -type f >&2
		echo "FAIL: $suite wrote into the user's state directory" >&2
		exit 1
	fi
done
echo "ok - in-process suites never touch the real user's state"
