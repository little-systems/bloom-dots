#!/usr/bin/env bash
# A stand-in file picker: prints the first line of $BLOOM_FAKE_PICK and
# exits with the second (0 chosen, 1 cancelled).
set -euo pipefail
sed -n 1p "$BLOOM_FAKE_PICK"
exit "$(sed -n 2p "$BLOOM_FAKE_PICK")"
