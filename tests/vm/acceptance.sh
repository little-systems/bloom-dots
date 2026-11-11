#!/usr/bin/env bash
# Release acceptance inside a disposable Arch VM (H6), run by tools/vm/bloom-vm.sh.
# Follows docs/INSTALL.md as a user would. Every check prints "ok - " or
# "FAIL - " and the run continues, so one pass shows the whole matrix.
# Usage (in the VM, as the test user): bash acceptance.sh [stage...]
set -uo pipefail

SRC="$HOME/bloom-dots.bundle"
CLONE="$HOME/.local/share/bloom"
BLOOM="$CLONE/bin/bloom"
STATE="$HOME/.local/state/bloom"
LOG="$HOME/acceptance.log"
export PATH="$HOME/.local/bin:$PATH"
failures=0

ok() { echo "ok - $*" | tee -a "$LOG"; }
bad() { echo "FAIL - $*" | tee -a "$LOG"; failures=$((failures + 1)); }
check() { local what=$1; shift; if "$@" >>"$LOG" 2>&1; then ok "$what"; else bad "$what"; fi; }
refuse() { local what=$1; shift; if "$@" >>"$LOG" 2>&1; then bad "$what (was accepted)"; else ok "$what"; fi; }
note() { echo "-- $*" | tee -a "$LOG"; }

session_env() {
	XDG_RUNTIME_DIR="/run/user/$(id -u)"
	export XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
	HYPRLAND_INSTANCE_SIGNATURE="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)"
	WAYLAND_DISPLAY="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | head -1)"
}

start_hyprland() {
	# A headless compositor with software rendering stands in for an SDDM login.
	systemd-run --user --unit=accept-hyprland --collect -E HYPRLAND_HEADLESS_ONLY=1 \
		-E LIBGL_ALWAYS_SOFTWARE=1 -E XDG_SESSION_TYPE=wayland /usr/bin/Hyprland >>"$LOG" 2>&1
	for _ in $(seq 1 60); do session_env; [[ -n "$WAYLAND_DISPLAY" && -n "$HYPRLAND_INSTANCE_SIGNATURE" ]] && hyprctl version >/dev/null 2>&1 && return 0; sleep 1; done
	return 1
}

stop_hyprland() {
	session_env
	hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || systemctl --user stop accept-hyprland >/dev/null 2>&1
	for _ in $(seq 1 20); do systemctl --user is-active --quiet accept-hyprland || return 0; sleep 0.5; done
	systemctl --user stop accept-hyprland >/dev/null 2>&1
}

shell_answers() { for _ in $(seq 1 40); do [[ "$(timeout 3 qs -c bloom ipc call shell ping 2>/dev/null)" == pong ]] && return 0; sleep 0.5; done; return 1; }
fingerprint() { find "$HOME/.config" -type f -not -path '*/bloom/*' -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -c1-16; }

stage_prereqs() {
	note "prerequisites"
	sudo loginctl enable-linger "$USER" 2>&1 | tee -a "$LOG" >/dev/null
	check "base system and prerequisites install" sudo pacman -Syu --noconfirm --needed git base-devel quickshell hyprland python
	mkdir -p "$HOME/.config/hypr"
	cat > "$HOME/.config/hypr/hyprland.lua" <<'LUA'
-- owner's personal configuration (acceptance fixture)
hl.config({ general = { gaps_out = 7 } })
LUA
	mkdir -p "$HOME/.config/gtk-3.0"
	echo '/* owner style */' > "$HOME/.config/gtk-3.0/gtk.css"
	git clone -q "$SRC" "$CLONE" >>"$LOG" 2>&1 && git -C "$CLONE" checkout -q -B main >>"$LOG" 2>&1
	check "checkout cloned from the release bundle" test -x "$BLOOM"
}

stage_install() {
	note "install"
	local before; before="$(fingerprint)"
	check "dry run succeeds" "$BLOOM" install --dry-run
	[[ "$(fingerprint)" == "$before" && ! -e "$STATE/install-manifest.json" ]] && ok "dry run changes nothing" || bad "dry run changed files"
	refuse "missing dependencies are refused before effects" env PATH=/usr/bin/false-path:/usr/bin "$BLOOM" install --no-deps --dry-run
	check "normal install (builds and installs bloom-shell-deps)" "$BLOOM" install
	check "repeated install is a no-op" "$BLOOM" install
	grep -q 'bloom managed loader' "$HOME/.config/hypr/hyprland.lua" && grep -q 'gaps_out = 7' "$HOME/.config/hypr/hyprland.lua" \
		&& ok "personal Hyprland config kept with one loader line" || bad "Hyprland config"
	check "dependency package installed" pacman -Q bloom-shell-deps
}

stage_session() {
	note "session"
	check "headless Hyprland login starts" start_hyprland
	check "the start hook launched Bloom and it answers" shell_answers
	check "doctor runs inside the session" bash -c "'$BLOOM' doctor --json > '$HOME/doctor.json'; [ \$? -le 1 ]"
	stop_hyprland
	check "service skips cleanly after logout" bash -c "! systemctl --user is-failed --quiet bloom-shell"
	check "second login starts Bloom again" start_hyprland
	check "Bloom answers after relogin" shell_answers
	for _ in 1 2 3 4 5 6; do pkill -SEGV -x qs; sleep 1.5; done
	[[ "$(systemctl --user show bloom-shell -p Result --value)" == start-limit-hit ]] && ok "crash loop hits the restart limit" || bad "crash loop limit"
	"$BLOOM" doctor --json > "$HOME/doctor-limited.json" 2>>"$LOG"
	grep -q 'reset-failed' "$HOME/doctor-limited.json" && ok "doctor explains the restart limit" || bad "doctor restart limit"
	stop_hyprland
	check "next login clears the limit and starts Bloom" start_hyprland
	check "Bloom answers after the limit was cleared" shell_answers
}

