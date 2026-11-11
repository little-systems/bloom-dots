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
export LANG=C.UTF-8
failures=0

ok() { echo "ok - $*" | tee -a "$LOG"; }
bad() { echo "FAIL - $*" | tee -a "$LOG"; failures=$((failures + 1)); }
check() { local what=$1; shift; if "$@" >>"$LOG" 2>&1; then ok "$what"; else bad "$what"; fi; }
refuse() { local what=$1; shift; if "$@" >>"$LOG" 2>&1; then bad "$what (was accepted)"; else ok "$what"; fi; }
note() { echo "-- $*" | tee -a "$LOG"; }

# The user manager's environment is what the start hook imported at login.
session_env() {
	XDG_RUNTIME_DIR="/run/user/$(id -u)"
	export XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
	HYPRLAND_INSTANCE_SIGNATURE="$(systemctl --user show-environment | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')"
	WAYLAND_DISPLAY="$(systemctl --user show-environment | sed -n 's/^WAYLAND_DISPLAY=//p')"
}

hyprland_running() { pgrep -x Hyprland >/dev/null; }

# A real console login: tty1 autologin runs ~/.bash_profile, which starts
# Hyprland while ~/.start-hyprland exists (set up in the prereqs stage).
start_hyprland() {
	local before; before="$(systemctl --user show-environment | sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')"
	touch "$HOME/.start-hyprland"
	sudo systemctl restart getty@tty1
	for _ in $(seq 1 60); do
		session_env
		if hyprland_running && [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" && "$HYPRLAND_INSTANCE_SIGNATURE" != "$before" ]] \
			&& hyprctl version >/dev/null 2>&1; then return 0; fi
		sleep 1
	done
	return 1
}

# Use Bloom's normal logout, or exit Hyprland directly when Bloom has failed.
stop_hyprland() {
	session_env
	rm -f "$HOME/.start-hyprland"
	if [[ "${1:-}" == compositor ]]; then
		hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || return 1
	else
		"$BLOOM" ipc session run logout >/dev/null 2>&1 || return 1
	fi
	for _ in $(seq 1 30); do hyprland_running || return 0; sleep 0.5; done
	return 1
}

shell_answers() { for _ in $(seq 1 60); do timeout 3 qs -c bloom ipc call shell ping 2>/dev/null | grep -qx pong && return 0; sleep 0.5; done; return 1; }
fingerprint() { find "$HOME/.config" -type f -not -path '*/bloom/*' -print0 2>/dev/null | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -c1-16; }

stage_prereqs() {
	note "prerequisites"
	sudo loginctl enable-linger "$USER" 2>&1 | tee -a "$LOG" >/dev/null
	sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
	printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear %%I $TERM\n' "$USER" \
		| sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
	cat > "$HOME/.bash_profile" <<'PROFILE'
[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ "$(tty)" == /dev/tty1 && -f ~/.start-hyprland ]]; then
	exec Hyprland > ~/hyprland-tty.log 2>&1
fi
PROFILE
	sudo systemctl daemon-reload
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
	# A PATH with everything the CLI needs except Quickshell.
	local nodeps="$HOME/nodeps-bin" tool
	mkdir -p "$nodeps"
	for tool in bash env python3 git systemctl hyprctl makepkg sudo dirname readlink cat jq timeout; do
		ln -sf "$(command -v "$tool")" "$nodeps/$tool" 2>/dev/null
	done
	refuse "a missing Quickshell is refused before effects" env PATH="$nodeps" "$BLOOM" install --no-deps --dry-run
	[[ ! -e "$STATE/install-manifest.json" ]] && ok "the refusal changed nothing" || bad "the refusal left a manifest"
	# makepkg asks for a provider and a confirmation; a user answers in their
	# terminal, here the defaults are fed on stdin.
	check "normal install (builds and installs bloom-shell-deps)" bash -c "yes '' | '$BLOOM' install"
	check "repeated install is a no-op" bash -c "yes '' | '$BLOOM' install"
	grep -q 'bloom managed loader' "$HOME/.config/hypr/hyprland.lua" && grep -q 'gaps_out = 7' "$HOME/.config/hypr/hyprland.lua" \
		&& ok "personal Hyprland config kept with one loader line" || bad "Hyprland config"
	check "dependency package installed" pacman -Q bloom-shell-deps
}

