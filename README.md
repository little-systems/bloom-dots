<div align="center">

<img src="shell/assets/bloom.png" width="72" alt="Bloom" />

# Bloom for Linux

**Your desktop, brought to life.**

The official Bloom desktop shell and dotfiles for Arch Linux and Hyprland.

[Get It Running](#get-it-running) · [Features](#the-island) · [Installation & Recovery](docs/INSTALL.md) · [Bloom for Windows](https://github.com/SehajveerSingh2005/bloom)

</div>

---

Bloom makes your Linux desktop feel alive.

A notch that opens into your music, calendar and controls. A dock that follows
your work. Notifications, search and Settings that feel like parts of the same
desktop.

`bloom-dots` is the official Linux member of the **Bloom product family**, alongside
[the original Bloom for Windows](https://github.com/SehajveerSingh2005/bloom).
The same visual identity, interactions and attention to motion, built around
Linux's desktop services.

---

## The Island

A notch at the top of your screen that adapts to what you're doing.

**Music** — album art, track information, playback controls and an audio visualizer.

**Command Center** — Wi-Fi, Bluetooth, power controls, Do Not Disturb, volume
and brightness.

**Status** — battery, weather, system activity and device alerts.

**Calendar** — your month, a focus timer and todos, within reach.

**Shelf** — a place for files and text you want to keep close.

Choose **Fixed**, **Smart** or **Peek** behavior. Open the panels you need, then
let the island settle back into your desktop.

---

## The Dock

Your apps and workspaces, together.

Pin your favorites. Drag to reorder. Hover for window previews. Right-click
for app actions and custom icons.

Fixed mode reserves room for your app windows. Smart mode gets out of their
way. Peek mode keeps the dock at the screen edge until you need it.

---

## The Rest of Your Desktop

**Search** — launch apps, find files and windows, calculate, search the web,
restore clipboard entries and pick emoji. AI chat lives in the same launcher,
with a key you provide.

**Notifications** — cards slide in from the top-right corner, then tuck away.
Return to the edge for history, expand the stack or clear it.

**Settings** — display, sound, power, network, Bluetooth, input and desktop
appearance, alongside Bloom's own controls. Separate UI and font scales,
exact numeric values, keyboard navigation and live previews.

**System surfaces** — a lock screen, session menu, authentication prompts,
system tray, workspace overview and keybinding cheatsheet.

**Tools** — screenshots, annotation, OCR, translation, screen recording,
wallpaper selection, an on-screen keyboard and a widget overlay.

---

## Under the Hood

Built with **Quickshell and Qt Quick**, with native Linux services doing the work.

PipeWire handles audio. NetworkManager handles networks. BlueZ handles Bluetooth.
UPower reports battery status. Hyprland supplies windows and workspaces.

Bloom's surfaces share their theme, typography and motion. Reduced motion and
a low-power mode let you tune the experience to your desktop.

The installer records what it changes, preserves your custom configuration and
keeps backups. Updates, rollback and uninstall use that same record.

---

## Get It Running

**Supported platform:** Arch Linux, Hyprland **0.56+** with Lua configuration,
and Quickshell **0.3+**. Install Python, Git and `base-devel` first.

Run as your desktop user:

```sh
git clone https://github.com/DhanushSantosh/bloom-dots ~/.local/share/bloom
~/.local/share/bloom/bin/bloom install --dry-run
~/.local/share/bloom/bin/bloom install
```

The dry run shows the plan. The installer then builds the dependency
metapackage, installs Bloom and registers its user service and Settings app.
Package installation uses your normal authentication prompt.

A new installation starts with the notch and dock. Open **Bloom Settings** to
choose additional surfaces and configure shortcuts. When another shell or
notification daemon is running, choose which service should own each surface
before enabling replacements.

Read [installation and recovery](docs/INSTALL.md) for requirements, customization,
updates, rollback and uninstall. Make sure `~/.local/bin` is on your PATH.

```sh
bloom settings
bloom doctor
bloom update
bloom update --rollback
```

---

## One Bloom Family

| Product | Desktop |
| --- | --- |
| [Bloom](https://github.com/SehajveerSingh2005/bloom) | The original Bloom for Windows |
| [Bloom for Linux](README.md) | The official Arch Linux / Hyprland shell and dotfiles in this repository |

Each product uses its platform's native services while sharing Bloom's design
and interaction language.

---

## Contributing

Found a bug? Open an issue with your Bloom revision, Hyprland and Quickshell
versions, and steps to reproduce it. Remove personal information from logs.

Have an idea? Open a feature request so we can agree on the behavior and keep
it consistent across the Bloom family.

For development:

- [UI and motion conventions](docs/ui-parity.md)
- [Design specification](docs/specs/2026-10-25-bloom-shell-design.md)
- Focused installer checks: `bash tests/cli/test_lifecycle.sh`
- Complete CI gate: `CI=true tests/run-all.sh`

Tests use disposable configuration and isolated compositors. GitHub CI runs the
checks in Arch Linux. See [the installation guide](docs/INSTALL.md#development)
for the development workflow.

Licensed under [GPLv3](LICENSE). Bundled third-party notices live in [licenses](licenses/) (Lucide icons and the OFL fonts: Inter, Selawik, Syne).

---

<div align="center">

**Your desktop is waiting.**

</div>
