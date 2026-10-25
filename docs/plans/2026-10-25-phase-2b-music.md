# Phase 2B: Music in the Notch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Bloom's music mode to the notch:
- **Collapsed:** while media plays, the collapsed pill shows Bloom's 5-bar visualizer and album art. A paused session lingers for 5 s, then hands the pill back to the clock, but is still reachable on hover.
- **Open:** clicking the art opens Bloom's classic or compact player: title marquee, prev/play/next with Bloom's slide-push, volume, a compact progress bar with seek, an audio-output button and the album-art ambience glow.
- **Peek mode:** a new track or a resumed playback shows the notch for 3 s.

**Architecture:**
- **Music rules** (sizes, which mode the pill is in, peek, marquee timing, player choice, cava parsing) are plain JS, unit-tested.
- **Services** (`Media` for MPRIS, `Audio` for PipeWire volume and the mixer app, `Cava` for the visualizer) are loaded by the notch only while music mode is on. `Audio` loads only while the player is open, so a shell without music never touches MPRIS, PipeWire or cava.
- **Components:** Visualizer, AlbumArt, TitleMarquee, SkipButton, PlayButton, VolumeRow, ClassicPlayer, CompactPlayer and Ambience are plain QML, tested with `qmltestrunner`. NotchView composes them.
- **Media test:** a fake MPRIS player on a private D-Bus (`dbus-run-session` + Python GObject) tests the `Media` service and the notch's music mode end to end.

**Tech Stack:** Quickshell 0.3.2 (`Quickshell.Services.Mpris`, `Quickshell.Services.Pipewire`, `Quickshell.Io`), Qt 6.12 Quick/Effects/Shapes/QtTest, cava, python-gobject + dbus (tests only), headless sway (tests).

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` (sections 4.1 Notch "Music", 5.1, 6, 8 phase 2, 9, Appendix A). This is plan 2B of three for Phase 2. It builds on 2A as merged at `049cbd6`.

## Global Constraints

- **Platform:** Arch Linux; Hyprland ≥ 0.56 (Lua config); Quickshell ≥ 0.3.
- **Layer surfaces never resize while animating:** the notch surface stays 1000×480, and only its input mask follows the pill (spec §3.3).
- **Settings:** `bloom-*` keys in native JSON types, plus Bloom for Windows' string forms. An invalid value uses its default and logs a warning.
- **Polling** happens only while something visible needs it (spec §5.1):
  - player position 4 times a second, only while the player is open;
  - cava only while the visualizer is shown and media is playing.
- **Motion:** framer-motion parity through `Spring`.
  - A transition given only a duration uses framer `easeOut` `[0, 0, 0.58, 1]`.
  - A value with no transition: opacity and colour use `[0.25, 0.1, 0.35, 1]` over 300 ms; scale uses a 550/30 spring; `x`/`y` use a 500/25 spring.
  - framer `easeInOut` is `[0.42, 0, 0.58, 1]`. CSS `ease` is `[0.25, 0.1, 0.25, 1]`.
- **Files:** nothing under `~/.config` or `~/dots-hyprland` changes, except Task 9, run by the owner after approving it.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** QML and JS use tabs. Comments explain why, not what.

## Review Focus

1. **Several media players at once** (a browser tab plus Spotify).
   - The notch follows the player that most recently started playing.
   - When everything is paused, it follows the one that played last.
   - A player with no track (an idle tab) is ignored.
   - Test: Task 3 `test_pickPlayer`, Task 4 `test_media.sh`.
2. **The player disappears while the music panel is open** (an app quit, or a tab closed). The panel closes, the pill falls back to the clock, and no binding errors are logged. Test: Task 7 `test_playerVanishingClosesThePanel`.
3. **No cava installed.** The visualizer is not drawn, and the pill is sized as if the visualizer were off, never with a 30 px hole. Test: Task 7 `test_noVisualizerWithoutCava`.
4. **Tracks with no length** (live streams) or **players that can't seek.** The compact layout hides the progress row and uses the 116 px height, and dragging the bar of a non-seekable player sends no seek. Test: Task 6 `test_noProgressWithoutLength`, `test_noSeekWhenNotSeekable`.
5. **Very long or empty titles.**
   - A long title scrolls with Bloom's timing.
   - An empty title doesn't scroll and doesn't break the layout.
   - The artist line elides.
   - Test: Task 5 `test_marqueeScrollsOnlyWhenTooLong`, `test_emptyTitle`.

## Rulings already made (the owner sees these in the handoff)

- **Icons (owner decision, 2026-10-25):** the player uses Bloom's SF Symbols SVGs, copied from Bloom's `src/icons/sf/` into `third_party/bloom-sf-symbols/` with a NOTICE.
  - Apple's SF Symbols licence restricts use to apps for Apple platforms. The owner accepted that risk.
  - The NOTICE records it, so it can be revisited before the repo goes public.
- **Art flips:** Qt Quick has no perspective, so Bloom's `rotateY` flip of the album art shows as a horizontal squash (`cos(angle)`) with the same timing and fade.
- **Visualizer glow dropped:** Bloom gives each visualizer bar a soft 8 px `box-shadow` glow. Dropped: three visualizers × 5 bars of shadow passes is real cost on the UHD 620 for a barely visible halo.
- **Collapsed art exit:** when music leaves the pill, the art fades and shrinks over 120 ms. Bloom's extra 20 px rise and 8 px blur on exit are dropped (the blur needs an effect pass).
- **Audio-output button:** Bloom opened Windows' sound settings. Here it opens the first of `pavucontrol`, `pwvucontrol`, `pavucontrol-qt` that is installed, and is hidden when none is (spec §6: a missing tool hides its feature).
- **cava at 30 fps:** Bloom's backend frame rate wasn't fixed. The bars spring towards each level, so 30 fps looks the same as 60 at half the cost.
- **Placeholder gradient:** Bloom's 135° placeholder gradient becomes a top-to-bottom one, because a QML `Gradient` is vertical or horizontal only.

---

## File map

| File | Responsibility |
|---|---|
| `shell/services/settings.js`, `tools/gen-settings-doc.mjs`, `docs/SETTINGS.md` | Music keys and the legacy `bloom-visualizer-enabled` alias |
| `third_party/bloom-sf-symbols/*.svg`, `third_party/bloom-sf-symbols/NOTICE.md` | Bloom's player icons, vendored |
| `tools/gen-icons.mjs`, `shell/common/icons.js` | Icon table gains `sf-*` icons |
| `shell/common/tokens.js` | + `music` tokens |
| `shell/services/media.js` | Player choice, cava line parsing, time formats |
| `shell/modules/notch/music.js` | Music mode rules: pill mode, sizes, peek, marquee, bar scale |
| `shell/services/Media.qml`, `Audio.qml`, `Cava.qml`, `shell/assets/cava.conf` | MPRIS, PipeWire volume and mixer, visualizer |
| `shell/modules/notch/PressArea.qml` | framer `whileHover`/`whileTap` scale |
| `shell/modules/notch/Visualizer.qml`, `AlbumArt.qml`, `TitleMarquee.qml`, `SkipButton.qml`, `PlayButton.qml`, `VolumeRow.qml` | Player parts |
| `shell/modules/notch/ClassicPlayer.qml`, `CompactPlayer.qml`, `Ambience.qml` | The two open layouts and the glow |
| `shell/modules/notch/NotchView.qml` | Music mode in the notch |
| `shell/modules/notch/MusicData.qml`, `AudioData.qml`, `NotchWindow.qml`, `shell/shell.qml` | Wiring; `notch openMusic` IPC |
| `tests/qml/tst_settings.qml`, `tst_svgicon.qml`, `tst_media.qml`, `tst_music.qml`, `tst_musicparts.qml`, `tst_players.qml`, `tst_notchview.qml` | Unit and component tests |
| `tests/integration/fake_mpris.py`, `media-harness.qml`, `test_media.sh`, `test_notch_music.sh`, `test_notch.sh` | Fake player, Media service test, notch music test |
| `.github/workflows/ci.yml` | + `python-gobject dbus` |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-25)

- **Bloom music behaviour** (App.tsx, App.css, CompactMediaPlayer.tsx @ b5fb962):
  - **Pill mode:** `collapsedMode = "music"` when `bloom-music-mode-enabled`, `bloom-music-compact-notch`, a media session and `musicActivityVisible` are all true. Otherwise `"status"`.
  - **Activity linger:** `musicActivityVisible` turns on with a session and turns off 5000 ms after playback pauses.
  - **Session on hover:** `showMusicOnStatusHover` = not open, hovered, mode `status`, music enabled, has media, and (activity faded, or compact notch off).
  - **Width order** (`getDynamicWidth`):
    1. status-hover music: 170 (+30 with the visualizer on);
    2. status hover: Phase 2A rule;
    3. open music: classic 340 / compact 300;
    4. base: 140 (−16 for 24 h), then music mode adds +30 for visualizer-on-and-playing and +30 for art-on.
  - **Heights:** open classic 120; compact 116, or 132 with a progress bar, +36 with the volume row open.
  - **Peek:** in peek mode, show 3000 ms when a new title arrives while playing, or when playback starts.
  - **Collapsed art:** clicking it opens music; right-click skips to the previous track. It's 24 px (20 paused), radius 6, background white 0.15 (0.25 on hover). Size changes take 0.2 s with CSS `ease`; flips take 0.25 s `easeInOut`. Glow: inset −4, blur 6, saturate 2.5, brightness 0.8, opacity 0.6; on hover inset −6, blur 8, saturate 3, brightness 0.9, opacity 0.7, fading over 0.4 s. It appears with opacity and scale 0.8→1 over 0.12 s.
  - **Visualizer:** 5 bars, 3 px wide, 2.5 px gaps, 20 px tall (18 in the classic header, 16 in compact). `scaleY` and opacity spring 600/30, mass 0.5, to `max(0.2, level)` at 0.95 opacity while playing, or 0.1 at 0.5 when paused. Idle level 0.18.
  - **Classic player:**
    - Art 96 px, radius 12, 0.5 px white 0.1 border, shadow 0 4 16 black 0.4. Hover ×1.05, tap ×0.95 (default scale spring); clicking it switches to compact.
    - Column gap 5. Title 14.5/600, tracking −0.15, marquee; artist 12/400 muted.
    - Visualizer 5×18 at 0.8 opacity, 4 px from the top; on hover it swaps to a 20 px headphones button at 0.5 opacity.
    - Controls gap 24, buttons padded 8. Prev/next 32×16 icons with hover ×1.2 / tap ×0.9 (spring 400/25). Play/pause in a 44 px box with a 26 px icon; tap ×0.95; the icon swap is opacity plus scale 0.8 over 0.15 s.
    - Volume row 12 tall: icons 12 and 14 at 0.5; track 5 px, radius 2.5, white 0.15 (0.2 on hover); white fill.
  - **Compact player:**
    - Padding 3. Info row: gap 8, 6 px below; art 50 px radius 10 with shadow 0 2 8 0.3; title 15/600, tracking −0.2, line height 1.2; artist 12 muted; visualizer 5×16 at 0.7.
    - Progress row: gap 6, padding 3 0; times 11/500 muted, 30 px minimum, tabular figures; bar 3 px (6 on hover), white 0.15, white fill.
    - Controls row: space-between, 8 px above. Side buttons 22 px at 0.5 (0.8 on hover). Main buttons at 0.8 (1 on hover), padded 5, gap 4. Skips in a 32 px box with 30 px icons. Play 44 px box with a 26 px icon; the swap is scale 0.7 over 0.12 s; tap ×0.95, side and skip taps ×0.9.
    - Volume row slides open to 36 px (spring 500/30): padding 6 0, gap 8, track 4 px (5 on hover).
    - Times: `m:ss` elapsed and `-m:ss` remaining.
  - **Marquee:** speed 30 px/s, minimum 5 s. Keyframes: hold 0–12 %, slide 12–42 %, hold 42–55 %, slide back 55–80 %, hold 80–100 %, each segment eased with CSS `ease`. 8 px fade on the right.
  - **Ambience:** shown when open, ambience enabled and art present. Blur 52, saturate 3.5, contrast 1.1, brightness 1.4, scale 1.8, opacity 0.85, under a radial vignette (transparent 20 %, black 0.25 at 50 %, notch background at 85 %), clipped to the pill.
  - **Slide-push:** two icons in a clip, ±30 px over 180 ms, cubic-bezier(0.4, 0, 0.2, 1); the skip is sent at the end.
- **Quickshell MPRIS** (probed with a fake player):
  - `length` and `position` are in seconds; Quickshell interpolates `position` locally. Calling `player.positionChanged()` refreshes bindings.
  - Assigning `position` sends `SetPosition`.
  - `togglePlaying()` sends `Pause`/`Play`.
  - `isPlayingChanged` fires.
  - `Instantiator { model: Mpris.players }` works.
  - A player on a `dbus-run-session` bus is seen within about 200 ms.
- **Tools:** `cava` and `python-gobject` are in Arch `extra`. `pavucontrol-qt` is installed on the owner's machine. Python GObject and `dbus-run-session` are available locally.
- **2A as merged:** NotchWindow is loaded per screen through a `Loader` with `setSource(... { modelData })`. The notch test resets the shared pointer with `mouseMove(host, 0, 400)` before creating a view.

---

### Task 1: Music settings

**Files:**
- Modify: `shell/services/settings.js`, `tools/gen-settings-doc.mjs`, `tests/qml/tst_settings.qml`
- Regenerate: `docs/SETTINGS.md`

**Interfaces:**
- Produces keys:
  - `bloom-music-mode-enabled` (true), `bloom-music-compact-notch` (true);
  - `bloom-media-layout` (`"classic"` | `"compact"`, default classic);
  - `bloom-media-visualizer-enabled` (true, legacy key `bloom-visualizer-enabled`);
  - `bloom-media-album-art-enabled`, `bloom-media-ambience-enabled`, `bloom-media-compact-glow-enabled` (all true).
- Produces: a schema field `legacyKey` that `validate()` reads when the modern key is absent.

- [ ] **Step 1: Add the failing tests to `tests/qml/tst_settings.qml`**

Insert before the closing `}` of the `TestCase`:

```qml
	function test_musicDefaults() {
		const d = Settings.defaults();
		compare(d["bloom-music-mode-enabled"], true);
		compare(d["bloom-music-compact-notch"], true);
		compare(d["bloom-media-layout"], "classic");
		compare(d["bloom-media-visualizer-enabled"], true);
		compare(d["bloom-media-album-art-enabled"], true);
		compare(d["bloom-media-ambience-enabled"], true);
		compare(d["bloom-media-compact-glow-enabled"], true);
		verify(!Settings.validateOne("bloom-media-layout", "grid").ok);
	}

	// Bloom read the visualizer switch from an older key too.
	function test_legacyVisualizerKey() {
		const old = Settings.validate({ "bloom-visualizer-enabled": "false" });
		compare(old.values["bloom-media-visualizer-enabled"], false);
		compare(old.warnings, [], "the legacy key is not an unknown setting");
		const both = Settings.validate({ "bloom-visualizer-enabled": false, "bloom-media-visualizer-enabled": true });
		compare(both.values["bloom-media-visualizer-enabled"], true, "the modern key wins");
		compare(both.warnings, []);
		const bad = Settings.validate({ "bloom-visualizer-enabled": "maybe" });
		compare(bad.values["bloom-media-visualizer-enabled"], true);
		compare(bad.warnings.length, 1);
	}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `test_musicDefaults` and `test_legacyVisualizerKey` FAIL.

- [ ] **Step 3: Add the keys to `SCHEMA` in `shell/services/settings.js`**

Insert after the `"bloom-scale"` entry (add a comma after its closing `}`):

```js
	"bloom-music-mode-enabled": {
		type: "bool",
		default: true,
		doc: "Show playing media in the notch: album art, visualizer and the music player."
	},
	"bloom-music-compact-notch": {
		type: "bool",
		default: true,
		doc: "Show playing media in the collapsed notch. When off, music appears only when you hover the notch."
	},
	"bloom-media-layout": {
		type: "enum",
		values: ["classic", "compact"],
		default: "classic",
		doc: "Music player layout: classic = large album art; compact = small art with a progress bar."
	},
	"bloom-media-visualizer-enabled": {
		type: "bool",
		default: true,
		legacyKey: "bloom-visualizer-enabled",
		doc: "Audio visualizer bars in music mode (needs cava)."
	},
	"bloom-media-album-art-enabled": {
		type: "bool",
		default: true,
		doc: "Album artwork in the collapsed notch."
	},
	"bloom-media-ambience-enabled": {
		type: "bool",
		default: true,
		doc: "Coloured glow from the album art behind the open player."
	},
	"bloom-media-compact-glow-enabled": {
		type: "bool",
		default: true,
		doc: "Glow around the album art in the collapsed notch."
	}
```

- [ ] **Step 4: Teach `validate()` the legacy key**

In `shell/services/settings.js`, replace the body of `validate(obj)` from `Object.keys(obj).forEach(k => {` up to the end of that `forEach` with:

```js
	// Keys Bloom used to store under another name: legacy -> modern.
	const legacy = {};
	keys().forEach(k => {
		if (SCHEMA[k].legacyKey)
			legacy[SCHEMA[k].legacyKey] = k;
	});
	Object.keys(obj).forEach(k => {
		if (!SCHEMA[k]) {
			const modern = legacy[k];
			if (!modern) {
				warnings.push(k + ": unknown setting, ignored");
				return;
			}
			// The modern key wins when both are present.
			if (Object.prototype.hasOwnProperty.call(obj, modern))
				return;
			const r = validateOne(modern, obj[k]);
			if (r.ok)
				values[modern] = r.value;
			else
				warnings.push(`${k}: ${r.error}; using default ${JSON.stringify(SCHEMA[modern].default)}`);
			return;
		}
		const r = validateOne(k, obj[k]);
		if (r.ok)
			values[k] = r.value;
		else
			warnings.push(`${k}: ${r.error}; using default ${JSON.stringify(SCHEMA[k].default)}`);
	});
```

- [ ] **Step 5: Mention legacy keys in the generated reference**

In `tools/gen-settings-doc.mjs`, change the row builder to:

```js
const rows = ctx.keys().map(k => {
	const s = ctx.SCHEMA[k];
	const legacy = s.legacyKey ? ` Also read from \`${s.legacyKey}\`.` : "";
	return `| \`${k}\` | ${s.type} | \`${JSON.stringify(s.default)}\` | ${allowed(s)} | ${s.doc}${legacy} |`;
});
```

- [ ] **Step 6: Run the tests, regenerate, run the suite, commit**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `0 failed`.

Run: `node tools/gen-settings-doc.mjs && tests/run-all.sh 2>&1 | tail -1`
Expected: `wrote docs/SETTINGS.md`, then `all checks passed`.

```bash
git add shell/services/settings.js tools/gen-settings-doc.mjs tests/qml/tst_settings.qml docs/SETTINGS.md
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add music mode settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Player icons and music tokens

**Files:**
- Create: `third_party/bloom-sf-symbols/` (10 SVGs + `NOTICE.md`)
- Modify: `tools/gen-icons.mjs`, `shell/common/icons.js` (regenerated), `shell/common/tokens.js` (append), `tests/qml/tst_svgicon.qml`

**Interfaces:**
- Produces:
  - icon names `sf-play.fill`, `sf-pause.fill`, `sf-backward.fill`, `sf-forward.fill`, `sf-music.note`, `sf-headphones`, `sf-speaker.wave.1.fill`, `sf-speaker.wave.2.fill`, `sf-speaker.wave.3.fill`, `sf-speaker.slash.fill`, all usable with `SvgIcon`;
  - the `Tokens.music.*` tokens (Step 5).

- [ ] **Step 1: Add the failing test to `tests/qml/tst_svgicon.qml`**

Add an icon next to the existing ones in the host `Item` (keep the existing ones):

```qml
	SvgIcon { id: play; x: 0; y: 0; name: "sf-play.fill"; color: "#00ff00"; size: 24; visible: false }
```

and this test inside the `TestCase`:

```qml
		// Bloom's SF player icons are filled; recolouring must reach the fill.
		function test_recoloursAFilledIcon() {
			red.visible = false;
			play.visible = true;
			tryCompare(play, "status", Image.Ready, 3000);
			const img = grabImage(host);
			verify(Qt.colorEqual(img.pixel(10, 12), "#00ff00"), `got ${img.pixel(10, 12)}`);
			play.visible = false;
			red.visible = true;
		}
```

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_svgicon.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `test_recoloursAFilledIcon` FAILs. The suite also prints `unknown icon "sf-play.fill"`.

- [ ] **Step 2: Vendor the icons**

```bash
mkdir -p third_party/bloom-sf-symbols
for i in play.fill pause.fill backward.fill forward.fill music.note headphones speaker.wave.1.fill speaker.wave.2.fill speaker.wave.3.fill speaker.slash.fill; do
	cp "$HOME/Projects/bloom/src/icons/sf/$i.svg" third_party/bloom-sf-symbols/
done
ls third_party/bloom-sf-symbols | wc -l
```

Expected: `10`.

Create `third_party/bloom-sf-symbols/NOTICE.md`:

```markdown
# Player icons from Bloom

These SVGs are copied unchanged from Bloom for Windows
(`src/icons/sf/` in https://github.com/SehajveerSingh2005/bloom @ b5fb962),
which ships them as its media-player icons. They are drawings of Apple's
SF Symbols.

Apple's SF Symbols licence allows the symbols only in apps for Apple
platforms. The owner chose to use them anyway for visual parity with Bloom
(decision recorded 2026-10-25 in docs/plans/2026-10-25-phase-2b-music.md).
Revisit this before the repository is made public: replacing them means
editing tools/gen-icons.mjs and the `sf-*` names in shell/modules/notch.
```

- [ ] **Step 3: Extend `tools/gen-icons.mjs`**

After the `entries` array is built, add the vendored icons:

```js
// Bloom's player icons (filled SF Symbols drawings), see third_party/bloom-sf-symbols/NOTICE.md.
const SF = [
	"play.fill", "pause.fill", "backward.fill", "forward.fill", "music.note", "headphones",
	"speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill", "speaker.slash.fill"
];
for (const name of SF) {
	const raw = readFileSync(new URL(`third_party/bloom-sf-symbols/${name}.svg`, root), "utf8");
	const svg = raw.replace(/<!--[\s\S]*?-->/g, "").replace(/\s*\n\s*/g, " ").replace(/>\s+</g, "><").trim();
	entries.push(`\t${JSON.stringify("sf-" + name)}: ${JSON.stringify(svg)}`);
}
```

Then change the generated header line to:

```js
const out = `// Generated by tools/gen-icons.mjs from lucide-static ${version} (ISC licence,
// see licenses/lucide.txt) and Bloom's player icons (third_party/bloom-sf-symbols,
// see its NOTICE.md). Do not edit by hand.
```