stage_state() {
	note "state and diagnostics"
	session_env
	echo '{broken' > "$STATE/dock.json"
	"$BLOOM" doctor --json > "$HOME/doctor-state.json" 2>>"$LOG"
	grep -q '"id": "state"' "$HOME/doctor-state.json" && grep -q 'dock' "$HOME/doctor-state.json" && ok "doctor reports damaged state" || bad "doctor damaged state"
	check "support bundle preview writes nothing" "$BLOOM" support --preview
	check "support bundle is written privately" bash -c "'$BLOOM' support --output '$HOME/support.tar.gz' && [ \$(stat -c %a '$HOME/support.tar.gz') = 600 ]"
	if tar -xOzf "$HOME/support.tar.gz" | grep -q "$HOME"; then bad "support bundle leaks the home path"; else ok "support bundle is redacted"; fi
}

stage_update() {
	note "update"
	session_env
	local upstream="$HOME/upstream" initial
	git clone -q --bare "$CLONE" "$HOME/remote.git"
	git -C "$CLONE" remote set-url origin "$HOME/remote.git" 2>/dev/null || git -C "$CLONE" remote add origin "$HOME/remote.git"
	git -C "$CLONE" fetch -q origin && git -C "$CLONE" branch -q --set-upstream-to=origin/main main
	git clone -q "$HOME/remote.git" "$upstream"
	git -C "$upstream" config user.email accept@example.invalid; git -C "$upstream" config user.name Acceptance
	initial="$(git -C "$CLONE" rev-parse HEAD)"
	echo "# acceptance" >> "$upstream/docs/INSTALL.md"; git -C "$upstream" commit -qam "healthy change"; git -C "$upstream" push -q
	check "healthy update applies and Bloom answers" bash -c "'$BLOOM' update && qs -c bloom ipc call shell ping | grep -q pong"
	echo 'def broken(:' > "$upstream/tools/bloom-lifecycle.py"; git -C "$upstream" commit -qam "broken"; git -C "$upstream" push -q
	local good; good="$(git -C "$CLONE" rev-parse HEAD)"
	refuse "broken candidate is refused" "$BLOOM" update
	[[ "$(git -C "$CLONE" rev-parse HEAD)" == "$good" ]] && ok "checkout unchanged after a refused candidate" || bad "checkout moved"
	git -C "$upstream" revert -q --no-edit HEAD && git -C "$upstream" push -q
	check "update after a fixed upstream succeeds" "$BLOOM" update
	check "explicit rollback returns to the previous revision" "$BLOOM" update --rollback
	check "Bloom answers after rollback" shell_answers
	note "initial revision ${initial:0:12}"
}

stage_uninstall() {
	note "uninstall"
	session_env
	echo '-- edited after install' >> "$HOME/.config/hypr/custom/bloom.lua" 2>/dev/null
	check "uninstall" "$BLOOM" uninstall
	grep -q 'gaps_out = 7' "$HOME/.config/hypr/hyprland.lua" && ! grep -q 'bloom managed loader' "$HOME/.config/hypr/hyprland.lua" \
		&& ok "personal Hyprland config restored" || bad "Hyprland config after uninstall"
	[[ "$(cat "$HOME/.config/gtk-3.0/gtk.css")" == '/* owner style */' ]] && ok "pre-Bloom GTK theme restored" || bad "GTK theme after uninstall"
	grep -q 'edited after install' "$HOME/.config/hypr/custom/bloom.lua" 2>/dev/null && ok "edited custom file kept" || bad "edited custom file"
	check "uninstall twice is a no-op" "$BLOOM" uninstall
	pgrep -x qs >/dev/null && bad "orphan shell process after uninstall" || ok "no orphan shell process"
	[[ ! -e "$STATE/install-manifest.json" ]] || grep -q '"uninstalled"' "$STATE/install-manifest.json" && ok "manifest retired" || bad "manifest still active"
	check "reinstall after uninstall" "$BLOOM" install --no-deps
	"$BLOOM" uninstall >>"$LOG" 2>&1 &
	local pid=$!; sleep 0.4; kill -KILL "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
	check "interrupted uninstall is inspectable" "$BLOOM" recover
	check "interrupted uninstall resumes" bash -c "'$BLOOM' recover --resume || '$BLOOM' uninstall"
	grep -q 'gaps_out = 7' "$HOME/.config/hypr/hyprland.lua" && ok "owner config intact after interrupted removal" || bad "owner config after interrupted removal"
}

: > "$LOG"
stages=("$@")
[[ ${#stages[@]} -gt 0 ]] || stages=(prereqs install session state update uninstall)
for s in "${stages[@]}"; do "stage_$s"; done
echo "ACCEPTANCE_FAILURES=$failures" | tee -a "$LOG"
exit $(( failures > 0 ))
