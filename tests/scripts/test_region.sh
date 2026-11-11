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
# Like the real OCR process, drain the image before returning text. Exiting
# early races grim's write and can make pipefail report SIGPIPE (141).
fake tesseract 'cat > /dev/null; echo recognised text'
fake notify-send
fake swappy 'cat > /dev/null'
# Like the real recorder (a C program with its own SIGINT handler), the file
# is finished when it is interrupted. A sh fake can't trap a signal ignored at
# start, as background jobs' SIGINT is, so this one is Python.
cat > "$T/bin/wf-recorder" <<FAKE_RECORDER
#!/usr/bin/python3
import os, signal, sys, time
out = sys.argv[sys.argv.index("-f") + 1]
def finish(*_):
    if not os.environ.get("FAKE_REC_LOSE"):
        open(out, "w").write("MP4")
    sys.exit(0)
# Handlers first: the test stops the recorder as soon as the call is logged.
signal.signal(signal.SIGINT, finish)
signal.signal(signal.SIGTERM, finish)
with open("$T/calls", "a") as calls:
    calls.write("wf-recorder " + " ".join(sys.argv[1:]) + "\\n")
time.sleep(30)
FAKE_RECORDER
chmod +x "$T/bin/wf-recorder"
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
for _ in $(seq 1 30); do
	called 'wf-recorder -g 1,2 30x40 -f' && break
	sleep 0.1
done
called 'wf-recorder -g 1,2 30x40 -f' || fail "recording didn't start"
[[ "$(bash "$SCRIPT" status)" == recording ]] || fail "not reported as recording"
if called 'wf-recorder.*-a'; then fail "audio on a silent recording"; fi
bash "$SCRIPT" record || fail "stopping the recording failed"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ "$(bash "$SCRIPT" status)" == idle ]] && break; sleep 0.2; done
[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "the second press didn't stop it"
ls "$T/pics"/Recording_*.mp4 >/dev/null 2>&1 || fail "the recording file wasn't finished"
called 'notify-send.*Recording saved' || fail "a finished recording wasn't announced"
echo "ok - record toggles, and stopping waits for a finished file"

# A recorder that stops without producing a file is reported, not "saved".
: > "$T/calls"
FAKE_REC_LOSE=1 bash "$SCRIPT" record
for _ in $(seq 1 30); do [[ "$(bash "$SCRIPT" status)" == recording ]] && break; sleep 0.1; done
if bash "$SCRIPT" record; then fail "a lost recording reported success"; fi
called 'notify-send.*Recording failed' || fail "a lost recording wasn't reported"
if called 'notify-send.*Recording saved'; then fail "a lost recording was announced as saved"; fi
echo "ok - a recording that produced no file is reported as failed"

# A stale record whose PID now belongs to something else is never signalled.
sleep 300 & other=$!
printf '%s\n1\n%s/x.mp4\n' "$other" "$T/pics" > "$T/run/bloom-recording.pid"
[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "a reused PID was taken for the recorder"
printf '%s\n' "$other" > "$T/run/bloom-recording.pid"
[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "a legacy record with a reused PID was trusted"
: > "$T/calls"
bash "$SCRIPT" record
kill -0 "$other" 2>/dev/null || fail "an unrelated process was interrupted"
for _ in $(seq 1 30); do called 'wf-recorder -g' && break; sleep 0.1; done
called 'wf-recorder -g' || fail "a stale record blocked a new recording"
bash "$SCRIPT" record || true
kill "$other"
echo "ok - a reused PID is never signalled and doesn't block recording"

# A recorder that exited but wasn't reaped (some containers' init never reaps
# orphans) is a zombie with the same name and start time: it is finished.
mkdir -p "$T/zombie-bin"
printf '#!/bin/sh\nexit 0\n' > "$T/zombie-bin/wf-recorder"
chmod +x "$T/zombie-bin/wf-recorder"
python3 - "$T/zombie-bin/wf-recorder" "$T/zombie.pid" <<'PY' &
import os, sys, time
pid = os.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1]])
open(sys.argv[2], "w").write(str(pid))
time.sleep(20)  # never reaps the child
PY
parent=$!
for _ in $(seq 1 30); do [[ -s "$T/zombie.pid" ]] && grep -q ' Z ' "/proc/$(cat "$T/zombie.pid")/stat" 2>/dev/null && break; sleep 0.1; done
zombie="$(cat "$T/zombie.pid")"
grep -q ' Z ' "/proc/$zombie/stat" || fail "fixture: no zombie recorder"
printf '%s\n%s\n%s/z.mp4\n' "$zombie" "$(awk '{ print $22 }' "/proc/$zombie/stat")" "$T/pics" > "$T/run/bloom-recording.pid"
[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "an exited, unreaped recorder was taken as still recording"
kill "$parent" 2>/dev/null; wait "$parent" 2>/dev/null || true
rm -f "$T/run/bloom-recording.pid"
echo "ok - an exited recorder that was never reaped counts as finished"

# Full display recording uses the focused output, never a region selector.
fake hyprctl 'echo "[{\"name\":\"DP-2\",\"focused\":false},{\"name\":\"eDP-1\",\"focused\":true}]"'
for action in record-screen record-screen-audio; do
	: > "$T/calls"
	bash "$SCRIPT" "$action"
	for _ in $(seq 1 30); do called 'wf-recorder -o eDP-1 -f' && break; sleep 0.1; done
	called 'wf-recorder -o eDP-1 -f' || fail "fullscreen didn't use the focused display"
	if called slurp; then fail "fullscreen asked for a region"; fi
	if [[ "$action" == record-screen-audio ]]; then
		called 'wf-recorder.*-a' || fail "audio wasn't requested"
	elif called 'wf-recorder.*-a'; then fail "silent fullscreen requested audio"; fi
	bash "$SCRIPT" "$action"
	[[ "$(bash "$SCRIPT" status)" == idle ]] || fail "fullscreen didn't stop"
done
fake hyprctl 'echo "[]"'
: > "$T/calls"
if bash "$SCRIPT" record-screen; then fail "recording without a focused output was accepted"; fi
if called wf-recorder; then fail "recorded every screen after missing focused output"; fi
echo "ok - fullscreen recording selects the focused output, handles audio, and refuses a missing output"

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
