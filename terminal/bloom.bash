# Bloom's terminal: its prompt (Oh My Posh) and, once in each new kitty
# window, fastfetch with the Bloom logo. __bloom_terminal stays set for the
# fastfetch function below. ~/.bashrc loads this with one line
# that bloom uninstall removes.
[[ $- == *i* ]] || return 0
__bloom_terminal="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v oh-my-posh >/dev/null; then
	eval "$(oh-my-posh init bash --config "$__bloom_terminal/bloom.omp.json")"
fi
# The window id, not a yes/no: a nested shell in the same window stays quiet,
# while kitty's next window (a different id) shows it again.
if [[ -n ${KITTY_WINDOW_ID:-} && ${BLOOM_FASTFETCH_WINDOW:-} != "$KITTY_WINDOW_ID" ]] && command -v fastfetch >/dev/null; then
	export BLOOM_FASTFETCH_WINDOW="$KITTY_WINDOW_ID"
	command fastfetch --config "$__bloom_terminal/fastfetch.jsonc" --logo "$__bloom_terminal/bloom-logo.png" --logo-type kitty-direct
fi
# Typing fastfetch shows Bloom's layout too (the logo only in kitty, the one
# terminal that draws it), unless you keep a fastfetch config of your own.
fastfetch() {
	if [[ -e ${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc ]]; then
		command fastfetch "$@"
	elif [[ -n ${KITTY_WINDOW_ID:-} ]]; then
		command fastfetch --config "$__bloom_terminal/fastfetch.jsonc" --logo "$__bloom_terminal/bloom-logo.png" --logo-type kitty-direct "$@"
	else
		command fastfetch --config "$__bloom_terminal/fastfetch.jsonc" "$@"
	fi
}