and the log line to `console.log(\`wrote shell/common/icons.js (${entries.length} icons)\`);`.

Run: `node tools/gen-icons.mjs`
Expected: `wrote shell/common/icons.js (23 icons)`.

- [ ] **Step 4: Run the icon test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_svgicon.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `0 failed`. If the sampled pixel misses the triangle, sample the icon's centre instead (`img.pixel(12, 12)`); the play glyph covers its centre.

- [ ] **Step 5: Append the music tokens to `shell/common/tokens.js`**

```js

// Music mode (Bloom App.tsx, App.css, CompactMediaPlayer.tsx @ b5fb962).
var music = {
	activityLingerMs: 5000,
	peekMs: 3000,
	flipCurve: [0.42, 0, 0.58, 1], // framer easeInOut
	flipMs: 300,
	collapsedArt: { size: 24, pausedSize: 20, radius: 6, sizeMs: 200, flipMs: 250, appearMs: 120, glowInset: 4, glowHoverInset: 6 },
	visualizer: { bars: 5, barWidth: 3, gap: 2.5, height: 20, idleLevel: 0.18 },
	classic: { art: 96, artRadius: 12, gap: 22, columnGap: 5, controlsGap: 24, buttonPadding: 8, playBox: 44, playIcon: 26, skipWidth: 32, skipHeight: 16, volumeRow: 12, track: 5, vizHeight: 18 },
	compact: { padding: 3, art: 50, artRadius: 10, infoGap: 8, infoBelow: 6, progressGap: 6, progressPad: 3, controlsAbove: 8, sideIcon: 22, skipBox: 32, skipIcon: 30, playBox: 44, playIcon: 26, mainGap: 4, buttonPadding: 5, bar: 3, barHover: 6, volumeTrack: 4, volumeTrackHover: 5, time: 11, timeWidth: 30, vizHeight: 16, volumeHeight: 36 },
	marquee: { speed: 30, minSeconds: 5, fade: 8 },
	slide: { distance: 30, ms: 180, curve: [0.4, 0, 0.2, 1] },
	ambience: { blur: 52, scale: 1.8, opacity: 0.85, fadeMs: 600 }
};
```

- [ ] **Step 6: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add third_party/bloom-sf-symbols tools/gen-icons.mjs shell/common/icons.js shell/common/tokens.js tests/qml/tst_svgicon.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add Bloom's player icons and music tokens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Music rules

**Files:**
- Create: `shell/services/media.js`, `shell/modules/notch/music.js`, `tests/qml/tst_media.qml`, `tests/qml/tst_music.qml`

**Interfaces:**
- Produces `media.js`:
  - `pickPlayer(players: {id, playing, hasTrack, playingSince, lastActive}[]) → string` (`""` = none)
  - `parseCava(line: string) → number[5] | null` (levels 0–1)
  - `formatTime(ms) → "m:ss"`, `formatRemaining(elapsedMs, durationMs) → "-m:ss"`
- Produces `music.js`:
  - `collapsedMode({enabled, compactNotch, hasMedia, activityVisible}) → "music"|"status"`
  - `musicOnStatusHover({open, hovered, mode, enabled, hasMedia, activityVisible, compactNotch}) → bool`
  - `contentWidth({open, mode, hovered, onStatusHover, layout, visualizer, playing, albumArt, widgetCount, fitWidth, use24h}) → number`
  - `contentHeight({open, mode, layout, hasProgress, volumeExpanded}) → number`
  - `shouldPeek(prev: {title, playing}, cur: {title, playing}) → bool`
  - `marqueeDuration(overflowPx) → seconds`, `barScale(playing, level) → number`

- [ ] **Step 1: Write the failing tests**

`tests/qml/tst_media.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/services/media.js" as Media

TestCase {
	name: "MediaRules"

	function p(id, props) {
		const o = { id: id, playing: false, hasTrack: true, playingSince: 0, lastActive: 0 };
		for (const k in props) o[k] = props[k];
		return o;
	}

	// Review focus 1.
	function test_pickPlayer() {
		compare(Media.pickPlayer([]), "");
		compare(Media.pickPlayer([p("a"), p("b", { playing: true, playingSince: 5 })]), "b");
		compare(Media.pickPlayer([p("a", { playing: true, playingSince: 9 }), p("b", { playing: true, playingSince: 5 })]), "a", "most recently started wins");
		compare(Media.pickPlayer([p("a", { lastActive: 3 }), p("b", { lastActive: 7 })]), "b", "nothing playing: the one that played last");
		compare(Media.pickPlayer([p("tab", { playing: true, hasTrack: false, playingSince: 99 }), p("b")]), "b", "a player with no track is ignored");
		compare(Media.pickPlayer([p("tab", { hasTrack: false })]), "");
	}

	function test_parseCava() {
		compare(Media.parseCava("0;50;100;25;75;"), [0, 0.5, 1, 0.25, 0.75]);
		compare(Media.parseCava("10;20;"), null);
		compare(Media.parseCava(""), null);
	}

	// Bloom formatTime / formatRemaining.
	function test_times() {
		compare(Media.formatTime(0), "0:00");
		compare(Media.formatTime(65000), "1:05");
		compare(Media.formatTime(600999), "10:00");
		compare(Media.formatRemaining(65000, 200000), "-2:15");
		compare(Media.formatRemaining(300000, 200000), "-0:00");
	}
}
```

