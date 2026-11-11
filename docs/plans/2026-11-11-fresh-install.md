# Fresh Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `bloom install` turns a bare Arch install (inside `arch-chroot`, at a console, or on an existing desktop) into a Bloom desktop with a Bloom SDDM login screen, in one command.

**Architecture:** A new root-only module `tools/bloom_system.py` plans and applies system changes (packages, services, SDDM, theme, login folder) under its own manifest. `tools/bloom-lifecycle.py` gains a root mode (choose user → system phase → user phase via `runuser`) and a user mode (system phase via one `sudo`), an offline user phase that leaves a first-login marker, and a `first-login` command run by the Hyprland start hook. The SDDM theme reuses `LockView.qml` through a thin greeter adapter.

**Tech Stack:** Python 3 (stdlib only), Bash, Lua (Hyprland config), QML/Qt 6 (SDDM 0.21 Qt 6 greeter), unittest + qmltestrunner.

**Spec:** `docs/specs/2026-11-11-fresh-install-design.md`

## Global Constraints

- Arch only, SDDM 0.21+ Qt 6 greeter (`QtVersion=6` in theme metadata), Hyprland 0.56+ Lua config, Quickshell 0.3+.
- No ii code; Bloom style; hardening contracts hold (acknowledged writes, fingerprints, event ledger, typed results, doctor).
- Never write into a home as root; home files are written by their owner.
- No `systemctl --user`, `start`, `--now` or health pings inside a chroot.
- `--dry-run` lists every system change and changes nothing.
- Every system change is recorded in `/var/lib/bloom/system-manifest.json` and undone by `bloom uninstall`.
- Interactive and informative: plain-language plan + `Continue? [Y/n]` (`--yes` skips; no TTY = no prompt), numbered user menu, stages "System", "Your desktop", "First login", ✓/✗ step lines, final summary with next step and undo, colour only on a TTY and off under `NO_COLOR`.
- Tests never touch the real system: `BLOOM_SYSTEM_ROOT` (fake `/`), `BLOOM_AS_ROOT=1` (act as root), stub `pacman`, `runuser`, `groupadd`, `usermod`, `chown`, `systemctl`, `systemd-detect-virt`, `sudo`, `makepkg`.

## Review Focus

1. A second `bloom install` on a finished machine: no sudo prompt, no package step, no changes.
2. Root run where the checkout is root-owned inside the user's home: ownership handed to the user before the user phase; user files never root-owned.
3. A failed system step (pacman fails): system files rolled back, user phase never starts, message names the next command.
4. Booted console install with no display manager: SDDM enabled but not started mid-session; summary says reboot.
5. Existing SDDM config by the person in `/etc/sddm.conf`: untouched; only Bloom's drop-in is added/removed.

---

### Task 1: System facts

**Files:** Create `tools/bloom_system.py`; Test `tests/cli/system_cases.py`, `tests/cli/test_system.sh`

**Produces:**
- `system_root() -> Path` (env `BLOOM_SYSTEM_ROOT`, default `/`)
- `regular_users(root) -> list[dict(name, uid, home)]` from `root/etc/passwd`: 1000 ≤ uid < 60000, shell not ending in `nologin`/`false`.
- `choose_user(root, requested: str|None, ask: Callable|None) -> dict` — requested must be regular; one user → it; several → `ask(users)` or `Failure("several accounts … use --user NAME")`.
- `display_manager(root) -> str|None` — stem of `root/etc/systemd/system/display-manager.service` link target.
- `enabled_network(root) -> list[str]` — which of `NetworkManager, systemd-networkd, iwd, connman, netctl` have any `*.service` link under `root/etc/systemd/system/**`.
- `in_chroot() -> bool` — `systemd-detect-virt --chroot` exit 0.

- [ ] Tests: `test_regular_users_skip_system_and_nologin_accounts`, `test_one_user_is_chosen_without_asking`, `test_several_users_without_a_terminal_name_the_flag`, `test_requested_user_must_exist`, `test_display_manager_is_read_from_the_link`, `test_network_services_are_detected` — all against a temp fake root. Run `bash tests/cli/test_system.sh` → FAIL (module missing).
- [ ] Implement; rerun → PASS. Commit `feat(install): read users, display manager and network from the target system`.

### Task 2: System plan, apply, uninstall

**Files:** Modify `tools/bloom_system.py`; Create `sddm/bloom/` placeholder (`metadata.desktop`, `theme.conf`, `Main.qml` stub) so copying is testable; Test `tests/cli/system_cases.py`

