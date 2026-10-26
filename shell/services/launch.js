// How Bloom starts apps. Plain JS, shared with the tests.
//
// Each app runs in its own systemd user scope, the way desktop launchers do.
// The shell's own unit kills its whole cgroup on restart (KillMode=
// control-group), so an app started as a child would die with it. Where no
// user systemd answers (containers) the app is simply exec'd.

var SCOPE_SCRIPT = 'u=$1; shift; '
	+ 'if [ "$BLOOM_LAUNCH_SCOPE" != 0 ] && command -v systemd-run >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then '
	+ 'exec systemd-run --user --scope --collect --quiet --unit="$u" -- "$@"; fi; exec "$@"';

function unitName(id, n) {
	return "app-bloom-" + id.replace(/[^A-Za-z0-9_.-]/g, "_") + "-" + Math.floor(n).toString(36);
}

// Terminal=true entries: the user's $TERMINAL first, then the freedesktop
// launcher (xdg-terminal-exec, often not installed), then common terminals
// with the way each takes a command.
var TERMINAL_SCRIPT = 'for t in "$TERMINAL" xdg-terminal-exec kitty foot alacritty wezterm konsole gnome-terminal; do '
	+ '[ -n "$t" ] && command -v "$t" >/dev/null 2>&1 || continue; '
	+ 'case "${t##*/}" in '
	+ 'xdg-terminal-exec|kitty|foot) exec "$t" "$@" ;; '
	+ 'wezterm) exec "$t" start -- "$@" ;; '
	+ 'gnome-terminal) exec "$t" -- "$@" ;; '
	+ '*) exec "$t" -e "$@" ;; '
	+ 'esac; done; echo "bloom: no terminal found for $1" >&2; exit 127';

function argv(command, unit, terminal) {
	const cmd = terminal ? ["sh", "-c", TERMINAL_SCRIPT, "sh"].concat(command) : command;
	return ["sh", "-c", SCOPE_SCRIPT, "sh", unit].concat(cmd);
}