`tests/qml/tst_music.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch/music.js" as Music

TestCase {
	name: "MusicRules"

	function test_collapsedMode() {
		compare(Music.collapsedMode({ enabled: true, compactNotch: true, hasMedia: true, activityVisible: true }), "music");
		compare(Music.collapsedMode({ enabled: true, compactNotch: true, hasMedia: true, activityVisible: false }), "status");
		compare(Music.collapsedMode({ enabled: true, compactNotch: false, hasMedia: true, activityVisible: true }), "status");
		compare(Music.collapsedMode({ enabled: false, compactNotch: true, hasMedia: true, activityVisible: true }), "status");
	}

	function hover(props) {
		const s = { open: false, hovered: true, mode: "status", enabled: true, hasMedia: true, activityVisible: false, compactNotch: true };
		for (const k in props) s[k] = props[k];
		return Music.musicOnStatusHover(s);
	}

	function test_musicOnStatusHover() {
		verify(hover({}), "a faded session shows on hover");
		verify(hover({ activityVisible: true, compactNotch: false }), "compact notch off: hover is the only way in");
		verify(!hover({ activityVisible: true }), "still the live activity");
		verify(!hover({ hovered: false }));
		verify(!hover({ open: true }));
		verify(!hover({ hasMedia: false }));
	}

	function width(props) {
		const s = { open: false, mode: "status", hovered: false, onStatusHover: false, layout: "classic", visualizer: true, playing: true, albumArt: true, widgetCount: 2, fitWidth: 0, use24h: false };
		for (const k in props) s[k] = props[k];
		return Music.contentWidth(s);
	}

	// Bloom getDynamicWidth, in its order.
	function test_contentWidth() {
		compare(width({ onStatusHover: true }), 200);
		compare(width({ onStatusHover: true, visualizer: false }), 170);
		compare(width({ hovered: true }), 300, "status hover");
		compare(width({ mode: "music", open: true }), 340);
		compare(width({ mode: "music", open: true, layout: "compact" }), 300);
		compare(width({ mode: "music" }), 200);
		compare(width({ mode: "music", playing: false }), 170, "visualizer width only while playing");
		compare(width({ mode: "music", albumArt: false }), 170);
		compare(width({ mode: "music", use24h: true }), 184);
		compare(width({}), 140);
	}

	function test_contentHeight() {
		compare(Music.contentHeight({ open: false, mode: "music", layout: "classic", hasProgress: false, volumeExpanded: false }), 36);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "classic", hasProgress: true, volumeExpanded: true }), 120);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: false, volumeExpanded: false }), 116);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: true, volumeExpanded: false }), 132);
		compare(Music.contentHeight({ open: true, mode: "music", layout: "compact", hasProgress: true, volumeExpanded: true }), 168);
	}

	function test_shouldPeek() {
		verify(Music.shouldPeek({ title: "A", playing: true }, { title: "B", playing: true }), "new track while playing");
		verify(Music.shouldPeek({ title: "A", playing: false }, { title: "A", playing: true }), "playback started");
		verify(!Music.shouldPeek({ title: "A", playing: true }, { title: "A", playing: true }));
		verify(!Music.shouldPeek({ title: "A", playing: true }, { title: "B", playing: false }), "new track while paused");
	}

	function test_marqueeAndBars() {
		compare(Music.marqueeDuration(60), 5, "5 s minimum");
		compare(Music.marqueeDuration(300), 10, "30 px/s");
		compare(Music.barScale(true, 0.05), 0.2);
		compare(Music.barScale(true, 0.8), 0.8);
		compare(Music.barScale(false, 0.8), 0.1);
	}
}
```

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | grep -E "compile|Totals"`
Expected: `compile()` failures for `media.js` and `music.js` (unavailable).

- [ ] **Step 2: Create `shell/services/media.js`**

```js
// Media rules: which MPRIS player the notch follows, cava output, and the
// player's time labels (Bloom CompactMediaPlayer formatTime/formatRemaining).
// Plain JS, shared with the unit tests.

// Bloom followed Windows' current media session. On MPRIS: the player that
// most recently started playing; with none playing, the one that played last.
// A player with no track (an idle browser tab) never counts.
function pickPlayer(players) {
	const withTrack = players.filter(p => p.hasTrack);
	const playing = withTrack.filter(p => p.playing).sort((a, b) => b.playingSince - a.playingSince);
	if (playing.length)
		return playing[0].id;
	const recent = withTrack.slice().sort((a, b) => b.lastActive - a.lastActive);
	return recent.length ? recent[0].id : "";
}

// One cava raw ASCII frame ("12;80;...;"), levels 0-100, to five 0-1 levels.
function parseCava(line) {
	const v = line.split(";").filter(s => s.trim() !== "").map(Number).filter(n => !isNaN(n)).map(n => n / 100);
	return v.length >= 5 ? v.slice(0, 5) : null;
}

function _clock(totalSeconds) {
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

function formatTime(ms) {
	return ms <= 0 ? "0:00" : _clock(Math.floor(ms / 1000));
}

function formatRemaining(elapsed, duration) {
	return "-" + _clock(Math.floor(Math.max(0, duration - elapsed) / 1000));
}
```

- [ ] **Step 3: Create `shell/modules/notch/music.js`**

```js
.import "notch.js" as Notch

// Music mode rules ported from Bloom (App.tsx @ b5fb962). Plain JS, shared
// with the unit tests.

// Like the Dynamic Island, the collapsed pill shows one live activity: music
// while a session is live (and for 5 s after it pauses), else the clock.
function collapsedMode(s) {
	return s.enabled && s.compactNotch && s.hasMedia && s.activityVisible ? "music" : "status";
}

// A session that faded from the pill stays reachable by hovering it.
function musicOnStatusHover(s) {
	return !s.open && s.hovered && s.mode === "status" && s.enabled && s.hasMedia && (!s.activityVisible || !s.compactNotch);
}

// Bloom getDynamicWidth, in its order (pulses arrive in phase 2C).
function contentWidth(s) {
	if (s.onStatusHover)
		return 170 + (s.visualizer ? 30 : 0);
	if (s.mode === "status")
		return Notch.statusWidth(s.hovered, s.widgetCount, s.fitWidth, s.use24h);
	if (s.open)
		return s.layout === "compact" ? 300 : 340;
	let w = 140 - (s.use24h ? 16 : 0);
	if (s.visualizer && s.playing)
		w += 30;
	if (s.albumArt)
		w += 30;
	return w;
}

function contentHeight(s) {
	if (s.mode !== "music" || !s.open)
		return 36;
	if (s.layout !== "compact")
		return 120;
	return (s.hasProgress ? 132 : 116) + (s.volumeExpanded ? 36 : 0);
}

// Bloom peeks for a new track while playing, or when playback starts.
function shouldPeek(prev, cur) {
	return cur.playing && (cur.title !== prev.title || !prev.playing);
}

// Bloom TitleMarquee: 30 px/s, never shorter than 5 s.
function marqueeDuration(overflow) {
	return Math.max(overflow / 30, 5);
}

function barScale(playing, level) {
	return playing ? Math.max(0.2, level) : 0.1;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_media.qml 2>&1 | grep -E "^FAIL|Totals"; QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_music.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 5 passed, 0 failed` and `Totals: 8 passed, 0 failed`.

- [ ] **Step 5: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/services/media.js shell/modules/notch/music.js tests/qml/tst_media.qml tests/qml/tst_music.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add music mode and media player rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Media, Audio and Cava services

**Files:**
- Create:
  - services: `shell/services/Media.qml`, `shell/services/Audio.qml`, `shell/services/Cava.qml`, `shell/assets/cava.conf`;
  - tests: `tests/integration/fake_mpris.py`, `tests/integration/media-harness.qml`, `tests/integration/test_media.sh`.
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces:
  - Singleton `Media`:
    - track data: `player`, `hasMedia`, `isPlaying`, `title`, `artist`, `artUrl`;
    - playback: `lengthMs`, `canSeek`, `positionMs`;
    - methods: `hold(key, on)` (polls position 4× a second while held), `togglePlaying()`, `next()`, `previous()`, `seek(ms)`.
  - Singleton `Audio`:
    - volume: `volume` (0–1), `muted`, `setVolume(v)`, which unmutes for v > 0 as Bloom does;
    - mixer: `mixer` (the command or `""`), `openMixer()`.
  - Singleton `Cava`: `available`, `levels` (5 values), `hold(key, on)`. It runs while held and `Media.isPlaying`.
  - Test tool `fake_mpris.py NAME [--playing] [--title T] [--artist A] [--length-s N]`. It prints `READY`, then `CALL <method> <args>` for each call.

- [ ] **Step 1: Create the fake player `tests/integration/fake_mpris.py`**

```python
#!/usr/bin/env python3
"""A minimal MPRIS player on the session bus for integration tests.

Usage: fake_mpris.py NAME [--playing] [--title T] [--artist A] [--length-s N]
Records every method call (PlayPause, Next, Previous, SetPosition, Seek) on
stdout as "CALL <name> <args>" so tests can assert on them.
"""
import argparse, sys
from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/><method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
    <method name="Stop"/><method name="Play"/>
    <method name="Seek"><arg direction="in" type="x" name="Offset"/></method>
    <method name="SetPosition"><arg direction="in" type="o" name="TrackId"/><arg direction="in" type="x" name="Position"/></method>
    <method name="OpenUri"><arg direction="in" type="s" name="Uri"/></method>
    <signal name="Seeked"><arg type="x" name="Position"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/><property name="Rate" type="d" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/><property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""

p = argparse.ArgumentParser()
p.add_argument("name")
p.add_argument("--playing", action="store_true")
p.add_argument("--title", default="Fake Song")
p.add_argument("--artist", default="Fake Artist")
p.add_argument("--length-s", type=int, default=200)
a = p.parse_args()

state = {"playing": a.playing, "title": a.title, "position": 0}
TRACK = "/org/bloom/fake/track/1"
node = Gio.DBusNodeInfo.new_for_xml(XML)
conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)

def metadata():
    return GLib.Variant("a{sv}", {
        "mpris:trackid": GLib.Variant("o", TRACK),
        "mpris:length": GLib.Variant("x", a.length_s * 1_000_000),
        "xesam:title": GLib.Variant("s", state["title"]),
        "xesam:artist": GLib.Variant("as", [a.artist]),
    })

def props(iface):
    if iface == "org.mpris.MediaPlayer2":
        return {"CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False),
                "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", a.name),
                "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", [])}
    return {"PlaybackStatus": GLib.Variant("s", "Playing" if state["playing"] else "Paused"),
            "Rate": GLib.Variant("d", 1.0), "Metadata": metadata(), "Volume": GLib.Variant("d", 1.0),
            "Position": GLib.Variant("x", state["position"]), "MinimumRate": GLib.Variant("d", 1.0),
            "MaximumRate": GLib.Variant("d", 1.0), "CanGoNext": GLib.Variant("b", True),
            "CanGoPrevious": GLib.Variant("b", True), "CanPlay": GLib.Variant("b", True),
            "CanPause": GLib.Variant("b", True), "CanSeek": GLib.Variant("b", True),
            "CanControl": GLib.Variant("b", True)}

def changed(names):
    p = props("org.mpris.MediaPlayer2.Player")
    conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", {n: p[n] for n in names}, [])))

def call(_c, _s, _o, iface, method, params, inv):
    print("CALL", method, params.unpack() if params else "", flush=True)
    if method in ("PlayPause", "Play", "Pause", "Stop"):
        state["playing"] = {"PlayPause": not state["playing"], "Play": True}.get(method, False)
        changed(["PlaybackStatus"])
    elif method in ("Next", "Previous"):
        state["title"] = f"{a.title} ({method})"; state["position"] = 0; changed(["Metadata"])
    elif method == "SetPosition":
        state["position"] = params.unpack()[1]
        conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Seeked",
                         GLib.Variant("(x)", (state["position"],)))
    inv.return_value(None)

def get_prop(_c, _s, _o, iface, name):
    return props(iface)[name]

def set_prop(*_):
    return True

for iface in node.interfaces:
    conn.register_object("/org/mpris/MediaPlayer2", iface, call, get_prop, set_prop)
Gio.bus_own_name_on_connection(conn, f"org.mpris.MediaPlayer2.{a.name}", Gio.BusNameOwnerFlags.NONE, None, None)
print("READY", flush=True)
GLib.MainLoop().run()
```

Run: `chmod +x tests/integration/fake_mpris.py && dbus-run-session -- sh -c 'timeout 2 python3 tests/integration/fake_mpris.py probe | head -1'`
Expected: `READY`.

- [ ] **Step 2: Write the failing Media test**

`tests/integration/media-harness.qml`:

```qml
import QtQuick
import Quickshell
import qs.services

// Test harness for Media, run by tests/integration/test_media.sh with two
// fake players: "idle" (paused) and "busy" (playing). Prints RESULT lines.
ShellRoot {
	Component.onCompleted: Media.hold("harness", true)

	Timer {
		id: step1
		interval: 800
		running: true
		onTriggered: {
			console.log(`RESULT follows=${Media.title} playing=${Media.isPlaying} length=${Media.lengthMs} canSeek=${Media.canSeek}`);
			Media.seek(42000);
			Media.next();
			Media.togglePlaying();
			step2.start();
		}
	}

	Timer {
		id: step2
		interval: 800
		onTriggered: {
			console.log(`RESULT after title=${Media.title} playing=${Media.isPlaying} position>=42=${Media.positionMs >= 42000}`);
			Qt.exit(0);
		}
	}
}
```

`tests/integration/test_media.sh`:

```bash
#!/usr/bin/env bash
# Media follows the playing MPRIS player and controls it (fake players on a
# private session bus, so the owner's real players never interfere).
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	exec dbus-run-session -- env BLOOM_IN_DBUS=1 bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

python3 "$ROOT/tests/integration/fake_mpris.py" idle --title "Idle Song" >"$TEST_TMP/idle.log" 2>&1 &
IDLE_PID=$!
python3 "$ROOT/tests/integration/fake_mpris.py" busy --playing --title "Busy Song" --length-s 200 >"$TEST_TMP/busy.log" 2>&1 &
BUSY_PID=$!
trap 'kill $IDLE_PID $BUSY_PID 2>/dev/null || true; bloom_cleanup' EXIT
wait_for "the fake players" grep -q READY "$TEST_TMP/busy.log"

HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$HARNESS/"
cp "$ROOT/tests/integration/media-harness.qml" "$HARNESS/shell.qml"

timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1 || fail "harness exited with an error"

# Review focus 1: the playing player wins over the paused one.
log_has "RESULT follows=Busy Song playing=true length=200000 canSeek=true" || fail "Media did not follow the playing player"
pass "Media follows the playing player"

grep -q "CALL SetPosition ('/org/bloom/fake/track/1', 42000000)" "$TEST_TMP/busy.log" || fail "seek not sent"
grep -q "CALL Next" "$TEST_TMP/busy.log" || fail "next not sent"
grep -q "CALL Pause" "$TEST_TMP/busy.log" || fail "toggle not sent"
log_has "RESULT after title=Busy Song (Next) playing=false position>=42=" || fail "state after control"
pass "seek, next and play/pause reach the player, and Media follows its state"

if grep -E '^ *(WARN|ERROR)' "$TEST_TMP/shell.log"; then fail "harness logged warnings"; fi
pass "no warnings"
```

Run: `chmod +x tests/integration/test_media.sh && bash tests/integration/test_media.sh`
Expected: FAIL with `harness exited with an error`; the log shows `ReferenceError: Media is not defined`.

- [ ] **Step 3: Create `shell/services/Media.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "media.js" as Logic

// The media player the notch follows (Bloom: Windows' current media session):
// the most recently started player that is playing, else the one that played
// last. MPRIS doesn't push position, so it is re-read 4 times a second, but
// only while something holds the service (the open player).
Singleton {
	id: root

	// dbusName -> when it last started playing / last changed play state.
	property var _since: ({})
	property var _active: ({})
	property var _holders: ({})

	readonly property var player: {
		const ps = Mpris.players.values;
		const id = Logic.pickPlayer(ps.map(p => ({
			id: p.dbusName,
			playing: p.isPlaying,
			hasTrack: (p.trackTitle ?? "") !== "",
			playingSince: root._since[p.dbusName] ?? 0,
			lastActive: root._active[p.dbusName] ?? 0
		})));
		return ps.find(p => p.dbusName === id) ?? null;
	}

	readonly property bool hasMedia: root.player !== null
	readonly property bool isPlaying: root.player?.isPlaying ?? false
	readonly property string title: root.player?.trackTitle ?? ""
	readonly property string artist: root.player?.trackArtist ?? ""
	readonly property string artUrl: root.player?.trackArtUrl ?? ""
	readonly property real lengthMs: root.player && root.player.lengthSupported ? root.player.length * 1000 : 0
	readonly property bool canSeek: root.player?.canSeek ?? false
	property real positionMs: 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function togglePlaying() {
		if (root.player && root.player.canTogglePlaying)
			root.player.togglePlaying();
	}

	function next() {
		if (root.player && root.player.canGoNext)
			root.player.next();
	}

	function previous() {
		if (root.player && root.player.canGoPrevious)
			root.player.previous();
	}

	function seek(ms) {
		if (!root.player || !root.player.canSeek)
			return;
		root.player.position = ms / 1000;
		root.positionMs = ms;
	}

	function _mark(p) {
		const now = Date.now();
		const active = Object.assign({}, root._active);
		active[p.dbusName] = now;
		root._active = active;
		if (p.isPlaying) {
			const since = Object.assign({}, root._since);
			since[p.dbusName] = now;
			root._since = since;
		}
	}

	Instantiator {
		model: Mpris.players
		delegate: Connections {
			required property var modelData
			target: modelData
			function onIsPlayingChanged() { root._mark(modelData); }
		}
	}

	Timer {
		interval: 250
		repeat: true
		triggeredOnStart: true
		running: Object.keys(root._holders).length > 0 && root.player !== null
		onTriggered: {
			root.player.positionChanged();
			root.positionMs = root.player.position * 1000;
		}
	}
}
```

- [ ] **Step 4: Run the Media test to verify it passes**

Run: `bash tests/integration/test_media.sh`
Expected: 3 `ok - …` lines.

- [ ] **Step 5: Create `shell/services/Audio.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// System output volume for the player's volume rows, and the mixer app its
// audio-output button opens (Bloom opened Windows' sound settings). The
// button hides when no mixer is installed.
Singleton {
	id: root

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property real volume: root.sink?.audio?.volume ?? 0
	readonly property bool muted: root.sink?.audio?.muted ?? false
	property string mixer: ""

	// Bloom: setting a non-zero volume also unmutes.
	function setVolume(v) {
		if (!root.sink || !root.sink.audio)
			return;
		const clamped = Math.max(0, Math.min(1, v));
		root.sink.audio.volume = clamped;
		if (clamped > 0)
			root.sink.audio.muted = false;
	}

	function openMixer() {
		if (root.mixer)
			Quickshell.execDetached([root.mixer]);
	}

	PwObjectTracker { objects: [root.sink] }

	Process {
		running: true
		command: ["sh", "-c", "for c in pavucontrol pwvucontrol pavucontrol-qt; do command -v \"$c\" >/dev/null && { echo \"$c\"; exit 0; }; done; exit 0"]
		stdout: StdioCollector { onStreamFinished: root.mixer = text.trim() }
	}
}
```

- [ ] **Step 6: Create `shell/assets/cava.conf` and `shell/services/Cava.qml`**

`shell/assets/cava.conf`:

```
# Five levels for the notch visualizer (Bloom drew five bars).
[general]
bars = 5
framerate = 30
[input]
method = pipewire
source = auto
[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
```

`shell/services/Cava.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "media.js" as Logic

// Five visualizer levels from cava (PipeWire input), only while something
// holds the service and media is playing. `available` is false without cava,
// and the notch then draws no visualizer at all.
Singleton {
	id: root

	readonly property var idle: [0.18, 0.18, 0.18, 0.18, 0.18]
	property var levels: root.idle
	property bool available: false
	property var _holders: ({})
	readonly property bool _running: root.available && Object.keys(root._holders).length > 0 && Media.isPlaying

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	on_RunningChanged: if (!root._running) root.levels = root.idle

	Process {
		running: true
		command: ["sh", "-c", "command -v cava"]
		onExited: code => root.available = code === 0
	}

	Process {
		running: root._running
		command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
		stdout: SplitParser {
			onRead: line => {
				const v = Logic.parseCava(line);
				if (v)
					root.levels = v;
			}
		}
	}
}
```

- [ ] **Step 7: Add the test tools to CI**

In `.github/workflows/ci.yml`, add `python-gobject dbus` to the `pacman -Syu` line.

- [ ] **Step 8: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`; qmllint accepts the three services).

```bash
git add shell/services/Media.qml shell/services/Audio.qml shell/services/Cava.qml shell/assets/cava.conf tests/integration/fake_mpris.py tests/integration/media-harness.qml tests/integration/test_media.sh .github/workflows/ci.yml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add media, audio and visualizer services

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Player parts

**Files:**
- Create: `shell/modules/notch/PressArea.qml`, `Visualizer.qml`, `AlbumArt.qml`, `TitleMarquee.qml`, `SkipButton.qml`, `PlayButton.qml`, `VolumeRow.qml`, `tests/qml/tst_musicparts.qml`

**Interfaces:**
- Produces (all in `shell/modules/notch/`):
  - `PressArea` (Item):
    - inputs: `hoverScale`, `tapScale`, `stiffness`, `damping` (default framer scale spring 550/30);
    - signals: `clicked()`, `rightClicked()`;
    - output: `hovered`.
  - `Visualizer` (Row): `playing`, `levels`, `barHeight`, `color`. Each bar's `objectName` is `bar<i>`, with readonly `targetScale` and `targetOpacity`.
  - `AlbumArt` (Item): `source`, `radius`, `flipMs`; readonly `flipping`, `shown` (the url currently drawn).
  - `TitleMarquee` (Item): `text`, `color`, `pixelSize`, `weight`, `letterSpacing`, `lineHeight`; readonly `overflow`, `scrolling`, `cycleMs`.
  - `SkipButton` (Item): `forward`, `iconWidth`, `iconHeight`, `boxWidth`, `boxHeight`, `padding`, `color`, `hoverScale`, `tapScale`, `stiffness`, `damping`; signal `activated()`.
  - `PlayButton` (Item): `playing`, `box`, `iconSize`, `color`, `swapScale`, `swapMs`, `hoverScale`, `tapScale`, `stiffness`, `damping`; readonly `shownPlaying`; signal `clicked()`.
  - `VolumeRow` (Row): `volume`, `trackHeight`, `trackHoverHeight`, `color`, `hoverTint`; signal `moved(real v)`.

- [ ] **Step 1: Write the failing test `tests/qml/tst_musicparts.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 400
	height: 300

	Visualizer { id: viz; levels: [0.05, 0.5, 1, 0.3, 0.9] }
	TitleMarquee { id: shortTitle; y: 40; width: 300; text: "Short" }
	TitleMarquee { id: longTitle; y: 70; width: 100; text: "A very long title that cannot possibly fit in a hundred pixels" }
	TitleMarquee { id: emptyTitle; y: 100; width: 100; text: "" }
	SkipButton { id: next; y: 130; forward: true }
	SkipButton { id: prev; x: 60; y: 130; forward: false }
	PlayButton { id: play; x: 120; y: 130 }
	VolumeRow { id: vol; y: 200; width: 200; volume: 0.25 }
	AlbumArt { id: art; x: 300; y: 200; width: 50; height: 50; source: "" ; flipMs: 50 }

	SignalSpy { id: nextSpy; target: next; signalName: "activated" }
	SignalSpy { id: playSpy; target: play; signalName: "clicked" }
	SignalSpy { id: volSpy; target: vol; signalName: "moved" }

	TestCase {
		name: "MusicParts"
		when: windowShown

		function test_visualizerTargets() {
			const bar = i => findChild(viz, "bar" + i);
			viz.playing = true;
			compare(bar(0).targetScale, 0.2, "never below 0.2 while playing");
			compare(bar(2).targetScale, 1);
			compare(bar(0).targetOpacity, 0.95);
			viz.playing = false;
			compare(bar(2).targetScale, 0.1);
			compare(bar(2).targetOpacity, 0.5);
			compare(viz.width, 5 * 3 + 4 * 2.5);
		}

		// Review focus 5.
		function test_marqueeScrollsOnlyWhenTooLong() {
			verify(!shortTitle.scrolling);
			verify(longTitle.scrolling);
			verify(longTitle.overflow > 0);
			compare(longTitle.cycleMs, Math.max(longTitle.overflow / 30, 5) * 1000);
		}

		function test_emptyTitle() {
			verify(!emptyTitle.scrolling);
			compare(emptyTitle.overflow, 0);
		}

		function test_skipPushesThenActivates() {
			mouseClick(next);
			compare(nextSpy.count, 0, "the skip is sent once the slide ends");
			tryCompare(nextSpy, "count", 1, 1000);
		}

		function test_playSwapsIcon() {
			play.playing = false;
			mouseClick(play);
			compare(playSpy.count, 1);
			play.playing = true;
			tryCompare(play, "shownPlaying", true, 1000);
		}

		function test_volumeDrag() {
			const track = findChild(vol, "volumeTrack");
			const p = track.mapToItem(host, track.width * 0.75, track.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			verify(volSpy.count >= 1);
			fuzzyCompare(volSpy.signalArguments[volSpy.count - 1][0], 0.75, 0.05);
		}

		function test_albumArtFlipsOnChange() {
			compare(art.shown.toString(), "");
			art.source = "file:///nonexistent-a.png";
			verify(art.flipping, "the old art turns away first");
			tryCompare(art, "flipping", false, 1000);
			compare(art.shown.toString(), "file:///nonexistent-a.png");
		}
	}
}
```

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_musicparts.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile()` (`Visualizer is not a type`).

- [ ] **Step 2: Create `shell/modules/notch/PressArea.qml`**

```qml
import QtQuick
import "../../common"

// framer-motion whileHover/whileTap: scales with a spring while hovered or
// pressed. The default is framer's own scale spring (550/30); Bloom's
// buttons that set a transition pass 400/25.
Item {
	id: root

	property real hoverScale: 1
	property real tapScale: 0.9
	property real stiffness: 550
	property real damping: 30
	readonly property bool hovered: hover.hovered

	signal clicked()
	signal rightClicked()

	scale: spring.value

	Spring {
		id: spring
		stiffness: root.stiffness
		damping: root.damping
		target: left.pressed ? root.tapScale : hover.hovered ? root.hoverScale : 1
		initial: 1
	}

	HoverHandler { id: hover }

	TapHandler {
		id: left
		acceptedButtons: Qt.LeftButton
		onTapped: root.clicked()
	}

	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: root.rightClicked()
	}
}
```

- [ ] **Step 3: Create `shell/modules/notch/Visualizer.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "music.js" as Music

// Bloom's 5-bar visualizer: each bar's height and opacity spring (600/30,
// mass 0.5) towards its level while playing, and rest low and dim when paused.
Row {
	id: root

	property bool playing: false
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property real barHeight: Tokens.music.visualizer.height
	property color color: "white"

	spacing: Tokens.music.visualizer.gap
	height: root.barHeight

	Repeater {
		model: Tokens.music.visualizer.bars

		Rectangle {
			id: bar
			required property int index
			readonly property real targetScale: Music.barScale(root.playing, root.levels[bar.index] ?? Tokens.music.visualizer.idleLevel)
			readonly property real targetOpacity: root.playing ? 0.95 : 0.5

			objectName: "bar" + bar.index
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.music.visualizer.barWidth
			height: root.barHeight
			radius: 2
			color: root.color
			opacity: opacitySpring.value
			transform: Scale { origin.y: root.barHeight / 2; yScale: scaleSpring.value }

			Spring { id: scaleSpring; stiffness: 600; damping: 30; mass: 0.5; initial: 0.1; target: bar.targetScale }
			Spring { id: opacitySpring; stiffness: 600; damping: 30; mass: 0.5; initial: 0.5; target: bar.targetOpacity }
		}
	}
}
```

