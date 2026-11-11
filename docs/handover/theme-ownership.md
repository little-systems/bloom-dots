# Application theme ownership

`shell/scripts/adaptive-theme.sh` renders app themes (GTK 3/4 CSS and
`settings.ini`, fuzzel, Hyprland colors, Qt/KDE palette and schemes, kitty) into
a private staging copy of the current files. `shell/scripts/theme-owner.py` then
installs them. Renderers never write the owner's files directly.

## Ownership rule

A target is owned by Bloom when Bloom has not touched it yet, or when its content
still matches the SHA-256 that Bloom last wrote. The ledger is
`$XDG_STATE_HOME/bloom/app-themes/ownership.json` (version 1, mode 0600, in a
0700 directory). Pre-Bloom copies are kept in `originals/`.

- **First touch:** the original is copied, fsynced and recorded before the write.
  A file that did not exist is recorded as Bloom-created.
- **Each write:** the new fingerprint is recorded as `pending` before the atomic
  replacement and promoted to `written` afterwards. A crash between the two is
  recognised by its pending fingerprint, not mistaken for an owner edit.
- **Conflicts:** content edited after Bloom wrote it, a deleted target, a
  symlink or a non-regular file is left alone and listed as `conflict …` on
  stdout. Exit status 3 means the run finished but left something alone, and the
  shell still treats the palette as applied. Exit 2 means a staged path outside
  the target list was refused before any change.
- **Restore:**
  - Owned targets get their original back, and Bloom-created files are removed.
  - An edited target stays; its pre-Bloom copy moves to `kept/<time>/` and is
    reported.
  - The ledger is deleted once it is empty.
- **Desktop settings:** GNOME `color-scheme` and `gtk-theme` follow the same rule.
  The original value is recorded on first set. A value changed after Bloom set it
  is neither overwritten nor restored.

Targets follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME`.
`BLOOM_THEME_HOME` overrides the whole tree as a virtual home, which the tests use.

## Legacy migration

The earlier script kept bare backups plus a `manifest` listing what existed, with
no fingerprints. The first run under the new code converts them:

- Listed files become originals, with no `written` fingerprint, so Bloom still
  owns its current copy.
- An unlisted file that exists now cannot be attributed to anyone. The next apply
  backs up today's copy as its original. A restore before any apply leaves it in
  place and reports it.
- The legacy `gnome-*` value files become recorded originals.

The cost of the legacy rule is that an owner edit made before upgrading can't be
told apart from Bloom's last write, as before. Unlisted files are never deleted.

Uninstall restores themes when either ledger format exists, and treats exit 3 as
done, with the kept files listed.

Tests: `tests/cli/test_theme_owner.sh` (13 ownership cases), the two app-theme
script tests, and the lifecycle uninstall theme cases.

## What app theming covers, and what it doesn't

Supported:
- GTK 3/4: CSS colours, `settings.ini` light/dark, and the GNOME
  `color-scheme`/`gtk-theme` keys. Electron apps follow the GTK theme name.
- Qt/KDE apps, through `kdeglobals` and colour schemes. A Qt app sees them only
  when a platform theme reads them (Plasma integration or qt6ct).
- Hyprland borders, fuzzel, and kitty, through the ii-style include path.

Not themed:
- Web page content in browsers.
- Apps that ignore the platform theme (some Flatpaks, Java and SDL apps).
- Terminals other than kitty, and editors' own themes.

A change reaches a running app only if the app reloads its theme; kitty gets
SIGUSR1 and Hyprland reloads. Others pick it up when they next start.
