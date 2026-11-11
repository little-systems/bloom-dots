# Fresh install: from archinstall to Bloom in one reboot

Status: approved by the owner, 2026-11-11.

## Intent

Today `bloom install` assumes a working desktop: Quickshell, Hyprland and a
login path must already exist, and the installer stops at the first missing
binary ("missing qs; install it before running Bloom's installer"). The owner
wants Bloom to be the thing that turns a bare Arch install into a Bloom desktop.

The target moment, in the owner's words: archinstall, then `arch-chroot`, clone
Bloom and run install; reboot straight into Bloom. The installer takes care of
everything the OS needs and everything Bloom needs: packages, scripts, links,
services. The same command must also work on a fresh Arch system that has
already booted to a text console, and keep working on an existing desktop
(today's case).

The first thing the person sees after that reboot is a login screen that looks
exactly like Bloom's lock screen. Boot, login and desktop read as one surface.

## Goals

1. `bloom install` succeeds in three places, with one command and no prior
   package steps beyond `git`:
   - **chroot:** inside `arch-chroot /mnt` right after archinstall, as root.
   - **console:** on a booted fresh Arch at a text login, as the user.
   - **desktop:** on an existing Hyprland desktop (today's behaviour).
2. The installer installs Quickshell, Hyprland and every other dependency
   itself. Missing packages are never a reason to stop; only a missing
   package manager or network is.
3. After a chroot install, the first boot shows the Bloom login screen, and
   logging in lands in Hyprland with Bloom running, with no further command.
4. Login screen:
   - No display manager installed → install SDDM, enable it, Bloom theme.
   - SDDM installed (for example archinstall's Hyprland profile) → switch it to
     the Bloom theme.
   - Another display manager (GDM, greetd, LightDM, ly) → leave it alone and
     say so.
5. The Bloom SDDM theme matches the lock screen exactly: same clock, islands,
   type, springs and colours.
6. System services Bloom's features need are enabled: NetworkManager,
   Bluetooth, power profiles.
7. Everything Bloom changes at system level is recorded and restorable by
   `bloom uninstall`, with the same guarantees the user-level installer has
   today (manifest, fingerprints, rollback, `bloom recover`).

## Non-goals

- Bloom does not partition disks, install the base system, or replace
  archinstall. Bloom has no ISO of its own. (Owner: "we dont deal with that at
  all.")
- No support for distributions other than Arch.
- No theming of display managers other than SDDM.
- No automatic login. The person always types their password at the login
  screen.

## Anti-goals (failure even if it technically works)

- A login screen that only resembles Bloom. Parity is literal, measured against
  the lock screen, like the rest of the project.
- Breaking networking on a booted machine: enabling a second network manager
  next to a working one can drop the connection mid-install.
- A root step that runs without being shown first (`--dry-run` must list every
  system change too), or a system change that uninstall can't undo.
- Any change to files in a user's home made as root. Home files are always
  written as their owner.
- A first boot that drops to a text console or a blank screen because a step
  silently waited for a session that didn't exist yet.

## Constraints

- Arch only, SDDM 0.21+ with its Qt 6 greeter, Hyprland 0.56+ (Lua config),
  Quickshell 0.3+.
- Everything in `AGENTS.md`/project rules still holds: no ii code, Bloom style,
  and the hardening contracts (acknowledged writes, ownership fingerprints,
  event ledger, typed operation results, `bloom doctor`).
- Inside `arch-chroot` there is no running systemd, no user manager, no
  D-Bus session and no compositor. `systemctl enable` works offline;
  `systemctl --user`, `start`, `--now` and health pings do not.
- `makepkg` refuses to run as root.
- The SDDM greeter runs as the `sddm` user and can't read anyone's home
  (mode 0700), so anything it shows must live in a system location.

## The decided how

### Three phases

The installer splits its work into three phases. This is the pattern Omarchy
uses for its ISO installs (root setup in the chroot, user setup in the chroot
as the user, then a first-login step for whatever needs a live session).

| Phase | Runs as | When | Does |
|---|---|---|---|
| System | root | chroot: directly. Console/desktop: through one `sudo` invocation | packages, system services, SDDM and its theme, the login wallpaper folder |
| User | the target user | right after the system phase | today's install: checkout links, Hyprland loader, custom files, settings, user units linked |
| First login | the target user | the first Hyprland session after a chroot or console install | `systemctl --user` enable and start, health check, then it removes its marker |

- Run as root (the chroot case), the installer does the system phase itself and
  runs the user phase as the target user (for example with `runuser`). It never
  writes into a home as root.
- Run as a user, it shows the system plan, asks for `sudo` once for the whole
  system phase, then continues as the user. The system phase is skipped when
  nothing in it needs to change, so a repeat install on a finished machine asks
  for no password. A user who can't use `sudo` is told before any change.
- When no user session is running (chroot, console, SSH), the user phase leaves
  a first-login marker in the user's Bloom state instead of starting anything.
  The installer already skips start and health without a session; this
  formalises it.
- The first-login step runs from Hyprland's start hook in `hypr/bloom.lua`, in
  both the native and the UWSM paths. If it fails, the marker stays, Bloom
  shows a notification, and it runs again at the next login. `bloom doctor`
  reports a pending first login.

### Choosing the user (root runs)

`--user NAME` picks the user explicitly. Without it, the installer uses the only
regular account (UID ≥ 1000 with a login shell). With several regular accounts
it asks interactively; when it can't ask (no terminal), it stops before any
change and names the flag.

### Where the checkout lives

The documented path stays `~/.local/share/bloom` in the user's home. In the
chroot, the person clones it as root to that path under the user's home (the
README shows the command), and the installer makes the user its owner before
the user phase. A clone anywhere else is accepted as long as the target user
can read it.

### Packages

- The dependency metapackage (`packaging/bloom-shell-deps`) stays the single
  list of what Bloom needs. It already pulls in Quickshell and Hyprland.
- As root, the installer builds it as the target user and installs the result
  with `pacman -U`. As a user, today's `makepkg -si` path stays.
- Preflight no longer requires binaries that the dependency package provides
  (`qs`, `hyprctl`). It checks them after the package step instead, together
  with the Quickshell and Hyprland version floors.
- SDDM is installed only when the login-screen rule below needs it. Fonts the
  greeter and a bare system need (the Bloom font, a fallback for text with no
  font at all) come from the dependency package.

### System services

Enabled with plain `systemctl enable` (no `--now` in chroot; `--now` on a
booted system):

- NetworkManager, but only when no other network service is enabled.
- `bluetooth.service`, which stays inert on machines without Bluetooth.
- `power-profiles-daemon.service`.

Services Bloom enabled are recorded. Uninstall lists them and leaves them
enabled, because disabling networking or Bluetooth on removal is more
surprising than leaving it on.

### Login screen

- **Detection:** the active display manager is whatever
  `display-manager.service` points to.
- **None:** install `sddm`, enable it, apply the Bloom theme.
- **SDDM:** apply the Bloom theme. The previous theme setting is recorded.
- **Other:** change nothing and print one line saying the Bloom login screen
  needs SDDM.
- **Configuration:** a drop-in under `/etc/sddm.conf.d/` sets the theme and
  makes Hyprland the default session (`DefaultSession`). Bloom never edits the
  person's own `sddm.conf`.
- **Uninstall:** restores the previous theme setting by removing the drop-in.
  If Bloom installed SDDM, uninstall disables it again so the machine returns
  to what it had (a text login); the package itself is removed only with
  `--remove-deps`.

### The Bloom SDDM theme

- It installs to `/usr/share/sddm/themes/bloom` as a copy, not a link, since
  the greeter can't read the checkout. `bloom update` refreshes the copy when
  it changes, which is the only time an update needs `sudo`.
- It reuses the lock screen's view rather than reimplementing it.
  `shell/modules/lock/LockView.qml` and what it imports (clock, backdrop,
  tokens, fonts, springs, icons) are plain Qt Quick with no Quickshell types,
  so the SDDM greeter can load them. A small SDDM entry file connects SDDM's
  models and actions (`sddm.login`, `userModel`, `sessionModel`,
  `sddm.powerOff`/`reboot`/`suspend`, login failure) to the view's existing
  properties and signals: the password field, error shake, Caps Lock line,
  and the suspend, shut down and restart buttons.
- **What the login screen adds over the lock screen** (my design call, in the
  lock screen's own vocabulary):
  - The left island already shows who and which keyboard. With more than one
    user, small arrows either side of the name switch user.
  - When more than one desktop session is installed, the left island also
    shows the session name, and clicking it cycles sessions. With one session
    it's hidden.
  - The right island keeps battery and the three power buttons. Battery shows
    when the greeter can read it, otherwise that part of the island is hidden.
  - The media card never shows (there's no session to play anything yet).
  - The clock's "Locked" tag names the machine instead (builder's call).
- **Wallpaper:**
  - Bloom ships a default login wallpaper: original artwork with the Bloom
    logo on Bloom's dark backdrop. A fresh machine looks right on its first
    boot.
  - The system phase creates `/var/lib/bloom/login/`, writable by a `bloom-login`
    group the target user joins, so later updates need no password.
  - When the person changes their wallpaper, Bloom copies the current image,
    plus the accent colour and theme mode the lock screen would use, into that
    folder. Video wallpapers contribute a still frame. Group membership only
    applies from the next login, so on a desktop install the login screen
    shows the shipped wallpaper until the first wallpaper or theme change
    after logging in again (builder's call: the root phase never reads a
    home). The state is a generated `State.qml` (validated colours and
    numbers only) that the greeter loads with a Loader, because the greeter
    can't read JSON files without special permissions.
  - With several users, the most recent change wins.
  - The greeter falls back to the shipped default if the folder is empty or
    unreadable.

### Talking to the person (owner: "user friendly, interactive and informative")

- Before any change, the installer prints a short plain-language summary of
  what it will do at system level and in the user's desktop, then asks
  `Continue? [Y/n]`. `--yes` answers for them.
- With several accounts it shows a numbered list to pick the user.
- Work is shown as three labelled stages (System, Your desktop, First login),
  each step as one line that ends in ✓ or ✗ with a plain explanation, and
  pacman's own output is shown while packages install.
- It ends with a summary: what changed, what happens next (for example "Reboot:
  you'll see the Bloom login screen"), and how to undo it (`bloom uninstall`).
- A failure says what failed, what was put back, and the next command to run.
- Without a terminal (scripts, archinstall's custom commands) it asks nothing,
  explains and proceeds. Colour only in a terminal; `NO_COLOR` turns it off.

### Dry run, recovery, diagnostics

- `bloom install --dry-run` prints the system plan (packages, services, SDDM
  actions, theme files, folder, group) before the user plan, and changes
  nothing at either level.
- The system phase keeps its own manifest at
  `/var/lib/bloom/system-manifest.json` (root-owned) with the same transaction
  model as the user manifest: pending/installed fingerprints, rollback on
  failure, `bloom recover` to inspect or resume. A failed system phase rolls
  back before the user phase starts.
- `bloom doctor` gains checks for: the login screen (Bloom theme active, or
  which other display manager is in use), the first-login marker, and the
  system services above.

### Verification

- Unit tests drive the system phase against a fake root (an override for `/`
  in the same spirit as the existing `BLOOM_*` overrides), covering each
  display-manager case, user selection, the network-service rule and rollback.
- The SDDM theme gets offscreen QML tests like the lock screen's, plus a
  side-by-side comparison against the lock screen at equal size.
- VM acceptance gains two paths:
  - **chroot:** build a fresh Arch root on a second virtual disk inside the
    acceptance VM (`pacstrap`), run the install in `arch-chroot`, then boot
    that disk as its own VM. Check that SDDM shows the Bloom theme and that
    logging in reaches a Bloom that answers `ping`.
  - **console:** today's VM path with the prerequisite step removed.
- The owner repeats the archinstall walkthrough by hand in the interactive VM
  (`tools/vm/bloom-vm.sh up --screen`) before release.

## Left to the builder

- How the root and user phases pass the plan and results between them, and
  the exact command shape (one `bloom install`, with internal phases).
- How the greeter reads battery and how the theme gets Bloom's icons and font
  files.
- The exact first-login notification wording.
- How the default login wallpaper is drawn, within the description above.
- How the chroot VM path is automated, within the description above.

## Calls made without an owner answer

- When another network service is enabled (archinstall's "copy ISO network
  configuration" uses systemd-networkd and iwd), Bloom leaves it alone; the
  Wi-Fi panel and `bloom doctor` explain that Wi-Fi controls need
  NetworkManager. Chosen as the safer default (anti-goal: never break
  networking); the owner can reverse it.
