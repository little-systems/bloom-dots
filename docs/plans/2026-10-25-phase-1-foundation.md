# Phase 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the base every later phase stands on:
- the repo skeleton;
- the spring engine and `EdgeSurface`;
- typed, live-reloading settings; UI state files; theme tokens;
- a shell that starts under systemd and answers `bloom ipc`;
- the `bloom` CLI (ipc, doctor, dev install);
- a test harness that runs locally and in CI.

**Architecture:**
- **Shell:** a Quickshell config in `shell/`. `shell.qml` loads singleton services from `shell/services/` and exposes `IpcHandler`s.
- **Logic:** everything testable is plain JS (`*.js`, no `.pragma`, no `export`), so three things can load the same file: QML (`import "x.js" as X`), `qmltestrunner` unit tests, and Node (via `vm`, for the framer-motion parity test and the settings doc generator).
- **Integration tests:** run the real shell headless with `QT_QPA_PLATFORM=offscreen` against throwaway XDG directories.
- **Headless compositor deferred:** spec §9's headless wlroots compositor (sway) is needed only once there are layer surfaces. Phase 1 has none, so its load test uses Qt's offscreen platform, and phase 2 adds sway headless.

**Tech Stack:**
- Quickshell 0.3.2 (`quickshell` in Arch `extra`), Qt 6.12 Quick / QtTest / Shapes
- bash
- Node 26 + `motion-dom@12.43.0` (parity test only)
- systemd user units
- GitHub Actions on an `archlinux:latest` container

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` (sections 3, 5.2, 5.3, 6, 8 phase 1, 9, 10, Appendix A).

## Global Constraints

- Arch Linux only; Hyprland ≥ 0.56 with the Lua config; Quickshell ≥ 0.3. Phase 1 has no Hyprland code.
- Settings file: `~/.config/bloom/settings.json` (`$XDG_CONFIG_HOME/bloom/settings.json`). A flat object, key names `bloom-*` as in Bloom, values in native JSON types.
- UI state: `~/.local/state/bloom/<name>.json` (`$XDG_STATE_HOME/bloom/`), kept apart from settings.
- An invalid or missing setting falls back to its default and logs a warning. A bad `settings.json` never stops the shell.
- Spring parity: our engine must stay within **0.01 px** of framer-motion (`motion-dom@12.43.0`) for every Appendix A spring over 0→100 px, until framer reports the spring at rest.
- Layer surfaces never resize while animating; only the input mask follows the shape. Phase 1 has no surfaces, but `EdgeSurface` is built for this rule.
- Layer namespaces are `bloom:<panel>`.
- Shell unit: `bloom-shell.service`, `Restart=on-failure`, `RestartSec=1`, `StartLimitBurst=5` within 60 s; after giving up, report via `hyprctl notify`.
- **Nothing under `~/.config` or `~/dots-hyprland` is touched by any task.** The only exception is Task 9, which the owner runs themselves after approving it.
- Commits: conventional commits (`feat:`, `fix:`, `test:`, `docs:`, `chore:`), each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Git identity:** this machine has no git identity configured, so commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`. Do not change git config.
- **Style:** QML and JS use tabs, like Bloom. Comments explain why, not what.

## Review Focus

1. **A hand-edited `settings.json` saved with a syntax error.** The shell keeps the last good values, logs a warning, and refuses `settings set` until the file is fixed. It never overwrites the broken file. Test: Task 7 `test_shell.sh`.
2. **Settings copied from Bloom for Windows, with string values (`"true"`, `"0.8"`).** These are accepted as bool/number. Test: Task 5 `tst_settings.qml` `test_bloomStringForms`.
3. **First run with no `settings.json`.** Defaults apply, the file is *not* created by starting the shell, and creating the file later is picked up. FileView cannot watch a file that never existed, so Settings polls until it appears. Test: Task 7 `test_shell.sh`.
4. **`bloom dev install` when `~/.config/quickshell/bloom` already exists** (e.g. the user's own config). The command refuses and creates nothing, not even the unit links. Test: Task 8 `test_bloom.sh`.
5. **`bloom ipc` while the shell is down.** It exits non-zero quickly, so `bloom ipc … || fallback` keybinds work. Test: Task 7 `test_shell.sh` (real `qs`) and Task 8 (stub).

---

## File map

| File | Responsibility |
|---|---|
| `VERSION` | Single version string (`0.1.0`) |
| `.gitignore` | Adds `tests/parity/node_modules/` |
| `README.md` | Adds a Development section |
| `.github/workflows/ci.yml` | CI: an Arch container that runs `tests/run-all.sh` |
| `tests/run-all.sh` | Runs every check: lint, unit, parity, integration, CLI, units, docs |
| `shell/common/spring.js` | Damped-spring maths (closed form) and framer-motion rest thresholds |
| `shell/common/Spring.qml` | Animated value that follows `target` with spring physics |
| `shell/common/tokens.js` | Appendix A design tokens as data |
| `shell/common/EdgeSurface.qml` | Pill + concave flares background (Bloom EdgeSurface) |
| `shell/common/paths.js` | XDG path helpers |
| `shell/services/settings.js` | Settings schema, validation, parsing |
| `shell/services/Settings.qml` | Live settings singleton (file watch, write, warnings) |
| `shell/services/theme.js` | Bloom theme maths ported from `theme.ts` |
| `shell/services/Theme.qml` | Theme token singleton bound to Settings |
| `shell/services/state.js` | UI state file parsing |
| `shell/services/StateFile.qml` | One UI state JSON document with corrupt-file recovery |
| `shell/shell.qml` | Shell root: loads services, IPC handlers |
| `systemd/bloom-shell.service`, `systemd/bloom-shell-failed.service` | Supervision units |
| `bin/bloom` | CLI: `ipc`, `doctor`, `dev install/uninstall/status`, `version` |
| `tools/gen-settings-doc.mjs` | Generates/checks `docs/SETTINGS.md` from the schema |
| `docs/SETTINGS.md` | Generated settings reference |
| `tests/qml/tst_*.qml` | `qmltestrunner` unit tests |
| `tests/parity/*` | framer-motion parity test (Node) |
| `tests/integration/*` | Real-shell offscreen tests |
| `tests/cli/test_bloom.sh` | CLI tests with stubbed `qs`/`systemctl`/`journalctl`/`hyprctl` |
| `tests/units/test_units.sh` | `systemd-analyze verify` on the units |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-25)

- `qmllint` exits 0 on warnings and 255 on syntax errors. Quickshell types produce false-positive warnings (e.g. "PanelWindow is not creatable"), so CI fails only on non-zero exit.
- `qmltestrunner` (`/usr/lib/qt6/bin/qmltestrunner`) runs with `QT_QPA_PLATFORM=offscreen`. Pixel tests need the scene root to be a visual `Item` that contains the `TestCase`.
- **Layers:** `layer.sourceRect` *scales* the texture into the item's bounds; it does not extend them. Children outside a layered item's bounds are therefore clipped, so `EdgeSurface` makes its own box include the flare margins.
- **Running headless:** `qs -p <dir>` runs headless with `QT_QPA_PLATFORM=offscreen` and `WAYLAND_DISPLAY` unset.
- **`Qt.exit(code)`** sets qs's exit code when called after load (e.g. from a `Timer`). It does nothing inside `Component.onCompleted` of the root.
- **Imports:** a config can only import QML from inside its own folder, so test harnesses copy `shell/` into a temp config folder. `import qs.services` resolves `<config root>/services`, and singletons in the same folder can reference each other.
- **`FileView` watching:**
  - With `watchChanges: true` it reloads on in-place edits, atomic replace (rename), delete (`loadFailed` FileNotFound) and re-creation, **but only for a file that existed when first read**. A file missing at startup is never noticed.
  - `setText()` creates missing parent directories.
