#!/bin/sh
# Opens Settings, on a page if given. Usage: open-settings.sh APP.qml [PAGE]
# A preloaded (hidden) Settings shows at once; otherwise a new one starts.
# The real path: Quickshell tells instances apart by it, and the shell names
# Settings through its config link while `bloom settings` names the checkout.
app="$(realpath "$1")"
page="${2:-display}"
[ "$(qs ipc -p "$app" call settingsapp open "$page" 2>/dev/null)" = ok ] && exit 0
BLOOM_SETTINGS_TAB="$page" exec qs --no-duplicate -p "$app"
