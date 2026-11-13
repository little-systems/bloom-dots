#!/usr/bin/env bash
# Runs every check CI runs, in order. Usage: tests/run-all.sh
# Set CI=true to make missing tools an error instead of a skipped step.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
export QT_QPA_PLATFORM=offscreen NO_COLOR=1
unset WAYLAND_DISPLAY
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
	XDG_RUNTIME_DIR="$(mktemp -d)"
	export XDG_RUNTIME_DIR
fi

step() { printf '\n== %s\n' "$1"; }
need() {
	command -v "$1" >/dev/null && return 0
	[[ "${CI:-}" == true ]] && { echo "missing required tool: $1" >&2; exit 1; }
	echo "skipped: $1 not installed"
	return 1
}

step "qmllint (fails on errors; Quickshell types cause harmless warnings)"
mapfile -d '' qml_files < <(find "$ROOT/shell" "$ROOT/tests" -name '*.qml' -not -path '*/node_modules/*' -print0 2>/dev/null)
if (( ${#qml_files[@]} )); then
	if ! "$QT_BIN/qmllint" "${qml_files[@]}" >/dev/null 2>&1; then
		"$QT_BIN/qmllint" "${qml_files[@]}" 2>&1 | grep -v '^Warning' || true
		exit 1
	fi
	echo "ok"
fi

step "shellcheck"
if need shellcheck; then
	mapfile -d '' sh_files < <(find "$ROOT/bin" "$ROOT/tests" "$ROOT/shell/scripts" -type f \( -name '*.sh' -o -name bloom \) -print0 2>/dev/null)
	shellcheck -x -P SCRIPTDIR --severity=warning "${sh_files[@]}"
	# Sourced into bash, so no shebang: name the shell.
	shellcheck -s bash --severity=warning "$ROOT"/terminal/*.bash
	echo "ok"
fi

step "QML unit tests"
if compgen -G "$ROOT/tests/qml/tst_*.qml" >/dev/null; then
	# Offscreen: otherwise each test is a real window under the real pointer.
	QT_QPA_PLATFORM=offscreen "$QT_BIN/qmltestrunner" -input "$ROOT/tests/qml"
fi

step "spring parity with framer-motion"
if [[ -f "$ROOT/tests/parity/spring-parity.mjs" ]] && need node; then
	[[ -d "$ROOT/tests/parity/node_modules" ]] || (cd "$ROOT/tests/parity" && npm ci --silent)
	node "$ROOT/tests/parity/spring-parity.mjs"
fi

step "settings reference is up to date"
if [[ -f "$ROOT/tools/gen-settings-doc.mjs" ]] && need node; then
	node "$ROOT/tools/gen-settings-doc.mjs" --check
fi

step "icons are up to date"
if [[ -f "$ROOT/tools/gen-icons.mjs" ]] && need node; then
	[[ -d "$ROOT/tools/node_modules" ]] || (cd "$ROOT/tools" && npm ci --silent)
	node "$ROOT/tools/gen-icons.mjs" --check
fi

step "settings search index is up to date"
node "$ROOT/tools/gen-settings-index.mjs" --check

step "every clickable shows Bloom's cursor"
if need node; then
	node "$ROOT/tools/check-cursors.mjs"
fi

step "shell scripts"
for t in "$ROOT"/tests/scripts/test_*.sh; do
	bash "$t"
done

step "integration tests (real shell, offscreen)"
for t in "$ROOT"/tests/integration/test_*.sh; do
	[[ -e "$t" ]] || continue
	need qs || break
	bash "$t"
done

step "CLI tests"
for t in "$ROOT"/tests/cli/test_*.sh; do
	[[ -e "$t" ]] && bash "$t"
done

step "systemd units"
for t in "$ROOT"/tests/units/test_*.sh; do
	[[ -e "$t" ]] && bash "$t"
done

printf '\nall checks passed\n'
