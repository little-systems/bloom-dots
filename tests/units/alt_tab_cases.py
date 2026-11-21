#!/usr/bin/env python3
"""Alt + Tab: hypr/alt-tab.lua switches windows on the current workspace,
most recent first. Tiled windows take focus as Tab steps, with no card;
floating ones get the shell's card and come to the front when Alt is let go.
Runs it in plain Lua with a stand-in hl that records dispatches, binds, timers
and shell messages."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local windows, active, ws = {}, nil, { id = 1 }
local log = {}
local alt_down = false
local function add(address, history, workspace, floating)
 local w = { address = address, focus_history_id = history, workspace = { id = workspace or 1 }, floating = floating or false, mapped = true, hidden = false }
 windows[#windows + 1] = w
 return w
end
local binds, timers = {}, {}
hl = {
 get_windows = function() local copy = {} for i, w in ipairs(windows) do copy[i] = w end return copy end,
 get_active_workspace = function() return ws end,
 get_active_window = function() return active end,
 is_key_down = function(key) return alt_down and (key == "Alt_L" or key == "Alt_R") end,
 timer = function(fn, opts)
  local t = { fn = fn, opts = opts, enabled = true }
  timers[#timers + 1] = t
  log[#log + 1] = "timer " .. opts.timeout .. " " .. opts.type
  function t:set_enabled(on) t.enabled = on; log[#log + 1] = "timer " .. (on and "on" or "off") end
  return t
 end,
 dsp = {
  focus = function(args) return { name = "focus", window = args.window } end,
  window = {
   bring_to_top = function() return { name = "top" } end
  }
 },
 dispatch = function(d)
  if d.name == "focus" then active = d.window; log[#log + 1] = "focus " .. d.window.address
  else log[#log + 1] = d.name end
 end,
 bind = function(keys, fn, opts)
  local b = { keys = keys, fn = fn, opts = opts }
  binds[keys] = b
  log[#log + 1] = "bind " .. keys
  function b:unbind() binds[keys] = nil; log[#log + 1] = "unbind " .. keys end
  return b
 end
}
local function tick() for _, t in ipairs(timers) do if t.enabled then t.fn() end end end
local M = dofile(arg[1])
local mode = M.new(hl, function(message) log[#log + 1] = "shell " .. message end)
local function setup(floating)
 local a = add("0xa", 0, 1, floating); local b = add("0xb", 2, 1, floating); local c = add("0xc", 1, 1, floating); add("0xother", 3, 2)
 active = a
 return a, b, c
end
local steps = {}
function steps.tiled_tap() setup(); mode.step(1); mode.commit() end
function steps.tiled_hold() setup(); mode.step(1); mode.step(1); mode.step(1); mode.commit() end
function steps.tiled_back() setup(); mode.step(-1); mode.commit() end
function steps.tiled_cancel() setup(); mode.step(1); mode.step(1); binds["Escape"].fn(); mode.commit() end
function steps.mixed() local a = add("0xa", 0); add("0xf", 1, 1, true); active = a; mode.step(1); mode.commit() end
function steps.floating_tap() setup(true); mode.step(1); mode.commit() end
function steps.floating_hold() setup(true); mode.step(1); mode.step(1); mode.step(1); mode.commit() end
function steps.floating_back() setup(true); mode.step(-1); mode.commit() end
function steps.floating_cancel() setup(true); mode.step(1); binds["Escape"].fn(); mode.commit() end
function steps.clicked()
 local a, b = setup(true)
 mode.step(1)
 active = b -- the shell focused a clicked tile
 mode.commit()
end
function steps.alt_watched()
 setup(true); alt_down = true
 mode.step(1); tick()
 log[#log + 1] = "-- let go"
 alt_down = false; tick(); tick()
 mode.commit() -- the release bind fires late
end
function steps.alt_watched_again()
 setup(); alt_down = true
 mode.step(1); alt_down = false; tick()
 alt_down = true; mode.step(1); alt_down = false; tick()
end
local swipe = mode.gesture
local function moved(x) swipe.update({ phase = "update", delta = { x = x, y = 0 } }) end
local function hold() for _ = 1, 5 do tick() end end
function steps.flick() setup(); swipe.start({ delta = { x = -40, y = 0 } }); moved(-60); swipe.finish({ cancelled = false }) end
function steps.flick_right() setup(true); swipe.start({ delta = { x = 40, y = 0 } }); swipe.finish({ cancelled = false }) end
function steps.held()
 setup(); swipe.start({ delta = { x = -40, y = 0 } })
 for _ = 1, 4 do tick() end
 log[#log + 1] = "-- 80 ms"
 tick()
 moved(-100); moved(-60) -- one step left
 moved(170) -- one step back right
 moved(160) -- and one more, wrapping
 swipe.finish({ cancelled = false })
end
function steps.held_still() setup(true); swipe.start({ delta = { x = -40, y = 0 } }); hold(); hold(); swipe.finish({ cancelled = false }) end
function steps.flick_steps() setup(); swipe.start({ delta = { x = -40, y = 0 } }); moved(-160); swipe.finish({ cancelled = false }) end
function steps.cancelled() setup(); swipe.start({ delta = { x = -40, y = 0 } }); hold(); swipe.finish({ cancelled = true }) end
function steps.swipe_escape() setup(); swipe.start({ delta = { x = -40, y = 0 } }); hold(); binds["Escape"].fn(); moved(-200); swipe.finish({ cancelled = false }) end
function steps.swipe_alone() local a = add("0xa", 0); active = a; swipe.start({ delta = { x = -40, y = 0 } }); hold(); moved(-300); swipe.finish({ cancelled = false }) end
function steps.swipe_during_alt_tab() setup(true); mode.step(1); swipe.start({ delta = { x = -40, y = 0 } }); moved(-200); swipe.finish({ cancelled = false }); mode.commit() end
function steps.alone() local a = add("0xa", 0); active = a; mode.step(1); mode.commit() end
function steps.release_without_cycle() setup(); mode.commit() end
steps[arg[2]]()
print(table.concat(log, "|"))
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run alt-tab.lua")
class AltTab(unittest.TestCase):
    def run_step(self, step):
        run = subprocess.run(["lua", "-", str(ROOT / "hypr/alt-tab.lua"), step], input=HARNESS,
                             text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        return run.stdout.strip().split("|")

    def test_tiled_windows_take_focus_as_tab_steps_without_a_card(self):
        self.assertEqual(self.run_step("tiled_tap"), ["bind Escape", "focus 0xc", "unbind Escape"])

    def test_tiled_holding_alt_steps_further_and_wraps(self):
        self.assertEqual(self.run_step("tiled_hold"), [
            "bind Escape", "focus 0xc", "focus 0xb", "focus 0xa", "unbind Escape"])

    def test_tiled_shift_goes_backwards(self):
        self.assertEqual(self.run_step("tiled_back"), ["bind Escape", "focus 0xb", "unbind Escape"])

    def test_tiled_escape_goes_back_to_where_it_started(self):
        self.assertEqual(self.run_step("tiled_cancel"), [
            "bind Escape", "focus 0xc", "focus 0xb", "unbind Escape", "focus 0xa"])

    def test_a_workspace_with_tiled_windows_gets_no_card(self):
        self.assertEqual(self.run_step("mixed"), ["bind Escape", "focus 0xf", "top", "unbind Escape"])

    def test_floating_windows_get_the_card_and_come_to_the_front_on_release(self):
        self.assertEqual(self.run_step("floating_tap"), [
            "shell open 1 0xa,0xc,0xb 1", "bind Escape", "shell hide 2", "unbind Escape", "focus 0xc", "top"])

    def test_floating_holding_alt_moves_the_card_selection_and_wraps(self):
        log = self.run_step("floating_hold")
        self.assertEqual([m for m in log if m.startswith("shell")], [
            "shell open 1 0xa,0xc,0xb 1", "shell open 2 0xa,0xc,0xb 2", "shell open 3 0xa,0xc,0xb 0",
            "shell hide 4"])
        self.assertEqual(log[-2:], ["focus 0xa", "top"])
        self.assertNotIn("focus 0xc", log)

    def test_floating_shift_goes_backwards(self):
        log = self.run_step("floating_back")
        self.assertEqual(log[0], "shell open 1 0xa,0xc,0xb 2")
        self.assertEqual(log[-2:], ["focus 0xb", "top"])

    def test_floating_escape_cancels(self):
        self.assertEqual(self.run_step("floating_cancel"), [
            "shell open 1 0xa,0xc,0xb 1", "bind Escape", "shell hide 2", "unbind Escape"])

    def test_a_clicked_tile_wins(self):
        self.assertNotIn("focus", " ".join(self.run_step("clicked")))

    def test_letting_go_of_alt_ends_the_cycle_even_if_the_release_bind_is_missed(self):
        log = self.run_step("alt_watched")
        after = log[log.index("-- let go") + 1:]
        self.assertEqual(after, ["timer off", "shell hide 2", "unbind Escape", "focus 0xc", "top"])
        self.assertIn("timer 30 repeat", log[:log.index("-- let go")])

    def test_the_alt_watch_is_made_once_and_reused(self):
        log = self.run_step("alt_watched_again")
        self.assertEqual(log.count("timer 30 repeat"), 1)
        self.assertEqual(log.count("timer on"), 1)
        self.assertEqual(log.count("timer off"), 2)
        self.assertEqual(log.count("unbind Escape"), 2)

    def test_a_quick_swipe_goes_back_to_the_last_window_without_a_card(self):
        self.assertEqual(self.run_step("flick"), ["bind Escape", "timer 20 repeat", "timer off", "unbind Escape", "focus 0xc"])

    def test_a_quick_swipe_either_way_goes_back_and_brings_a_floating_window_up(self):
        self.assertEqual(self.run_step("flick_right")[-2:], ["focus 0xc", "top"])

    def test_a_quick_swipe_that_travels_still_steps(self):
        self.assertEqual(self.run_step("flick_steps")[-1], "focus 0xb")

    def test_holding_shows_the_card_and_moving_steps_it(self):
        log = self.run_step("held")
        before = log[:log.index("-- 80 ms")]
        self.assertFalse([m for m in before if m.startswith("shell")], "the card showed before the hold")
        self.assertEqual([m for m in log if m.startswith("shell")], [
            "shell reveal 1 0xa,0xc,0xb 1", "shell open 2 0xa,0xc,0xb 2", "shell open 3 0xa,0xc,0xb 1",
            "shell open 4 0xa,0xc,0xb 0", "shell hide 5"])
        self.assertEqual(log[-1], "focus 0xa")

    def test_holding_still_keeps_the_choice_and_opens_the_card_once(self):
        log = self.run_step("held_still")
        self.assertEqual([m for m in log if m.startswith("shell")], ["shell reveal 1 0xa,0xc,0xb 1", "shell hide 2"])
        self.assertEqual(log[-2:], ["focus 0xc", "top"])

    def test_a_cancelled_swipe_changes_nothing(self):
        log = self.run_step("cancelled")
        self.assertNotIn("focus", " ".join(log))
        self.assertEqual(log[-2:], ["shell hide 2", "unbind Escape"])

    def test_escape_ends_a_swipe(self):
        log = self.run_step("swipe_escape")
        self.assertNotIn("focus", " ".join(log))
        self.assertEqual([m for m in log if m.startswith("shell")], ["shell reveal 1 0xa,0xc,0xb 1", "shell hide 2"])

    def test_a_swipe_with_one_window_does_nothing(self):
        self.assertEqual(self.run_step("swipe_alone"), [""])

    def test_a_swipe_during_alt_tab_leaves_it_alone(self):
        log = self.run_step("swipe_during_alt_tab")
        self.assertEqual([m for m in log if m.startswith("shell")], ["shell open 1 0xa,0xc,0xb 1", "shell hide 2"])
        self.assertEqual(log[-2:], ["focus 0xc", "top"])

    def test_one_window_does_nothing(self):
        self.assertEqual(self.run_step("alone"), [""])

    def test_releasing_alt_alone_does_nothing(self):
        self.assertEqual(self.run_step("release_without_cycle"), [""])

    def test_desktop_binds_it(self):
        text = (ROOT / "hypr/desktop.lua").read_text()
        self.assertIn('local alt_tab = dofile(checkout .. "/hypr/alt-tab.lua").new(hl, function(message) hl.dispatch(ipc("switcher " .. message)) end)', text)
        self.assertIn('hl.bind("ALT + Tab", function() alt_tab.step(1) end, { description = "Windows: Switch" })', text)
        self.assertIn('hl.bind("ALT + SHIFT + Tab", function() alt_tab.step(-1) end, { description = "Windows: Switch back" })', text)
        self.assertIn('hl.gesture({ fingers = 3, direction = "horizontal", action = alt_tab.gesture })', text)
        self.assertNotIn("switching.swipe", text)
        self.assertNotIn('action = "move"', text)
        self.assertIn('hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen" })', text)
        for key in ("ALT_L", "ALT_R"):
            self.assertIn(f'hl.bind("{key}", alt_tab.commit, {{ release = true, ignore_mods = true, non_consuming = true }})', text)


if __name__ == "__main__":
    unittest.main()
