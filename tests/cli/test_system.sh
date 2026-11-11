#!/usr/bin/env bash
# System-phase tests use a fake root and stub tools; nothing on this machine changes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/system_cases.py"