**Produces:**
- `Step = dict(kind, label, ...)`; kinds `packages` (pkgbuild hash), `install-sddm`, `enable` (unit), `group`, `login-folder`, `theme` (dir copy), `dropin` (file `etc/sddm.conf.d/10-bloom.conf`), `note` (no effect: other DM, other network).
- `plan(root, user, deps: bool) -> list[Step]` — empty when manifest already matches (pkgbuild hash, theme tree digest, drop-in content).
- `apply(root, user, steps, booted: bool, run)` — writes manifest `root/var/lib/bloom/system-manifest.json` (mode 0600, version 1) with `pending` before each step; on failure undoes file steps and services it enabled, re-raises.
- `uninstall(root, remove_deps: bool, run)` — removes drop-in/theme/login folder, disables SDDM only if Bloom enabled it, keeps other services (listed), `pacman -Rns bloom-shell-deps` only with `remove_deps`, retires manifest.
- Packages: build as user `runuser -u USER -- makepkg -d --noconfirm` in a temp dir owned by the user, then `pacman -U --noconfirm --needed <pkg>`; SDDM: `pacman -S --noconfirm --needed sddm`.
- Services: `systemctl enable` (+`--now` when booted, never for `sddm`). NetworkManager only when `enabled_network` is empty or contains it.
- Drop-in content: `[Theme]\nCurrent=bloom\n\n[General]\nDefaultSession=hyprland.desktop\n`.
- Login folder `root/var/lib/bloom/login` mode 2775, `chown root:bloom`; group via `groupadd -r bloom`, `usermod -aG bloom USER`.

- [ ] Tests: `test_no_display_manager_installs_and_enables_sddm`, `test_existing_sddm_gets_the_theme_without_reinstall`, `test_other_display_manager_is_left_alone_with_a_note`, `test_networkd_is_left_alone_and_noted`, `test_chroot_enables_without_now`, `test_booted_never_starts_sddm`, `test_second_plan_is_empty`, `test_failed_package_step_rolls_back_files`, `test_uninstall_restores_previous_state`, `test_person_sddm_conf_is_never_touched`. FAIL first.
- [ ] Implement; PASS. Commit `feat(install): plan and apply system setup with its own manifest`.

### Task 3: Installer modes, offline user phase, first login, friendly output

**Files:** Modify `tools/bloom-lifecycle.py`, `bin/bloom` (usage); Create `tools/bloom_ui.py` (printing/prompts); Test `tests/cli/lifecycle_cases.py`

**Produces:**
- CLI: `install [--dry-run] [--no-deps] [--restart] [--yes] [--user NAME]`; internal `system-apply --user NAME [--no-deps] [--booted]`, `system-uninstall [--remove-deps]`; `first-login [--start]`.
- `bloom_ui`: `stage(title)`, `step(label, ok: bool, detail="")`, `confirm(summary_lines) -> bool` (TTY only; `--yes` → True), `menu(prompt, options) -> int`, colour only when `isatty` and no `NO_COLOR`.
- Root mode (`os.geteuid()==0` or `BLOOM_AS_ROOT=1`): choose user → summary/confirm → system apply → chown checkout (`chown -R user:user`) when under the user's home and not owned by them → `runuser -u USER -- env HOME=… <ROOT>/bin/bloom install --no-deps --yes`.
- User mode: system plan; if non-empty and not dry-run: `sudo -v` (refusal → `Failure("Bloom needs sudo for system setup…")` before changes), then `sudo <python> tools/bloom-lifecycle.py system-apply …` (inherited terminal).
- Preflight no longer requires `qs`/`hyprctl`/`makepkg` before the system phase; version floors checked after it.
- Offline user manager (`systemctl --user show-environment` fails): link files, write `state/first-login-pending`, skip enable/start; message "Bloom finishes at your first login".
- `first-login`: no marker → no-op; else `daemon-reload`, `enable`, with `--start` also start + ping; success removes marker; failure keeps it and calls `notify-send`.
- Uninstall: after the user uninstall, `sudo … system-uninstall` when the system manifest exists.
- Update existing tests that expected `makepkg -si`.

- [ ] Tests: `test_root_install_runs_system_then_user_phase_as_the_user`, `test_root_install_hands_the_checkout_to_the_user`, `test_install_without_quickshell_installs_it_first`, `test_chroot_install_leaves_a_first_login_marker`, `test_first_login_enables_and_clears_the_marker`, `test_first_login_failure_keeps_the_marker`, `test_repeat_install_asks_for_no_sudo`, `test_without_sudo_nothing_changes`, `test_dry_run_lists_system_steps`, `test_output_has_stages_and_a_next_step`, `test_no_colour_without_a_terminal`. FAIL first.
- [ ] Implement; `bash tests/cli/test_lifecycle.sh` and `test_system.sh` PASS. Commit `feat(install): root and user install modes with a first-login step`.

### Task 4: Start hook runs first login

**Files:** Modify `hypr/bloom.lua`; Test `tests/units/session_start_cases.py`

