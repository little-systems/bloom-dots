#!/bin/sh
# Sets kitty's background opacity, or puts back what it was. Usage:
# terminal-opacity.sh OPACITY|restore CONF
value="$1"
conf="$2"
keep="$conf.bloom-before"
mkdir -p "$(dirname "$conf")" || exit 1
if [ "$value" = restore ]; then
	[ -f "$keep" ] || exit 0
	mv "$keep" "$conf"
else
	[ -f "$keep" ] || cp "$conf" "$keep" 2>/dev/null
	printf 'background_opacity %s\n' "$value" > "$conf" || exit 1
fi
pkill -USR1 -x kitty
exit 0
