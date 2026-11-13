# Bloom's terminal: its prompt (Oh My Posh) and, once in each new kitty
# window, fastfetch with the Bloom logo. __bloom_terminal stays set for the
# fastfetch functions below. ~/.bashrc loads this with one line
# that bloom uninstall removes.
[[ $- == *i* ]] || return 0
__bloom_terminal="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v oh-my-posh >/dev/null; then
	eval "$(oh-my-posh init bash --config "$__bloom_terminal/bloom.omp.json")"
fi
# Bloom's fastfetch, fitted to the window: the logo needs about 88x24, a
# narrower or shorter window (down to 40x10) gets the compact layout, and a
# tiny one gets nothing (returns 1). Interactive bash sets COLUMNS and LINES from the window;
# without them the size is unknown and the full layout is used. The image
# logo only in kitty, the one terminal that draws it.
__bloom_fastfetch() {
	local cols=${COLUMNS:-999} lines=${LINES:-999}
	if (( cols >= 88 && lines >= 24 )); then
		if [[ -n ${KITTY_WINDOW_ID:-} ]]; then
			command fastfetch --config "$__bloom_terminal/fastfetch.jsonc" --logo "$__bloom_terminal/bloom-logo.png" --logo-type kitty-direct "$@"
		else
			command fastfetch --config "$__bloom_terminal/fastfetch.jsonc" "$@"
		fi
	elif (( cols >= 40 && lines >= 10 )); then
		command fastfetch --config "$__bloom_terminal/fastfetch-compact.jsonc" "$@"
	else
		return 1
	fi
}
# The window id, not a yes/no: a nested shell in the same window stays quiet,
# while kitty's next window (a different id) shows it again.
if [[ -n ${KITTY_WINDOW_ID:-} && ${BLOOM_FASTFETCH_WINDOW:-} != "$KITTY_WINDOW_ID" ]] && command -v fastfetch >/dev/null; then
	export BLOOM_FASTFETCH_WINDOW="$KITTY_WINDOW_ID"
	__bloom_fastfetch || true
	# Until the first command the window shows only the welcome, so a resize
	# (another window tiling in) redraws it to fit instead of leaving kitty's
	# rewrapped text under the logo. kitty clears its prompt on a resize, so
	# the redraw waits a moment for that. PS0 runs before each command and ends
	# the welcome; the next resize then puts the shell's own traps back.
	__bloom_fresh=1
	__bloom_traps="$(trap -p WINCH USR1)"
	__bloom_refit() {
		if (( __bloom_fresh )); then
			printf '\e[H\e[2J\e[3J'
			__bloom_fastfetch
			printf '%s' "${PS1@P}"
		else
			trap - WINCH USR1
			eval "$__bloom_traps"
		fi
	}
	trap '{ sleep 0.15; kill -USR1 $$; } >/dev/null 2>&1 & disown' WINCH
	trap '__bloom_refit' USR1
	# shellcheck disable=SC2016 # expanded later, by bash, each time PS0 shows
	PS0+='${__bloom_fresh:0:$((__bloom_fresh=0))}'
fi
# Typing fastfetch shows Bloom's layout too (the compact one even in a tiny
# window), unless you keep a fastfetch config of your own.
fastfetch() {
	if [[ -e ${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc ]]; then
		command fastfetch "$@"
	else
		__bloom_fastfetch "$@" || command fastfetch --config "$__bloom_terminal/fastfetch-compact.jsonc" "$@"
	fi
}
