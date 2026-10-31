# Phase 6: System surfaces

**Goal:** the launcher, session menu, workspace overview, polkit agent and lock screen, in Bloom's design language, with polkit and the tray handed over from ii.

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` (§3.3, §3.4, §4.2, §6, §8).

Windows Bloom has none of these surfaces, so there is no reference to measure. "1:1" here means Bloom's language: its tokens, Bloom Inter, its springs, `qp` parts and panel surfaces. Each sub-phase gets its own task plan before it starts, as phases 2 and 3 did.

## Global constraints

- No code from end-4 ii, read or copied.
- Nothing under `~/.config` or `~/dots-hyprland` changes without the owner's OK for that step, with a backup first.
- Tests never touch the real session: sealed buses, fakes, headless sway. Real pointer input goes through `tests/integration/vpointer.py`.
- Every external tool a feature needs is checked on the real machine, not only faked (the `bluetoothctl` lesson): missing tools hide the feature and say what's needed.
- New modules are opt-in through `bloom-enabled-modules` until the owner switches them on.
- Never enter a password. Lock and polkit flows are tested with fake PAM/agent sources; real auth is the owner's live check.

## Order

Lowest risk first, so a mistake can't lock the owner out.

### 6A: Launcher

Centred floating panel (D13). App search over `Apps`, then the prefixes: clipboard (cliphist), emoji, calculator (qalc), shell command, web search, user actions (`~/.config/bloom/actions`). Pure prefix parsing and ranking in JS, unit-tested. `bloom ipc launcher toggle`.

### 6B: Session menu

Lock, log out, suspend, hibernate, reboot, shut down, firmware setup. Warns when pacman or a download is running. Tests never run real power commands.

### 6C: Workspace overview

Grid of workspaces with live previews (the dock's previews already use Screencopy), drag windows between workspaces, search. Tests use headless sway or fixtures, never the owner's windows.

### 6D: Polkit agent, then tray handover

`Quickshell.Services.Polkit` with a Bloom dialog. Exclusive with ii: one switch, never both, with a rollback step. The dock's tray host follows the same handover. Owner live check required.

**Result (2026-10-31):** polkit switched, see `docs/handover/phase6-polkit-switch.md`. The tray needed no ii change: nothing held `org.kde.StatusNotifierWatcher` on the session bus, so adding `tray` to the modules made Bloom the watcher and host. No tray app was running at the time, so a real icon in the dock is still the owner's live check.

### 6E: Lock screen

`WlSessionLock` with `Quickshell.Services.Pam`, config `hyprlock`'s PAM stack or our own. hyprlock stays the fallback; `misc:allow_session_lock_restore` keeps the session locked if the surface crashes. hypridle's `lock_cmd` currently calls ii, so changing it is an owner-approved step. Last, because a bug here is the one that can lock the owner out; TTY recovery steps are written before the first live test.

**Design (2026-10-31, revised at the owner's request):** ii's lock screen behaviour and layout, rebuilt in Bloom's design with no ii code. A `lock` module, off by default, built from `WlSessionLock` and `PamContext` with the existing `hyprlock` PAM service, so Bloom needs no new file in `/etc/pam.d`. The wallpaper blurred and zoomed in, a nine-lobed turning analog clock with the date and a Locked tag, and three islands along the bottom: user and keyboard layout, password with a confirm button, battery with sleep, shut down and restart. Shared text across screens, cleared after 10 seconds idle; Esc clears; pointer movement refocuses; a wrong password shakes the field. Power buttons need no password, as in the owner's ii config.

Unlike ii, the surface draws its own wallpaper over solid black, so it never relies on `session_lock_xray` and never needs the empty-workspace trick. The blur renders once and stays a still, so a locked screen doesn't keep the GPU busy. Left out: fingerprint (no `fprintd` here), Ctrl+Enter's idle inhibit (Bloom has no inhibit service yet), and the keyring unlock. Wallpaper comes from `bloom-lock-wallpaper`, then ii's config, until Phase 7.

A marker in `$XDG_RUNTIME_DIR`, keyed by the compositor instance, re-locks after a crash; `bloom-shell` restarts on failure and `allow_session_lock_restore` lets it reclaim the lock. Only a PAM success unlocks.

Tests run in headless sway with a fixture PAM stack (`pam_exec` comparing a fake password) and real keystrokes through `wtype`. Recovery steps live in `docs/handover/phase6-lock-recovery.md` and come before the first live test. Pointing `hypridle` and `Super+L` at Bloom is a separate owner-approved step.

## Review

The final review of this phase covers Phase 5's merged parity work too: that branch merged without its whole-branch review, at the owner's call.

## Owner decisions (2026-10-31)

1. Launcher: Spotlight-style, a centred search bar that grows on springs as results appear.
2. Web search: Google, in the default browser.
3. Prefixes: `;` clipboard, `:` emoji, `=` calculator, `>` command, `?` web, `!` user actions.
