#!/usr/bin/env bash
# CLI tests with stubbed qs/systemctl/journalctl/hyprctl and a throwaway HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" STUB_LOG="$TMP/stub.log"
mkdir -p "$HOME" "$TMP/stub"
export PATH="$TMP/stub:$PATH"

stub() {
	printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "%s" "$*" >>"$STUB_LOG"\n%s\n' "$1" "$2" >"$TMP/stub/$1"
	chmod +x "$TMP/stub/$1"
}
stub qs 'if [[ "$*" == *"ipc call settings result "* && -n "${STUB_QS_RESULT:-}" ]]; then echo "$STUB_QS_RESULT"; exit 0; fi; if [[ "$1" == --version ]]; then echo "Quickshell 0.3.2 (stub)"; exit 0; fi; if [[ -n "${STUB_QS_SLEEP:-}" ]]; then sleep "$STUB_QS_SLEEP"; fi; if [[ -n "${STUB_QS_OUT:-}" ]]; then echo "$STUB_QS_OUT"; elif [[ "$*" == *"ipc call settings"* ]]; then echo "{}"; fi; exit "${STUB_QS_EXIT:-0}"'
stub systemctl 'echo "bloom-shell.service (stub)"'
stub journalctl 'echo "journal line (stub)"'
stub hyprctl 'case "$1" in version) echo "{\"tag\":\"v0.56.2\"}";; getoption) echo "bool: true";; esac'

BLOOM="$ROOT/bin/bloom"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$*"; }

# version
[[ "$("$BLOOM" version)" == "$(cat "$ROOT/VERSION")"* ]] || fail "version"
pass "version prints VERSION"

# usage errors
if "$BLOOM" >/dev/null 2>&1; then fail "no command should fail"; fi
if "$BLOOM" nope >/dev/null 2>&1; then fail "unknown command should fail"; fi
if "$BLOOM" ipc shell >/dev/null 2>&1; then fail "ipc without a function should fail"; fi
grep -q "dev install" <<<"$("$BLOOM" help)" || fail "help lists commands"
pass "usage errors exit non-zero; help lists commands"

# ipc forwards and keeps qs's exit code (review focus 5)
"$BLOOM" ipc shell ping
grep -qx 'qs -c bloom ipc call shell ping' "$STUB_LOG" || fail "ipc forwarding"
set +e
STUB_QS_EXIT=255 "$BLOOM" ipc shell ping
code=$?
set -e
[[ $code -eq 255 ]] || fail "ipc exit code: $code"
pass "ipc forwards to qs and keeps its exit code"

# settings set must fail visibly when the shell rejects the value, so scripts can rely on it.
set +e
out="$(STUB_QS_OUT="bloom-theme-opacity: expected a number from 0 to 1" "$BLOOM" ipc settings set bloom-theme-opacity 9 2>&1)"
code=$?
set -e
[[ $code -ne 0 ]] || fail "settings set reported success for a rejected value"
grep -qF "expected a number from 0 to 1" <<<"$out" || fail "settings set error text missing: $out"
STUB_QS_OUT=ok "$BLOOM" ipc settings set bloom-theme-opacity 0.5 >/dev/null || fail "settings set ok should exit 0"
pass "settings set exits non-zero when the value is rejected"

# A queued receipt is not success; terminal storage results determine exit.
out="$(STUB_QS_OUT=pending:settings-1 STUB_QS_RESULT='{"state":"succeeded","error":""}' "$BLOOM" ipc settings set bloom-theme-opacity 0.5)"
[[ "$out" == ok ]] || fail "pending success was not awaited"
if STUB_QS_OUT=pending:settings-2 STUB_QS_RESULT='{"state":"failed","error":"fixture conflict"}' "$BLOOM" ipc settings set bloom-theme-opacity 0.6 > "$TMP/failed-result"; then
    fail "queued conflict reported success"
fi
grep -q 'fixture conflict' "$TMP/failed-result" || fail "queued error missing"
pass "CLI waits for commit and propagates asynchronous failure"

# dev install / status / uninstall
"$BLOOM" dev install >/dev/null
[[ "$(readlink "$XDG_CONFIG_HOME/quickshell/bloom")" == "$ROOT/shell" ]] || fail "shell link"
for u in bloom-shell.service bloom-shell-failed.service; do
	[[ "$(readlink "$XDG_CONFIG_HOME/systemd/user/$u")" == "$ROOT/systemd/$u" ]] || fail "unit link $u"
done
grep -qx 'systemctl --user daemon-reload' "$STUB_LOG" || fail "daemon-reload"
if grep -q 'systemctl --user enable' "$STUB_LOG"; then fail "dev install must not enable the unit"; fi
"$BLOOM" dev install >/dev/null || fail "dev install should be idempotent"
grep -q "linked" <<<"$("$BLOOM" dev status)" || fail "status"
"$BLOOM" dev uninstall >/dev/null
[[ ! -e "$XDG_CONFIG_HOME/quickshell/bloom" && ! -L "$XDG_CONFIG_HOME/quickshell/bloom" ]] || fail "uninstall left the shell link"
[[ ! -L "$XDG_CONFIG_HOME/systemd/user/bloom-shell.service" ]] || fail "uninstall left a unit link"
pass "dev install links, is idempotent, never enables; uninstall removes"

# Review focus 4: refuse when the config path is taken, and create nothing.
mkdir -p "$XDG_CONFIG_HOME/quickshell/bloom"
touch "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml"
if "$BLOOM" dev install >/dev/null 2>&1; then fail "dev install should refuse"; fi
[[ ! -e "$XDG_CONFIG_HOME/systemd/user/bloom-shell.service" ]] || fail "refused install still linked a unit"
[[ -f "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml" ]] || fail "existing config touched"
"$BLOOM" dev uninstall >/dev/null
[[ -f "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml" ]] || fail "uninstall removed a foreign config"
pass "dev install refuses an existing config and changes nothing; uninstall leaves it"

# doctor
status=0
out="$("$BLOOM" doctor)" || status=$?
(( status <= 2 )) || fail "doctor exit status $status is not a verdict"
for want in "Bloom doctor:" "Quickshell 0.3.2 (stub)" "v0.56.2" "allow_session_lock_restore" "Recent shell log"; do
	grep -qF "$want" <<<"$out" || fail "doctor output missing: $want"
done
pass "doctor reports versions, lock safety and logs"

# doctor is for when the shell is in trouble, so a hung shell must not hang it (spec §6 timeouts).
start=$SECONDS
status=0
STUB_QS_SLEEP=30 timeout 20 "$BLOOM" doctor >/dev/null || status=$?
(( status <= 2 )) || fail "doctor failed or hung with a hung shell (exit $status)"
(( SECONDS - start < 15 )) || fail "doctor took $((SECONDS - start)) s with a hung shell"
pass "doctor does not hang when the shell is hung"
