#!/usr/bin/env bash
# Apply or restore the reviewed ii notification opt-out in two explicit roots.
# This script never restarts ii or Bloom; the owner handover performs that step.
set -euo pipefail

if [[ $# -ne 4 || ! "$1" =~ ^(apply|restore)$ ]]; then
	printf 'usage: %s apply|restore LIVE_II_ROOT TRACKED_II_ROOT BACKUP_DIR\n' "$0" >&2
	exit 2
fi

mode="$1"
live_root="$2"
tracked_root="$3"
backup_dir="$4"
patch_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/handover/ii-notification-optout.patch"
files=(
	services/Notifications.qml
	panelFamilies/IllogicalImpulseFamily.qml
	panelFamilies/WaffleFamily.qml
	modules/ii/sidebarRight/SidebarRightContent.qml
)

restore_files() {
	local label root rel
	for label in live tracked; do
		root="$live_root"
		[[ "$label" == tracked ]] && root="$tracked_root"
		for rel in "${files[@]}"; do
			[[ -f "$backup_dir/$label/$rel" ]] || { printf 'missing backup: %s\n' "$backup_dir/$label/$rel" >&2; return 1; }
			cp -p -- "$backup_dir/$label/$rel" "$root/$rel"
		done
	done
}

if [[ "$mode" == restore ]]; then
	restore_files
	printf 'ii source restored from %s; restart ii and verify bus ownership\n' "$backup_dir"
	exit 0
fi

[[ ! -e "$backup_dir" ]] || { printf 'backup directory already exists: %s\n' "$backup_dir" >&2; exit 1; }
for root in "$live_root" "$tracked_root"; do
	[[ -d "$root" ]] || { printf 'ii root missing: %s\n' "$root" >&2; exit 1; }
	patch --dry-run --fuzz=0 --batch -d "$root" -p1 <"$patch_file" >/dev/null
done

mkdir -m 700 "$backup_dir"
for label in live tracked; do
	root="$live_root"
	[[ "$label" == tracked ]] && root="$tracked_root"
	for rel in "${files[@]}"; do
		mkdir -p "$backup_dir/$label/$(dirname "$rel")"
		cp -p -- "$root/$rel" "$backup_dir/$label/$rel"
	done
done

if ! patch --fuzz=0 --batch -d "$live_root" -p1 <"$patch_file" \
	|| ! patch --fuzz=0 --batch -d "$tracked_root" -p1 <"$patch_file"; then
	printf 'patch failed; restoring both ii roots\n' >&2
	restore_files
	exit 1
fi
printf 'ii opt-out applied; backups in %s; restart ii before enabling Bloom notifications\n' "$backup_dir"
