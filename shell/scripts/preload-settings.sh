#!/bin/sh
# Starts Settings hidden, so opening it later is instant (owner: preload at
# login). Usage: preload-settings.sh APP.qml
# A hidden Settings from an older shell (say, after an update) is replaced so
# it runs the current code; one that is open is left alone.
# The real path, as open-settings.sh uses, so both reach the same instance.
app="$(realpath "$1")"
state="$(qs ipc -p "$app" call settingsapp state 2>/dev/null)"
if [ -n "$state" ]; then
	case "$state" in *'"visible":true'*) exit 0 ;; esac
	qs ipc -p "$app" call settingsapp quit >/dev/null 2>&1
	i=0
	while qs ipc -p "$app" call settingsapp state >/dev/null 2>&1 && [ "$i" -lt 50 ]; do
		sleep 0.1
		i=$((i + 1))
	done
fi
BLOOM_SETTINGS_HIDDEN=1 qs --no-duplicate -p "$app" >/dev/null 2>&1 &
