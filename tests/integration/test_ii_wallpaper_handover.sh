#!/usr/bin/env bash
# The ii wallpaper opt-out script, on throwaway roots built from the patch's own
# context lines: it never touches ~/.config or ~/dots-hyprland.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo/scripts/phase7-ii-wallpaper.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

mkdir -p "$tmp/live/modules/ii/background" "$tmp/tracked/modules/ii/background"
# The file before the patch, as far as the hunks show it. The hunks are
# rebased onto it by keeping only their old-side lines.
python3 - "$repo/docs/handover/ii-wallpaper-optout.patch" "$tmp/live/modules/ii/background/Background.qml" <<'PY'
import re, sys
out, line = [], 1
for l in open(sys.argv[1]).read().split("\n"):
    m = re.match(r"@@ -(\d+)", l)
    if m:
        out += ["// filler"] * (int(m[1]) - line); line = int(m[1])
    elif l[:3] in ("---", "+++") or l == "":
        continue
    elif l[0] in " -":
        out.append(l[1:]); line += 1
open(sys.argv[2], "w").write("\n".join(out) + "\n")
PY
cp "$tmp/live/modules/ii/background/Background.qml" "$tmp/tracked/modules/ii/background/"
original="$(sha256sum <"$tmp/live/modules/ii/background/Background.qml")"

"$script" apply "$tmp/live" "$tmp/tracked" "$tmp/backup" >/dev/null
for root in live tracked; do
	grep -q 'visible: false' "$tmp/$root/modules/ii/background/Background.qml" || fail "$root not patched"
done
[[ "$(sha256sum <"$tmp/backup/live/modules/ii/background/Background.qml")" == "$original" ]] || fail "backup differs from the original"
[[ "$(stat -c %a "$tmp/backup")" == 700 ]] || fail "backup directory not private"

# A second apply must not overwrite the good backup.
"$script" apply "$tmp/live" "$tmp/tracked" "$tmp/backup" >/dev/null 2>&1 && fail "second apply was allowed"
[[ "$(sha256sum <"$tmp/backup/live/modules/ii/background/Background.qml")" == "$original" ]] || fail "backup overwritten"

"$script" restore "$tmp/live" "$tmp/tracked" "$tmp/backup" >/dev/null
for root in live tracked; do
	[[ "$(sha256sum <"$tmp/$root/modules/ii/background/Background.qml")" == "$original" ]] || fail "$root not restored"
done

# A tree the patch doesn't fit changes nothing.
printf 'different\n' >"$tmp/tracked/modules/ii/background/Background.qml"
"$script" apply "$tmp/live" "$tmp/tracked" "$tmp/backup2" >/dev/null 2>&1 && fail "applied to a tree that doesn't fit"
[[ ! -e "$tmp/backup2" ]] || fail "backup left by a refused apply"
[[ "$(sha256sum <"$tmp/live/modules/ii/background/Background.qml")" == "$original" ]] || fail "live changed by a refused apply"

printf 'ii wallpaper handover: ok\n'
