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
