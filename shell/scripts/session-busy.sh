#!/bin/sh
# What's running that a shutdown would hurt: "pacman" if it holds its lock
# (BLOOM_PACMAN_LOCK overrides the path, for tests), then one line per partial
# download touched in the last two minutes in ~/Downloads.
[ -e "${BLOOM_PACMAN_LOCK:-/var/lib/pacman/db.lck}" ] && echo pacman
find "${BLOOM_DOWNLOADS:-$HOME/Downloads}" -maxdepth 2 -type f \( -name '*.part' -o -name '*.crdownload' -o -name '*.aria2' \) -mmin -2 2>/dev/null
exit 0
