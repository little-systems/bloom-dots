#!/usr/bin/env bash
# A stand-in checkupdates for tests: the first line of $BLOOM_FAKE_UPDATES is
# the exit code, the rest is printed. "hang" never answers, trapping TERM as
# the real checkupdates does (bash defers the trap until its foreground
# command ends, so a plain SIGTERM can't stop it).
set -euo pipefail
code="$(head -1 "$BLOOM_FAKE_UPDATES")"
if [[ "$code" == hang ]]; then
	trap 'exit 1' TERM
	sleep 600
	exit 1
fi
tail -n +2 "$BLOOM_FAKE_UPDATES"
exit "$code"
