#!/usr/bin/env bash
# Tray icon owners: each D-Bus tray item's process, for matching it to its app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/tray_owners_cases.py"