- **Polling a missing file:** if Settings polls `reload()` on a missing file until it appears, the watch is active from then on (edits and atomic replaces are seen).
- **`qs ipc call`** exits 255 when no instance is running.
- **Parity:** `motion-dom@12.43.0` exports `spring({keyframes, stiffness, damping, mass})` with `.next(ms) → {value, done}`. Our closed form matches it to about 1e-14 for every Appendix A spring.
- **Units:** `systemd-analyze verify` (without `--user`) accepts the units below.
- **Bloom theme references** (computed with Bloom's own `hexToHsl`/`hslToHex`):
  - custom `#007aff`, saturation 0.5, brightness 0.15 → background `#132639`;
  - custom `#ff9500`, 0.3, 0.7 → `#c9b69c` (light).

---

### Task 1: Repo scaffolding, test runner, CI

**Files:**
- Create: `VERSION`, `tests/run-all.sh`, `.github/workflows/ci.yml`
- Modify: `.gitignore`, `README.md`

**Interfaces:**
- Produces: `tests/run-all.sh`, the single entry point CI and developers run. Later tasks add their test files in the locations it scans. It runs each step only when that step's inputs exist, so it passes from Task 1 on.

- [ ] **Step 1: Owner installs the lint tool** (it needs sudo; ask the owner to run it):

```bash
sudo pacman -S --needed shellcheck
```

Expected: `shellcheck` on PATH. (`quickshell`, `qt6-declarative`, `nodejs`, `npm` and `jq` are already installed.)

- [ ] **Step 2: Create `VERSION`**

```
0.1.0
```

- [ ] **Step 3: Append to `.gitignore`**

```
tests/parity/node_modules/
```

- [ ] **Step 4: Create `tests/run-all.sh`**

```bash
#!/usr/bin/env bash
# Runs every check CI runs, in order. Usage: tests/run-all.sh
# Set CI=true to make missing tools an error instead of a skipped step.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
export QT_QPA_PLATFORM=offscreen NO_COLOR=1
unset WAYLAND_DISPLAY
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
	XDG_RUNTIME_DIR="$(mktemp -d)"
	export XDG_RUNTIME_DIR
fi

step() { printf '\n== %s\n' "$1"; }
need() {
	command -v "$1" >/dev/null && return 0
	[[ "${CI:-}" == true ]] && { echo "missing required tool: $1" >&2; exit 1; }
	echo "skipped: $1 not installed"
	return 1
}

step "qmllint (fails on errors; Quickshell types cause harmless warnings)"
mapfile -d '' qml_files < <(find "$ROOT/shell" "$ROOT/tests" -name '*.qml' -not -path '*/node_modules/*' -print0)
if (( ${#qml_files[@]} )); then
	if ! "$QT_BIN/qmllint" "${qml_files[@]}" >/dev/null 2>&1; then
		"$QT_BIN/qmllint" "${qml_files[@]}" 2>&1 | grep -v '^Warning' || true
		exit 1
	fi
	echo "ok"
fi

step "shellcheck"
if need shellcheck; then
	mapfile -d '' sh_files < <(find "$ROOT/bin" "$ROOT/tests" -type f \( -name '*.sh' -o -name bloom \) -print0 2>/dev/null)
	shellcheck -x -P SCRIPTDIR --severity=warning "${sh_files[@]}"
	echo "ok"
fi

step "QML unit tests"
if compgen -G "$ROOT/tests/qml/tst_*.qml" >/dev/null; then
	"$QT_BIN/qmltestrunner" -input "$ROOT/tests/qml"
fi

step "spring parity with framer-motion"
if [[ -f "$ROOT/tests/parity/spring-parity.mjs" ]] && need node; then
	[[ -d "$ROOT/tests/parity/node_modules" ]] || (cd "$ROOT/tests/parity" && npm ci --silent)
	node "$ROOT/tests/parity/spring-parity.mjs"
fi

step "settings reference is up to date"
if [[ -f "$ROOT/tools/gen-settings-doc.mjs" ]] && need node; then
	node "$ROOT/tools/gen-settings-doc.mjs" --check
fi

step "integration tests (real shell, offscreen)"
for t in "$ROOT"/tests/integration/test_*.sh; do
	[[ -e "$t" ]] || continue
	need qs || break
	bash "$t"
done

step "CLI tests"
for t in "$ROOT"/tests/cli/test_*.sh; do
	[[ -e "$t" ]] && bash "$t"
done

step "systemd units"
for t in "$ROOT"/tests/units/test_*.sh; do
	[[ -e "$t" ]] && bash "$t"
done

printf '\nall checks passed\n'
```

- [ ] **Step 5: Make it executable and run it**

Run: `chmod +x tests/run-all.sh && tests/run-all.sh`
Expected: each step prints its header, the shellcheck step prints `ok`, and the last line is `all checks passed`.

- [ ] **Step 6: Create `.github/workflows/ci.yml`**

```yaml
name: ci
on:
  push:
  pull_request:
jobs:
  checks:
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - name: Install tools
        run: pacman -Syu --noconfirm --needed git quickshell qt6-declarative qt6-svg nodejs npm jq shellcheck systemd
      - uses: actions/checkout@v4
      - name: Run all checks
        run: CI=true tests/run-all.sh
```

- [ ] **Step 7: Append a Development section to `README.md`**

```markdown

## Development

Requirements: Arch Linux with `quickshell`, `qt6-declarative`, `nodejs`, `npm`, `jq`, `shellcheck`.

- Run every check (the same as CI): `tests/run-all.sh`
- The design spec lives in `docs/specs/`, implementation plans in `docs/plans/`.
```

- [ ] **Step 8: Commit**

```bash
git add VERSION .gitignore README.md tests/run-all.sh .github/workflows/ci.yml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "chore: add test runner and CI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Spring maths and framer-motion parity

**Files:**
- Create: `shell/common/spring.js`, `tests/qml/tst_spring.qml`, `tests/parity/package.json`, `tests/parity/package-lock.json` (generated), `tests/parity/spring-parity.mjs`

**Interfaces:**
- Produces (in `shell/common/spring.js`, imported in QML as `import "spring.js" as SpringMath`):
  - `springStep(k: number, c: number, m: number, d0: number, v0: number, dt: number) → [offset: number, velocity: number]`: the exact state `dt` seconds later, where `d0 = value - target`.
  - `isGranular(from: number, to: number) → bool`: true when `|to - from| < 5`.
  - `restThresholds(granular: bool, restDelta: number, restSpeed: number) → [delta, speed]`. A negative argument means "framer-motion's default": `0.5`/`2`, or `0.005`/`0.01` when granular.

- [ ] **Step 1: Write the failing unit test `tests/qml/tst_spring.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/common/spring.js" as SpringMath

TestCase {
	name: "SpringMath"

	// value at time t (s) for a 0 -> 100 move
	function at(k, c, m, t) {
		return 100 + SpringMath.springStep(k, c, m, -100, 0, t)[0];
	}

	function test_underdampedMatchesFramerReference() {
		// framer-motion 12.43 (motion-dom spring generator), stiffness 500, damping 30
		fuzzyCompare(at(500, 30, 1, 0.050), 36.586, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.150), 102.563, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.250), 103.057, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.300), 100.682, 0.001);
	}

	function test_criticallyDampedClosedForm() {
		// k=100, c=20, m=1 -> zeta = 1, w0 = 10: d(t) = (d0 + (v0 + w0*d0) t) e^(-w0 t)
		fuzzyCompare(at(100, 20, 1, 0.1), 100 - 200 * Math.exp(-1), 1e-9);
	}

	function test_overdampedIsMonotonic() {
		let prev = 0;
		for (let t = 0.01; t < 1; t += 0.01) {
			const x = at(100, 40, 1, t);
			verify(x >= prev && x <= 100, `overdamped spring overshot at t=${t}: ${x}`);
			prev = x;
		}
	}

	function test_stepsCompose_data() {
		return [
			{ tag: "underdamped", k: 400, c: 31, m: 1 },
			{ tag: "critical", k: 100, c: 20, m: 1 },
			{ tag: "overdamped", k: 100, c: 40, m: 1 },
			{ tag: "light mass", k: 550, c: 45, m: 0.8 }
		];
	}

	// Ten 1 ms steps must land exactly where one 10 ms step does, so frame
	// timing never changes the motion.
	function test_stepsCompose(row) {
		let d = -100, v = 0;
		for (let i = 0; i < 10; i++) [d, v] = SpringMath.springStep(row.k, row.c, row.m, d, v, 0.001);
		const one = SpringMath.springStep(row.k, row.c, row.m, -100, 0, 0.010);
		fuzzyCompare(d, one[0], 1e-9);
		fuzzyCompare(v, one[1], 1e-9);
	}

	function test_restThresholds() {
		compare(SpringMath.restThresholds(false, -1, -1), [0.5, 2]);
		compare(SpringMath.restThresholds(true, -1, -1), [0.005, 0.01]);
		compare(SpringMath.restThresholds(false, 0.001, -1), [0.001, 2]);
	}

	function test_isGranular() {
		verify(SpringMath.isGranular(0, 1));
		verify(!SpringMath.isGranular(0, 5));
		verify(!SpringMath.isGranular(140, 340));
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_spring.qml`
Expected: FAIL, because `spring.js` does not exist yet ("No such file" / `SpringMath` is not defined).

- [ ] **Step 3: Create `shell/common/spring.js`**

```js
// Damped spring maths shared by Spring.qml, the QML unit tests and the
// framer-motion parity test (tests/parity). Plain JS on purpose: no .pragma
// and no exports, so Node can evaluate the same file.

// Exact state of a damped spring after dt seconds, starting at offset d0
// (value - target) with velocity v0. Parameters are framer-motion's:
// stiffness k, damping c, mass m. Returns [offset, velocity].
// Stepping from the current state each frame is exact for any frame time,
// and keeps velocity when the target changes mid-flight, as framer-motion does.
function springStep(k, c, m, d0, v0, dt) {
	const w0 = Math.sqrt(k / m);
	const z = c / (2 * Math.sqrt(k * m));
	if (z < 1) {
		const wd = w0 * Math.sqrt(1 - z * z);
		const e = Math.exp(-z * w0 * dt);
		const A = d0;
		const B = (v0 + z * w0 * d0) / wd;
		const cs = Math.cos(wd * dt);
		const sn = Math.sin(wd * dt);
		const d = e * (A * cs + B * sn);
		return [d, -z * w0 * d + e * wd * (B * cs - A * sn)];
	}
	if (z === 1) {
		const e = Math.exp(-w0 * dt);
		const C = v0 + w0 * d0;
		const d = (d0 + C * dt) * e;
		return [d, C * e - w0 * d];
	}
	const s = Math.sqrt(z * z - 1);
	const r1 = -w0 * (z - s);
	const r2 = -w0 * (z + s);
	const C2 = (v0 - r1 * d0) / (r2 - r1);
	const C1 = d0 - C2;
	const e1 = Math.exp(r1 * dt);
	const e2 = Math.exp(r2 * dt);
	return [C1 * e1 + C2 * e2, r1 * C1 * e1 + r2 * C2 * e2];
}

// framer-motion treats moves under 5 units (scale, opacity...) as granular
// and uses finer rest thresholds for them.
function isGranular(from, to) {
	return Math.abs(to - from) < 5;
}

// [restDelta, restSpeed]; a negative argument selects framer-motion's default.
function restThresholds(granular, restDelta, restSpeed) {
	return [
		restDelta >= 0 ? restDelta : granular ? 0.005 : 0.5,
		restSpeed >= 0 ? restSpeed : granular ? 0.01 : 2
	];
}
```

- [ ] **Step 4: Run the unit test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_spring.qml`
Expected: `Totals: … passed, 0 failed`.

- [ ] **Step 5: Create `tests/parity/package.json`**

```json
{
	"name": "bloom-spring-parity",
	"private": true,
	"type": "module",
	"dependencies": {
		"motion-dom": "12.43.0"
	}
}
```

- [ ] **Step 6: Create `tests/parity/spring-parity.mjs`**

```js
// Fails if shell/common/spring.js drifts from framer-motion's spring for any
// spring Bloom uses (spec Appendix A). Samples every millisecond of a
// 0 -> 100 px move until framer reports the spring at rest; framer snaps to
// the target at that point, so the comparison stops there.
import { spring } from "motion-dom";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const TOLERANCE_PX = 0.01;
const SPRINGS = [
	{ name: "pill width", stiffness: 400, damping: 31, mass: 1 },
	{ name: "pill height", stiffness: 450, damping: 29, mass: 1 },
	{ name: "pill y", stiffness: 550, damping: 45, mass: 0.8 },
	{ name: "corner radii", stiffness: 1000, damping: 40, mass: 1 },
	{ name: "default", stiffness: 500, damping: 30, mass: 1 },
	{ name: "clock flip", stiffness: 600, damping: 30, mass: 1 },
	{ name: "visualizer bar", stiffness: 600, damping: 30, mass: 0.5 },
	{ name: "button press", stiffness: 400, damping: 25, mass: 1 }
];

const ctx = {};
vm.createContext(ctx);
vm.runInContext(readFileSync(new URL("../../shell/common/spring.js", import.meta.url), "utf8"), ctx);

let failed = false;
for (const s of SPRINGS) {
	const framer = spring({ keyframes: [0, 100], stiffness: s.stiffness, damping: s.damping, mass: s.mass });
	let worst = 0;
	let t = 0;
	for (; t <= 10000; t++) {
		const f = framer.next(t);
		if (f.done) break;
		const ours = 100 + ctx.springStep(s.stiffness, s.damping, s.mass, -100, 0, t / 1000)[0];
		worst = Math.max(worst, Math.abs(f.value - ours));
	}
	const ok = worst <= TOLERANCE_PX;
	failed ||= !ok;
	console.log(`${ok ? "ok  " : "FAIL"} ${s.name} ${s.stiffness}/${s.damping}/${s.mass}: max error ${worst.toExponential(2)} px over ${t} ms`);
}
process.exit(failed ? 1 : 0);
```

- [ ] **Step 7: Install the pinned dependency and run the parity test**

Run: `cd tests/parity && npm install && cd ../.. && node tests/parity/spring-parity.mjs`
Expected: 8 lines starting with `ok`, each with a max error around `2.84e-14`, and exit code 0. `npm install` writes `tests/parity/package-lock.json`.

- [ ] **Step 8: Run the whole suite**

Run: `tests/run-all.sh`
Expected: the unit test and parity steps run and pass, then `all checks passed`.

- [ ] **Step 9: Commit**

```bash
git add shell/common/spring.js tests/qml/tst_spring.qml tests/parity/package.json tests/parity/package-lock.json tests/parity/spring-parity.mjs
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add spring maths matching framer-motion

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Spring component

**Files:**
- Create: `shell/common/Spring.qml`, `tests/qml/tst_springitem.qml`

**Interfaces:**
- Consumes: `springStep`, `isGranular`, `restThresholds` from `shell/common/spring.js`.
- Produces: QML type `Spring` (from `shell/common/`):
  - inputs: `stiffness: real`, `damping: real`, `mass: real`, `restDelta: real` (-1 = default), `restSpeed: real` (-1 = default), `initial: real` (NaN = start at target), `target: real`, `autoRun: bool` (default true);
  - outputs: `value: real`, `velocity: real`, `settled: bool`;
  - methods: `step(dt: real)` (seconds), `jump(v: real)` (snap the value, zero the velocity, start moving toward target).

- [ ] **Step 1: Write the failing test `tests/qml/tst_springitem.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/common"

TestCase {
	name: "Spring"

	Component {
		id: springComponent
		Spring { autoRun: false }
	}

	function make(props) {
		const s = createTemporaryObject(springComponent, null, props);
		verify(s !== null);
		return s;
	}

	function test_startsAtTargetByDefault() {
		const s = make({ target: 140 });
		compare(s.value, 140);
		verify(s.settled);
	}

	function test_initialValue() {
		const s = make({ target: 140, initial: 30.6 });
		compare(s.value, 30.6);
		verify(!s.settled);
	}

	function test_stepFollowsFramerCurve() {
		const s = make({ stiffness: 500, damping: 30, initial: 0, target: 100 });
		s.step(0.05);
		fuzzyCompare(s.value, 36.586, 0.001);
	}

	// framer-motion keeps position and velocity when the target changes mid-flight.
	function test_retargetKeepsVelocity() {
		const s = make({ stiffness: 400, damping: 31, initial: 140, target: 340 });
		s.step(0.05);
		const value = s.value, velocity = s.velocity;
		verify(velocity > 0);
		s.target = 140;
		compare(s.value, value);
		compare(s.velocity, velocity);
		s.step(0.016);
		verify(s.value > value, "still moving toward the old target for a moment");
	}

	function test_settlesExactlyOnTarget() {
		const s = make({ stiffness: 450, damping: 29, initial: 36, target: 120 });
		for (let i = 0; i < 200 && !s.settled; i++) s.step(0.016);
		verify(s.settled);
		compare(s.value, 120);
		compare(s.velocity, 0);
	}

	function test_granularMovesUseFineThresholds() {
		const s = make({ stiffness: 600, damping: 30, mass: 0.5, initial: 0.1, target: 0.9 });
		s.step(0.1);
		verify(!s.settled || Math.abs(s.value - 0.9) <= 0.005);
	}

	function test_nonFiniteTargetIsIgnored() {
		const s = make({ initial: 10, target: 20 });
		s.target = NaN;
		s.step(0.016);
		verify(isFinite(s.value), "value must never become NaN");
	}

	function test_jump() {
		const s = make({ initial: 0, target: 100 });
		s.step(0.05);
		s.jump(250);
		compare(s.value, 250);
		compare(s.velocity, 0);
		verify(!s.settled);
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_springitem.qml`
Expected: FAIL, because `Spring is not a type`.

- [ ] **Step 3: Create `shell/common/Spring.qml`**

```qml
import QtQuick
import "spring.js" as SpringMath

// A value that follows `target` with framer-motion's spring physics
// (stiffness, damping, mass; seconds), so Bloom's motion carries over exactly.
// Bind a property to `value`. Retargeting mid-flight keeps position and
// velocity, like an interrupted framer-motion animation.
Item {
	id: root
	visible: false

	property real stiffness: 500
	property real damping: 30
	property real mass: 1
	// Negative means framer-motion's default (see spring.js restThresholds).
	property real restDelta: -1
	property real restSpeed: -1
	// Starting value; NaN starts at the target.
	property real initial: NaN
	property real target: 0
	// Frames drive the spring; tests turn this off and call step() themselves.
	property bool autoRun: true

	property real value: 0
	property real velocity: 0
	property bool settled: true
	property bool _granular: false

	Component.onCompleted: {
		root.value = isNaN(root.initial) ? root.target : root.initial;
		root._granular = SpringMath.isGranular(root.value, root.target);
		root.settled = root.value === root.target;
	}

	onTargetChanged: {
		if (!isFinite(root.target)) {
			console.warn(`bloom: Spring ignored non-finite target ${root.target}`);
			return;
		}
		root._granular = SpringMath.isGranular(root.value, root.target);
		root.settled = false;
	}

	function jump(v) {
		root.value = v;
		root.velocity = 0;
		root._granular = SpringMath.isGranular(v, root.target);
		root.settled = v === root.target;
	}

	function step(dt) {
		if (root.settled || !isFinite(root.target))
			return;
		const r = SpringMath.springStep(root.stiffness, root.damping, root.mass, root.value - root.target, root.velocity, dt);
		const rest = SpringMath.restThresholds(root._granular, root.restDelta, root.restSpeed);
		let x = root.target + r[0];
		let v = r[1];
		if (Math.abs(x - root.target) <= rest[0] && Math.abs(v) <= rest[1]) {
			x = root.target;
			v = 0;
			root.settled = true;
		}
		root.velocity = v;
		root.value = x;
	}

	FrameAnimation {
		running: root.autoRun && !root.settled
		// Cap long frames (e.g. after a stall) so the spring never jumps.
		onTriggered: root.step(Math.min(frameTime, 0.064))
	}
}
```

Note on `jump()`: it marks the spring settled only when `v` equals the target. `test_jump` expects `settled` to be false after `jump(250)` with target 100, which this satisfies.

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_springitem.qml`
Expected: `0 failed`. A `WARN … Spring ignored non-finite target nan` line is expected from `test_nonFiniteTargetIsIgnored`.

- [ ] **Step 5: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add shell/common/Spring.qml tests/qml/tst_springitem.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add Spring component

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Design tokens and EdgeSurface

**Files:**
- Create: `shell/common/tokens.js`, `shell/common/EdgeSurface.qml`, `tests/qml/tst_edgesurface.qml`

**Interfaces:**
- Produces:
  - `tokens.js`, imported as `import "tokens.js" as Tokens` (or `"../common/tokens.js"`). It exposes top-level vars `springs`, `sizes`, `edge`, `type`, `status` (exact fields below).
  - QML type `EdgeSurface`:
    - inputs: `edge: string` (`"top" | "bottom" | "left" | "right"`), `pillWidth: real`, `pillHeight: real`, `edgeRadius: real`, `farRadius: real`, `color: color`, `flares: bool`;
    - outputs: `pillRect: rect` (the pill inside the item's own box), `horizontal: bool`.
    - Its own `width`/`height` include the 13 px flare margins along the edge, because a layer clips children outside the item's bounds.

- [ ] **Step 1: Write the failing test `tests/qml/tst_edgesurface.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/common"

Item {
	id: host
	width: 400
	height: 200

	Rectangle { anchors.fill: parent; color: "white" }

	EdgeSurface {
		id: top
		x: 20
		edge: "top"
		pillWidth: 140
		pillHeight: 36
		edgeRadius: 0
		farRadius: 18
		color: Qt.rgba(0, 0, 0, 0.8)
	}

	EdgeSurface {
		id: left
		x: 0
		y: 80
		edge: "left"
		pillWidth: 40
		pillHeight: 80
		color: Qt.rgba(0, 0, 0, 0.8)
		flares: false
	}

	TestCase {
		name: "EdgeSurface"
		when: windowShown

		function test_boxIncludesFlareMargins() {
			compare(top.width, 140 + 26);
			compare(top.height, 36);
			compare(top.pillRect, Qt.rect(13, 0, 140, 36));
			compare(left.width, 40);
			compare(left.height, 80 + 26);
			compare(left.pillRect, Qt.rect(0, 13, 40, 80));
		}

		function test_flaresPaintAtThePillsAlpha() {
			waitForRendering(host);
			const img = grabImage(host);
			const pill = img.pixel(20 + 13 + 70, 18);
			const nearEdge = img.pixel(20 + 10, 0); // start flare where it meets the edge (the curve leaves the edge at x≈6)
			const end = img.pixel(20 + 13 + 140 + 2, 0); // end flare, mirrored
			verify(Qt.colorEqual(nearEdge, pill), `start flare ${nearEdge} vs pill ${pill}`);
			verify(Qt.colorEqual(end, pill), `end flare ${end} vs pill ${pill}`);
			verify(!Qt.colorEqual(pill, "white"));
		}

		function test_flareIsConcave() {
			waitForRendering(host);
			const img = grabImage(host);
			// Bottom-left of the start flare's box is outside the curve.
			verify(Qt.colorEqual(img.pixel(20 + 1, 12), "white"));
		}

		function test_farCornersAreRounded() {
			waitForRendering(host);
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(20 + 13, 35), "white"), "bottom-left corner cut by farRadius");
			verify(!Qt.colorEqual(img.pixel(20 + 13, 0), "white"), "top-left corner square (edgeRadius 0)");
		}

		function test_flaresOff() {
			waitForRendering(host);
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(0 + 1, 80 + 2), "white"), "left surface has no flares");
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_edgesurface.qml`
Expected: FAIL, because `EdgeSurface is not a type`.

- [ ] **Step 3: Create `shell/common/tokens.js`** (Appendix A as data; later phases add fields here, never literals in panels)

```js
// Bloom design tokens (spec Appendix A, from Bloom App.tsx / App.css /
// theme.ts / EdgeSurface @ b5fb962). Plain JS: imported by QML and readable
// by Node tools.

// framer-motion spring parameters.
var springs = {
	pillWidth: { stiffness: 400, damping: 31, mass: 1 },
	pillHeight: { stiffness: 450, damping: 29, mass: 1 },
	pillY: { stiffness: 550, damping: 45, mass: 0.8, restDelta: 0.001 },
	radius: { stiffness: 1000, damping: 40, mass: 1 },
	standard: { stiffness: 500, damping: 30, mass: 1 },
	flip: { stiffness: 600, damping: 30, mass: 1 },
	visualizerBar: { stiffness: 600, damping: 30, mass: 0.5 },
	press: { stiffness: 400, damping: 25, mass: 1 }
};

// Notch geometry in px.
var sizes = {
	collapsed: { width: 140, height: 36 },
	clock24hTrim: 16,
	musicVisualizer: 30,
	musicArt: 30,
	statusHoverBase: 200,
	statusHoverPerWidget: 50,
	statusHoverMax: 380,
	musicClassic: { width: 340, height: 120 },
	edgeRadius: 0,
	farRadius: 18,
	calendarFarRadius: 28,
	padding: 12,
	mainRow: 36
};

// EdgeSurface: concave flares bridging a pill to its screen edge.
var edge = {
	flareSize: 13,
	// Cubic handle length; a circle would use 7.2, longer eases into both edges.
	flareHandle: 10,
	flareFadeMs: 300
};

var type = {
	family: "Inter",
	clock: { size: 13, weight: 500, tracking: 0.3 },
	widgetLabel: { size: 11, weight: 500, opacity: 0.85 },
	title: { size: 14.5, weight: 600, tracking: -0.15 },
	artist: { size: 12, weight: 400 }
};

var status = {
	green: "#32D74B",
	red: "#FF453A"
};
```

- [ ] **Step 4: Create `shell/common/EdgeSurface.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import "tokens.js" as Tokens

// Background of a surface attached to a screen edge (notch, dock, OSD): the
// pill plus two concave flares that bridge it to the edge, as Bloom's
// EdgeSurface. The pieces are painted opaque and the whole layer takes the
// colour's alpha, so no seam or darker overlap shows where they meet.
// A layer clips children outside the item, so this item's own box includes
// the flare margins along the edge; put content inside `pillRect`.
Item {
	id: root

	property string edge: "top"
	property real pillWidth: Tokens.sizes.collapsed.width
	property real pillHeight: Tokens.sizes.collapsed.height
	// Corners touching the screen edge, and corners facing away from it.
	property real edgeRadius: Tokens.sizes.edgeRadius
	property real farRadius: Tokens.sizes.farRadius
	property color color: Qt.rgba(0, 0, 0, 0.8)
	property bool flares: true

	readonly property bool horizontal: edge === "top" || edge === "bottom"
	readonly property real _f: Tokens.edge.flareSize
	readonly property rect pillRect: horizontal
		? Qt.rect(_f, 0, pillWidth, pillHeight)
		: Qt.rect(0, _f, pillWidth, pillHeight)
	readonly property color _solid: Qt.rgba(color.r, color.g, color.b, 1)

	width: horizontal ? pillWidth + 2 * _f : pillWidth
	height: horizontal ? pillHeight : pillHeight + 2 * _f

	layer.enabled: true
	opacity: color.a

	Rectangle {
		x: root.pillRect.x
		y: root.pillRect.y
		width: root.pillWidth
		height: root.pillHeight
		color: root._solid
		antialiasing: true
		topLeftRadius: root.edge === "top" || root.edge === "left" ? root.edgeRadius : root.farRadius
		topRightRadius: root.edge === "top" || root.edge === "right" ? root.edgeRadius : root.farRadius
		bottomLeftRadius: root.edge === "bottom" || root.edge === "left" ? root.edgeRadius : root.farRadius
		bottomRightRadius: root.edge === "bottom" || root.edge === "right" ? root.edgeRadius : root.farRadius
	}

	// Mirroring per edge and end, as EdgeSurface.css: index 0 = start, 1 = end.
	readonly property var _mirror: ({
		top: [[1, 1], [-1, 1]],
		bottom: [[1, -1], [-1, -1]],
		left: [[1, 1], [1, -1]],
		right: [[-1, 1], [-1, -1]]
	})

	Repeater {
		model: 2

		Shape {
			id: flare
			required property int index
			readonly property real len: root._f + 1 // 13 px curve + 1 px over the pill

			width: root.horizontal ? len : root._f
			height: root.horizontal ? root._f : len
			x: root.horizontal
				? (index === 0 ? 0 : root._f + root.pillWidth - 1)
				: (root.edge === "left" ? 0 : root.pillWidth - root._f)
			y: root.horizontal
				? (root.edge === "top" ? 0 : root.pillHeight - root._f)
				: (index === 0 ? 0 : root._f + root.pillHeight - 1)

			opacity: root.flares ? 1 : 0
			Behavior on opacity {
				// CSS `ease`, as Bloom's opacity transition.
				NumberAnimation {
					duration: Tokens.edge.flareFadeMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
				}
			}

			preferredRendererType: Shape.CurveRenderer
			transform: Scale {
				origin.x: flare.width / 2
				origin.y: flare.height / 2
				xScale: root._mirror[root.edge][flare.index][0]
				yScale: root._mirror[root.edge][flare.index][1]
			}

			// Drawn as the top edge's start flare (or the left edge's top flare).
			ShapePath {
				fillColor: root._solid
				strokeWidth: -1
				startX: 0
				startY: 0
				PathCubic {
					x: Tokens.edge.flareSize
					y: Tokens.edge.flareSize
					control1X: root.horizontal ? Tokens.edge.flareHandle : 0
					control1Y: root.horizontal ? 0 : Tokens.edge.flareHandle
					control2X: root.horizontal ? Tokens.edge.flareSize : Tokens.edge.flareSize - Tokens.edge.flareHandle
					control2Y: root.horizontal ? Tokens.edge.flareSize - Tokens.edge.flareHandle : Tokens.edge.flareSize
				}
				PathLine { x: root.horizontal ? flare.len : Tokens.edge.flareSize; y: root.horizontal ? Tokens.edge.flareSize : flare.len }
				PathLine { x: root.horizontal ? flare.len : 0; y: root.horizontal ? 0 : flare.len }
				PathLine { x: 0; y: 0 }
			}
		}
	}
}
```

The control points reproduce EdgeSurface.css exactly:
- horizontal: `curve to 13px 13px with 10px 0 / 13px 3px`;
- vertical: `with 0 10px / 3px 13px`.

`13 - 10 = 3`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_edgesurface.qml`
Expected: `0 failed`.
- If `test_flaresPaintAtThePillsAlpha` fails with near-equal colours, the cause is antialiasing at the sampled pixel. Move the sample one pixel further inside the shape; do not loosen the assertion to "not white".

- [ ] **Step 6: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add shell/common/tokens.js shell/common/EdgeSurface.qml tests/qml/tst_edgesurface.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add design tokens and EdgeSurface

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Paths, settings schema and the settings reference

**Files:**
- Create: `shell/common/paths.js`, `shell/services/settings.js`, `tests/qml/tst_paths.qml`, `tests/qml/tst_settings.qml`, `tools/gen-settings-doc.mjs`, `docs/SETTINGS.md` (generated)

**Interfaces:**
- Produces (`paths.js`):
  - `settingsFile(xdgConfigHome: string|undefined, home: string) → string`
  - `stateFile(xdgStateHome: string|undefined, home: string, name: string) → string`; throws on a name that isn't `[a-z0-9-]+`.
- Produces (`settings.js`):
  - data: `SCHEMA` (key → `{type, default, doc, values?, min?, max?}`), `MODULES` (string array);
  - lookups: `keys() → string[]`, `defaults() → object`;
  - validation, each returning `{ok: true, value} | {ok: false, error: string}`: `validateValue(spec, value)`, `validateOne(key, value)`;
  - `validate(obj) → {values, warnings: string[]}`;
  - `parse(text) → {ok: true, value} | {ok: false, error}`, where empty text means `{}`;
  - `serialize(obj) → string` (tab-indented JSON plus a newline);
  - `nonDefaults(values) → object`;
  - `changedKeys(a, b) → string[]`.

- [ ] **Step 1: Write the failing tests**

`tests/qml/tst_paths.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/common/paths.js" as Paths

TestCase {
	name: "Paths"

	function test_settingsFile() {
		compare(Paths.settingsFile(undefined, "/home/u"), "/home/u/.config/bloom/settings.json");
		compare(Paths.settingsFile("", "/home/u"), "/home/u/.config/bloom/settings.json");
		compare(Paths.settingsFile("/x/cfg", "/home/u"), "/x/cfg/bloom/settings.json");
	}

	function test_stateFile() {
		compare(Paths.stateFile(undefined, "/home/u", "todo"), "/home/u/.local/state/bloom/todo.json");
		compare(Paths.stateFile("/x/st", "/home/u", "dock-order"), "/x/st/bloom/dock-order.json");
	}

	function test_stateFileRejectsPathTricks() {
		let threw = false;
		try { Paths.stateFile(undefined, "/home/u", "../evil"); } catch (e) { threw = true; }
		verify(threw);
	}
}
```

`tests/qml/tst_settings.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/services/settings.js" as Settings

TestCase {
	name: "SettingsSchema"

	function test_defaults() {
		const d = Settings.defaults();
		compare(d["bloom-theme-mode"], "dark");
		compare(d["bloom-theme-color"], "#007aff");
		compare(d["bloom-theme-opacity"], 0.8);
		compare(d["bloom-theme-saturation"], 0.5);
		compare(d["bloom-theme-brightness"], 0.15);
		compare(d["bloom-enabled-modules"], []);
		compare(Object.keys(d).sort(), Settings.keys().sort());
	}

	function test_defaultsAreFreshCopies() {
		Settings.defaults()["bloom-enabled-modules"].push("notch");
		compare(Settings.defaults()["bloom-enabled-modules"], []);
	}

	// Review focus 2: Bloom for Windows stored every value as a string.
	function test_bloomStringForms() {
		compare(Settings.validateValue({ type: "bool" }, "true"), { ok: true, value: true });
		compare(Settings.validateValue({ type: "bool" }, "false"), { ok: true, value: false });
		compare(Settings.validateOne("bloom-theme-opacity", "0.8"), { ok: true, value: 0.8 });
		verify(!Settings.validateOne("bloom-theme-opacity", "").ok);
		verify(!Settings.validateValue({ type: "bool" }, "yes").ok);
	}

	function test_numberRange() {
		verify(Settings.validateOne("bloom-theme-opacity", 0).ok);
		verify(Settings.validateOne("bloom-theme-opacity", 1).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", 1.5).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", NaN).ok);
	}

	function test_enum() {
		verify(Settings.validateOne("bloom-theme-mode", "light").ok);
		verify(!Settings.validateOne("bloom-theme-mode", "neon").ok);
	}

	function test_colorNormalised() {
		compare(Settings.validateOne("bloom-theme-color", "#0AF"), { ok: true, value: "#00aaff" });
		compare(Settings.validateOne("bloom-theme-color", "#FF9500"), { ok: true, value: "#ff9500" });
		verify(!Settings.validateOne("bloom-theme-color", "blue").ok);
	}

	function test_listEntriesMustBeKnownAndAreDeduplicated() {
		compare(Settings.validateOne("bloom-enabled-modules", ["notch", "dock", "notch"]), { ok: true, value: ["notch", "dock"] });
		verify(!Settings.validateOne("bloom-enabled-modules", ["notch", "taskbar"]).ok);
		verify(!Settings.validateOne("bloom-enabled-modules", "notch").ok);
	}

	function test_validateFallsBackAndWarns() {
		const r = Settings.validate({ "bloom-theme-opacity": 1.5, "bloom-theme-mode": "neon", "bloom-theme-color": "#123456", "x-future": 1 });
		compare(r.values["bloom-theme-opacity"], 0.8);
		compare(r.values["bloom-theme-mode"], "dark");
		compare(r.values["bloom-theme-color"], "#123456");
		compare(r.warnings.length, 3);
		verify(r.warnings.some(w => w.startsWith("x-future: unknown setting")));
	}

	function test_validateNonObject() {
		compare(Settings.validate([1, 2]).values, Settings.defaults());
		compare(Settings.validate(null).warnings.length, 1);
	}

	function test_parse() {
		compare(Settings.parse(""), { ok: true, value: {} });
		compare(Settings.parse("  \n"), { ok: true, value: {} });
		compare(Settings.parse('{"a": 1}'), { ok: true, value: { a: 1 } });
		verify(!Settings.parse('{"a": ').ok);
	}

	function test_serializeRoundTrips() {
		const obj = { "bloom-theme-mode": "light", "x-future": [1, 2] };
		const text = Settings.serialize(obj);
		verify(text.endsWith("\n"));
		compare(JSON.parse(text), obj);
	}

	function test_nonDefaultsAndChangedKeys() {
		const v = Settings.defaults();
		v["bloom-theme-mode"] = "light";
		compare(Settings.nonDefaults(v), { "bloom-theme-mode": "light" });
		compare(Settings.changedKeys(Settings.defaults(), v), ["bloom-theme-mode"]);
	}
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml`
Expected: `tst_paths` and `tst_settings` FAIL because the JS files don't exist yet. The earlier tests still pass.

- [ ] **Step 3: Create `shell/common/paths.js`**

```js
// XDG locations for Bloom's files. Plain JS (shared with tests).

function _configHome(xdgConfigHome, home) {
	return xdgConfigHome ? xdgConfigHome : home + "/.config";
}

function _stateHome(xdgStateHome, home) {
	return xdgStateHome ? xdgStateHome : home + "/.local/state";
}

function settingsFile(xdgConfigHome, home) {
	return _configHome(xdgConfigHome, home) + "/bloom/settings.json";
}

// `name` becomes a file name, so it is limited to [a-z0-9-].
function stateFile(xdgStateHome, home, name) {
	if (!/^[a-z0-9-]+$/.test(name))
		throw new Error("invalid state name: " + name);
	return _stateHome(xdgStateHome, home) + "/bloom/" + name + ".json";
}
```

- [ ] **Step 4: Create `shell/services/settings.js`**

```js
// Settings schema and validation. Plain JS shared by Settings.qml, the QML
// unit tests and tools/gen-settings-doc.mjs (no .pragma, no exports).
// Each phase adds the keys its surfaces use; docs/SETTINGS.md is generated
// from SCHEMA.

var MODULES = ["notch", "dock", "osd", "notifications", "launcher", "overview", "session", "lock", "polkit", "tray", "regiontools", "wallpaper", "cheatsheet"];

var SCHEMA = {
	"bloom-theme-mode": {
		type: "enum",
		values: ["dark", "light", "custom", "adaptive"],
		default: "dark",
		doc: "Theme mode. Adaptive follows the wallpaper; until wallpaper theming exists it falls back to dark."
	},
	"bloom-theme-color": {
		type: "color",
		default: "#007aff",
		doc: "Accent colour for the custom theme (#rgb or #rrggbb)."
	},
	"bloom-theme-opacity": {
		type: "number",
		min: 0,
		max: 1,
		default: 0.8,
		doc: "Surface opacity. Hovered and open surfaces add 0.12."
	},
	"bloom-theme-saturation": {
		type: "number",
		min: 0,
		max: 1,
		default: 0.5,
		doc: "Background saturation for the custom and adaptive themes."
	},
	"bloom-theme-brightness": {
		type: "number",
		min: 0,
		max: 1,
		default: 0.15,
		doc: "Background lightness for the custom and adaptive themes. Above 0.55 the text turns dark."
	},
	"bloom-enabled-modules": {
		type: "list",
		values: MODULES,
		default: [],
		doc: "Bloom surfaces to run. Anything not listed is left to another shell (e.g. illogical-impulse)."
	}
};

function keys() {
	return Object.keys(SCHEMA);
}

function _copy(v) {
	return Array.isArray(v) ? v.slice() : v;
}

function defaults() {
	const out = {};
	keys().forEach(k => out[k] = _copy(SCHEMA[k].default));
	return out;
}

function _ok(value) {
	return { ok: true, value: value };
}

function _fail(error) {
	return { ok: false, error: error };
}

// Validates and normalises one value against a schema entry. Accepts Bloom
// for Windows' string forms ("true", "0.8"), which stored every value as text.
function validateValue(spec, value) {
	switch (spec.type) {
	case "bool":
		if (value === true || value === false)
			return _ok(value);
		if (value === "true" || value === "false")
			return _ok(value === "true");
		return _fail("expected true or false");
	case "number": {
		const n = typeof value === "string" && value.trim() !== "" ? Number(value) : value;
		if (typeof n !== "number" || !isFinite(n))
			return _fail("expected a number");
		if ((spec.min !== undefined && n < spec.min) || (spec.max !== undefined && n > spec.max))
			return _fail(`expected a number from ${spec.min} to ${spec.max}`);
		return _ok(n);
	}
	case "enum":
		if (spec.values.indexOf(value) < 0)
			return _fail("expected one of " + spec.values.join(", "));
		return _ok(value);
	case "color": {
		if (typeof value !== "string" || !/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value))
			return _fail("expected a colour like #007aff");
		let h = value.slice(1).toLowerCase();
		if (h.length === 3)
			h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
		return _ok("#" + h);
	}
	case "list": {
		if (!Array.isArray(value))
			return _fail("expected a list");
		const unknown = value.filter(v => spec.values.indexOf(v) < 0);
		if (unknown.length)
			return _fail(`unknown ${JSON.stringify(unknown)}; expected entries from ${spec.values.join(", ")}`);
		return _ok(value.filter((v, i) => value.indexOf(v) === i));
	}
	}
	return _fail("unsupported type " + spec.type);
}

function validateOne(key, value) {
	return SCHEMA[key] ? validateValue(SCHEMA[key], value) : _fail("unknown setting");
}

// Every schema key is present in `values`; invalid or missing ones take their
// default. Unknown keys are reported and ignored (Settings keeps them in the file).
function validate(obj) {
	const values = defaults();
	const warnings = [];
	if (obj === null || typeof obj !== "object" || Array.isArray(obj))
		return { values: values, warnings: ["settings file is not a JSON object; using defaults"] };
	Object.keys(obj).forEach(k => {
		if (!SCHEMA[k]) {
			warnings.push(k + ": unknown setting, ignored");
			return;
		}
		const r = validateOne(k, obj[k]);
		if (r.ok)
			values[k] = r.value;
		else
			warnings.push(`${k}: ${r.error}; using default ${JSON.stringify(SCHEMA[k].default)}`);
	});
	return { values: values, warnings: warnings };
}

// Empty or whitespace-only text is an empty settings object.
function parse(text) {
	if (!text || !text.trim())
		return _ok({});
	try {
		return _ok(JSON.parse(text));
	} catch (e) {
		return _fail(String(e.message || e));
	}
}

function serialize(obj) {
	return JSON.stringify(obj, null, "\t") + "\n";
}

function nonDefaults(values) {
	const out = {};
	keys().forEach(k => {
		if (JSON.stringify(values[k]) !== JSON.stringify(SCHEMA[k].default))
			out[k] = values[k];
	});
	return out;
}

function changedKeys(a, b) {
	return keys().filter(k => JSON.stringify(a[k]) !== JSON.stringify(b[k]));
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml`
Expected: `0 failed` across all test files.

- [ ] **Step 6: Create `tools/gen-settings-doc.mjs`**

```js
// Generates docs/SETTINGS.md from shell/services/settings.js.
// Usage: node tools/gen-settings-doc.mjs           (write)
//        node tools/gen-settings-doc.mjs --check   (exit 1 if out of date)
import { readFileSync, writeFileSync } from "node:fs";
import vm from "node:vm";

const root = new URL("../", import.meta.url);
const ctx = {};
vm.createContext(ctx);
vm.runInContext(readFileSync(new URL("shell/services/settings.js", root), "utf8"), ctx);

const allowed = s => {
	if (s.type === "enum" || s.type === "list") return s.values.map(v => `\`${v}\``).join(", ");
	if (s.type === "number") return `${s.min} to ${s.max}`;
	if (s.type === "color") return "`#rgb` or `#rrggbb`";
	if (s.type === "bool") return "`true`, `false`";
	return "";
};

const rows = ctx.keys().map(k => {
	const s = ctx.SCHEMA[k];
	return `| \`${k}\` | ${s.type} | \`${JSON.stringify(s.default)}\` | ${allowed(s)} | ${s.doc} |`;
});

const doc = `# Bloom settings

Generated from \`shell/services/settings.js\` by \`node tools/gen-settings-doc.mjs\`; do not edit by hand.

Settings live in \`~/.config/bloom/settings.json\` (\`$XDG_CONFIG_HOME/bloom/settings.json\`) as one flat JSON object. Edits apply live. An invalid or missing value uses its default and logs a warning; a file with a syntax error is ignored (the last good settings stay) until it is fixed. Values in Bloom for Windows' string form (\`"true"\`, \`"0.8"\`) are accepted.

| Key | Type | Default | Allowed | Description |
|---|---|---|---|---|
${rows.join("\n")}
`;

const target = new URL("docs/SETTINGS.md", root);
if (process.argv.includes("--check")) {
	let current = "";
	try { current = readFileSync(target, "utf8"); } catch {}
	if (current !== doc) {
		console.error("docs/SETTINGS.md is out of date; run: node tools/gen-settings-doc.mjs");
		process.exit(1);
	}
	console.log("ok");
} else {
	writeFileSync(target, doc);
	console.log("wrote docs/SETTINGS.md");
}
```

- [ ] **Step 7: Generate the doc and check it**

Run: `node tools/gen-settings-doc.mjs && node tools/gen-settings-doc.mjs --check`
Expected: `wrote docs/SETTINGS.md`, then `ok`. The file has a table with 6 rows.

- [ ] **Step 8: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add shell/common/paths.js shell/services/settings.js tests/qml/tst_paths.qml tests/qml/tst_settings.qml tools/gen-settings-doc.mjs docs/SETTINGS.md
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add settings schema and generated reference

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Theme maths

**Files:**
- Create: `shell/services/theme.js`, `tests/qml/tst_theme.qml`

**Interfaces:**
- Produces (`theme.js`):
  - `compute(mode: string, customColor: string, opacity: number, saturation: number, brightness: number, adaptiveAccent: string|null) → {mode, isLight, bg, bgExpanded, text, textMuted, border, groupBg, accent, scrollbarThumb}`.
  - Each colour is `{r, g, b, a}` with channels 0–255 and alpha 0–1.
  - `mode` in the result is the *effective* mode: `"adaptive"` with no accent yields `"dark"`.
  - Helpers: `hexToHsl(hex) → {h, s, l}`, `hslToHex(h, s, l) → "#rrggbb"` (Bloom's exact rounding).

- [ ] **Step 1: Write the failing test `tests/qml/tst_theme.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/services/theme.js" as Theme

TestCase {
	name: "ThemeMaths"

	function rgb(c) { return [c.r, c.g, c.b]; }

	function test_darkDefault() {
		const t = Theme.compute("dark", "#007aff", 0.8, 0.5, 0.15, null);
		compare(t.mode, "dark");
		verify(!t.isLight);
		compare(rgb(t.bg), [0, 0, 0]);
		fuzzyCompare(t.bg.a, 0.8, 1e-9);
		fuzzyCompare(t.bgExpanded.a, 0.92, 1e-9);
		compare(t.text, { r: 255, g: 255, b: 255, a: 1 });
		compare(t.textMuted, { r: 255, g: 255, b: 255, a: 0.6 });
		compare(t.border, { r: 255, g: 255, b: 255, a: 0.1 });
		compare(t.accent, { r: 0, g: 122, b: 255, a: 1 });
	}

	function test_expandedOpacityCapsAtOne() {
		fuzzyCompare(Theme.compute("dark", "#007aff", 0.95, 0.5, 0.15, null).bgExpanded.a, 1, 1e-9);
	}

	function test_light() {
		const t = Theme.compute("light", "#007aff", 0.8, 0.5, 0.15, null);
		verify(t.isLight);
		compare(rgb(t.bg), [255, 255, 255]);
		compare(rgb(t.bgExpanded), [245, 245, 247]);
		compare(t.text, { r: 28, g: 28, b: 30, a: 1 });
		compare(t.textMuted, { r: 28, g: 28, b: 30, a: 0.65 });
	}

	// Reference values computed with Bloom's own theme.ts functions.
	function test_customDark() {
		const t = Theme.compute("custom", "#007aff", 0.8, 0.5, 0.15, null);
		compare(t.mode, "custom");
		verify(!t.isLight);
		compare(rgb(t.bg), [0x13, 0x26, 0x39]);
		compare(t.textMuted, { r: 255, g: 255, b: 255, a: 0.65 });
		compare(t.accent, { r: 0, g: 122, b: 255, a: 1 });
	}

	function test_customLight() {
		const t = Theme.compute("custom", "#ff9500", 0.8, 0.3, 0.7, null);
		verify(t.isLight);
		compare(rgb(t.bg), [0xc9, 0xb6, 0x9c]);
		compare(t.text, { r: 28, g: 28, b: 30, a: 1 });
	}

	function test_adaptiveWithoutAccentFallsBackToDark() {
		compare(Theme.compute("adaptive", "#007aff", 0.8, 0.5, 0.15, null).mode, "dark");
	}

	function test_adaptiveWithAccent() {
		const t = Theme.compute("adaptive", "#007aff", 0.8, 0.5, 0.15, "#ff9500");
		compare(t.mode, "adaptive");
		compare(t.accent, { r: 255, g: 149, b: 0, a: 1 });
	}

	function test_hslHelpers() {
		compare(Theme.hexToHsl("#007aff"), { h: 211, s: 100, l: 50 });
		compare(Theme.hexToHsl("#fff"), { h: 0, s: 0, l: 100 });
		compare(Theme.hslToHex(211, 50, 15), "#132639");
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_theme.qml`
Expected: FAIL, because `theme.js` doesn't exist.

- [ ] **Step 3: Create `shell/services/theme.js`** (`hexToHsl`/`hslToHex` are Bloom's `theme.ts` verbatim, minus TypeScript)

```js
// Bloom theme maths, ported from Bloom src/theme.ts (b5fb962) so colours
// match exactly. Colours are {r, g, b, a}: channels 0-255, alpha 0-1.

function _rgba(r, g, b, a) {
	return { r: r, g: g, b: b, a: a };
}

function _expand(hex) {
	hex = hex.replace("#", "");
	if (hex.length === 3)
		hex = hex.split("").map(c => c + c).join("");
	return hex;
}

function _hexToRgb(hex, a) {
	hex = _expand(hex);
	return _rgba(parseInt(hex.substring(0, 2), 16) || 0, parseInt(hex.substring(2, 4), 16) || 0, parseInt(hex.substring(4, 6), 16) || 0, a);
}

function hexToHsl(hex) {
	hex = _expand(hex);
	const r = (parseInt(hex.substring(0, 2), 16) || 0) / 255;
	const g = (parseInt(hex.substring(2, 4), 16) || 0) / 255;
	const b = (parseInt(hex.substring(4, 6), 16) || 0) / 255;
	const max = Math.max(r, g, b);
	const min = Math.min(r, g, b);
	let h = 0;
	let s = 0;
	const l = (max + min) / 2;
	if (max !== min) {
		const d = max - min;
		s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
		switch (max) {
		case r:
			h = (g - b) / d + (g < b ? 6 : 0);
			break;
		case g:
			h = (b - r) / d + 2;
			break;
		case b:
			h = (r - g) / d + 4;
			break;
		}
		h /= 6;
	}
	return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
}

function hslToHex(h, s, l) {
	s /= 100;
	l /= 100;
	const c = (1 - Math.abs(2 * l - 1)) * s;
	const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
	const m = l - c / 2;
	let r = 0, g = 0, b = 0;
	if (0 <= h && h < 60) { r = c; g = x; b = 0; }
	else if (60 <= h && h < 120) { r = x; g = c; b = 0; }
	else if (120 <= h && h < 180) { r = 0; g = c; b = x; }
	else if (180 <= h && h < 240) { r = 0; g = x; b = c; }
	else if (240 <= h && h < 300) { r = x; g = 0; b = c; }
	else if (300 <= h && h < 360) { r = c; g = 0; b = x; }
	const toHex = val => {
		const hexVal = Math.round((val + m) * 255).toString(16);
		return hexVal.length === 1 ? "0" + hexVal : hexVal;
	};
	return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

// Mirrors Bloom's applyTheme(). For adaptive, `adaptiveAccent` is the
// wallpaper accent; while it is null (no wallpaper theming yet) the theme
// falls back to dark, as Bloom does when the system accent is unavailable.
function compute(mode, customColor, opacity, saturation, brightness, adaptiveAccent) {
	const op = opacity;
	const opExpanded = Math.min(1, opacity + 0.12);

	if (mode === "light") {
		return {
			mode: "light",
			isLight: true,
			bg: _rgba(255, 255, 255, op),
			bgExpanded: _rgba(245, 245, 247, opExpanded),
			text: _rgba(28, 28, 30, 1),
			textMuted: _rgba(28, 28, 30, 0.65),
			border: _rgba(0, 0, 0, 0.12),
			groupBg: _rgba(0, 0, 0, 0.04),
			accent: _rgba(0, 122, 255, 1),
			scrollbarThumb: _rgba(0, 0, 0, 0.15)
		};
	}

	if (mode === "custom" || (mode === "adaptive" && adaptiveAccent)) {
		const accent = mode === "custom" ? customColor : adaptiveAccent;
		const hsl = hexToHsl(accent);
		const bg = _hexToRgb(hslToHex(hsl.h, saturation * 100, brightness * 100), op);
		const light = brightness > 0.55;
		const ink = light ? 0 : 255;
		return {
			mode: mode,
			isLight: light,
			bg: bg,
			bgExpanded: _rgba(bg.r, bg.g, bg.b, opExpanded),
			text: light ? _rgba(28, 28, 30, 1) : _rgba(255, 255, 255, 1),
			textMuted: light ? _rgba(28, 28, 30, 0.65) : _rgba(255, 255, 255, 0.65),
			border: _rgba(ink, ink, ink, 0.12),
			groupBg: _rgba(ink, ink, ink, 0.04),
			accent: _hexToRgb(accent, 1),
			scrollbarThumb: _rgba(ink, ink, ink, 0.15)
		};
	}

	return {
		mode: "dark",
		isLight: false,
		bg: _rgba(0, 0, 0, op),
		bgExpanded: _rgba(0, 0, 0, opExpanded),
		text: _rgba(255, 255, 255, 1),
		textMuted: _rgba(255, 255, 255, 0.6),
		border: _rgba(255, 255, 255, 0.1),
		groupBg: _rgba(255, 255, 255, 0.04),
		accent: _rgba(0, 122, 255, 1),
		scrollbarThumb: _rgba(255, 255, 255, 0.1)
	};
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_theme.qml`
Expected: `0 failed`.

- [ ] **Step 5: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add shell/services/theme.js tests/qml/tst_theme.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: port Bloom theme maths

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Services, shell root and IPC (integration-tested)

**Files:**
- Create:
  - services: `shell/services/Settings.qml`, `shell/services/Theme.qml`, `shell/services/state.js`, `shell/services/StateFile.qml`;
  - shell root: `shell/shell.qml`;
  - CLI stub: `bin/bloom` (only the `ipc` command; Task 8 completes the CLI);
  - unit test: `tests/qml/tst_state.qml`;
  - integration: `tests/integration/lib.sh`, `tests/integration/test_shell.sh`, `tests/integration/test_state.sh`, `tests/integration/state-harness.qml`.

**Interfaces:**
- Consumes:
  - `settings.js`: `defaults`, `validate`, `validateOne`, `parse`, `serialize`, `nonDefaults`, `changedKeys`;
  - `theme.js`: `compute`;
  - `paths.js`: `settingsFile`, `stateFile`.
- Produces:
  - Singleton `Settings` (`import qs.services`):
    - properties: `values: var` (every schema key), `warnings: var` (string[]), `path: string`;
    - signal: `settingChanged(key: string)`;
    - methods: `get(key) → any`, `set(key, value) → string` (`""` on success, otherwise the error message), `nonDefaults() → object`.
  - Singleton `Theme`: `mode: string` (effective), `requestedMode: string`, `isLight: bool`, and `color` properties `bg`, `bgExpanded`, `text`, `textMuted`, `border`, `groupBg`, `accent`, `scrollbarThumb`.
  - Type `StateFile`: `name: string` (required), `defaultValue: var`, `value: var`, `loaded: bool`, `path: string`, `save(v)`.
  - IPC targets:
    - `shell.ping() → "pong"`;
    - `settings.get(key) → JSON`, `settings.set(key, jsonOrWord) → "ok" | error`, `settings.nonDefaults() → JSON`, `settings.warnings() → JSON`;
    - `theme.mode() → string`.
  - `state.js`: `parse(text)` (empty text = corrupt), `serialize(value)`.
  - `bin/bloom ipc <target> <function> [args…]`: execs `qs -c bloom ipc call …` and keeps its exit code.

- [ ] **Step 1: Write the failing unit test `tests/qml/tst_state.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/services/state.js" as State

TestCase {
	name: "StateParse"

	function test_parse() {
		compare(State.parse('{"items": [1]}'), { ok: true, value: { items: [1] } });
		compare(State.parse("[]"), { ok: true, value: [] });
	}

	// State files are only ever written whole (atomic); empty means damaged.
	function test_emptyOrBrokenIsCorrupt() {
		verify(!State.parse("").ok);
		verify(!State.parse("{\"items\": [").ok);
	}

	function test_serialize() {
		compare(JSON.parse(State.serialize({ a: 1 })), { a: 1 });
		verify(State.serialize({}).endsWith("\n"));
	}
}
```

- [ ] **Step 2: Write the failing integration tests**

`tests/integration/lib.sh`:

```bash
# Helpers for integration tests: run the real shell offscreen against
# throwaway XDG directories. Source this file, then call bloom_env.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHELL_PID=""

bloom_env() {
	TEST_TMP="$(mktemp -d)"
	export XDG_CONFIG_HOME="$TEST_TMP/config"
	export XDG_STATE_HOME="$TEST_TMP/state"
	export XDG_RUNTIME_DIR="$TEST_TMP/run"
	export QT_QPA_PLATFORM=offscreen NO_COLOR=1
	unset WAYLAND_DISPLAY
	mkdir -p "$XDG_CONFIG_HOME/quickshell" "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
	trap bloom_cleanup EXIT
}

bloom_cleanup() {
	if [[ -n "$SHELL_PID" ]]; then
		kill "$SHELL_PID" 2>/dev/null || true
		wait "$SHELL_PID" 2>/dev/null || true
	fi
	rm -rf "$TEST_TMP"
}

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	if [[ -f "$TEST_TMP/shell.log" ]]; then
		sed 's/^/  log: /' "$TEST_TMP/shell.log" >&2
	fi
	exit 1
}

pass() { printf 'ok - %s\n' "$*"; }

assert_eq() {
	[[ "$1" == "$2" ]] || fail "$3: expected [$2], got [$1]"
}

log_has() { grep -qF -- "$1" "$TEST_TMP/shell.log"; }

# wait_for <description> <command...>: retries the command for up to 6 s.
wait_for() {
	local what="$1"
	shift
	local i
	for i in $(seq 1 60); do
		if "$@" >/dev/null 2>&1; then return 0; fi
		sleep 0.1
	done
	fail "timed out waiting for: $what"
}

ipc() { "$ROOT/bin/bloom" ipc "$@"; }

ipc_equals() {
	local expected="$1"
	shift
	[[ "$(ipc "$@" 2>/dev/null)" == "$expected" ]]
}

# Links the checkout as the `bloom` config (like `bloom dev install`) and
# starts it.
start_shell() {
	ln -s "$ROOT/shell" "$XDG_CONFIG_HOME/quickshell/bloom"
	qs --no-color -c bloom >"$TEST_TMP/shell.log" 2>&1 &
	SHELL_PID=$!
	wait_for "the shell to answer ping" ipc_equals pong shell ping
}
```

`tests/integration/test_shell.sh`:

```bash
#!/usr/bin/env bash
# Starts the real shell offscreen and checks IPC and live settings.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# Review focus 5: ipc must fail fast while the shell is down so `|| fallback` binds work.
if ipc shell ping >/dev/null 2>&1; then fail "ipc succeeded with no shell running"; fi
pass "ipc fails while the shell is not running"

start_shell
pass "shell starts and answers ping"

SETTINGS="$XDG_CONFIG_HOME/bloom/settings.json"

# Review focus 3: first run uses defaults and does not create settings.json.
assert_eq "$(ipc settings get bloom-theme-opacity)" "0.8" "default opacity"
[[ ! -e "$SETTINGS" ]] || fail "starting the shell created $SETTINGS"
pass "first run uses defaults without creating settings.json"

mkdir -p "$(dirname "$SETTINGS")"
printf '{ "bloom-theme-opacity": 0.5, "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "a settings.json created after startup to apply" ipc_equals 0.5 settings get bloom-theme-opacity
pass "a settings.json created after startup is picked up"

printf '{ "bloom-theme-opacity": 0.4, "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "a hand edit to apply" ipc_equals 0.4 settings get bloom-theme-opacity
pass "hand edits apply live"

# Review focus 1: a syntax error keeps the last good values and the file is never overwritten.
printf '{ "bloom-theme-opacity": 0.3, \n' >"$SETTINGS"
wait_for "the parse warning" log_has "is not valid JSON"
assert_eq "$(ipc settings get bloom-theme-opacity)" "0.4" "opacity after a bad edit"
assert_eq "$(ipc settings set bloom-theme-opacity 0.6)" "settings.json has a syntax error; fix it before changing settings" "set while the file is broken"
grep -qF '"bloom-theme-opacity": 0.3, ' "$SETTINGS" || fail "the broken settings.json was overwritten"
pass "a broken file keeps the last good settings and is never overwritten"

printf '{ "bloom-theme-opacity": 1.5, "bloom-theme-mode": "neon", "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "invalid values to fall back" ipc_equals 0.8 settings get bloom-theme-opacity
assert_eq "$(ipc settings get bloom-theme-mode)" '"dark"' "invalid mode falls back"
assert_eq "$(ipc settings warnings | jq length)" "3" "warning count"
pass "invalid values fall back to defaults with warnings"

assert_eq "$(ipc settings set bloom-theme-mode light)" "ok" "set mode"
assert_eq "$(jq -r '."bloom-theme-mode"' "$SETTINGS")" "light" "mode written to the file"
assert_eq "$(jq -r '."x-future-key"' "$SETTINGS")" "1" "unknown key kept"
assert_eq "$(ipc theme mode)" "light" "theme follows settings"
assert_eq "$(ipc settings set bloom-theme-opacity 2)" "bloom-theme-opacity: expected a number from 0 to 1" "invalid set rejected"
pass "set validates, writes the file, keeps unknown keys, and the theme follows"

assert_eq "$(ipc settings set bloom-theme-mode adaptive)" "ok" "set adaptive"
assert_eq "$(ipc theme mode)" "dark" "adaptive falls back to dark until wallpaper theming"
pass "adaptive falls back to dark"

if grep -E '^ *(ERROR|FATAL)' "$TEST_TMP/shell.log"; then fail "shell logged errors"; fi
pass "no errors in the shell log"
```

`tests/integration/state-harness.qml` (copied into a temp config as `shell.qml` by the test):

```qml
import QtQuick
import Quickshell
import qs.services

// Test harness for StateFile, run by tests/integration/test_state.sh.
// Prints RESULT lines and exits 0 on success. Qt.exit only works once the
// config has loaded, hence the timers.
ShellRoot {
	id: root

	StateFile {
		id: corrupt
		name: "corrupt"
		defaultValue: ({ items: [] })
	}

	StateFile {
		id: fresh
		name: "fresh"
		defaultValue: []
	}

	Timer {
		interval: 300
		running: true
		onTriggered: {
			const okCorrupt = corrupt.loaded && JSON.stringify(corrupt.value) === JSON.stringify({ items: [] });
			const okFresh = fresh.loaded && JSON.stringify(fresh.value) === "[]";
			console.log(`RESULT corrupt-uses-default=${okCorrupt} missing-uses-default=${okFresh}`);
			fresh.save(["a", "b"]);
			finish.restart();
			if (!okCorrupt || !okFresh)
				Qt.exit(1);
		}
	}

	Timer {
		id: finish
		interval: 300
		onTriggered: Qt.exit(0)
	}
}
```

`tests/integration/test_state.sh`:

```bash
#!/usr/bin/env bash
# Runs StateFile in a harness: corrupt files move to .bak, missing files use
# the default, save() writes the file.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# A config can only import QML from inside its own folder, so build one.
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$HARNESS/"
cp "$ROOT/tests/integration/state-harness.qml" "$HARNESS/shell.qml"

mkdir -p "$XDG_STATE_HOME/bloom"
printf '{ "items": [ \n' >"$XDG_STATE_HOME/bloom/corrupt.json"

if ! timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1; then
	fail "harness exited with an error"
fi
log_has "RESULT corrupt-uses-default=true missing-uses-default=true" || fail "unexpected harness result"
[[ -f "$XDG_STATE_HOME/bloom/corrupt.json.bak" ]] || fail "corrupt file was not moved to .bak"
[[ ! -e "$XDG_STATE_HOME/bloom/corrupt.json" ]] || fail "corrupt file still in place"
log_has "is corrupt" || fail "no warning for the corrupt file"
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/fresh.json")" '["a","b"]' "saved state"
pass "corrupt state moves to .bak, missing state uses the default, save writes"
```

- [ ] **Step 3: Run them to verify they fail**

Run: `chmod +x tests/integration/*.sh && QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_state.qml; bash tests/integration/test_shell.sh`
Expected:
- `tst_state` FAILS because `state.js` is missing.
- `test_shell.sh` FAILS because `bin/bloom` doesn't exist ("No such file or directory" on the first `ipc` call is enough).

- [ ] **Step 4: Create `shell/services/state.js`**

```js
// UI state file parsing. Plain JS (shared with tests). State files are only
// written whole and atomically, so an empty file means damage.

function parse(text) {
	if (!text || !text.trim())
		return { ok: false, error: "file is empty" };
	try {
		return { ok: true, value: JSON.parse(text) };
	} catch (e) {
		return { ok: false, error: String(e.message || e) };
	}
}

function serialize(value) {
	return JSON.stringify(value, null, "\t") + "\n";
}
```

- [ ] **Step 5: Create `shell/services/StateFile.qml`**

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "state.js" as Logic

// One JSON document of UI state in $XDG_STATE_HOME/bloom/<name>.json (todos,
// dock order, notification history...), kept apart from settings so a
// settings reset never touches it. A corrupt file is moved to
// <name>.json.bak and the default is used, so one bad file can't break a panel.
Scope {
	id: root

	required property string name
	property var defaultValue: ({})
	property var value: root.defaultValue
	property bool loaded: false
	readonly property string path: Paths.stateFile(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), root.name)

	function save(v) {
		root.value = v;
		file.setText(Logic.serialize(v));
	}

	FileView {
		id: file
		path: root.path
		atomicWrites: true
		printErrors: false

		onLoaded: {
			const r = Logic.parse(text());
			if (r.ok) {
				root.value = r.value;
			} else {
				console.warn(`bloom state: ${root.path} is corrupt (${r.error}); moved to ${root.path}.bak`);
				backup.running = true;
				root.value = root.defaultValue;
			}
			root.loaded = true;
		}

		onLoadFailed: error => {
			if (error !== FileViewError.FileNotFound)
				console.warn(`bloom state: cannot read ${root.path} (error ${error}); using the default`);
			root.value = root.defaultValue;
			root.loaded = true;
		}
	}

	Process {
		id: backup
		command: ["mv", "-f", root.path, root.path + ".bak"]
	}
}
```

- [ ] **Step 6: Create `shell/services/Settings.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../common/paths.js" as Paths
import "settings.js" as Logic

// Live settings from $XDG_CONFIG_HOME/bloom/settings.json. `values` always
// holds every schema key (invalid or missing ones take defaults), and hand
// edits apply immediately. A file with a syntax error is ignored, keeping the
// last good settings, and is never overwritten.
Singleton {
	id: root

	readonly property string path: Paths.settingsFile(Quickshell.env("XDG_CONFIG_HOME"), Quickshell.env("HOME"))
	property var values: Logic.defaults()
	property var warnings: []

	// Last parsed file contents, unknown keys included, so a write never drops
	// keys this version doesn't know.
	property var _raw: ({})
	property bool _fileValid: true
	// FileView only watches a file that existed when it was first read.
	property bool _seenFile: false

	signal settingChanged(string key)

	function get(key) {
		return root.values[key];
	}

	// Validates and saves one setting. Returns "" on success, else the error.
	function set(key, value) {
		if (!root._fileValid)
			return "settings.json has a syntax error; fix it before changing settings";
		const r = Logic.validateOne(key, value);
		if (!r.ok)
			return `${key}: ${r.error}`;
		const next = Object.assign({}, root._raw);
		next[key] = r.value;
		file.setText(Logic.serialize(next));
		root._apply(next);
		return "";
	}

	function nonDefaults() {
		return Logic.nonDefaults(root.values);
	}

	function _apply(obj) {
		const res = Logic.validate(obj);
		const old = root.values;
		root._raw = obj;
		root.values = res.values;
		root.warnings = res.warnings;
		res.warnings.forEach(w => console.warn("bloom settings:", w));
		Logic.changedKeys(old, res.values).forEach(k => root.settingChanged(k));
	}

	FileView {
		id: file
		path: root.path
		watchChanges: true
		atomicWrites: true
		printErrors: false

		onFileChanged: reload()

		onLoaded: {
			root._seenFile = true;
			const r = Logic.parse(text());
			root._fileValid = r.ok;
			if (r.ok)
				root._apply(r.value);
			else
				console.warn(`bloom settings: ${root.path} is not valid JSON (${r.error}); keeping the last good settings`);
		}

		onLoadFailed: error => {
			if (error !== FileViewError.FileNotFound) {
				console.warn(`bloom settings: cannot read ${root.path} (error ${error}); keeping the last good settings`);
				return;
			}
			root._fileValid = true;
			// Deleting the file resets to defaults; a file that never existed
			// already has them.
			if (root._seenFile)
				root._apply({});
		}
	}

	// First run: poll until settings.json appears, then the watch takes over.
	Timer {
		interval: 2000
		repeat: true
		running: !root._seenFile
		onTriggered: file.reload()
	}
}
```

- [ ] **Step 7: Create `shell/services/Theme.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import "theme.js" as Logic

// Theme colours derived from settings with Bloom's theme maths. Surfaces bind
// to these instead of hard-coding colours.
Singleton {
	id: root

	readonly property string requestedMode: Settings.values["bloom-theme-mode"]
	// Wallpaper accent for the adaptive theme; set by wallpaper theming (phase 7).
	property string adaptiveAccent: ""

	readonly property var _t: Logic.compute(
		root.requestedMode,
		Settings.values["bloom-theme-color"],
		Settings.values["bloom-theme-opacity"],
		Settings.values["bloom-theme-saturation"],
		Settings.values["bloom-theme-brightness"],
		root.adaptiveAccent || null)

	readonly property string mode: _t.mode
	readonly property bool isLight: _t.isLight
	readonly property color bg: _color(_t.bg)
	readonly property color bgExpanded: _color(_t.bgExpanded)
	readonly property color text: _color(_t.text)
	readonly property color textMuted: _color(_t.textMuted)
	readonly property color border: _color(_t.border)
	readonly property color groupBg: _color(_t.groupBg)
	readonly property color accent: _color(_t.accent)
	readonly property color scrollbarThumb: _color(_t.scrollbarThumb)

	function _color(c) {
		return Qt.rgba(c.r / 255, c.g / 255, c.b / 255, c.a);
	}

	onModeChanged: {
		if (root.requestedMode === "adaptive" && root.mode !== "adaptive")
			console.info("bloom theme: adaptive needs wallpaper theming; using dark for now");
	}
}
```

- [ ] **Step 8: Create `shell/shell.qml`**

```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Bloom shell root. Phase 1 has no surfaces yet: it loads the core services
// and exposes the IPC interface used by `bloom ipc` and keybinds.
ShellRoot {
	Component.onCompleted: console.log(`bloom: shell started (theme ${Theme.mode}, settings ${Settings.path})`)

	IpcHandler {
		target: "shell"

		function ping(): string {
			return "pong";
		}
	}

	IpcHandler {
		target: "settings"

		// The value as JSON (null for an unknown key).
		function get(key: string): string {
			return JSON.stringify(Settings.get(key) ?? null);
		}

		// `value` is JSON (0.6, true, "\"light\""); a bare word is taken as a string.
		function set(key: string, value: string): string {
			let parsed;
			try {
				parsed = JSON.parse(value);
			} catch (e) {
				parsed = value;
			}
			return Settings.set(key, parsed) || "ok";
		}

		function nonDefaults(): string {
			return JSON.stringify(Settings.nonDefaults());
		}

		function warnings(): string {
			return JSON.stringify(Settings.warnings);
		}
	}

	IpcHandler {
		target: "theme"

		function mode(): string {
			return Theme.mode;
		}
	}
}
```

- [ ] **Step 9: Create `bin/bloom` with the `ipc` command** (Task 8 adds the rest)

```bash
#!/usr/bin/env bash
# bloom: command-line entry point for the Bloom shell.
set -euo pipefail

die() {
	printf 'bloom: %s\n' "$*" >&2
	exit 1
}

cmd_ipc() {
	[[ $# -ge 2 ]] || die "usage: bloom ipc <target> <function> [args...]"
	exec qs -c bloom ipc call "$@"
}

main() {
	local cmd="${1:-}"
	shift || true
	case "$cmd" in
	ipc) cmd_ipc "$@" ;;
	*) die "unknown command: ${cmd:-<none>}" ;;
	esac
}

main "$@"
```

Run: `chmod +x bin/bloom`

- [ ] **Step 10: Run the tests to verify they pass**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml && bash tests/integration/test_shell.sh && bash tests/integration/test_state.sh`
Expected:
- every QML test passes;
- `test_shell.sh` prints 10 `ok - …` lines;
- `test_state.sh` prints 1 `ok - …` line.

Warning lines in the shell log from the deliberately invalid settings are expected.

- [ ] **Step 11: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add shell/services/state.js shell/services/StateFile.qml shell/services/Settings.qml shell/services/Theme.qml shell/shell.qml bin/bloom tests/qml/tst_state.qml tests/integration
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add settings, theme and state services with shell IPC

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: systemd units and the rest of the CLI

**Files:**
- Create: `systemd/bloom-shell.service`, `systemd/bloom-shell-failed.service`, `tests/units/test_units.sh`, `tests/cli/test_bloom.sh`
- Modify: `bin/bloom` (replace the whole file)

**Interfaces:**
- Consumes: `VERSION`; IPC targets `settings.nonDefaults`, `settings.warnings`.
- Produces:
  - `bloom version`;
  - `bloom ipc <target> <function> [args…]`;
  - `bloom doctor`;
  - `bloom dev install|uninstall|status`.
  - Links made by `dev install`: `$XDG_CONFIG_HOME/quickshell/bloom → <repo>/shell`, and `$XDG_CONFIG_HOME/systemd/user/{bloom-shell,bloom-shell-failed}.service → <repo>/systemd/…`. It never enables the unit.

- [ ] **Step 1: Write the failing tests**

`tests/units/test_units.sh`:

```bash
#!/usr/bin/env bash
# The supervision units must load cleanly.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
systemd-analyze verify "$ROOT/systemd/bloom-shell.service" "$ROOT/systemd/bloom-shell-failed.service"
grep -qx 'Restart=on-failure' "$ROOT/systemd/bloom-shell.service"
grep -qx 'StartLimitBurst=5' "$ROOT/systemd/bloom-shell.service"
grep -qx 'OnFailure=bloom-shell-failed.service' "$ROOT/systemd/bloom-shell.service"
echo "ok - systemd units verify"
```

`tests/cli/test_bloom.sh`:

```bash
#!/usr/bin/env bash
# CLI tests with stubbed qs/systemctl/journalctl/hyprctl and a throwaway HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" STUB_LOG="$TMP/stub.log"
mkdir -p "$HOME" "$TMP/stub"
export PATH="$TMP/stub:$PATH"

stub() {
	printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "%s" "$*" >>"$STUB_LOG"\n%s\n' "$1" "$2" >"$TMP/stub/$1"
	chmod +x "$TMP/stub/$1"
}
stub qs 'if [[ "$1" == --version ]]; then echo "Quickshell 0.3.2 (stub)"; exit 0; fi; if [[ "$*" == *"ipc call settings"* ]]; then echo "{}"; fi; exit "${STUB_QS_EXIT:-0}"'
stub systemctl 'echo "bloom-shell.service (stub)"'
stub journalctl 'echo "journal line (stub)"'
stub hyprctl 'case "$1" in version) echo "{\"tag\":\"v0.56.2\"}";; getoption) echo "bool: true";; esac'

BLOOM="$ROOT/bin/bloom"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$*"; }

# version
[[ "$("$BLOOM" version)" == "$(cat "$ROOT/VERSION")"* ]] || fail "version"
pass "version prints VERSION"

# usage errors
if "$BLOOM" >/dev/null 2>&1; then fail "no command should fail"; fi
if "$BLOOM" nope >/dev/null 2>&1; then fail "unknown command should fail"; fi
if "$BLOOM" ipc shell >/dev/null 2>&1; then fail "ipc without a function should fail"; fi
"$BLOOM" help | grep -q "dev install" || fail "help lists commands"
pass "usage errors exit non-zero; help lists commands"

# ipc forwards and keeps qs's exit code (review focus 5)
"$BLOOM" ipc shell ping
grep -qx 'qs -c bloom ipc call shell ping' "$STUB_LOG" || fail "ipc forwarding"
set +e
STUB_QS_EXIT=255 "$BLOOM" ipc shell ping
code=$?
set -e
[[ $code -eq 255 ]] || fail "ipc exit code: $code"
pass "ipc forwards to qs and keeps its exit code"

# dev install / status / uninstall
"$BLOOM" dev install >/dev/null
[[ "$(readlink "$XDG_CONFIG_HOME/quickshell/bloom")" == "$ROOT/shell" ]] || fail "shell link"
for u in bloom-shell.service bloom-shell-failed.service; do
	[[ "$(readlink "$XDG_CONFIG_HOME/systemd/user/$u")" == "$ROOT/systemd/$u" ]] || fail "unit link $u"
done
grep -qx 'systemctl --user daemon-reload' "$STUB_LOG" || fail "daemon-reload"
if grep -q 'systemctl --user enable' "$STUB_LOG"; then fail "dev install must not enable the unit"; fi
"$BLOOM" dev install >/dev/null || fail "dev install should be idempotent"
"$BLOOM" dev status | grep -q "linked" || fail "status"
"$BLOOM" dev uninstall >/dev/null
[[ ! -e "$XDG_CONFIG_HOME/quickshell/bloom" && ! -L "$XDG_CONFIG_HOME/quickshell/bloom" ]] || fail "uninstall left the shell link"
[[ ! -L "$XDG_CONFIG_HOME/systemd/user/bloom-shell.service" ]] || fail "uninstall left a unit link"
pass "dev install links, is idempotent, never enables; uninstall removes"

# Review focus 4: refuse when the config path is taken, and create nothing.
mkdir -p "$XDG_CONFIG_HOME/quickshell/bloom"
touch "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml"
if "$BLOOM" dev install >/dev/null 2>&1; then fail "dev install should refuse"; fi
[[ ! -e "$XDG_CONFIG_HOME/systemd/user/bloom-shell.service" ]] || fail "refused install still linked a unit"
[[ -f "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml" ]] || fail "existing config touched"
"$BLOOM" dev uninstall >/dev/null
[[ -f "$XDG_CONFIG_HOME/quickshell/bloom/shell.qml" ]] || fail "uninstall removed a foreign config"
pass "dev install refuses an existing config and changes nothing; uninstall leaves it"

# doctor
out="$("$BLOOM" doctor)"
for want in "## Versions" "Quickshell 0.3.2 (stub)" "v0.56.2" "## Lock screen" "allow_session_lock_restore" "## Recent log"; do
	grep -qF "$want" <<<"$out" || fail "doctor output missing: $want"
done
pass "doctor reports versions, lock safety and logs"
```

- [ ] **Step 2: Run them to verify they fail**

Run: `bash tests/units/test_units.sh; bash tests/cli/test_bloom.sh`
Expected:
- `test_units.sh` FAILS because the unit files are missing;
- `test_bloom.sh` FAILS at `version` with "unknown command: version".

- [ ] **Step 3: Create `systemd/bloom-shell.service`**

```ini
[Unit]
Description=Bloom shell (Quickshell)
Documentation=https://github.com/DhanushSantosh/bloom-dots
# Stops with the session where graphical-session.target is used (e.g. uwsm).
# On a plain Hyprland session the shell is started by Hyprland (phase 8).
PartOf=graphical-session.target
After=graphical-session.target
StartLimitIntervalSec=60
StartLimitBurst=5
OnFailure=bloom-shell-failed.service

[Service]
Type=simple
ExecStart=/usr/bin/qs --no-color -c bloom
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
```

- [ ] **Step 4: Create `systemd/bloom-shell-failed.service`**

```ini
[Unit]
Description=Report that the Bloom shell stopped after repeated crashes

[Service]
Type=oneshot
# Hyprland's own notification works while the shell (and its notification
# server) is down.
ExecStart=/bin/sh -c 'hyprctl notify 3 15000 0 "Bloom shell stopped after repeated crashes. Run: bloom doctor" || true'
```

- [ ] **Step 5: Replace `bin/bloom` with the full CLI**

```bash
#!/usr/bin/env bash
# bloom: command-line entry point for the Bloom shell.
set -euo pipefail

BLOOM_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_LINK="$CONFIG_HOME/quickshell/bloom"
UNIT_DIR="$CONFIG_HOME/systemd/user"
UNITS=(bloom-shell.service bloom-shell-failed.service)

die() {
	printf 'bloom: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage: bloom <command> [args]

  ipc <target> <function> [args...]  Call a shell IPC function; fails if the shell isn't running
  doctor                             Print a diagnostic report
  dev install                        Link this checkout into ~/.config (shell config + systemd units)
  dev uninstall                      Remove the links made by dev install
  dev status                         Show what dev install linked
  version                            Print the Bloom version
  help                               Show this help
EOF
}

cmd_version() {
	local v
	v="$(cat "$BLOOM_ROOT/VERSION")"
	if git -C "$BLOOM_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
		printf '%s (%s)\n' "$v" "$(git -C "$BLOOM_ROOT" rev-parse --short HEAD)"
	else
		printf '%s\n' "$v"
	fi
}

cmd_ipc() {
	[[ $# -ge 2 ]] || die "usage: bloom ipc <target> <function> [args...]"
	exec qs -c bloom ipc call "$@"
}

# Pairs of "target link" that dev install manages.
dev_links() {
	printf '%s %s\n' "$BLOOM_ROOT/shell" "$QS_LINK"
	local u
	for u in "${UNITS[@]}"; do
		printf '%s %s\n' "$BLOOM_ROOT/systemd/$u" "$UNIT_DIR/$u"
	done
}

dev_install() {
	local target link
	# Check every link first so a refusal leaves nothing half-installed.
	while read -r target link; do
		if [[ -L "$link" ]]; then
			[[ "$(readlink "$link")" == "$target" ]] || die "$link already links to $(readlink "$link"); remove it first"
		elif [[ -e "$link" ]]; then
			die "$link already exists; move it away first"
		fi
	done < <(dev_links)
	while read -r target link; do
		[[ -L "$link" ]] && continue
		mkdir -p "$(dirname "$link")"
		ln -s "$target" "$link"
		printf 'linked %s -> %s\n' "$link" "$target"
	done < <(dev_links)
	systemctl --user daemon-reload
	echo "Not enabled. Start with: systemctl --user start bloom-shell"
}

dev_uninstall() {
	systemctl --user stop bloom-shell.service >/dev/null 2>&1 || true
	local target link
	while read -r target link; do
		if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
			rm "$link"
			printf 'removed %s\n' "$link"
		elif [[ -e "$link" || -L "$link" ]]; then
			printf 'left %s (not a bloom link)\n' "$link"
		fi
	done < <(dev_links)
	systemctl --user daemon-reload
}

dev_status() {
	local target link
	while read -r target link; do
		if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
			printf 'linked     %s\n' "$link"
		elif [[ -e "$link" || -L "$link" ]]; then
			printf 'foreign    %s\n' "$link"
		else
			printf 'missing    %s\n' "$link"
		fi
	done < <(dev_links)
}

cmd_dev() {
	case "${1:-}" in
	install) dev_install ;;
	uninstall) dev_uninstall ;;
	status) dev_status ;;
	*) die "usage: bloom dev install|uninstall|status" ;;
	esac
}

cmd_doctor() {
	section() { printf '\n## %s\n' "$1"; }

	section "Versions"
	printf 'bloom: %s\n' "$(cmd_version)"
	printf 'quickshell: %s\n' "$(qs --version 2>/dev/null | head -n 1 || echo 'not found')"
	printf 'hyprland: %s\n' "$(hyprctl version -j 2>/dev/null | jq -r '.tag // "unknown"' 2>/dev/null || echo 'not running')"

	section "Install"
	dev_status

	section "Service"
	systemctl --user status bloom-shell.service --no-pager --lines 0 2>&1 | head -n 5 || true

	section "Settings"
	printf 'file: %s\n' "$CONFIG_HOME/bloom/settings.json"
	if qs -c bloom ipc call shell ping >/dev/null 2>&1; then
		printf 'changed from defaults: %s\n' "$(qs -c bloom ipc call settings nonDefaults)"
		printf 'warnings: %s\n' "$(qs -c bloom ipc call settings warnings)"
	else
		echo "shell not running; settings not checked"
	fi

	section "Lock screen"
	printf 'misc:allow_session_lock_restore = %s\n' "$(hyprctl getoption misc:allow_session_lock_restore 2>/dev/null | head -n 1 || echo 'unknown')"
	cat <<'EOF'
If the lock screen crashes the session stays locked. To recover:
  1. Press Ctrl+Alt+F3 and log in on the text console.
  2. Run: hyprctl --instance 0 keyword misc:allow_session_lock_restore 1
  3. Run: systemctl --user restart bloom-shell   (or: hyprctl --instance 0 dispatch exec hyprlock)
  4. Press Ctrl+Alt+F1 (or F2) to return and unlock.
EOF

	section "Recent log"
	journalctl --user -u bloom-shell.service -n 50 --no-pager 2>&1 || true
}

main() {
	local cmd="${1:-}"
	shift || true
	case "$cmd" in
	ipc) cmd_ipc "$@" ;;
	doctor) cmd_doctor ;;
	dev) cmd_dev "$@" ;;
	version) cmd_version ;;
	help | -h | --help) usage ;;
	"") usage >&2; exit 1 ;;
	*) die "unknown command: $cmd (see: bloom help)" ;;
	esac
}

main "$@"
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/units/test_units.sh && bash tests/cli/test_bloom.sh && bash tests/integration/test_shell.sh`
Expected:
- `ok - systemd units verify`;
- 6 `ok - …` lines from the CLI tests;
- the integration test still passes, since `ipc` behaviour is unchanged.

- [ ] **Step 7: Verify the doctor's lock-recovery command against Hyprland 0.56**

Run: `hyprctl keyword misc:allow_session_lock_restore 1 && hyprctl getoption misc:allow_session_lock_restore | head -n 1`
Expected: `ok`, then `bool: true`.
- This setting is already `true` on the owner's machine, so the command changes nothing.
- If `keyword` is rejected under the Lua config, stop and report it, so the doctor text and spec §6 can be corrected. Do not guess a replacement.

- [ ] **Step 8: Run the whole suite and commit**

Run: `tests/run-all.sh` (expected: `all checks passed`), then:

```bash
git add systemd bin/bloom tests/units tests/cli
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add systemd units and bloom CLI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Owner verification on the real session

This task changes `~/.config`: it adds two links under `quickshell/` and `systemd/user/`. **Ask the owner before running Step 1** and show them the exact command. ii keeps running; phase 1 draws nothing on screen.

**Files:** none changed.

- [ ] **Step 1: Owner approves, then link the checkout**

Run: `~/Projects/bloom-dots/bin/bloom dev install`
Expected: three `linked …` lines and `Not enabled. Start with: systemctl --user start bloom-shell`.

- [ ] **Step 2: Start the shell and check IPC**

Run: `systemctl --user start bloom-shell && ~/Projects/bloom-dots/bin/bloom ipc shell ping`
Expected: `pong`.

- [ ] **Step 3: Check live settings on the real session**

Run: `~/Projects/bloom-dots/bin/bloom ipc settings set bloom-theme-mode light && ~/Projects/bloom-dots/bin/bloom ipc theme mode`
Expected: `ok`, then `light`. `~/.config/bloom/settings.json` now contains `"bloom-theme-mode": "light"`.

Then: `~/Projects/bloom-dots/bin/bloom ipc settings set bloom-theme-mode dark`
Expected: `ok`.

- [ ] **Step 4: Check supervision**

Run: `systemctl --user kill --signal=SIGKILL bloom-shell` and wait about 2 s. Then run `systemctl --user show -p NRestarts --value bloom-shell` and `~/Projects/bloom-dots/bin/bloom ipc shell ping`.
Expected: `1`, then `pong`.

- [ ] **Step 5: Check the doctor report**

Run: `~/Projects/bloom-dots/bin/bloom doctor`
Expected:
- Versions shows `Quickshell 0.3.2` and `v0.56.2`;
- Install shows three `linked` lines;
- Settings shows `{}` changed from defaults (after Step 3 reset the mode) and `[]` warnings;
- Lock screen shows `bool: true`.

- [ ] **Step 6: Leave it running or stop it** (owner's choice)

To stop: `systemctl --user stop bloom-shell`. To remove the links: `~/Projects/bloom-dots/bin/bloom dev uninstall`.
Report the results of Steps 2–5 to the owner. This task has no commit.
