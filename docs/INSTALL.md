# Install and maintain Bloom

Bloom targets Arch Linux. The installer brings everything else: Hyprland 0.56
or newer (Lua configuration), Quickshell 0.3 or newer, Bloom's dependency
package, the SDDM login screen with Bloom's theme, and the system services its
controls use. Only `git` has to be there to clone Bloom.

## Install

### From archinstall, before the first boot

After archinstall, chroot into the new system (archinstall offers this at the
end, or run `arch-chroot /mnt`). Replace `you` with the account you created:

```sh
pacman -S --needed git
git clone https://github.com/little-systems/bloom-dots /home/you/.local/share/bloom
/home/you/.local/share/bloom/bin/bloom install
```

Run as root, the installer:

1. picks the account (the only regular one, `--user NAME`, or a numbered
   choice when there are several);
2. sets up the system: Bloom's packages (built as that user, installed with
   pacman), the SDDM login screen with the Bloom theme, NetworkManager,
   Bluetooth and power profiles, and the login wallpaper folder;
3. hands the clone to that account and installs the desktop part as them.

Nothing that needs a running session happens in the chroot. Exit and reboot:
the Bloom login screen appears, and your first login finishes the setup
(`bloom first-login`, run by Hyprland's start hook; if it fails it says so and
runs again at the next login).

### On an Arch system you already use

```sh
git clone https://github.com/little-systems/bloom-dots ~/.local/share/bloom
~/.local/share/bloom/bin/bloom install --dry-run
~/.local/share/bloom/bin/bloom install
```