- Native path: `[ -e "$XDG_STATE_HOME/bloom/first-login-pending" ] && <ROOT>/bin/bloom first-login;` before the existing import/restart chain. UWSM path: same check with `first-login --start`. `<ROOT>` from `debug.getinfo(1, "S").source`.
- [ ] Tests: `test_native_login_runs_first_login_when_pending`, `test_uwsm_login_starts_bloom_when_pending`. FAIL, implement, PASS. Commit `feat(session): finish a chroot install at the first login`.

### Task 5: Bloom SDDM theme

**Files:** Create `sddm/bloom/{metadata.desktop,theme.conf,Main.qml,BloomGreeter.qml,default-wallpaper.png}`; Modify `shell/modules/lock/LockView.qml` (optional `users`, `userIndex`, `sessionName`, `sessionCount` props and `userStepped(int)`, `sessionStepped()` signals; arrows/session label hidden by default so the lock screen is unchanged); Modify `tools/bloom_system.py` theme step to copy `sddm/bloom` plus `shell/common`, `shell/modules/lock`, `shell/modules/notch/FilterBlur.qml` and its deps, `shell/assets/fonts`; Test `tests/qml/tst_greeter.qml`, `tests/qml/tst_lockview.qml`

- `BloomGreeter` props: `sddmApi`, `users` (ListModel-like), `sessions`, `loginState` (`/var/lib/bloom/login/login.json`: `{wallpaper, accent, mode}`); default wallpaper fallback.
- Mapping: submit → `sddmApi.login(user, password, sessionIndex)`; `loginFailed` → shake + message "Wrong password"; power buttons → `powerOff/reboot/suspend`; media card hidden; battery hidden.
- [ ] Tests: `test_lock_screen_unchanged_without_greeter_props`, `test_arrows_only_with_several_users`, `test_session_only_with_several_sessions`, `test_submit_calls_login_with_selected_user_and_session`, `test_failed_login_shakes_and_clears`, `test_missing_login_state_uses_default_wallpaper`. FAIL, implement, PASS (`qmltestrunner -input tests/qml/tst_greeter.qml`).
- [ ] Default wallpaper: original artwork, Bloom logo (`shell/assets/bloom.png`) on Bloom's dark backdrop, 3840×2160 PNG.
- [ ] Commit `feat(login): Bloom SDDM theme that reuses the lock screen`.

### Task 6: Login wallpaper sync

**Files:** Create `shell/scripts/login-wallpaper.sh`; Modify `shell/services/Wallpaper.qml` (call it after a wallpaper is applied); Test `tests/scripts/test_login_wallpaper.sh`

- `login-wallpaper.sh IMAGE ACCENT MODE` writes `wallpaper-<sha12>.<ext>` and `login.json` atomically into `${BLOOM_LOGIN_DIR:-/var/lib/bloom/login}`, removes older wallpapers, exits 0 silently when the folder is not writable; video → first frame via `ffmpeg` when present, else keeps previous.
- [ ] Tests: `copies_image_and_state`, `replaces_previous`, `unwritable_folder_is_quiet`, `video_without_ffmpeg_keeps_previous`. FAIL, implement, PASS. Commit `feat(login): keep the login wallpaper in step with the desktop`.

### Task 7: Doctor and Wi-Fi explanation

**Files:** Modify `tools/bloom-doctor.py`, `shell/services/Network.qml`, `shell/services/network.js`, `shell/modules/notch/WifiPanel.qml`; Tests `tests/cli/observability_cases.py` (doctor), `tests/qml/tst_connectivity.qml`

- Doctor checks `login` (Bloom theme active / other DM named / none), `first-login` (pending → degraded with "log out and back in"), `system-services` (NetworkManager or the other service named).
- Network: when `nmcli` is missing and `systemd-networkd`/`iwd` is active, `unavailableReason` = "Wi-Fi is managed by systemd-networkd. Bloom's Wi-Fi controls need NetworkManager."; WifiPanel shows it.
- [ ] Tests FAIL → implement → PASS. Commit `feat(doctor): report login screen, first login and network service`.

### Task 8: Docs and VM acceptance

**Files:** Modify `README.md`, `docs/INSTALL.md`, `tests/vm/acceptance.sh`, `tools/vm/bloom-vm.sh`

- Docs: the chroot flow (archinstall → `arch-chroot /mnt` → `git clone … /home/USER/.local/share/bloom` → `/home/USER/.local/share/bloom/bin/bloom install`), the console flow (no prerequisites but `git`), login screen behaviour, undo.
- Acceptance: `prereqs` installs only `git`; new `chroot` stage builds a root on a second disk with `pacstrap`, installs in `arch-chroot`, boots it as its own VM, checks SDDM theme config and that login reaches a pinging Bloom.
- [ ] Run acceptance in the VM; all stages ok. Commit `docs(install): fresh Arch and archinstall chroot install` and `test(vm): chroot install acceptance`.