stage_session() {
	note "session"
	check "headless Hyprland login starts" start_hyprland
	check "the start hook launched Bloom and it answers" shell_answers
	check "doctor runs inside the session" bash -c "'$BLOOM' doctor --json > '$HOME/doctor.json'; [ \$? -le 1 ]"
	check "logout ends Hyprland" stop_hyprland
	check "service stopped cleanly at logout" bash -c '[[ "$(systemctl --user show bloom-shell -p ActiveState --value)" == inactive && "$(systemctl --user show bloom-shell -p Result --value)" == success ]]'
	check "second login starts Bloom again" start_hyprland
	check "Bloom answers after relogin" shell_answers
	# Count only confirmed process replacements, within the unit's start window.
	systemctl --user reset-failed bloom-shell
	local previous next deadline=$((SECONDS + 40))
	for _ in $(seq 1 6); do
		previous="$(systemctl --user show bloom-shell -p MainPID --value)"
		[[ "$previous" =~ ^[1-9][0-9]*$ ]] || break
		systemctl --user kill --kill-whom=main --signal=KILL bloom-shell || break
		while ((SECONDS < deadline)); do
			[[ "$(systemctl --user show bloom-shell -p Result --value)" == start-limit-hit ]] && break 2
			next="$(systemctl --user show bloom-shell -p MainPID --value)"
			[[ "$next" =~ ^[1-9][0-9]*$ && "$next" != "$previous" ]] && break
			sleep 0.2
		done
		((SECONDS < deadline)) || break
	done
	[[ "$(systemctl --user show bloom-shell -p Result --value)" == start-limit-hit ]] && ok "crash loop hits the restart limit" || bad "crash loop limit"
	"$BLOOM" doctor --json > "$HOME/doctor-limited.json" 2>>"$LOG"
	grep -q 'reset-failed' "$HOME/doctor-limited.json" && ok "doctor explains the restart limit" || bad "doctor restart limit"
	check "compositor can exit after Bloom hits the limit" stop_hyprland compositor
	check "next login clears the limit and starts Bloom" start_hyprland
	check "Bloom answers after the limit was cleared" shell_answers
}

stage_state() {
	note "state and diagnostics"
	session_env
	echo '{broken' > "$STATE/dock.json"
	"$BLOOM" doctor --json > "$HOME/doctor-state.json" 2>>"$LOG"
	grep -q '"id": "state"' "$HOME/doctor-state.json" && grep -q 'dock' "$HOME/doctor-state.json" && ok "doctor reports damaged state" || bad "doctor damaged state"
	local output
	output="$(mktemp -d)" || { bad "allocate support bundle fixture"; return; }
	check "support bundle preview succeeds" "$BLOOM" support --preview --output "$output/support.tar.gz"
	check "support preview leaves output absent" test ! -e "$output/support.tar.gz"
	check "support bundle is written" "$BLOOM" support --output "$output/support.tar.gz"
	[[ "$(stat -c %a "$output/support.tar.gz" 2>/dev/null)" == 600 ]] && ok "support bundle is private" || bad "support bundle permissions"
	if tar -xOzf "$output/support.tar.gz" > "$output/contents"; then
		if grep -Fq "$HOME" "$output/contents"; then bad "support bundle leaks the home path"; else ok "support bundle is redacted"; fi
	else
		bad "support bundle is unreadable"
	fi
}

