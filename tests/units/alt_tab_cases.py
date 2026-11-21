#!/usr/bin/env python3
"""Alt + Tab: hypr/alt-tab.lua switches windows on the current workspace,
most recent first, and tells the shell what to draw. Runs it in plain Lua
with a stand-in hl that records dispatches, binds and shell messages."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local windows, active, ws = {}, nil, { id = 1 }
local log = {}
local function add(address, history, workspace, floating)
 local w = { address = address, focus_history_id = history, workspace = { id = workspace or 1 }, floating = floating or false, mapped = true, hidden = false }
 windows[#windows + 1] = w
 return w
end
local binds = {}
hl = {
 get_windows = function() local copy = {} for i, w in ipairs(windows) do copy[i] = w end return copy end,
 get_active_workspace = function() return ws end,
 get_active_window = function() return active end,
 dsp = {
  focus = function(args) return { name = "focus", window = args.window } end,
  window = { bring_to_top = function() return { name = "top" } end }
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
local mode = dofile(arg[1]).new(hl, function(message) log[#log + 1] = "shell " .. message end)
local function setup()
 local a = add("0xa", 0); local b = add("0xb", 2); local c = add("0xc", 1); add("0xother", 3, 2)
 active = a
 return a, b, c
end
local steps = {}
function steps.quick_tap() setup(); mode.step(1); mode.commit() end
function steps.hold_and_step() setup(); mode.step(1); mode.step(1); mode.step(1); mode.commit() end
function steps.backwards() setup(); mode.step(-1); mode.commit() end
function steps.floating()
 local a = add("0xa", 0); add("0xf", 1, 1, true); active = a
 mode.step(1); mode.commit()
end
function steps.clicked()
 local a, b, c = setup()
 mode.step(1)
 active = b -- the shell focused a clicked tile
 mode.commit()
end
function steps.cancel() setup(); mode.step(1); binds["Escape"].fn(); mode.commit() end
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

    def test_quick_tap_goes_back_to_the_last_window(self):
        self.assertEqual(self.run_step("quick_tap"), [
            "shell open 0xa,0xc,0xb 1", "bind Escape", "shell hide", "unbind Escape", "focus 0xc"])

    def test_holding_alt_steps_further_and_wraps(self):
        log = self.run_step("hold_and_step")
        self.assertEqual([m for m in log if m.startswith("shell")], [
            "shell open 0xa,0xc,0xb 1", "shell select 2", "shell select 0", "shell hide"])
        self.assertEqual(log[-1], "focus 0xa")

    def test_shift_goes_backwards(self):
        self.assertEqual(self.run_step("backwards")[0], "shell open 0xa,0xc,0xb 2")
        self.assertEqual(self.run_step("backwards")[-1], "focus 0xb")

    def test_floating_windows_come_to_the_front(self):
        self.assertEqual(self.run_step("floating")[-2:], ["focus 0xf", "top"])

    def test_a_clicked_tile_wins(self):
        self.assertNotIn("focus", " ".join(self.run_step("clicked")))

    def test_escape_cancels_and_only_binds_while_cycling(self):
        log = self.run_step("cancel")
        self.assertEqual(log, ["shell open 0xa,0xc,0xb 1", "bind Escape", "shell hide", "unbind Escape"])

    def test_one_window_does_nothing(self):
        self.assertEqual(self.run_step("alone"), [""])

    def test_releasing_alt_alone_does_nothing(self):
        self.assertEqual(self.run_step("release_without_cycle"), [""])

    def test_desktop_binds_it(self):
        text = (ROOT / "hypr/desktop.lua").read_text()
        self.assertIn('dofile(checkout .. "/hypr/alt-tab.lua").new(hl, function(message) hl.dispatch(ipc("switcher " .. message)) end)', text)
        self.assertIn('hl.bind("ALT + Tab", function() alt_tab.step(1) end, { description = "Windows: Switch" })', text)
        self.assertIn('hl.bind("ALT + SHIFT + Tab", function() alt_tab.step(-1) end, { description = "Windows: Switch back" })', text)
        for key in ("ALT_L", "ALT_R"):
            self.assertIn(f'hl.bind("{key}", alt_tab.commit, {{ release = true, ignore_mods = true, non_consuming = true }})', text)


if __name__ == "__main__":
    unittest.main()
