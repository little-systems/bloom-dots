# Upstream round 3: what Bloom shipped since cd04ac9, for Linux

Bloom (Windows) main at `63a9bf5` (2026-11-16) is 47 commits past `cd04ac9`, the
last ported commit. Five merged pull requests:

| Bloom PR | What | bloom-dots |
|---|---|---|
| #389 | Dedicated Bloom Settings icon (sliders) | Port: icon swap (A) |
| #393 (+ d683f80, 3379d64) | Localization, 6 languages, English fallback | Port: foundation first (B), strings last (E) |
| #388 | First-run setup and quick guide | Port as **our own** guide (C) |
| #377 | Agent live activities in the notch | Port with a Linux bridge (D) |
| #381 | Dock web apps (Internet shortcuts, AUMIDs) | Nothing: Linux web apps are desktop entries the dock already matches |
| #391 | CI workflow permissions | Nothing |

**Order:** A, B, C, D, E. The i18n foundation lands before C and D so their
new text is translatable from the first commit; E converts the existing UI.

**Why:** the owner's standing goal is 1:1 parity with Bloom, measured against
it, except where Linux needs its own answer (the owner chose a Linux-first guide
over a copy of Bloom's Windows tour).

**Anti-goals:** no Windows wording on Linux (taskbar, "Start with Windows");
no network service, token or cloud dependency for agent events; no change to an
agent's behaviour (hooks are advisory and never decide anything); no machine-
translated catalogs.

---

## A. Bloom Settings icon (#389)

- Bloom's dock pins Settings with `public/bloom-settings-sliders.png` (grey bloom
  silhouette with three sliders) at 32 px inside the 40 px slot
  (`.dock-icon img.bloom-settings-icon { width: 32px; height: 32px }`).
- bloom-dots: replace `share/icons/hicolor/*/apps/bloom-settings.png` (today the
  white mascot) with that artwork at every size the theme already ships, so the
  dock, launcher and Settings window all use it. The dock draws it at 32 px in the
  same slot; other apps keep their size.
- Licence: GPL-3.0, as Bloom; note the source in `third_party/bloom-icons/README.md`.

## B. Localization foundation (#393, d683f80, 3379d64)

**Bloom's model:** i18next JSON v4 catalogs (`src/i18n/locales/{en,ru,fr,es,pt-BR,pt-PT}.json`),
nested keys, `{{name}}` placeholders, `_one`/`_other` plurals; English is complete
and every other catalog may be partial; anything missing or invalid falls back to
English per message. `bloom-language`: `"system"` (default) or a locale code;
changes apply live; unsupported languages use English.

**bloom-dots:**
- **Catalogs:** `shell/i18n/locales/*.json` are copies of Bloom's catalogs
  (shared keys, shared translations), refreshed by `tools/sync-bloom-i18n.mjs
  <bloom checkout>`; `shell/i18n/linux/en.json` (and optional `linux/<locale>.json`)
  holds Linux-only messages under a top-level `linux` key. A message is looked up
  in the locale's Bloom catalog, its Linux overlay, then English (Bloom, then
  overlay).
