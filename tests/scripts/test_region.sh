#!/usr/bin/env bash
# shellcheck disable=SC2016  # the fakes' bodies expand when they run, not here
# Region tools with fake slurp, grim and friends on PATH: nothing here captures
# the real screen or starts a real recording.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/shell/scripts/region.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; [[ -f "$T/calls" ]] && sed 's/^/  call: /' "$T/calls" >&2; exit 1; }
called() { grep -q -- "$1" "$T/calls"; }
mkdir -p "$T/bin" "$T/run" "$T/pics"
export PATH="$T/bin:/usr/bin" XDG_RUNTIME_DIR="$T/run" BLOOM_SCREENSHOT_DIR="$T/pics" BLOOM_RECORDING_DIR="$T/pics"
fake() { printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n%s\n' "$1" "$T" "${2:-}" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
fake hyprctl 'if [ "$1" = monitors ]; then echo "[{\"activeWorkspace\":{\"id\":1}}]"; else echo "[{\"at\":[10,20],\"size\":[300,200],\"workspace\":{\"id\":1},\"hidden\":false,\"mapped\":true},{\"at\":[0,0],\"size\":[50,50],\"workspace\":{\"id\":9},\"hidden\":false,\"mapped\":true}]"; fi'
fake slurp 'cat > "'"$T"'/slurp-in"; echo "1,2 30x40"'
fake grim 'for last; do :; done; if [ "$last" = - ]; then printf PNG; else printf PNG > "$last"; fi'
fake wl-copy 'cat > "'"$T"'/clip"'
fake tesseract 'echo recognised text'
fake notify-send
fake swappy 'cat > /dev/null'
fake wf-recorder 'trap "exit 0" INT TERM; sleep 30 & wait'
fake pidof 'exit 1'

bash "$SCRIPT" screenshot
called 'grim -g 1,2 30x40' || fail "grim didn't get the region"
[[ "$(cat "$T/clip")" == PNG ]] || fail "the shot isn't on the clipboard"
ls "$T/pics"/*.png >/dev/null || fail "the shot wasn't saved"
pass_windows="$(cat "$T/slurp-in")"
[[ "$pass_windows" == *"10,20 300x200"* ]] || fail "visible windows aren't offered"
[[ "$pass_windows" != *"0,0 50x50"* ]] || fail "a window on another workspace was offered"
called 'notify-send' || fail "no confirmation"
echo "ok - screenshot copies, saves and offers windows"

bash "$SCRIPT" annotate
called 'swappy -f -' || fail "swappy wasn't used"
echo "ok - annotate uses swappy without satty"

fake satty 'cat > /dev/null'
bash "$SCRIPT" annotate
called 'satty --filename -' || fail "satty wasn't preferred"
echo "ok - annotate prefers satty"

bash "$SCRIPT" ocr
[[ "$(cat "$T/clip")" == "recognised text" ]] || fail "OCR text isn't on the clipboard"
echo "ok - OCR copies the text"

fake trans 'cat > /dev/null; echo hola'
bash "$SCRIPT" translate
[[ "$(cat "$T/clip")" == hola ]] || fail "the translation isn't on the clipboard"
fake trans 'cat > /dev/null; exit 1'
bash "$SCRIPT" translate
called 'notify-send.*reach the translation' || fail "a failed translation wasn't reported"
echo "ok - translate copies the result, and reports a failure"

bash "$SCRIPT" record
called 'wf-recorder -g 1,2 30x40 -f' || fail "recording didn't start"
[[ "$(bash "$SCRIPT" status)" == recording ]] || fail "not reported as recording"
if called 'wf-recorder.*-a'; then fail "audio on a silent recording"; fi
bash "$SCRIPT" record
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ "$(bash "$SCRIPT" status)" == idle ]] && break; sleep 0.2; done
[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "the second press didn't stop it"
echo "ok - record toggles"

# A cancelled selection does nothing, quietly.
: > "$T/calls"
fake slurp 'exit 1'
bash "$SCRIPT" screenshot || fail "cancelling is an error"
if called 'grim'; then fail "captured after a cancel"; fi
echo "ok - cancelling captures nothing"

# Only one selector at a time.
fake slurp 'echo "1,2 30x40"'
fake pidof 'exit 0'
: > "$T/calls"
bash "$SCRIPT" screenshot
if called 'grim'; then fail "a second selector ran"; fi
fake pidof 'exit 1'
echo "ok - a running selector isn't doubled"

# A missing tool says so instead of failing silently.
rm "$T/bin/tesseract"
PATH="$T/bin" /usr/bin/bash "$SCRIPT" ocr || true
called 'notify-send.*tesseract' || fail "a missing tool wasn't reported"
echo "ok - a missing tool is reported"

bash "$SCRIPT" nonsense 2>/dev/null && fail "an unknown action was accepted"
echo "ok - unknown actions are refused"
