# Helpers for integration tests: run the real shell offscreen against
# throwaway XDG directories. Source this file, then call bloom_env.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHELL_PID=""

bloom_env() {
	# systemd --user is reached through the session's own runtime dir.
	HOST_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
	TEST_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$TEST_TMP/config"
	export XDG_STATE_HOME="$TEST_TMP/state"
	export XDG_RUNTIME_DIR="$TEST_TMP/run"
	export QT_QPA_PLATFORM=offscreen NO_COLOR=1
	# Never sync the real pacman databases from a test (tests that need
	# updates point this at tests/integration/updates-fake.sh).
	export BLOOM_CHECKUPDATES="$TEST_TMP/no-checkupdates"
	# Apps launched by the shell in tests stay out of the real user systemd.
	export BLOOM_LAUNCH_SCOPE=0
	# Adaptive theming writes here, never to the real home.
	export BLOOM_THEME_HOME="$TEST_TMP/home"
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
	if [[ -n "${SWAY_UNIT:-}${SWAY_PID:-}" ]]; then stop_sway; fi
	rm -rf "$TEST_TMP"
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	if [[ -f "$TEST_TMP/shell.log" ]]; then
		sed 's/^/  log: /' "$TEST_TMP/shell.log" >&2
	fi
	if [[ -f "$TEST_TMP/sway.log" ]]; then
		sed 's/^/  sway: /' "$TEST_TMP/sway.log" >&2
	fi
	exit 1
}

pass() { printf 'ok - %s\n' "$*"; }

assert_eq() {
	[[ "$1" == "$2" ]] || fail "$3: expected [$2], got [$1]"
}

log_has() { grep -qF -- "$1" "$TEST_TMP/shell.log"; }

# wait_for <description> <command...>: retries the command for up to
# $WAIT_S seconds (default 6).
wait_for() {
	local what="$1"
	shift
	for _ in $(seq 1 $(( ${WAIT_S:-6} * 10 ))); do
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


# Headless sway hosts the real layer surfaces. Its socket path must stay
# under 108 bytes, so it gets its own short runtime dir. Launched as a plain
# background job from some sandboxes sway is killed, so where a user systemd
# is reachable it runs as a transient unit.
SWAY_UNIT=""
SWAY_PID=""
HOST_RUNTIME_DIR=""
SWAY_RUNTIME_DIR=""

start_sway() {
	local rt
	# The test compositor must not inherit the host Hyprland session. Its
	# signature would make HyprState query a socket outside this runtime dir.
	unset HYPRLAND_INSTANCE_SIGNATURE
	if [[ -d "/run/user/$UID" ]]; then
		rt="$(mktemp -d "/run/user/$UID/bt.XXXX")"
	else
		rt="$(mktemp -d)"
	fi
	chmod 700 "$rt"
	SWAY_RUNTIME_DIR="$rt"
	export XDG_RUNTIME_DIR="$rt"
	if [[ -n "$HOST_RUNTIME_DIR" ]] && XDG_RUNTIME_DIR="$HOST_RUNTIME_DIR" systemctl --user show-environment >/dev/null 2>&1; then
		SWAY_UNIT="bloom-test-sway-$$"
		XDG_RUNTIME_DIR="$HOST_RUNTIME_DIR" systemd-run --user --quiet --unit="$SWAY_UNIT" \
			-E XDG_RUNTIME_DIR="$rt" -E WLR_BACKENDS=headless -E WLR_RENDERER=pixman -E WLR_LIBINPUT_NO_DEVICES=1 \
			/usr/bin/sway -c "$ROOT/tests/integration/sway.conf"
	else
		WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
			sway -c "$ROOT/tests/integration/sway.conf" >"$TEST_TMP/sway.log" 2>&1 &
		SWAY_PID=$!
	fi
	wait_for "sway's Wayland socket" test -S "$rt/wayland-1"
	export WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland
}

stop_sway() {
	if [[ -n "$SWAY_UNIT" ]]; then
		XDG_RUNTIME_DIR="$HOST_RUNTIME_DIR" systemctl --user stop "$SWAY_UNIT" 2>/dev/null || true
		XDG_RUNTIME_DIR="$HOST_RUNTIME_DIR" systemctl --user reset-failed "$SWAY_UNIT" 2>/dev/null || true
	fi
	if [[ -n "$SWAY_PID" ]]; then
		kill "$SWAY_PID" 2>/dev/null || true
		wait "$SWAY_PID" 2>/dev/null || true
	fi
	if [[ -n "$SWAY_RUNTIME_DIR" ]]; then
		rm -rf "$SWAY_RUNTIME_DIR"
		SWAY_RUNTIME_DIR=""
	fi
}
