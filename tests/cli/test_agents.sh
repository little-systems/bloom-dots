#!/usr/bin/env bash
# The agents CLI: connect, update and disconnect Claude Code, Codex and OpenCode.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/agents_cases.py"
