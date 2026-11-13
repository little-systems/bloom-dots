#!/usr/bin/env bash
# The supervision units must load cleanly.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
systemd-analyze verify "$ROOT/systemd/bloom-shell.service" "$ROOT/systemd/bloom-shell-failed.service"
grep -qx 'Restart=on-failure' "$ROOT/systemd/bloom-shell.service"
grep -qx 'StartLimitBurst=5' "$ROOT/systemd/bloom-shell.service"
grep -qx 'OnFailure=bloom-shell-failed.service' "$ROOT/systemd/bloom-shell.service"
echo "ok - systemd units verify"
python3 "$ROOT/tests/units/session_start_cases.py"
python3 "$ROOT/tests/units/reduce_motion_cases.py"