- [ ] **Step 4: Create `shell/modules/notch/AlbumArt.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens

// Album art that flips when the track's art changes, like Bloom's
// AnimatePresence "wait": the old art turns away, then the new one turns in,
// each half easeInOut. Qt Quick has no perspective, so the turn reads as a
// horizontal squash. Without art it shows Bloom's music-note placeholder.
Item {
	id: root

	property url source: ""
	property real radius: 6
	property int flipMs: Tokens.music.flipMs
	property real noteScale: 0.55
	property color noteColor: Qt.rgba(1, 1, 1, 0.85)
	property color placeholderTop: Qt.rgba(1, 1, 1, 0.12)
	property color placeholderBottom: Qt.rgba(1, 1, 1, 0.03)

	readonly property bool flipping: flip.running
	property url shown: ""
	property real _angle: 0

	Component.onCompleted: root.shown = root.source
	onSourceChanged: if (root.source !== root.shown || flip.running) flip.restart()

	SequentialAnimation {
		id: flip
		NumberAnimation {
			target: root; property: "_angle"; to: -90; duration: root.flipMs
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1]
		}
		ScriptAction { script: { root.shown = root.source; root._angle = 90; } }
		NumberAnimation {
			target: root; property: "_angle"; to: 0; duration: root.flipMs
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1]
		}
	}

	Item {
		id: face
		anchors.fill: parent
		opacity: 1 - Math.abs(root._angle) / 90
		transform: Scale { origin.x: face.width / 2; xScale: Math.cos(root._angle * Math.PI / 180) }
		layer.enabled: true
		layer.effect: MultiEffect {
			maskEnabled: true
			maskSource: mask
			maskThresholdMin: 0.5
			maskSpreadAtMin: 1
		}

		Rectangle {
			anchors.fill: parent
			visible: image.status !== Image.Ready
			gradient: Gradient {
				GradientStop { position: 0; color: root.placeholderTop }
				GradientStop { position: 1; color: root.placeholderBottom }
			}
		}

		SvgIcon {
			anchors.centerIn: parent
			visible: image.status !== Image.Ready
			name: "sf-music.note"
			size: parent.width * root.noteScale
			color: root.noteColor
		}

		Image {
			id: image
			anchors.fill: parent
			source: root.shown
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
			visible: status === Image.Ready
		}
	}

	Item {
		id: mask
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle { anchors.fill: parent; radius: root.radius }
	}
}
```

- [ ] **Step 5: Create `shell/modules/notch/TitleMarquee.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens
import "music.js" as Music

// A track title that scrolls when it doesn't fit (Bloom TitleMarquee): hold,
// slide to the end, hold, slide back, hold, at 30 px/s and never quicker than
// 5 s, each slide eased with CSS `ease`. The right edge fades over 8 px.
Item {
	id: root

	property string text: ""
	property color color: "white"
	property real pixelSize: 14.5
	property int weight: Font.DemiBold
	property real letterSpacing: -0.15
	property real lineHeight: 1

	readonly property real overflow: Math.max(0, Math.ceil(label.implicitWidth - root.width))
	readonly property bool scrolling: root.overflow > 0 && root.width > 0
	readonly property real cycleMs: Music.marqueeDuration(root.overflow) * 1000

	implicitHeight: label.implicitHeight
	clip: true
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: fade
	}

	Text {
		id: label
		text: root.text
		color: root.color
		font.family: Tokens.type.family
		font.pixelSize: root.pixelSize
		font.weight: root.weight
		font.letterSpacing: root.letterSpacing
		lineHeight: root.lineHeight
	}

	SequentialAnimation {
		running: root.scrolling && root.visible
		loops: Animation.Infinite
		onRunningChanged: if (!running) label.x = 0
		PauseAnimation { duration: root.cycleMs * 0.12 }
		NumberAnimation {
			target: label; property: "x"; from: 0; to: -root.overflow; duration: root.cycleMs * 0.30
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
		PauseAnimation { duration: root.cycleMs * 0.13 }
		NumberAnimation {
			target: label; property: "x"; to: 0; duration: root.cycleMs * 0.25
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
		PauseAnimation { duration: root.cycleMs * 0.20 }
	}

	Item {
		id: fade
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle {
			anchors.fill: parent
			gradient: Gradient {
				orientation: Gradient.Horizontal
				GradientStop { position: 0; color: "black" }
				GradientStop { position: Math.max(0, 1 - Tokens.music.marquee.fade / Math.max(1, root.width)); color: "black" }
				GradientStop { position: 1; color: "transparent" }
			}
		}
	}
}
```

- [ ] **Step 6: Create `shell/modules/notch/SkipButton.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// Bloom's prev/next push: the icon slides out 30 px while a copy slides in
// (180 ms, cubic-bezier(0.4, 0, 0.2, 1)), then the skip is sent.
PressArea {
	id: root

	property bool forward: true
	property real iconWidth: 32
	property real iconHeight: 16
	property real boxWidth: 32
	property real boxHeight: 16
	property real padding: 8
	property color color: "white"

	signal activated()

	implicitWidth: root.boxWidth + 2 * root.padding
	implicitHeight: root.boxHeight + 2 * root.padding
	hoverScale: 1.2
	tapScale: 0.9
	stiffness: 400
	damping: 25

	readonly property real _d: Tokens.music.slide.distance
	readonly property string _icon: root.forward ? "sf-forward.fill" : "sf-backward.fill"

	onClicked: {
		front.x = 0;
		back.x = root.forward ? -root._d : root._d;
		slide.restart();
	}

	Item {
		anchors.centerIn: parent
		width: root.boxWidth
		height: root.boxHeight
		clip: true

		SvgIcon {
			id: back
			x: root.forward ? -root._d : root._d
			y: (root.boxHeight - height) / 2
			name: root._icon
			size: root.iconWidth
			height: root.iconHeight
			color: root.color
		}

		SvgIcon {
			id: front
			y: (root.boxHeight - height) / 2
			name: root._icon
			size: root.iconWidth
			height: root.iconHeight
			color: root.color
		}
	}

	ParallelAnimation {
		id: slide
		NumberAnimation {
			target: front; property: "x"; to: root.forward ? root._d : -root._d; duration: Tokens.music.slide.ms
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
		}
		NumberAnimation {
			target: back; property: "x"; to: 0; duration: Tokens.music.slide.ms
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
		}
		onFinished: root.activated()
	}
}
```

- [ ] **Step 7: Create `shell/modules/notch/PlayButton.qml`**

```qml
import QtQuick
import "../../common"

// Play/pause with Bloom's icon swap: the old icon fades and shrinks, then the
// new one grows in (AnimatePresence "wait").
PressArea {
	id: root

	property bool playing: false
	property real box: 44
	property real iconSize: 26
	property color color: "white"
	property real swapScale: 0.8
	property int swapMs: 150
	readonly property bool shownPlaying: root._shown

	property bool _shown: root.playing
	implicitWidth: root.box
	implicitHeight: root.box
	tapScale: 0.95

	onPlayingChanged: swap.restart()

	SequentialAnimation {
		id: swap
		ParallelAnimation {
			NumberAnimation { target: icon; property: "opacity"; to: 0; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			NumberAnimation { target: icon; property: "scale"; to: root.swapScale; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
		ScriptAction { script: root._shown = root.playing }
		ParallelAnimation {
			NumberAnimation { target: icon; property: "opacity"; to: 1; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			NumberAnimation { target: icon; property: "scale"; to: 1; duration: root.swapMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
	}

	SvgIcon {
		id: icon
		anchors.centerIn: parent
		// Bloom nudges the play glyph 1 px right to centre its mass.
		anchors.horizontalCenterOffset: root._shown ? 0 : 1
		name: root._shown ? "sf-pause.fill" : "sf-play.fill"
		size: root.iconSize
		color: root.color
	}
}
```

- [ ] **Step 8: Create `shell/modules/notch/VolumeRow.qml`**

```qml
import QtQuick
import "../../common"

// Bloom's volume row: quiet and loud speaker icons around a thin track whose
// fill follows the system volume; dragging sets it.
Row {
	id: root

	property real volume: 0
	property real trackHeight: 5
	property real trackHoverHeight: 5
	property color color: "white"
	property real trackOpacity: 0.15
	property real trackHoverOpacity: 0.2

	signal moved(real v)

	spacing: 8
	height: 14

	SvgIcon {
		anchors.verticalCenter: parent.verticalCenter
		name: "sf-speaker.wave.1.fill"
		size: 12
		color: root.color
		opacity: 0.5
	}

	Item {
		id: hit
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(0, root.width - 12 - 14 - 2 * root.spacing)
		height: 14

		HoverHandler { id: hover }

		Rectangle {
			id: track
			objectName: "volumeTrack"
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width
			height: hover.hovered ? root.trackHoverHeight : root.trackHeight
			radius: height / 2
			color: Qt.rgba(root.color.r, root.color.g, root.color.b, hover.hovered ? root.trackHoverOpacity : root.trackOpacity)
			clip: true

			Rectangle {
				height: parent.height
				radius: parent.radius
				width: parent.width * Math.max(0, Math.min(1, root.volume))
				color: root.color
				Behavior on width {
					NumberAnimation { duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
				}
			}
		}

		MouseArea {
			anchors.fill: parent
			function set(mx) { root.moved(Math.max(0, Math.min(1, mx / width))); }
			onPressed: mouse => set(mouse.x)
			onPositionChanged: mouse => { if (pressed) set(mouse.x); }
		}
	}

	SvgIcon {
		anchors.verticalCenter: parent.verticalCenter
		name: "sf-speaker.wave.3.fill"
		size: 14
		color: root.color
		opacity: 0.5
	}
}
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_musicparts.qml 2>&1 | grep -E "^FAIL|Totals|Actual|Expected"`
Expected: `Totals: 9 passed, 0 failed`. Any failure is a defect: debug it with superpowers:systematic-debugging, and do not loosen the test.

- [ ] **Step 10: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/modules/notch/PressArea.qml shell/modules/notch/Visualizer.qml shell/modules/notch/AlbumArt.qml shell/modules/notch/TitleMarquee.qml shell/modules/notch/SkipButton.qml shell/modules/notch/PlayButton.qml shell/modules/notch/VolumeRow.qml tests/qml/tst_musicparts.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add Bloom music player parts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Classic and compact players, ambience

**Files:**
- Create: `shell/modules/notch/ClassicPlayer.qml`, `shell/modules/notch/CompactPlayer.qml`, `shell/modules/notch/Ambience.qml`, `tests/qml/tst_players.qml`

**Interfaces:**
- Consumes: Task 5 parts, `media.js` `formatTime`/`formatRemaining`.
- Produces:
  - **Shared player inputs** (both players): `media` (`{title, artist, artUrl, isPlaying, lengthMs, canSeek}`), `positionMs`, `levels`, `visualizer` (bool), `volume`, `muted`, `mixerAvailable`, `textColor`, `textMuted`.
  - **Shared player signals:** `togglePlay()`, `previousTrack()`, `nextTrack()`, `setVolume(real v)`, `openMixer()`, `switchLayout()`.
  - **`CompactPlayer` adds:**
    - `volumeExpanded` (bool, read and write);
    - readonly `hasProgress`;
    - signal `seekTo(real ms)`.
  - **`Ambience`:** `source`, `bg` (the notch background colour), `radius`; readonly `shown`.

- [ ] **Step 1: Write the failing test `tests/qml/tst_players.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 600
	height: 400

	readonly property var track: ({ title: "Song", artist: "Artist", artUrl: "", isPlaying: true, lengthMs: 200000, canSeek: true })

	ClassicPlayer { id: classic; width: 316; height: 120; media: host.track; volume: 0.5; mixerAvailable: false }
	CompactPlayer { id: compact; y: 150; width: 276; height: 132; media: host.track; positionMs: 65000; volume: 0.5; mixerAvailable: true }

	SignalSpy { id: playSpy; target: classic; signalName: "togglePlay" }
	SignalSpy { id: prevSpy; target: classic; signalName: "previousTrack" }
	SignalSpy { id: layoutSpy; target: classic; signalName: "switchLayout" }
	SignalSpy { id: seekSpy; target: compact; signalName: "seekTo" }
	SignalSpy { id: mixerSpy; target: compact; signalName: "openMixer" }

	TestCase {
		name: "Players"
		when: windowShown

		function centre(item) { return item.mapToItem(host, item.width / 2, item.height / 2); }
		function click(name, root) {
			const it = findChild(root, name);
			verify(it !== null, name);
			const p = centre(it);
			mouseClick(host, p.x, p.y);
		}

		function test_classicControls() {
			click("playButton", classic);
			compare(playSpy.count, 1);
			click("prevButton", classic);
			tryCompare(prevSpy, "count", 1, 1000);
			click("bigArt", classic);
			compare(layoutSpy.count, 1, "clicking the art switches layout");
		}

		function test_classicHidesMixerButtonWithoutMixer() {
			compare(findChild(classic, "mixerButton").visible, false);
		}

		function test_compactTimes() {
			compare(findChild(compact, "elapsed").text, "1:05");
			compare(findChild(compact, "remaining").text, "-2:15");
		}

		function test_compactSeek() {
			const bar = findChild(compact, "progressBar");
			const p = bar.mapToItem(host, bar.width / 2, bar.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			compare(seekSpy.count, 1);
			fuzzyCompare(seekSpy.signalArguments[0][0], 100000, 3000);
		}

		// Review focus 4.
		function test_noSeekWhenNotSeekable() {
			compact.media = { title: "Live", artist: "", artUrl: "", isPlaying: true, lengthMs: 200000, canSeek: false };
			const before = seekSpy.count;
			const bar = findChild(compact, "progressBar");
			const p = bar.mapToItem(host, bar.width / 2, bar.height / 2);
			mousePress(host, p.x, p.y);
			mouseRelease(host, p.x, p.y);
			compare(seekSpy.count, before);
			compact.media = host.track;
		}

		function test_noProgressWithoutLength() {
			compact.media = { title: "Stream", artist: "", artUrl: "", isPlaying: true, lengthMs: 0, canSeek: false };
			verify(!compact.hasProgress);
			compare(findChild(compact, "progressRow").visible, false);
			compact.media = host.track;
			verify(compact.hasProgress);
		}

		function test_compactSpeakerTogglesVolume() {
			compact.volumeExpanded = false;
			click("speakerButton", compact);
			verify(compact.volumeExpanded);
			click("speakerButton", compact);
			verify(!compact.volumeExpanded);
		}

		function test_compactMixer() {
			click("mixerButton", compact);
			compare(mixerSpy.count, 1);
		}
	}
}
```

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_players.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile()` (`ClassicPlayer is not a type`).

- [ ] **Step 2: Create `shell/modules/notch/ClassicPlayer.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens

// Bloom's classic player (App.tsx compact-premium-layout): large album art
// beside the title, artist, visualizer, controls and volume. Clicking the art
// switches to the compact layout.
Item {
	id: root

	property var media: ({ title: "", artist: "", artUrl: "", isPlaying: false, lengthMs: 0, canSeek: false })
	property real positionMs: 0
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property bool visualizer: true
	property real volume: 0
	property bool muted: false
	property bool mixerAvailable: false
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal setVolume(real v)
	signal openMixer()
	signal switchLayout()

	readonly property var _c: Tokens.music.classic

	Row {
		anchors.verticalCenter: parent.verticalCenter
		spacing: root._c.gap

		PressArea {
			objectName: "bigArt"
			width: root._c.art
			height: root._c.art
			hoverScale: 1.05
			tapScale: 0.95
			onClicked: root.switchLayout()

			RectangularShadow {
				anchors.fill: parent
				offset.y: 4
				blur: 16
				radius: root._c.artRadius
				color: Qt.rgba(0, 0, 0, 0.4)
			}

			AlbumArt {
				anchors.fill: parent
				source: root.media.artUrl
				radius: root._c.artRadius
				noteScale: 32 / root._c.art
				noteColor: Qt.rgba(1, 1, 1, 0.65)
				placeholderTop: Qt.rgba(1, 1, 1, 0.08)
				placeholderBottom: Qt.rgba(1, 1, 1, 0.02)
			}

			Rectangle {
				anchors.fill: parent
				radius: root._c.artRadius
				color: "transparent"
				border.width: 0.5
				border.color: Qt.rgba(1, 1, 1, 0.1)
			}
		}

		Column {
			anchors.verticalCenter: parent.verticalCenter
			width: root.width - root._c.art - root._c.gap
			spacing: root._c.columnGap

			Item {
				width: parent.width
				height: trackInfo.height

				Column {
					id: trackInfo
					width: parent.width - 30 - 12
					spacing: 1

					TitleMarquee {
						width: parent.width
						text: root.media.title
						color: root.textColor
						pixelSize: 14.5
						weight: Font.DemiBold
						letterSpacing: -0.15
					}

					Text {
						width: parent.width
						elide: Text.ElideRight
						text: root.media.artist
						color: root.textMuted
						font.family: Tokens.type.family
						font.pixelSize: 12
					}
				}

				Item {
					anchors.right: parent.right
					y: 4
					width: 30
					height: root._c.vizHeight

					HoverHandler { id: vizHover }

					Visualizer {
						visible: root.visualizer
						playing: root.media.isPlaying
						levels: root.levels
						barHeight: root._c.vizHeight
						color: root.textColor
						opacity: vizHover.hovered && root.mixerAvailable ? 0 : 0.8
						Behavior on opacity { NumberAnimation { duration: 200 } }
					}

					PressArea {
						objectName: "mixerButton"
						visible: root.mixerAvailable
						width: 20
						height: 20
						opacity: vizHover.hovered ? 1 : 0
						Behavior on opacity { NumberAnimation { duration: 200 } }
						onClicked: root.openMixer()

						SvgIcon {
							anchors.centerIn: parent
							name: "sf-headphones"
							size: 20
							color: root.textColor
							opacity: 0.5
						}
					}
				}
			}

			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: root._c.controlsGap

				SkipButton {
					objectName: "prevButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: false
					color: root.textColor
					onActivated: root.previousTrack()
				}

				PlayButton {
					objectName: "playButton"
					anchors.verticalCenter: parent.verticalCenter
					playing: root.media.isPlaying
					box: root._c.playBox
					iconSize: root._c.playIcon
					color: root.textColor
					hoverScale: 1.2
					stiffness: 400
					damping: 25
					onClicked: root.togglePlay()
				}

				SkipButton {
					objectName: "nextButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: true
					color: root.textColor
					onActivated: root.nextTrack()
				}
			}

			VolumeRow {
				width: parent.width
				height: root._c.volumeRow
				volume: root.muted ? 0 : root.volume
				trackHeight: root._c.track
				trackHoverHeight: root._c.track
				color: root.textColor
				onMoved: v => root.setVolume(v)
			}
		}
	}
}
```

- [ ] **Step 3: Create `shell/modules/notch/CompactPlayer.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/media.js" as Fmt

// Bloom's compact player (CompactMediaPlayer.tsx): small art, title and
// visualizer; a progress bar with seek when the track has a length; side
// buttons for the volume row and the audio output; the volume row slides open.
Item {
	id: root

	property var media: ({ title: "", artist: "", artUrl: "", isPlaying: false, lengthMs: 0, canSeek: false })
	property real positionMs: 0
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property bool visualizer: true
	property real volume: 0
	property bool muted: false
	property bool mixerAvailable: false
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.5)
	property bool volumeExpanded: false
	readonly property bool hasProgress: root.media.lengthMs > 0

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal setVolume(real v)
	signal openMixer()
	signal switchLayout()
	signal seekTo(real ms)

	readonly property var _c: Tokens.music.compact
	property bool _seeking: false
	property real _seekMs: 0
	readonly property real _shownMs: Math.min(root._seeking ? root._seekMs : root.positionMs, root.media.lengthMs || Infinity)

	Column {
		x: root._c.padding
		y: root._c.padding
		width: root.width - 2 * root._c.padding

		Row {
			width: parent.width
			height: root._c.art + root._c.infoBelow
			spacing: root._c.infoGap

			PressArea {
				width: root._c.art
				height: root._c.art
				tapScale: 1
				onClicked: root.switchLayout()

				RectangularShadow {
					anchors.fill: parent
					offset.y: 2
					blur: 8
					radius: root._c.artRadius
					color: Qt.rgba(0, 0, 0, 0.3)
				}

				AlbumArt {
					anchors.fill: parent
					source: root.media.artUrl
					radius: root._c.artRadius
					noteScale: 22 / root._c.art
					noteColor: Qt.rgba(1, 1, 1, 0.4)
					placeholderTop: Qt.rgba(1, 1, 1, 0.08)
					placeholderBottom: Qt.rgba(1, 1, 1, 0.08)
				}
			}

			Column {
				width: parent.width - root._c.art - (root.visualizer ? 30 + root._c.infoGap : 0) - root._c.infoGap
				y: (root._c.art - height) / 2
				spacing: 1

				TitleMarquee {
					width: parent.width
					text: root.media.title
					color: root.textColor
					pixelSize: 15
					weight: Font.DemiBold
					letterSpacing: -0.2
					lineHeight: 1.2
				}

				Text {
					width: parent.width
					elide: Text.ElideRight
					text: root.media.artist
					color: root.textMuted
					font.family: Tokens.type.family
					font.pixelSize: 12
					lineHeight: 1.2
				}
			}

			Visualizer {
				visible: root.visualizer
				y: (root._c.art - height) / 2
				opacity: 0.7
				playing: root.media.isPlaying
				levels: root.levels
				barHeight: root._c.vizHeight
				color: root.textColor
			}
		}

		Row {
			objectName: "progressRow"
			visible: root.hasProgress
			width: parent.width
			height: visible ? 16 : 0
			spacing: root._c.progressGap

			Text {
				objectName: "elapsed"
				width: root._c.timeWidth
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignHCenter
				text: Fmt.formatTime(root._shownMs)
				color: root.textMuted
				font.family: Tokens.type.family
				font.pixelSize: root._c.time
				font.weight: Font.Medium
				font.features: { "tnum": 1 }
			}

			Item {
				objectName: "progressBar"
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - 2 * root._c.timeWidth - 2 * root._c.progressGap
				height: 12

				HoverHandler { id: barHover }

				Rectangle {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					height: barHover.hovered ? root._c.barHover : root._c.bar
					radius: 2
					color: Qt.rgba(1, 1, 1, 0.15)

					Rectangle {
						height: parent.height
						radius: 2
						color: root.textColor
						width: root.media.lengthMs > 0 ? parent.width * Math.min(1, root._shownMs / root.media.lengthMs) : 0
					}
				}

				MouseArea {
					anchors.fill: parent
					enabled: root.media.canSeek
					function at(mx) { return Math.max(0, Math.min(1, mx / width)) * root.media.lengthMs; }
					onPressed: mouse => { root._seeking = true; root._seekMs = at(mouse.x); }
					onPositionChanged: mouse => { if (pressed) root._seekMs = at(mouse.x); }
					onReleased: mouse => {
						root._seekMs = at(mouse.x);
						root.seekTo(root._seekMs);
						root._seeking = false;
					}
				}
			}

			Text {
				objectName: "remaining"
				width: root._c.timeWidth
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignHCenter
				text: Fmt.formatRemaining(root._shownMs, root.media.lengthMs)
				color: root.textMuted
				font.family: Tokens.type.family
				font.pixelSize: root._c.time
				font.weight: Font.Medium
				font.features: { "tnum": 1 }
			}
		}

		Item {
			width: parent.width
			height: root._c.controlsAbove + root._c.playBox

			PressArea {
				objectName: "speakerButton"
				x: 0
				y: root._c.controlsAbove + (root._c.playBox - height) / 2
				width: root._c.sideIcon + 2 * root._c.buttonPadding
				height: width
				opacity: hovered ? 0.8 : 0.5
				onClicked: root.volumeExpanded = !root.volumeExpanded

				SvgIcon {
					anchors.centerIn: parent
					name: root.volume === 0 || root.muted ? "sf-speaker.slash.fill" : "sf-speaker.wave.2.fill"
					size: root._c.sideIcon
					color: root.textColor
				}
			}

			Row {
				anchors.horizontalCenter: parent.horizontalCenter
				y: root._c.controlsAbove
				spacing: root._c.mainGap

				SkipButton {
					objectName: "prevButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: false
					iconWidth: root._c.skipIcon
					iconHeight: root._c.skipIcon / 2
					boxWidth: root._c.skipBox
					boxHeight: root._c.skipBox
					padding: root._c.buttonPadding
					hoverScale: 1
					stiffness: 550
					damping: 30
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onActivated: root.previousTrack()
				}

				PlayButton {
					objectName: "playButton"
					playing: root.media.isPlaying
					box: root._c.playBox
					iconSize: root._c.playIcon
					swapScale: 0.7
					swapMs: 120
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onClicked: root.togglePlay()
				}

				SkipButton {
					objectName: "nextButton"
					anchors.verticalCenter: parent.verticalCenter
					forward: true
					iconWidth: root._c.skipIcon
					iconHeight: root._c.skipIcon / 2
					boxWidth: root._c.skipBox
					boxHeight: root._c.skipBox
					padding: root._c.buttonPadding
					hoverScale: 1
					stiffness: 550
					damping: 30
					opacity: hovered ? 1 : 0.8
					color: root.textColor
					onActivated: root.nextTrack()
				}
			}

			PressArea {
				objectName: "mixerButton"
				visible: root.mixerAvailable
				anchors.right: parent.right
				y: root._c.controlsAbove + (root._c.playBox - height) / 2
				width: root._c.sideIcon + 2 * root._c.buttonPadding
				height: width
				opacity: hovered ? 0.8 : 0.5
				onClicked: root.openMixer()

				SvgIcon {
					anchors.centerIn: parent
					name: "sf-headphones"
					size: root._c.sideIcon
					color: root.textColor
				}
			}
		}

		Item {
			width: parent.width
			height: volumeSpring.value
			clip: true
			opacity: volumeOpacity.value

			Spring { id: volumeSpring; stiffness: 500; damping: 30; initial: 0; target: root.volumeExpanded ? root._c.volumeHeight : 0 }
			Spring { id: volumeOpacity; stiffness: 500; damping: 30; initial: 0; target: root.volumeExpanded ? 1 : 0 }

			VolumeRow {
				y: 6
				width: parent.width
				volume: root.muted ? 0 : root.volume
				trackHeight: root._c.volumeTrack
				trackHoverHeight: root._c.volumeTrackHover
				color: root.textColor
				onMoved: v => root.setVolume(v)
			}
		}
	}
}
```

- [ ] **Step 4: Create `shell/modules/notch/Ambience.qml`**

```qml
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens

// Bloom's ambient glow behind the open player: the album art, enlarged and
// heavily blurred, under a radial vignette that fades into the notch colour,
// clipped to the pill's rounded bottom.
Item {
	id: root

	property url source: ""
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property real radius: 18
	readonly property bool shown: art.status === Image.Ready

	opacity: root.shown ? 1 : 0
	Behavior on opacity { NumberAnimation { duration: Tokens.music.ambience.fadeMs } }
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: clip
	}

	Image {
		id: art
		anchors.centerIn: parent
		width: parent.width * Tokens.music.ambience.scale
		height: parent.height * Tokens.music.ambience.scale
		source: root.source
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		sourceSize: Qt.size(128, 128)
		visible: false
	}

	MultiEffect {
		anchors.fill: art
		source: art
		blurEnabled: true
		blurMax: 64
		blur: Tokens.music.ambience.blur / 64
		saturation: 1
		contrast: 0.1
		brightness: 0.4
		opacity: Tokens.music.ambience.opacity
	}

	// Ellipse vignette: a circle stretched to the pill.
	Shape {
		width: root.width
		height: root.width
		y: (root.height - root.width) / 2
		transform: Scale { origin.x: root.width / 2; origin.y: root.width / 2; yScale: root.height / Math.max(1, root.width) }
		ShapePath {
			strokeWidth: -1
			fillGradient: RadialGradient {
				centerX: root.width / 2; centerY: root.width / 2; centerRadius: root.width / 2
				focalX: centerX; focalY: centerY
				GradientStop { position: 0.2; color: "transparent" }
				GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.25) }
				GradientStop { position: 0.85; color: root.bg }
				GradientStop { position: 1; color: root.bg }
			}
			PathRectangle { x: 0; y: 0; width: root.width; height: root.width }
		}
	}

	Item {
		id: clip
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle {
			anchors.fill: parent
			bottomLeftRadius: root.radius
			bottomRightRadius: root.radius
		}
	}
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_players.qml 2>&1 | grep -E "^FAIL|Totals|Actual|Expected"`
Expected: `Totals: 10 passed, 0 failed`. A failure is a defect: debug it with superpowers:systematic-debugging, and do not loosen the test.

- [ ] **Step 6: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/modules/notch/ClassicPlayer.qml shell/modules/notch/CompactPlayer.qml shell/modules/notch/Ambience.qml tests/qml/tst_players.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add Bloom's classic and compact music players

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Music mode in the notch

**Files:**
- Modify: `shell/modules/notch/NotchView.qml`, `tests/qml/tst_notchview.qml`

**Interfaces:**
- Consumes: `music.js` (Task 3), the Task 5 and 6 components.
- Produces, on `NotchView`:
  - **Inputs:**
    - music settings: `musicEnabled`, `compactNotch`, `visualizerEnabled`, `albumArtEnabled`, `ambienceEnabled`, `glowEnabled`, `layout`;
    - player data: `media` (`{hasMedia, isPlaying, title, artist, artUrl, lengthMs, canSeek}`), `positionMs`, `levels`, `volume`, `muted`, `mixerAvailable`.
  - **State:** `open` (read/write), `musicActivityVisible`, readonly `bloomMode` (`"status"`|`"music"`), readonly `collapsedMode`, readonly `onStatusHover`, `volumeExpanded`.
  - **Signals:**
    - playback: `togglePlay()`, `previousTrack()`, `nextTrack()`, `seekTo(real ms)`;
    - volume and output: `setVolume(real v)`, `openMixer()`;
    - layout: `layoutChosen(string layout)`;
    - polling: `musicWatched(bool watched)` (position polling and cava are wanted).
  - **Methods:** `openMusic()`; `stateObject()` gains `bloomMode` and `open`.

- [ ] **Step 1: Add the failing music tests to `tests/qml/tst_notchview.qml`**

Add these signal spies as children of the host `Item`, next to `viewComponent`:

```qml
	Component {
		id: spyComponent
		SignalSpy {}
	}
```

Add these helpers and tests inside the `TestCase` (keep the existing ones):

```qml
		function playing(title) {
			return { hasMedia: true, isPlaying: true, title: title || "Song", artist: "Artist", artUrl: "", lengthMs: 200000, canSeek: true };
		}

		function spy(target, signalName) {
			return createTemporaryObject(spyComponent, host, { target: target, signalName: signalName });
		}

		function clickArt(v) {
			const art = findChild(v, "musicArt");
			verify(art !== null, "collapsed art");
			const p = art.mapToItem(v, art.width / 2, art.height / 2);
			mouseClick(v, p.x, p.y);
		}

		function test_musicTakesTheCollapsedPill() {
			const v = make({ media: playing() });
			settle(v);
			compare(v.bloomMode, "music");
			compare(v.target.width, 200, "140 + visualizer 30 + art 30");
		}

		// Review focus 3.
		function test_noVisualizerWithoutCava() {
			const v = make({ media: playing(), visualizerEnabled: false });
			settle(v);
			compare(v.target.width, 170);
			compare(findChild(v, "collapsedVisualizer").visible, false);
		}

		function test_pausedMusicLingersThenFades() {
			const v = make({ media: playing() });
			settle(v);
			const paused = playing();
			paused.isPlaying = false;
			v.media = paused;
			compare(v.bloomMode, "music");
			compare(v.target.width, 170, "no visualizer width while paused");
			tryCompare(v, "bloomMode", "status", 6500);
			compare(v.target.width, 140);
		}

		function test_fadedSessionShowsOnHover() {
			const v = make({ media: playing() });
			settle(v);
			const paused = playing();
			paused.isPlaying = false;
			v.media = paused;
			tryCompare(v, "bloomMode", "status", 6500);
			mouseMove(v, 500, 18);
			tryCompare(v, "onStatusHover", true, 500);
			compare(v.target.width, 200, "170 + visualizer");
		}

		function test_artOpensAndLeavingClosesThePlayer() {
			const v = make({ media: playing() });
			settle(v);
			mouseMove(v, 500, 18);
			clickArt(v);
			verify(v.open);
			compare(v.target.width, 340);
			compare(v.target.height, 120);
			mouseMove(v, 500, 400);
			tryCompare(v, "open", false, 500);
			compare(v.target.width, 200);
		}

		function test_compactHeights() {
			const v = make({ media: playing(), layout: "compact" });
			settle(v);
			v.openMusic();
			compare(v.target.width, 300);
			compare(v.target.height, 132);
			v.volumeExpanded = true;
			compare(v.target.height, 168);
			const live = playing();
			live.lengthMs = 0;
			v.media = live;
			v.volumeExpanded = false;
			compare(v.target.height, 116);
		}

		function test_rightClickArtGoesBack() {
			const v = make({ media: playing() });
			const s = spy(v, "previousTrack");
			settle(v);
			const art = findChild(v, "musicArt");
			const p = art.mapToItem(v, art.width / 2, art.height / 2);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			compare(s.count, 1);
			verify(!v.open);
		}

		function test_trackChangePeeksInPeekMode() {
			const v = make({ mode: "peek", media: playing("One") });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.media = playing("Two");
			verify(!v.hidden, "a new track shows the notch");
			tryCompare(v, "hidden", true, 4000);
		}

		function test_musicOffFallsBackToStatus() {
			const v = make({ media: playing() });
			settle(v);
			v.openMusic();
			v.musicEnabled = false;
			verify(!v.open);
			compare(v.bloomMode, "status");
			compare(v.target.width, 140);
		}

		// Review focus 2.
		function test_playerVanishingClosesThePanel() {
			const v = make({ media: playing() });
			settle(v);
			v.openMusic();
			v.media = { hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false };
			verify(!v.open);
			compare(v.bloomMode, "status");
		}

		function test_layoutChoiceAndWatching() {
			const v = make({ media: playing() });
			const layouts = spy(v, "layoutChosen");
			const watched = spy(v, "musicWatched");
			settle(v);
			mouseMove(v, 500, 18);
			clickArt(v);
			verify(watched.count >= 1);
			compare(watched.signalArguments[watched.count - 1][0], true);
			const big = findChild(v, "bigArt");
			const p = big.mapToItem(v, big.width / 2, big.height / 2);
			mouseClick(v, p.x, p.y);
			compare(layouts.count, 1);
			compare(layouts.signalArguments[0][0], "compact");
		}
```

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchview.qml 2>&1 | grep -E "^FAIL|Totals" | head -12`
Expected: the 10 new tests FAIL (`Cannot assign to non-existent property "media"` or similar). The existing 16 still pass.

- [ ] **Step 2: Add the music state to `NotchView.qml`**

Add the import below the existing ones:

```qml
import "music.js" as Music
```

Add these declarations after `property var stats: …`:

```qml
	// Music (Bloom music mode), fed by NotchWindow.
	property bool musicEnabled: true
	property bool compactNotch: true
	property bool visualizerEnabled: true
	property bool albumArtEnabled: true
	property bool ambienceEnabled: true
	property bool glowEnabled: true
	property string layout: "classic"
	property var media: ({ hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false })
	property real positionMs: 0
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property real volume: 0
	property bool muted: false
	property bool mixerAvailable: false

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal seekTo(real ms)
	signal setVolume(real v)
	signal openMixer()
	signal layoutChosen(string layout)
	signal musicWatched(bool watched)

	property bool open: false
	property bool musicActivityVisible: false
	property bool volumeExpanded: false
	readonly property string collapsedMode: Music.collapsedMode({
		enabled: root.musicEnabled, compactNotch: root.compactNotch,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible
	})
	readonly property string bloomMode: root.open ? "music" : root.collapsedMode
	readonly property bool onStatusHover: Music.musicOnStatusHover({
		open: root.open, hovered: root.statusHover, mode: root.bloomMode, enabled: root.musicEnabled,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible, compactNotch: root.compactNotch
	})
	// Bloom showCompactMusicIcons: the collapsed row shows music, not widgets.
	readonly property bool _musicIcons: (root.bloomMode === "music" && !root.open) || root.onStatusHover
```

Replace the `target` property with:

```qml
	readonly property var target: Logic.geometry(
		{ ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded, impacted: root.impacted },
		{
			width: Music.contentWidth({
				open: root.open, mode: root.bloomMode, hovered: root.statusHover, onStatusHover: root.onStatusHover,
				layout: root.layout, visualizer: root.visualizerEnabled, playing: root.media.isPlaying,
				albumArt: root.albumArtEnabled, widgetCount: root.widgetCount, fitWidth: root.fitWidth, use24h: root.use24h
			}),
			height: Music.contentHeight({
				open: root.open, mode: root.bloomMode, layout: root.layout,
				hasProgress: root.media.lengthMs > 0, volumeExpanded: root.volumeExpanded
			})
		})
```

Add this behaviour block after `function peek(ms) { … }`:

```qml
	function openMusic() {
		if (root.musicEnabled && root.media.hasMedia)
			root.open = true;
	}

	// Bloom: a session shows as the live activity, and a paused one lingers
	// 5 s before handing the pill back to the clock.
	property bool _hadMedia: false
	property bool _wasPlaying: false
	property string _lastTitle: ""

	function _updateActivity() {
		if (!(root.musicEnabled && root.media.hasMedia)) {
			activityTimer.stop();
			root.musicActivityVisible = false;
			return;
		}
		root.musicActivityVisible = true;
		if (root.media.isPlaying)
			activityTimer.stop();
		else
			activityTimer.restart();
	}

	onMediaChanged: {
		if (root.media.hasMedia !== root._hadMedia || root.media.isPlaying !== root._wasPlaying)
			root._updateActivity();
		if (root.mode === "peek" && Music.shouldPeek({ title: root._lastTitle, playing: root._wasPlaying }, { title: root.media.title, playing: root.media.isPlaying }))
			root.peek(Tokens.music.peekMs);
		root._hadMedia = root.media.hasMedia;
		root._wasPlaying = root.media.isPlaying;
		root._lastTitle = root.media.title;
	}
	onMusicEnabledChanged: root._updateActivity()
	Component.onCompleted: root._updateActivity()

	// Leave the player when music is turned off or the player goes away.
	readonly property bool _musicAvailable: root.musicEnabled && root.media.hasMedia
	on_MusicAvailableChanged: if (!root._musicAvailable) root.open = false

	onOpenChanged: if (!root.open) root.volumeExpanded = false

	readonly property bool _watching: root.open || (root._musicIcons && root.visualizerEnabled && root.media.isPlaying)
	property bool _watchHeld: false
	on_WatchingChanged: {
		root._watchHeld = root._watching;
		root.musicWatched(root._watching);
	}

	Timer {
		id: activityTimer
		interval: Tokens.music.activityLingerMs
		onTriggered: root.musicActivityVisible = false
	}
```

Extend the existing `Component.onDestruction` so it also releases the music hold:

```qml
	Component.onDestruction: {
		if (root._statsHeld)
			root.statsWanted(false);
		if (root._watchHeld)
			root.musicWatched(false);
	}
```

(Remove the old single-line `Component.onDestruction`. Merge the new `Component.onCompleted: root._updateActivity()` with any existing `Component.onCompleted` in the file.)

In `onPillHoveredChanged`, add the close on leave (Bloom `releaseNotchHover`):

```qml
	onPillHoveredChanged: {
		if (root.pillHovered) {
			handoff.stop();
			root.edgeArmed = false;
		} else {
			root.open = false;
		}
	}
```

In `stateObject()`, add `bloomMode: root.bloomMode, open: root.open` to the returned object.

- [ ] **Step 3: Draw music in the pill**

1. In the `EdgeSurface`, darken the background while open as well as while hovered:

```qml
				color: root.statusHover || root.open ? root.bgExpanded : root.bg
```

2. Inside `pillArea`, before `mainRow`, add the ambience (it sits under the content):

```qml
			Ambience {
				anchors.fill: parent
				visible: root.open && root.ambienceEnabled && root.media.artUrl !== ""
				source: visible ? root.media.artUrl : ""
				bg: root.bgExpanded
				radius: Tokens.sizes.farRadius
			}
```

3. Make `mainRow` fade out while open by changing its opacity to:

```qml
				opacity: root.expanded && !root.hidden && !root.open ? 1 : 0
```

4. In `leftGroup` and `rightGroup`, hide the widgets while music icons show. `leftGroup`'s opacity becomes:

```qml
					opacity: root.statusHover && !root._musicIcons ? 1 : 0
```

(`rightGroup` already copies `leftGroup.opacity`.)

5. Inside `mainRow`, after `rightGroup`, add the collapsed visualizer and art:

