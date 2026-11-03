#!/usr/bin/env bash
# Soak checks use stub IPC/journal/service tools, never the live shell.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/soak_cases.py"