Run it as your desktop user. It shows what it will change and asks before
starting (`--yes` skips the question; without a terminal it doesn't ask). The
system part runs through `sudo` once, and only when something in it still
needs to change; Bloom never handles or saves your password. Use `--no-deps`
only when you have installed the dependency package's contents yourself.

### What the system part changes

- **Packages:** `packaging/bloom-shell-deps` is built and installed.
- **Login screen:** with no display manager, SDDM is installed and enabled.
  An existing SDDM is switched to the Bloom theme through
  `/etc/sddm.conf.d/zz-bloom.conf` (your own `sddm.conf` is never edited).
  GDM, greetd, LightDM and others are left alone.
- **The `bloom` command:** `/usr/local/bin/bloom` runs your own
  `~/.local/bin/bloom`, so `bloom` works in every terminal (stock Arch shells
  don't have `~/.local/bin` on `PATH`). A `bloom` someone else put there stays.
- **Services:** NetworkManager (only when no other network service is
  enabled; with systemd-networkd or iwd Bloom leaves networking alone and the
  Wi-Fi panel explains why its controls are unavailable), Bluetooth and power
  profiles.
- **Login wallpaper:** `/var/lib/bloom/login`, writable by the `bloom-login` group,
  so the login screen follows your wallpaper and colours without a password.
- **Default apps** (only without ii, and only once): kitty, Dolphin, Firefox,
  GNOME Text Editor, Loupe and mpv. They are ordinary apps: uninstall keeps
  them, and an update never reinstalls one you removed. One that another
  package brought in (ii, say) is marked as your own, so removing that
  package doesn't take it along.

Everything is recorded in `/var/lib/bloom/system-manifest.json`. A failed
system step undoes this run's file and service changes (installed packages
stay) before your desktop is touched.

### Bloom as the whole desktop

Without illogical-impulse (no `~/.config/quickshell/ii` or
`~/.config/illogical-impulse`), Bloom is the whole desktop: every module starts
on, and when `~/.config/hypr/hyprland.lua` is missing or still Hyprland's
untouched example, the installer writes a short one that loads Bloom's desktop
(`hypr/desktop.lua`: look, input and every shortcut, kept current by
`bloom update`) before your own lines, so anything you add there wins. Super+/
shows every shortcut. Uninstall removes that file again, or puts Hyprland's
example back; if you edited it, it keeps your lines and removes only Bloom's.

A personal `hyprland.lua` is never replaced: it only gains the loader line.
Beside ii, Bloom adds its notch and dock and leaves ii's own desktop alone; a
missing config then starts from Hyprland's default
(`/usr/share/hypr/hyprland.lua`).

The install links the shell, CLI and user units, registers Settings with its
icon, adds one marked loader line to `~/.config/hypr/hyprland.lua`, and offers
three user-owned Lua templates under `custom/`. Existing custom templates are
kept and the supplied version is written beside them as `.new`. Existing
settings and personal keybindings are kept. Shortcut examples are commented
out until you choose them.

kitty's `kitty.conf` starts with two lines from Bloom: its terminal settings
(`kitty/bloom.conf`) and the colours Bloom's theme writes
(`bloom-theme.conf`); your own lines come after and win. Uninstall removes
just those lines, or the file if Bloom created it.

Bloom's terminal: one managed line at the end of `~/.bashrc` loads
`terminal/bloom.bash`, which starts Bloom's prompt (Oh My Posh, theme
`terminal/bloom.omp.json`) and shows fastfetch with the Bloom logo once in
each new kitty window (a compact layout without the logo when the window is
small, nothing when it's tiny). Typing `fastfetch` shows Bloom's layout too, unless
you keep your own `~/.config/fastfetch/config.jsonc`. Oh My Posh is only in the AUR, so the system part
builds `oh-my-posh-bin` from it with makepkg (as you, never as root) and
rebuilds it when the AUR has a newer version; if the AUR can't be reached,
that step reports it and the rest of the install carries on. Uninstall
removes the line and keeps the package. kitty uses one blurred Bloom palette
in every theme mode; only its cursor and selection follow your accent.

App defaults from `defaults/` (Wayland and keyring flags for Chromium,
Chrome, Brave, VS Code and Electron; the KDE file picker; mpv keeping the
window open; Dolphin's full path) are copied only where you have no such
file. From then on the file is yours: Bloom updates it only while you haven't
touched it, never brings back one you deleted, and uninstall removes only
untouched copies.

Open Settings with `bloom settings`.
The loader imports the Hyprland session environment into the user service
manager at login, including your Qt theme, icon theme, XDG paths and PATH.
On a bare Hyprland desktop, configure a Qt theme provider such as `qt6ct`
to make system app icons available. It loads `custom/bloom-settings.lua`, `custom/bloom.lua`,
and `custom/bloom-keybinds.lua`, in that order.

A first install enables only the notch and dock. Enable additional surfaces
in Settings after choosing which desktop services Bloom should own. A manifest records managed files, the
original service state, and original-file backups under:

```
~/.local/state/bloom/install-manifest.json
~/.local/state/bloom/backups/
```

XDG_CONFIG_HOME, XDG_DATA_HOME and XDG_STATE_HOME are respected. All XDG paths
must be absolute. A second install does not restart an already-running service
when its managed files match. Use `bloom install --restart` when deliberately
reloading code edited inside the linked checkout. The update command explicitly
restarts after activating a revision.

A failing install attempts to restore its file changes and previous service
state; a failed service restoration is reported. Replacements are staged beside
their destinations and renamed, with file/directory syncs. An interrupted
transaction keeps its manifest and original backups; do not delete them blindly.
Backups created by the hardened installer have recorded fingerprints and are
checked before reinstall/removal. Legacy manifests without fingerprints can
only establish that their backups exist and are readable, not their historical
integrity. Recovery is not a filesystem snapshot or an OS/package rollback.

## Interrupted operations

```sh
bloom recover                     # inspect; no desktop changes
bloom recover --resume            # finish install/removal or recover an interrupted update
bloom recover --restore-originals # remove Bloom and restore pre-install files
```

Recovery validates the journal and refuses ambiguous owner edits. Resume of an
installation uses the current checkout and installed prerequisites; it never
runs a package transaction. `--restore-originals` restores the installation's
original files, not the immediately preceding code/configuration generation.
For an interrupted update, resume restores the pre-update checkout and restarts
Bloom when a session is available. Retry the update after recovery succeeds.
Keep the checkout and recovery backups until restoration finishes.
New mutation journals use manifest version 2; this reader also accepts legacy
version 1. Older Bloom lifecycle tools reject version 2 instead of incorrectly
replaying a removal they do not understand. Keep a checkout supporting version 2
available for recovery; rolling code back to an older lifecycle reader does not
downgrade the journal or make that older tool safe to use on it.

Uninstall records the complete removal plan before stopping Bloom, checks all
required originals before any file/service changes, and keeps originals until
restoration completes. An interrupted removal can resume without treating an
already-restored original as an owner edit. Repeating a completed uninstall is
a no-op and does not remove untracked development links.

Malformed/traversing/duplicate manifest entries and redirected parent directories
are refused. A symlink used as an XDG root is supported; redirecting a managed
subdirectory outside its XDG root is a conflict that must be resolved explicitly.
Only one lifecycle writer may run for a configuration; a concurrent request
returns a busy error instead of waiting indefinitely.

## Update and rollback

```sh
bloom update
bloom update --rollback
```

Updates require a clean checkout and fast-forward to the configured upstream. Keep personal
changes in the user-owned files under `~/.config/hypr/custom`, rather than
editing the clone. A changed PKGBUILD rebuilds the dependency metapackage.
Customized templates remain in place; updated defaults are offered as `.new`.
The previous revision is recorded before each completed update, and the shell
restarts after installation succeeds. Rollback checks out that revision; the
next update uses the recorded branch’s upstream.

Review and merge `.new` files yourself. Run `bloom doctor` if the shell does
not answer, and see [lock recovery](handover/phase6-lock-recovery.md) if you
need to recover a locked session.

## Uninstall

```sh
bloom uninstall
# Optional: bloom uninstall --remove-deps
```

Uninstall stops and disables Bloom, removes unchanged managed files and its
loader line, restores original files and service state, and prunes empty
installer-created directories. Application themes are restored from Bloom's
existing palette backups. Edited settings and Lua templates remain.
Edited managed service units or launchers cause an explicit refusal before
anything is stopped. Then, through `sudo`, the system part is undone: the
Bloom login theme and its setting are removed, SDDM is disabled again if Bloom
enabled it, and the login wallpaper folder and `bloom-login` group go. NetworkManager,
Bluetooth and power profiles stay enabled (listed), since turning them off is
more disruptive than leaving them. Packages stay installed unless
`--remove-deps` is specified. The clone itself and runtime history are kept.

## Development

`bloom dev install` and `bloom dev uninstall` remain lightweight link-only
commands and do not create a production install manifest. Run lifecycle tests
with `bash tests/cli/test_lifecycle.sh`; these use disposable homes, fake
package/service tools, and local Git remotes. They never modify the real
session or install packages.

## Release soak

```sh
bloom dev soak dock
bloom dev soak notch
bloom dev soak launcher
```

The visual soak opens and closes real panels for ten minutes at 250 ms
intervals. It supports notch/dock visibility and the launcher, overview,
session menu, cheatsheet, wallpaper picker, keyboard, and overlay. It restores
the original visibility on completion or interruption and stops if the session
locks. Native authentication, OSD and notification coverage uses the dedicated
isolated-compositor integration tests.

The result checks the shell's PID/start time, new journal warnings/errors, and
resident-memory growth after a one-minute warmup. The default growth limit is
8 MiB; `--max-growth-mib` can tighten it. Short diagnostic runs can use
`--duration`, `--interval` and `--warmup`; their JSON output explicitly reports
whether memory was measured. These short checks do not replace the ten-minute
release run. The soak helper's own tests use stub IPC and journal tools and
verify actual process-memory growth detection.