```qml
				Visualizer {
					objectName: "collapsedVisualizer"
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					visible: root._musicIcons && root.visualizerEnabled
					playing: root.media.isPlaying
					levels: root.levels
					color: root.textColor
					opacity: visible ? 1 : 0
					Behavior on opacity {
						NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
					}
				}

				Item {
					id: artSlot
					objectName: "musicArt"
					readonly property bool shown: root._musicIcons && (root.albumArtEnabled || root.onStatusHover)
					readonly property real side: root.media.isPlaying ? Tokens.music.collapsedArt.size : Tokens.music.collapsedArt.pausedSize
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					width: side
					height: side
					visible: opacity > 0
					opacity: shown ? 1 : 0
					scale: shown ? 1 : 0.8
					Behavior on width { NumberAnimation { duration: Tokens.music.collapsedArt.sizeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
					Behavior on height { NumberAnimation { duration: Tokens.music.collapsedArt.sizeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
					Behavior on opacity { NumberAnimation { duration: Tokens.music.collapsedArt.appearMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }
					Behavior on scale { NumberAnimation { duration: Tokens.music.collapsedArt.appearMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }

					HoverHandler { id: artHover }

					// Bloom's glow: the art itself, blurred and saturated, behind the button.
					Image {
						id: glowSource
						readonly property real inset: artHover.hovered ? Tokens.music.collapsedArt.glowHoverInset : Tokens.music.collapsedArt.glowInset
						x: -inset
						y: -inset
						width: artSlot.width + 2 * inset
						height: artSlot.height + 2 * inset
						source: root.glowEnabled && root.albumArtEnabled ? root.media.artUrl : ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						visible: false
					}

					MultiEffect {
						anchors.fill: glowSource
						source: glowSource
						visible: glowSource.status === Image.Ready
						blurEnabled: true
						blurMax: 16
						blur: (artHover.hovered ? 8 : 6) / 16
						saturation: 1
						brightness: artHover.hovered ? -0.1 : -0.2
						opacity: artHover.hovered ? 0.7 : 0.6
						Behavior on opacity { NumberAnimation { duration: 400 } }
					}

					Rectangle {
						anchors.fill: parent
						radius: Tokens.music.collapsedArt.radius
						color: Qt.rgba(1, 1, 1, artHover.hovered ? 0.25 : 0.15)
					}

					AlbumArt {
						anchors.fill: parent
						source: root.albumArtEnabled ? root.media.artUrl : ""
						radius: Tokens.music.collapsedArt.radius
						flipMs: Tokens.music.collapsedArt.flipMs
					}

					TapHandler {
						acceptedButtons: Qt.LeftButton
						onTapped: root.openMusic()
					}

					TapHandler {
						acceptedButtons: Qt.RightButton
						onTapped: root.previousTrack()
					}
				}
```

and add `import QtQuick.Effects` at the top of the file.

6. Inside `pillArea`, after `mainRow`, add the open player:

```qml
			Loader {
				x: Tokens.sizes.padding
				width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
				height: parent.height
				active: root.open
				opacity: root.open ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: 100 } }
				sourceComponent: root.layout === "compact" ? compactComponent : classicComponent
			}
```

7. At the end of the root `Item`, next to `widgetDelegate`, add the two components:

```qml
	Component {
		id: classicComponent
		ClassicPlayer {
			media: root.media
			positionMs: root.positionMs
			levels: root.levels
			visualizer: root.visualizerEnabled
			volume: root.volume
			muted: root.muted
			mixerAvailable: root.mixerAvailable
			textColor: root.textColor
			textMuted: root.textMuted
			onTogglePlay: root.togglePlay()
			onPreviousTrack: root.previousTrack()
			onNextTrack: root.nextTrack()
			onSetVolume: v => root.setVolume(v)
			onOpenMixer: root.openMixer()
			onSwitchLayout: root.layoutChosen("compact")
		}
	}

	Component {
		id: compactComponent
		CompactPlayer {
			media: root.media
			positionMs: root.positionMs
			levels: root.levels
			visualizer: root.visualizerEnabled
			volume: root.volume
			muted: root.muted
			mixerAvailable: root.mixerAvailable
			textColor: root.textColor
			textMuted: root.textMuted
			volumeExpanded: root.volumeExpanded
			onVolumeExpandedChanged: root.volumeExpanded = volumeExpanded
			onTogglePlay: root.togglePlay()
			onPreviousTrack: root.previousTrack()
			onNextTrack: root.nextTrack()
			onSeekTo: ms => root.seekTo(ms)
			onSetVolume: v => root.setVolume(v)
			onOpenMixer: root.openMixer()
			onSwitchLayout: root.layoutChosen("classic")
		}
	}
```

- [ ] **Step 4: Run the notch tests to verify they pass**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchview.qml 2>&1 | grep -E "^FAIL|Totals|Actual|Expected" | head -20`
Expected: `Totals: 28 passed, 0 failed` (26 tests + init/cleanup). Any failure is a defect: debug it with superpowers:systematic-debugging. If the compact player's `volumeExpanded` binding loops (`onVolumeExpandedChanged` writing back), bind one way into CompactPlayer and handle the speaker button through a signal instead. Record that as a ruling.

- [ ] **Step 5: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/modules/notch/NotchView.qml tests/qml/tst_notchview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: show music in the notch with Bloom's players

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Wiring, IPC and the end-to-end music test

**Files:**
- Create: `shell/modules/notch/MusicData.qml`, `shell/modules/notch/AudioData.qml`, `tests/integration/test_notch_music.sh`
- Modify: `shell/modules/notch/NotchWindow.qml`, `shell/shell.qml`, `tests/integration/test_notch.sh`

**Interfaces:**
- Consumes: `Media`, `Audio`, `Cava` (Task 4) and `NotchView` music API (Task 7).
- Produces:
  - `MusicData` exposes `media`, `positionMs`, `levels`, `visualizerAvailable`, `hold(key, on, visualizer)` and the controls.
  - `AudioData` exposes `volume`, `muted`, `mixerAvailable`, `setVolume(v)`, `openMixer()`.
  - New IPC: `notch openMusic() → "ok"`.

- [ ] **Step 1: Keep the existing notch test hermetic**

In `tests/integration/test_notch.sh`, change the settings line to turn music off, so that test never touches MPRIS, PipeWire or cava:

```bash
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false, "bloom-music-mode-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
```

- [ ] **Step 2: Write the failing end-to-end test `tests/integration/test_notch_music.sh`**

```bash
#!/usr/bin/env bash
# The notch follows a (fake) MPRIS player on headless sway: music takes the
# collapsed pill, openMusic opens Bloom's player, and the player going away
# hands the pill back to the clock.
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	exec dbus-run-session -- env BLOOM_IN_DBUS=1 bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
start_sway

python3 "$ROOT/tests/integration/fake_mpris.py" player --playing --title "End To End" >"$TEST_TMP/player.log" 2>&1 &
PLAYER_PID=$!
trap 'kill $PLAYER_PID 2>/dev/null || true; bloom_cleanup' EXIT
wait_for "the fake player" grep -q READY "$TEST_TMP/player.log"

mkdir -p "$XDG_CONFIG_HOME/bloom"
# No cava in tests: the visualizer is off, so the pill is 140 + 30 (art).
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false, "bloom-media-visualizer-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state_is() { [[ "$(ipc notch state | jq -c ".[0] | {$1}")" == "$2" ]]; }

wait_for "music to take the pill" state_is "bloomMode,width" '{"bloomMode":"music","width":170}'
pass "a playing player takes the collapsed pill"

assert_eq "$(ipc notch openMusic)" "ok" "openMusic"
wait_for "the classic player" state_is "open,width,height" '{"open":true,"width":340,"height":120}'
pass "openMusic opens the classic player"

kill "$PLAYER_PID"
wait_for "the pill to fall back to the clock" state_is "bloomMode,open,width" '{"bloomMode":"status","open":false,"width":140}'
pass "the player going away closes the panel and returns the clock"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
# Without a system bus (CI) UPower warns; without a session PipeWire, PipeWire does.
problems="$(grep -viE 'upower|powerprofiles|dbus|pipewire' <<<"$problems" || true)"
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no unexpected warnings"
```

Run: `chmod +x tests/integration/test_notch_music.sh && bash tests/integration/test_notch_music.sh`
Expected: FAIL at `music to take the pill`, because NotchWindow doesn't feed media yet.

- [ ] **Step 3: Create `shell/modules/notch/MusicData.qml`**

```qml
import QtQuick
import qs.services

// The notch's view of the music services. NotchWindow loads it only while
// music mode is on, so a shell without music never connects to MPRIS or runs cava.
Item {
	readonly property var media: ({
		hasMedia: Media.hasMedia, isPlaying: Media.isPlaying, title: Media.title, artist: Media.artist,
		artUrl: Media.artUrl, lengthMs: Media.lengthMs, canSeek: Media.canSeek
	})
	readonly property real positionMs: Media.positionMs
	readonly property var levels: Cava.levels
	readonly property bool visualizerAvailable: Cava.available

	// cava only runs when the visualizer is actually drawn.
	function hold(key, on, visualizer) {
		Media.hold(key, on);
		Cava.hold(key, on && visualizer);
	}

	function togglePlay() { Media.togglePlaying(); }
	function previousTrack() { Media.previous(); }
	function nextTrack() { Media.next(); }
	function seekTo(ms) { Media.seek(ms); }
}
```

- [ ] **Step 4: Create `shell/modules/notch/AudioData.qml`**

```qml
import QtQuick
import qs.services

// Volume and mixer for the open player. Loaded only while the player is open,
// so the collapsed notch never connects to PipeWire.
Item {
	readonly property real volume: Audio.volume
	readonly property bool muted: Audio.muted
	readonly property bool mixerAvailable: Audio.mixer !== ""

	function setVolume(v) { Audio.setVolume(v); }
	function openMixer() { Audio.openMixer(); }
}
```

- [ ] **Step 5: Wire NotchWindow**

In `shell/modules/notch/NotchWindow.qml`:

1. Add these loaders as children of the `PanelWindow`, before the `NotchView`:

```qml
	readonly property bool _musicOn: Settings.values["bloom-music-mode-enabled"]

	Loader {
		id: music
		active: win._musicOn
		source: "MusicData.qml"
	}

	Loader {
		id: audio
		active: view.open
		source: "AudioData.qml"
	}
```

2. Add these bindings and handlers inside `NotchView { id: view … }`:

```qml
		musicEnabled: win._musicOn
		compactNotch: Settings.values["bloom-music-compact-notch"]
		visualizerEnabled: Settings.values["bloom-media-visualizer-enabled"] && (music.item?.visualizerAvailable ?? false)
		albumArtEnabled: Settings.values["bloom-media-album-art-enabled"]
		ambienceEnabled: Settings.values["bloom-media-ambience-enabled"]
		glowEnabled: Settings.values["bloom-media-compact-glow-enabled"]
		layout: Settings.values["bloom-media-layout"]
		media: music.item?.media ?? ({ hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false })
		positionMs: music.item?.positionMs ?? 0
		levels: music.item?.levels ?? [0.18, 0.18, 0.18, 0.18, 0.18]
		volume: audio.item?.volume ?? 0
		muted: audio.item?.muted ?? false
		mixerAvailable: audio.item?.mixerAvailable ?? false
		onTogglePlay: music.item?.togglePlay()
		onPreviousTrack: music.item?.previousTrack()
		onNextTrack: music.item?.nextTrack()
		onSeekTo: ms => music.item?.seekTo(ms)
		onSetVolume: v => audio.item?.setVolume(v)
		onOpenMixer: audio.item?.openMixer()
		onLayoutChosen: layout => Settings.set("bloom-media-layout", layout)
		onMusicWatched: watched => music.item?.hold(win._key, watched, view.visualizerEnabled)
```

3. In `Component.onDestruction`, add `music.item?.hold(win._key, false, false);`.

- [ ] **Step 6: Add the `openMusic` IPC function**

In `shell/shell.qml`, inside `IpcHandler { target: "notch" … }`, add:

```qml
		// Opens Bloom's music player on every screen that has media (as a click on the art).
		function openMusic(): string {
			_windows().forEach(w => w.view.openMusic());
			return "ok";
		}
```

- [ ] **Step 7: Run the end-to-end test to verify it passes**

Run: `bash tests/integration/test_notch_music.sh`
Expected: 4 `ok - …` lines.

Run: `bash tests/integration/test_notch.sh`
Expected: still passes.

- [ ] **Step 8: Run the suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -3` (expected: `all checks passed`).

```bash
git add shell/modules/notch/MusicData.qml shell/modules/notch/AudioData.qml shell/modules/notch/NotchWindow.qml shell/shell.qml tests/integration/test_notch.sh tests/integration/test_notch_music.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: wire music services into the notch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Owner verification on the real session

This task changes the owner's session: it enables the notch module and starts the shell. **Ask the owner before Step 1.** ii keeps running.

**Files:** none.

- [ ] **Step 1: Owner approves; enable the notch and play something**

Run:
```bash
systemctl --user start bloom-shell
~/Projects/bloom-dots/bin/bloom ipc settings set bloom-enabled-modules '["notch"]'
```
Then start music in Spotify, a browser or any MPRIS player.

- [ ] **Step 2: Walk the owner through the parity checklist and record their answers**

1. **Collapsed:** the pill widens to 200 px with five dancing bars on the left and the album art on the right, with its glow. The art shrinks to 20 px when you pause.
2. **Pause:** about 5 s after pausing, the pill returns to the clock. Hovering it shows the music icons again (200 px).
3. **Classic player:** click the art.
   - It springs open to 340×120 with the large art, the title (scrolling if long), artist, visualizer, prev/play/next and volume.
   - The ambient glow sits behind it.
   - Prev/next do Bloom's slide-push and change the track.
   - Play/pause swaps its icon.
   - The volume slider changes the system volume.
   - Hovering the small visualizer shows the headphones button, which opens `pavucontrol-qt`.
4. **Compact player:** click the large art to switch.
   - It changes to 300×132 with the progress bar and times.
   - Dragging the bar seeks.
   - The speaker button opens the volume row (+36 px).
   - Clicking the art switches back.
5. **Track change in peek mode:**
   - Run `bloom ipc settings set bloom-notch-mode peek`.
   - Skip a track from the player app: the notch shows for 3 s.
   - Then restore with `bloom ipc settings set bloom-notch-mode fixed`.
6. **Right-click** on the collapsed art goes to the previous track.
7. **Fullscreen:** play a video fullscreen. The notch goes behind it. This also verifies the 2A fix.

- [ ] **Step 3: Check cost and logs**

Run:
```bash
pid=$(systemctl --user show -p MainPID --value bloom-shell)
a=$(awk '{print $14+$15}' /proc/$pid/stat); sleep 10; b=$(awk '{print $14+$15}' /proc/$pid/stat); echo "playing, collapsed: $((b-a)) ticks/10s"
journalctl --user -u bloom-shell --since "-10min" --no-pager | grep -E " (WARN|ERROR)" | head
```
Expected: no warnings. The ticks figure is reported to the owner; while music plays the visualizer runs, so it is above the 2A idle figure.

- [ ] **Step 4: Report to the owner** the checklist answers, the CPU figure and any log lines. Leave the notch enabled or disabled as they choose; disable with `bloom ipc settings set bloom-enabled-modules '[]'`.
