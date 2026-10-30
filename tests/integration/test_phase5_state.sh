#!/usr/bin/env bash
# Restores an active Pomodoro without opening Calendar, and checks shelf state.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-music-mode-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
deadline=$(( $(date +%s%3N) + 4000 ))
printf '{"todos":[{"id":1,"text":"restored task","done":false}],"durationSec":1500,"deadlineMs":%s,"pausedSec":3}\n' "$deadline" > "$XDG_STATE_HOME/bloom/calendar.json"
cat > "$TEST_TMP/bin/notify-send" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$BLOOM_NOTIFY_LOG"
FAKE
chmod +x "$TEST_TMP/bin/notify-send"
export PATH="$TEST_TMP/bin:$PATH" BLOOM_NOTIFY_LOG="$TEST_TMP/notifications.log"
start_shell

# A calendar.json from before the task list was removed (owner, 2026-10-29)
# still restores its timer; its todos are dropped.
timer_restored() { ipc calendar state | jq -e '.durationSec == 1500 and (has("todos") | not)' >/dev/null; }
timer_finished() { ipc calendar state | jq -e '.deadlineMs == 0 and .pausedSec == 0 and .finished' >/dev/null; }
wait_for "the timer restored without opening Calendar" timer_restored
WAIT_S=9 wait_for "Pomodoro expiry after restart" timer_finished
wait_for "one local completion notification" test -f "$BLOOM_NOTIFY_LOG"
assert_eq "$(wc -l < "$BLOOM_NOTIFY_LOG")" "1" "single completion notification"
pass "Pomodoro resumes and expires once without opening Calendar"

wait_for "the saved state drops the old todos" jq -e 'has("todos") | not' "$XDG_STATE_HOME/bloom/calendar.json"
pass "old saved todos are dropped"

assert_eq "$(ipc shelf addText 'temporary note')" "ok" "add temporary shelf text"
assert_eq "$(ipc shelf state | jq -r '.[0].value')" "temporary note" "shelf state"
[[ ! -e "$XDG_STATE_HOME/bloom/shelf.json" ]] || fail "Shelf persisted with its setting off"
ipc settings set bloom-shelf-persist true >/dev/null
assert_eq "$(ipc shelf addText 'saved note')" "ok" "add saved shelf text"
wait_for "shelf persisted after opt-in" jq -e '.[0].value == "saved note" and .[1].value == "temporary note"' "$XDG_STATE_HOME/bloom/shelf.json"
pass "Shelf persistence follows its setting"

# Bloom's shelf rules through the real service: files dropped together all
# go on (each checked to exist), folders too, newest first; a duplicate is
# skipped; a text file shows its opening; a full shelf refuses with Bloom's
# notice.
SHELF_DIR="$TEST_TMP/shelf-files"
mkdir -p "$SHELF_DIR/Photos"
printf 'first line\nsecond line\n' > "$SHELF_DIR/notes.md"
printf 'x' > "$SHELF_DIR/clip.mp4"
assert_eq "$(ipc shelf addFile "$SHELF_DIR/notes.md")" "checking" "add a text file"
assert_eq "$(ipc shelf addFile "$SHELF_DIR/Photos")" "checking" "add a folder right after"
assert_eq "$(ipc shelf addFile "$SHELF_DIR/clip.mp4")" "checking" "and a third"
three_files() { ipc shelf state | jq -e --arg d "$SHELF_DIR" '[.[] | select(.kind == "file") | .value] == [$d + "/clip.mp4", $d + "/Photos", $d + "/notes.md"]' >/dev/null; }
wait_for "all three files, newest first" three_files
pass "files added back to back all go on, folders included"
assert_eq "$(ipc shelf addFile "$SHELF_DIR/notes.md")" "checking" "add a file again"
sleep 1
assert_eq "$(ipc shelf state | jq --arg p "$SHELF_DIR/notes.md" '[.[] | select(.value == $p)] | length')" "1" "a duplicate is skipped"
previews() { ipc shelf details | jq -e --arg d "$SHELF_DIR" '.previews[$d + "/notes.md"] == {"kind":"text","thumb":"","text":"first line\nsecond line\n"} and .previews[$d + "/Photos"].kind == "folder"' >/dev/null; }
wait_for "previews for the text file and the folder" previews
pass "a text file shows its opening and a folder is a folder"
for i in 1 2 3 4 5; do ipc shelf addText "filler $i" >/dev/null; done
assert_eq "$(ipc shelf state | jq length)" "10" "the shelf is full"
assert_eq "$(ipc shelf addText 'one too many')" "Shelf is full (10) — remove an item first" "a full shelf refuses"
assert_eq "$(ipc shelf details | jq -r .notice)" "Shelf is full (10) — remove an item first" "with Bloom's notice"
assert_eq "$(ipc shelf state | jq length)" "10" "and keeps every item"
pass "a full shelf refuses new items with Bloom's notice"
