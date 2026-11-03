# Install and maintain Bloom

Bloom targets Arch Linux and Hyprland 0.56 or newer with a Lua configuration.
Quickshell 0.3 or newer, Python, Git and `base-devel` must be installed first.
Run the commands as your desktop user. Package tools prompt normally when
privileges are needed; Bloom does not handle or save your password.

## Install

```sh
git clone https://github.com/DhanushSantosh/bloom-dots ~/.local/share/bloom
~/.local/share/bloom/bin/bloom install --dry-run
~/.local/share/bloom/bin/bloom install
```

The installer builds `packaging/bloom-shell-deps/PKGBUILD` with `makepkg -si`
in a temporary directory. Use `--no-deps` only when you have installed the
metapackage's dependencies yourself. The dry run performs preflight checks
and prints its file plan, without changing your desktop or installing packages.

The install links the shell, CLI and user units, registers Settings with its
icon, adds one marked loader line to `~/.config/hypr/hyprland.lua`, and offers
three user-owned Lua templates under `custom/`. Existing custom templates are
kept and the supplied version is written beside them as `.new`. Existing
settings and personal keybindings are kept. Shortcut examples are commented
out until you choose them.

Ensure `~/.local/bin` is on your PATH. Open Settings with `bloom settings`.
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
bloom recover --resume            # finish the recorded install/removal
bloom recover --restore-originals # remove Bloom and restore pre-install files
```

Recovery validates the journal and refuses ambiguous owner edits. Resume of an
installation uses the current checkout and installed prerequisites; it never
runs a package transaction. `--restore-originals` restores the installation's
original files, not the immediately preceding code/configuration generation.
Keep the checkout and recovery backups until restoration finishes.

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

Updates require a clean checkout and use `git pull --ff-only`. Keep personal
changes in the user-owned files under `~/.config/hypr/custom`, rather than
editing the clone. A changed PKGBUILD rebuilds the dependency metapackage.
Customized templates remain in place; updated defaults are offered as `.new`.
The previous revision is recorded before each completed update, and the shell
restarts after installation succeeds. Rollback checks out that revision; the
next update returns to the recorded branch before pulling again.

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
anything is stopped. Dependencies stay installed unless `--remove-deps` is
specified; that command invokes the normal `sudo pacman -Rns` prompt.
The clone itself and runtime history are kept.

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
