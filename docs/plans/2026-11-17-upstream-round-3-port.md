# Upstream round 3 port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Bloom 63a9bf5's new work to bloom-dots: the Settings icon, localization, a Linux-first first-run guide, and agent live activities in the Island.

**Architecture:** Five parts in order A–E. B (an `I18n` singleton over Bloom's shared JSON catalogs plus a Linux overlay) comes before C and D so their text is translatable from the start. D's bridge is `bloom agent-hook` → `qs ipc call agents …`, with no network service.

**Tech Stack:** Quickshell/QML (Qt 6.12), Python 3 (lifecycle tools, hooks), Node (generators/checks), Bash.

**Spec:** `docs/specs/2026-11-17-upstream-round-3-port-design.md`

## Global Constraints

- Parity is literal: sizes, timings, easing and copy come from Bloom 63a9bf5 sources (`src/components/Onboarding.{tsx,css}`, `src/components/AgentAlert.{tsx,css}`, `src/agentAlerts.ts`, `src/i18n/*`, `integrations/*`), measured, never guessed.
- No Windows wording. No network listener, token or cloud dependency.
- Hooks are advisory: always exit 0, print `{}`, never block or decide.
- Settings are flat `bloom-`-prefixed keys in `shell/services/settings.js`; regenerate `SETTINGS.md` (`node tools/gen-settings-doc.mjs`) and the search index (`node tools/gen-settings-index.mjs`).
- Every clickable sets a cursor (`node tools/check-cursors.mjs`).
- Commits: conventional, author Dhanush Santosh, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Targeted tests while working; the full suite runs in CI.
- Live checks only on workspace 5, with a wlr virtual pointer.

## Review Focus

1. A hook firing while the shell is down or restarting: the agent must not stall (hook returns `{}` within its timeout, exit 0).
2. Out-of-order async Claude hooks: an older event must never overwrite a newer status.
3. Agent config with comments/unknown keys or an existing user hook on the same event: Connect/Disconnect must preserve everything else, byte-for-byte where untouched.
4. Language switched while the guide or an agent activity is showing: text re-renders, layout doesn't jump.
5. Guide on a small or scaled screen: arrows move inside the card; the card never leaves the screen.

---

## Part A — Settings icon

### Task 1: Bloom's sliders icon for Bloom Settings

**Files:**
- Modify: `share/icons/hicolor/*/apps/bloom-settings.png` (every size present)
- Modify: `third_party/bloom-icons/README.md`
- Modify: the dock icon delegate (`shell/modules/dock/DockIcon.qml`) for the 32 px draw size
- Test: `tests/qml/tst_dockview.qml`

- [ ] Step 1: Test `test_settingsIconDrawsAt32`: a pinned `bloom-settings` slot's icon image is 32×32 inside the standard slot; other apps unchanged.
- [ ] Step 2: Run it; expect FAIL.
- [ ] Step 3: Resize Bloom's `public/bloom-settings-sliders.png` (63a9bf5) to each existing size with ImageMagick (Lanczos), replace; credit it in the README; set the 32 px draw size for the `bloom-settings` id.
- [ ] Step 4: Test passes; `node tools/check-cursors.mjs` ok.
- [ ] Step 5: Commit `feat(dock): use Bloom's Settings icon`.

---

## Part B — Localization foundation

### Task 2: Catalogs and sync

**Files:** Create `shell/i18n/locales/{en,ru,fr,es,pt-BR,pt-PT}.json` (copied), `shell/i18n/linux/en.json`, `tools/sync-bloom-i18n.mjs`; Test `tests/cli/i18n_cases.py` (or `tests/scripts/test_i18n.sh`)

**Interfaces — Produces:** catalog files; `node tools/sync-bloom-i18n.mjs <bloom-checkout> [--check]` (copies `src/i18n/locales/*.json`; `--check` fails when they differ from the given checkout).

- [ ] Test: sync into a temp dir from a fixture checkout reproduces it; `--check` exits 1 on a difference.
- [ ] Implement; sync from `~/Projects/bloom` at 63a9bf5; record the commit in `shell/i18n/SOURCE`.
- [ ] Commit `feat(i18n): add Bloom's shared catalogs`.

### Task 3: `I18n` singleton

**Files:** Create `shell/services/I18n.qml`, `shell/services/i18n.js` (pure functions); Test `tests/qml/tst_i18n.qml`

**Interfaces — Produces:**
- `I18n.t(key: string, params?: object) -> string`
- `I18n.tCount(key: string, count: int, params?: object) -> string` (adds `count`)
- `I18n.language: string` (resolved), `I18n.revision: int`
- `i18n.js`: `resolveLanguage(setting, env) -> string`, `pluralCategory(lang, n) -> "one"|"few"|"many"|"other"`, `lookup(catalogs, lang, key) -> string|undefined`, `format(message, params) -> string`

- [ ] Tests (assert exactly): `resolveLanguage("system", {LANG:"ru_RU.UTF-8"})=="ru"`; `{LC_ALL:"pt_BR.UTF-8"}`→`"pt-BR"`; `{LANG:"pt"}`→`"pt-PT"`; `{LANG:"de_DE"}`→`"en"`; `("fr",{})`→`"fr"`. Russian plurals: 1 one, 2 few, 5 many, 21 one, 22 few, 11 many, 1.5 other. French: 0 and 1 one, 2 other. pt-BR 0 one; pt-PT 0 other. English 1 one, 0 other. Missing ru message falls back to en; empty string counts as missing; `{{name}}` replaced, unknown `{{x}}` left; Linux overlay key resolves; `t` of an unknown key returns the key.
- [ ] Implement; `revision` bumps on language or catalog change; FileView watches the catalogs.
- [ ] Commit `feat(i18n): add the I18n service`.

### Task 4: Language setting and check script

**Files:** Modify `shell/services/settings.js` (`bloom-language`: enum `system,en,ru,fr,es,pt-BR,pt-PT`, default `system`), `shell/settings/GeneralTab.qml`; Create `tools/check-i18n.mjs`; Modify `tests/run-all.sh` (quick group), `SETTINGS.md`, `TRANSLATING.md`; Tests `tests/qml/tst_settingsview.qml`, `tests/scripts/test_i18n_check.sh`

- [ ] Tests: Language row lists System default + six names in their own language (`English, Русский, Français, Español, Português (Brasil), Português (Portugal)`); choosing one updates `I18n.language` live. Check script: fixture with a used-but-missing key fails; a translation with an extra placeholder fails; incomplete plural set fails; coverage line printed.
- [ ] Implement; wire `node tools/check-i18n.mjs --check` into the quick group.
- [ ] Commit `feat(i18n): choose the language in Settings`.

---

## Part C — First-run guide

### Task 5: Lifecycle

**Files:** Modify `tools/bloom-lifecycle.py` (install writes `onboarding.json`), `shell/shell.qml` (IPC target `onboarding`: `open()`, `close()`, `state()`); Create `shell/services/OnboardingState.qml`; Tests `tests/cli/lifecycle_cases.py`, `tests/qml/tst_onboardingstate.qml`

- [ ] Tests: fresh install writes `{"completed": false}`; install with an existing `settings.json` writes `{"completed": true}`; an existing `onboarding.json` is never overwritten; `OnboardingState.pending` true only while not completed; finishing or skipping writes completed.
- [ ] Implement; the shell opens the guide once per session start while pending, after first-login.
- [ ] Commit `feat(onboarding): track first-run setup`.

### Task 6: Surface reveal

**Files:** Modify `shell/modules/notch/NotchView.qml`, `shell/modules/dock/DockView.qml` (`guideReveal: bool` — shown regardless of Smart/Peek hiding, not saved); Tests `tst_notchview.qml`, `tst_dockview.qml`

- [ ] Tests: in Peek mode with `guideReveal` the surface is shown; clearing it returns to normal hiding; the saved mode is unchanged.
- [ ] Implement. Commit `feat(onboarding): reveal the Island and Dock for the guide`.

### Task 7: The guide window

**Files:** Create `shell/modules/onboarding/OnboardingWindow.qml`, `OnboardingCard.qml`, `GuideArrow.qml`, `pages.js`; tokens in `shell/common/tokens.js` (`onboarding`, from Bloom's CSS); Test `tests/qml/tst_onboarding.qml`

**Interfaces — Consumes:** `I18n`, `OnboardingState`, `guideReveal`, `Settings.set`.

- [ ] Tests: 9 pages in the spec's order with their keys; card stays 500×400 across pages; pages 2 and 4 set `guideReveal` on Island/Dock and clear it on leave/close; step label "Step n of 9"; Back hidden on page 1; Escape closes and marks completed; reduced motion skips the move/fade; arrows inside the card when the anchor gap is below Bloom's threshold; input region equals card + arrows.
- [ ] Implement with Bloom's measured values (card, typography, button styles, fade/move timings, arrow geometry and stroke drawing).
- [ ] Commit `feat(onboarding): add the first-run guide`.

### Task 8: Choices, copy and replay

**Files:** Modify `pages.js`, `shell/i18n/linux/en.json` (Linux pages and hints), `shell/settings/GeneralTab.qml` ("Welcome to Bloom · Open setup"); Tests `tst_onboarding.qml`, `tst_settingsview.qml`

- [ ] Tests: Island/Dock mode buttons write `bloom-notch-mode`/`bloom-dock-mode` immediately; appearance writes `bloom-theme-mode` (dark/light/adaptive) and replay preserves an existing `custom`; "Show pending updates" writes `bloom-show-update-indicator`; a failed write keeps the old value and shows the error line; Settings "Open setup" calls the IPC.
- [ ] Implement; reuse Bloom keys for shared copy (`ui.onboarding.*`), `linux.onboarding.*` for ours.
- [ ] Commit `feat(onboarding): apply choices live and replay from Settings`.

### Task 9: Integration and live check

**Files:** Create `tests/integration/test_onboarding.sh`

- [ ] Headless sway: install fixture pending → shell opens the guide; virtual pointer clicks through all pages; state completed; a restart doesn't reopen it.
- [ ] Live check on workspace 5 (owner go-ahead), screenshots for review.
- [ ] Commit `test(onboarding): cover the guide end to end`.

---

## Part D — Agent live activities

### Task 10: Hook

**Files:** Create `tools/bloom_agent_hook.py`; Modify `bin/bloom` (`agent-hook <claude|codex>`); Test `tests/cli/agent_hook_cases.py`

**Interfaces — Produces:** stdin event JSON → `{agent, session, project, kind, activity?, at, pid, started}` sent via `qs ipc call agents event <json>`; stdout `{}`; exit 0 always.

- [ ] Tests: each Claude event → kind/activity exactly as Bloom's `agent-hook.ps1` (incl. Notification matcher types, PostToolUseFailure interrupt → stopped); Codex PermissionRequest → working; tool-name regexes; session from `session_id` else `thread_id`; project = basename of cwd; payload > 4 KiB never sent; owner = first ancestor not in the relay set, with `/proc` start time (fixture `/proc` via env); qs missing/failing → still `{}` and exit 0 within 3 s.
- [ ] Implement. Commit `feat(agents): add the agent hook`.

### Task 11: Connect, update, disconnect

**Files:** Create `tools/bloom_agents.py`; Modify `bin/bloom` (`agents status|connect|disconnect <agent>`); Create `integrations/opencode-bloom-v1.js`, `integrations/opencode-bloom-v2.js` (Bloom's, sending through `bloom agent-hook opencode-event`); Test `tests/cli/agents_cases.py`

- [ ] Tests (from Bloom's Rust tests): install idempotent; removal preserves user hooks and unrelated settings; backup written once before the first change; Claude handlers `{"type":"command","command":…,"async":true}`, Codex `{"type":"command","command":…,"timeout":3}`; Notification group has `matcher: "permission_prompt|elicitation_dialog"`; paths honour `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `XDG_CONFIG_HOME`; a modified OpenCode plugin is never overwritten; status reports installed/needs-update/verified; a checkout path with shell metacharacters is refused.
- [ ] Implement. Commit `feat(agents): connect Claude Code, Codex and OpenCode`.

### Task 12: AgentAlerts service

**Files:** Create `shell/services/AgentAlerts.qml`, `shell/services/agents.js`; IPC target `agents` in `shell/shell.qml` (`event(json)`, `test(agent, kind)`, `state()`); Test `tests/qml/tst_agentalerts.qml`

- [ ] Tests: per-session ordering by `at` drops stale events; status change keeps start time; completion freezes elapsed and holds 4000 ms; attention/finished expire at 10 min; working at 24 h; stopped clears; disabled setting clears all; owner-process exit (stubbed `/proc` probe) clears within one poll (2 s); queue held while a panel/shelf/device alert is open or DND is on; verified agent recorded in `agents.json`.
- [ ] Implement. Commit `feat(agents): track agent sessions`.

### Task 13: The Island activity

**Files:** Create `shell/modules/notch/AgentActivity.qml`; Modify `NotchView.qml` (activity holds the pill; music to its side pill), `shell/assets/agents/*.svg` (Bloom's logos); tokens from `AgentAlert.css`; Test `tst_notchview.qml`

- [ ] Tests: 36 px row, logo 20×20 in a 20×22 box, 16 px side padding, 24 px gap; status text per kind; elapsed formatting as Bloom; logo rotates while working and not under reduced motion; music bubble shown while an activity holds the pill; click opens the default/remembered panel and closing restores the activity.
- [ ] Implement. Commit `feat(notch): show agent live activities`.

### Task 14: Integrations tab

**Files:** Create `shell/settings/IntegrationsTab.qml`; Modify `SettingsView.qml` (tab + sidebar), `shell/services/settings.js` (`bloom-agent-alerts-enabled`), `SETTINGS.md`, search index; Test `tst_settingsview.qml`

- [ ] Tests: three agents with logos and status text; Connect/Update/Disconnect call `bloom agents …` and refresh; Setup help shown until verified; Test notch calls `agents test`; master switch writes the setting; layout per Bloom's `IntegrationsTab.css`.
- [ ] Implement. Commit `feat(settings): add the Integrations tab`.

### Task 15: Docs and dogfood

**Files:** Create `docs/AGENTS.md` (Linux version of Bloom's integrations README); Modify `README.md` feature list.
- [ ] Connect Claude Code on this machine (owner go-ahead), watch a real session in the Island; record results.
- [ ] Commit `docs(agents): document agent live activities`.

---

## Part E — Localize the existing UI

### Task 16–23: one task per area

Areas: notch (16), dock (17), launcher (18), OSD + notifications (19), lock + session + polkit (20), cheatsheet + overview + OSK (21), Settings tabs (22), settings-app dialogs (23).

Per task:
- [ ] Test: `node tools/check-i18n.mjs --check` passes and a Russian fixture run of the area's QML test shows a Russian string where Bloom has one (fallback English elsewhere).
- [ ] Replace literals with `I18n.t`/`tCount`, reusing Bloom's keys where the English is identical; Linux-only under `linux.<area>.*`.
- [ ] Commit `feat(i18n): localize the <area>`.

---

## Finish

- Final whole-branch review (fresh reviewer), fixes, then the owner's merge decision.
- Update the agc session-handoff after each part.
