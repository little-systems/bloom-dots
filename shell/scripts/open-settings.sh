#!/bin/sh
# Opens Settings on a page. Usage: open-settings.sh APP.qml PAGE
app="$1"
page="$2"
qs ipc -p "$app" call settingsapp tab "$page" 2>/dev/null && exit 0
BLOOM_SETTINGS_TAB="$page" exec qs --no-duplicate -p "$app"
