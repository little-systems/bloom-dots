#!/usr/bin/env bash
# Lifecycle tests use private homes, stub tools, and local Git repositories.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/lifecycle_cases.py"
