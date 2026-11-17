#!/usr/bin/env bash
# Catalog sync from Bloom (shared translations).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/i18n_cases.py"