stage_update() {
	note "update"
	session_env
	local fixture upstream initial
	fixture="$(mktemp -d)" || { bad "allocate update fixture"; return; }
	upstream="$fixture/upstream"
	git clone -q --bare "$CLONE" "$fixture/remote.git" || { bad "clone update remote"; return; }
	git -C "$CLONE" remote set-url origin "$fixture/remote.git" || { bad "set update remote"; return; }
	git -C "$CLONE" fetch -q origin && git -C "$CLONE" branch -q --set-upstream-to=origin/main main
	git clone -q "$fixture/remote.git" "$upstream" || { bad "clone update fixture"; return; }
	git -C "$upstream" config user.email accept@example.invalid; git -C "$upstream" config user.name Acceptance
	initial="$(git -C "$CLONE" rev-parse HEAD)"
	echo "# acceptance" >> "$upstream/docs/INSTALL.md"; git -C "$upstream" commit -qam "healthy change"; git -C "$upstream" push -q
	check "healthy update applies and Bloom answers" bash -c "'$BLOOM' update && qs -c bloom ipc call shell ping | grep -q pong"
	echo 'def broken(:' > "$upstream/tools/bloom-lifecycle.py"; git -C "$upstream" commit -qam "broken"; git -C "$upstream" push -q
	local good; good="$(git -C "$CLONE" rev-parse HEAD)"
	if "$BLOOM" update > "$fixture/rejected.log" 2>&1; then
		bad "broken candidate was accepted"
	elif grep -Fq 'failed validation' "$fixture/rejected.log"; then
		ok "broken candidate fails validation"
	else
		cat "$fixture/rejected.log" >> "$LOG"
		bad "broken candidate was refused for the wrong reason"
	fi
	[[ "$(git -C "$CLONE" rev-parse HEAD)" == "$good" ]] && ok "checkout unchanged after a refused candidate" || bad "checkout moved"
	git -C "$upstream" revert --no-edit HEAD && git -C "$upstream" push -q || { bad "publish repaired candidate"; return; }
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
	local fixture pid killed real_systemctl
	fixture="$(mktemp -d)" || { bad "allocate uninstall fixture"; return; }
	cat > "$fixture/systemctl" <<'SH'
#!/usr/bin/env bash
"$BLOOM_VM_REAL_SYSTEMCTL" "$@" || exit $?
if [[ "$*" == "--user disable --now bloom-shell.service" ]]; then
	touch "$BLOOM_VM_UNINSTALL_FIXTURE/paused"
	for _ in $(seq 1 100); do
		[[ -e "$BLOOM_VM_UNINSTALL_FIXTURE/release" ]] && break
		sleep 0.2
	done
fi
SH
	chmod +x "$fixture/systemctl"
	real_systemctl="$(command -v systemctl)" || { bad "locate systemctl"; return; }
	PATH="$fixture:$PATH" BLOOM_VM_REAL_SYSTEMCTL="$real_systemctl" BLOOM_VM_UNINSTALL_FIXTURE="$fixture" \
		"$BLOOM" uninstall >>"$LOG" 2>&1 &
	pid=$!
	for _ in $(seq 1 50); do
		[[ -e "$fixture/paused" ]] && break
		kill -0 "$pid" 2>/dev/null || break
		sleep 0.2
	done
	if [[ ! -e "$fixture/paused" ]] || ! kill -KILL "$pid" 2>/dev/null; then
		touch "$fixture/release"
		wait "$pid"
		bad "uninstall did not reach its interruption point"
		return
	fi
	wait "$pid" 2>/dev/null
	killed=$?
	touch "$fixture/release"
	[[ "$killed" == 137 ]] && ok "uninstall process was interrupted" || bad "uninstall did not exit from SIGKILL"
	check "interrupted uninstall has a pending journal" jq -e '.status == "uninstalling"' "$STATE/install-manifest.json"
	check "interrupted uninstall is inspectable" "$BLOOM" recover
	check "interrupted uninstall resumes" "$BLOOM" recover --resume
	check "resumed uninstall retires the manifest" jq -e '.status == "uninstalled"' "$STATE/install-manifest.json"
	grep -q 'gaps_out = 7' "$HOME/.config/hypr/hyprland.lua" && ok "owner config intact after interrupted removal" || bad "owner config after interrupted removal"
}

: > "$LOG"
stages=("$@")
[[ ${#stages[@]} -gt 0 ]] || stages=(prereqs install session state update uninstall)
for s in "${stages[@]}"; do "stage_$s"; done
echo "ACCEPTANCE_FAILURES=$failures" | tee -a "$LOG"
exit $(( failures > 0 ))
