#!/usr/bin/env bash
# The agent hook: Bloom's event mapping, its IPC call, and that it never stalls an agent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$ROOT/tests/cli/agent_hook_cases.py"
