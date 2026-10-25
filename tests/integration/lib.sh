# Helpers for integration tests: run the real shell offscreen against
# throwaway XDG directories. Source this file, then call bloom_env.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHELL_PID=""

bloom_env() {
	TEST_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$TEST_TMP/config"
	export XDG_STATE_HOME="$TEST_TMP/state"
	export XDG_RUNTIME_DIR="$TEST_TMP/run"
	export QT_QPA_PLATFORM=offscreen NO_COLOR=1
	unset WAYLAND_DISPLAY
	mkdir -p "$XDG_CONFIG_HOME/quickshell" "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
	trap bloom_cleanup EXIT
}

bloom_cleanup() {
	if [[ -n "$SHELL_PID" ]]; then
		kill "$SHELL_PID" 2>/dev/null || true
		wait "$SHELL_PID" 2>/dev/null || true
	fi
	rm -rf "$TEST_TMP"
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	if [[ -f "$TEST_TMP/shell.log" ]]; then
		sed 's/^/  log: /' "$TEST_TMP/shell.log" >&2
	fi
	exit 1
}

pass() { printf 'ok - %s\n' "$*"; }

assert_eq() {
	[[ "$1" == "$2" ]] || fail "$3: expected [$2], got [$1]"
}

log_has() { grep -qF -- "$1" "$TEST_TMP/shell.log"; }

# wait_for <description> <command...>: retries the command for up to 6 s.
wait_for() {
	local what="$1"
	shift
	local i
	for i in $(seq 1 60); do
		if "$@" >/dev/null 2>&1; then return 0; fi
		sleep 0.1
	done
	fail "timed out waiting for: $what"
}

ipc() { "$ROOT/bin/bloom" ipc "$@"; }

ipc_equals() {
	local expected="$1"
	shift
	[[ "$(ipc "$@" 2>/dev/null)" == "$expected" ]]
}

# Links the checkout as the `bloom` config (like `bloom dev install`) and
# starts it.
start_shell() {
	ln -s "$ROOT/shell" "$XDG_CONFIG_HOME/quickshell/bloom"
	qs --no-color -c bloom >"$TEST_TMP/shell.log" 2>&1 &
	SHELL_PID=$!
	wait_for "the shell to answer ping" ipc_equals pong shell ping
}