- **`I18n` singleton** (`shell/services/I18n.qml`): `t(key, params)`,
  `tCount(key, count, params)`, `language` (resolved code), `revision` (bumped on
  every change so bindings re-evaluate). Plural categories by the CLDR rules for
  the six languages, written out (QML's JS has no `Intl.PluralRules`): English,
  Spanish, both Portuguese use one/other (pt-PT: 1 is one; pt-BR and French: 0
  and 1 are one); Russian uses one/few/many/other. Placeholders replace
  `{{name}}`; an unknown placeholder is left as written; a message with an empty
  value counts as missing.
- **`system`** resolves from `LC_ALL`, `LC_MESSAGES`, `LANG` in that order
  (`ru_RU.UTF-8` → `ru`, `pt_BR` → `pt-BR`, `pt_PT` and `pt` → `pt-PT`).
- **Settings → General → Language**: System default plus the six languages,
  each shown in its own name. Changes apply live to the shell and Settings.
- **Check script** `tools/check-i18n.mjs --check` (CI quick job): every literal
  `I18n.t("…")`/`tCount("…")` key in `shell/` exists in English; catalogs parse;
  placeholders in a translation are a subset of English's; plural keys complete
  per language. Prints coverage per language (warning, not failure).
- **Docs:** `SETTINGS.md` gains `bloom-language`; `TRANSLATING.md` says
  translations are contributed to Bloom's catalogs upstream (shared), and Linux-
  only messages here.

## C. First-run guide (our own; Bloom #388 for look and motion)

**Look and motion: Bloom's, exactly.** Single opaque card 500×400 following the
current theme (light text and controls in Light, adaptive accent); content fades
out in place, the card moves with a transform and never resizes, new text fades
in without vertical motion; curved hand-drawn arrows point from outside the card
to the live Island or Dock (inside the card on small screens); reduced motion
removes movement and fades; the input region is the card and arrows only, so the
desktop stays usable. Values come from Bloom's `Onboarding.css`/`Onboarding.tsx`
(measured, not guessed), placed on a layer-shell overlay window.

**Pages (ours):**
1. **Welcome.** "Welcome to Bloom." / "Bloom makes your Linux desktop feel alive."
   [Show me around] [Skip]
2. **Meet the Island** (anchor: Island; the Island is revealed even in Smart/Peek).
   Hints: hover for widgets and status; click to open calendar and focus timer,
   Command Center and devices; scroll or swipe while hovering to switch; drop
   files or text on it to keep them on the shelf.
3. **Keep it in reach.** Island Fixed / Smart / Peek, Bloom's descriptions, live.
4. **Meet the Dock** (anchor: Dock, revealed). Hints: hover for names and window
   previews; drag apps to reorder; right-click for app options and custom icons;
   workspaces on the left.
5. **Give your apps some space.** Dock Fixed / Smart / Peek, live.
6. **A little less interruption.** Volume and brightness at the screen edges:
   keys work as usual; hover an edge and scroll or drag to adjust.
7. **Everything a keystroke away** (ours). Tap Super for search: apps, files,
   calculator, web; Super+V clipboard; Super+. emoji; Super+Tab overview; Super+/
   lists every shortcut.
8. **Make yourself at home.** Appearance Dark / Light / Adaptive (follows the
   wallpaper), applied live; "Show pending updates" (`bloom-show-update-indicator`).
   No startup toggle: on Linux Bloom is the session.
9. **Already blooming.** Hints: open Settings from Command Center or the Bloom
   Settings app; Super+/ for shortcuts; `bloom uninstall` puts your previous
   desktop back.

All choices apply immediately through the normal settings path; a failed change
keeps the old value and shows an error on the card. Skip/close keeps what was
already applied. Escape closes.

**Lifecycle:** `~/.local/state/bloom/onboarding.json` = `{"completed": bool}`,
independent of version. At install: an existing `settings.json` means completed
(no unsolicited guide after an update); a fresh install writes pending. The shell
opens the guide on its first start in a session while pending (after the first-
login finish), once. Replay: Settings → General → "Welcome to Bloom · Open setup",
and `bloom ipc onboarding open`.

**Defaults:** fresh installs already get Island Fixed, Dock Smart (unchanged).

## D. Agent live activities (#377)

**Behaviour, as Bloom** (`integrations/README.md` at 63a9bf5 is the reference):
- One row at the Island's normal 36 px height: animated agent logo + status on the
  left, elapsed wall time on the right; no dots, checkmark or close button. Logo
  rotates while working (reduced motion: still).
- Statuses: Working (thinking, reading, editing, running), Needs attention,
  Response ready, Error. Status changes keep the elapsed time; completion freezes
  it and holds 4 s before the Island returns to other content; new work resets it.
- Music moves to its side pill while an agent holds the Island. Hover keeps the
  activity compact; click opens the default/remembered panel; closing it brings
  the activity back with its time intact.
- Queue: alerts wait while a panel, shelf, device alert or announcement is open;
  bounded per-session queue, deduplicated; finished/attention entries expire after
  10 min; working entries stay until completion/end/interrupt, with a 24 h
  fallback; toggling alerts off or restarting Bloom clears them; nothing is
  written to disk. Do Not Disturb (Bloom's notification DND) holds presentation.
- Event mapping per agent exactly as Bloom's hook and plugins (Claude Code: 9
  events, async; Codex: 7 events, `{}` on stdout, 3 s timeout; OpenCode 1.x and
  2.x plugins). Events older than the latest for their session are dropped
  (ordering by hook launch time).
- Payload `{agent, session, project, kind, activity?, at?}`, ≤ 4 KiB,
  allow-listed values only. No prompts, responses, tool arguments or commands.
- Logos: Bloom's `public/agents/*.svg` (vendor geometry and colours, light variants).

**Linux bridge (ours):** no HTTP server or token. The hook command is
`'<checkout>/bin/bloom' agent-hook <agent>`: a small Python script reads the
event JSON from stdin, maps it, and sends it with `qs ipc call` to an `agents`
IPC target in the running shell (same-user only, like Quickshell IPC itself).
It always exits 0 and prints `{}`; a closed Bloom never slows or stops an agent.
For session end it records the agent process: the hook's parent chain, skipping
relay shells and interpreters (sh, bash, zsh, dash, fish, env, python, node only
when it is OpenCode's runner), with its start time from `/proc/<pid>/stat`
(field 22) so a reused PID isn't mistaken; the shell clears the session within a
few seconds of that process exiting.

**Integrations (Settings):** a tab listing Claude Code, Codex and OpenCode with
status (Not connected / Installed · awaiting first event / Connected / Needs
update), Connect / Update / Disconnect, Setup help, Test notch, and the master
switch `bloom-agent-alerts-enabled` (bool, default true). Connect merges hooks
into `~/.claude/settings.json` (`CLAUDE_CONFIG_DIR`), `~/.codex/hooks.json`
(`CODEX_HOME`) and writes `~/.config/opencode/plugins/bloom-notifications.js`
(`XDG_CONFIG_HOME`), saving `<file>.bloom-backup` before the first change,
preserving other settings and handlers, idempotent; Disconnect removes only
Bloom's exact handlers. "Connected" is remembered in
`~/.local/state/bloom/agents.json` after a real event. Done by
`bloom agents status|connect|disconnect <agent>` (Python, JSON output), so the
UI and CLI share one implementation.

## E. Localization of the existing UI

Convert user-facing text in shell and Settings to `I18n.t`/`tCount`, reusing
Bloom's key and message wherever the English text is identical (so Bloom's
translations apply), Linux-only text under `linux.*`. Module by module:
notch, dock, launcher, OSD and notifications, lock and session, cheatsheet and
overview, Settings tabs, settings-app dialogs. Excluded: logs, IPC strings,
setting keys, names supplied by apps/devices/users.

---

## Left to the builder

Exact QML structure, file splits, which existing tokens to reuse, test layout
(following the project's existing tests: QML TestCase, `tests/cli/*_cases.py`,
integration scripts), and wording of Linux-only hints within the meaning above.

## Verification

Each part: failing test first; targeted tests while working; CI runs the full
suite (owner's rule). Live checks on workspace 5 with a virtual pointer
(never `cursor.move` warps). Part D is dogfooded with Claude Code on this machine.
