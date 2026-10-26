#!/usr/bin/env bash
# A stand-in checkupdates for tests: the first line of $BLOOM_FAKE_UPDATES is
# the exit code, the rest is printed. "hang" as the code never answers.
set -euo pipefail
code="$(head -1 "$BLOOM_FAKE_UPDATES")"
if [[ "$code" == hang ]]; then exec sleep 600; fi
tail -n +2 "$BLOOM_FAKE_UPDATES"
exit "$code"
