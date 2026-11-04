#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
timeout 40 python3 "$ROOT/tests/integration/display_trial_process.py"
