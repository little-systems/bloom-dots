#!/usr/bin/env python3
"""Super + Alt + Space floats every window on every workspace, and tiles back
the ones it floated. Runs hypr/float-all.lua in plain Lua with a stand-in hl
whose windows change floating state as the dispatches arrive."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local windows = {}
local function add(address, floating, workspace)
 local w = { address = address, floating = floating, workspace = workspace }
 windows[#windows + 1] = w
 return w
end
local function find(address)
 for _, w in ipairs(windows) do if w.address == address then return w end end
end
local log = {}
hl = {
 get_windows = function() local copy = {} for i, w in ipairs(windows) do copy[i] = w end return copy end,
 dsp = { window = { float = function(args) return { kind = "float", args = args } end } },
 dispatch = function(d)
  local target = type(d.args.window) == "table" and d.args.window or find((d.args.window or ""):match("^address:(.*)$"))
  assert(target, "a float dispatch must name its window")
  target.floating = d.args.action == "enable"
  log[#log + 1] = d.args.action .. " " .. target.address
 end
}
local mode = dofile(arg[1]).new(hl)
local function state()
 local out = {}
 for _, w in ipairs(windows) do out[#out + 1] = w.address .. "=" .. (w.floating and "float" or "tile") end
 return table.concat(out, " ")
end
local steps = {}
function steps.float_all()
 add("0xa", false, 1); add("0xb", false, 2); add("0xdialog", true, 1)
 mode.toggle()
 print(state(), mode.active())
end
function steps.tile_back()
 add("0xa", false, 1); add("0xb", false, 3); add("0xdialog", true, 1)
 mode.toggle(); mode.toggle()
 print(state(), mode.active())
end
function steps.new_windows()
 add("0xa", false, 1)
 mode.toggle()
 mode.opened(add("0xnew", false, 2))
 mode.opened(add("0xrule", true, 2))
 mode.toggle()
 mode.opened(add("0xafter", false, 1))
 print(state())
end
function steps.closed()
 local a = add("0xa", false, 1)
 mode.toggle()
 for i, w in ipairs(windows) do if w == a then table.remove(windows, i) end end
 mode.closed(a)
 add("0xa", false, 1)
 mode.toggle()
 print(state(), table.concat(log, ","))
end
function steps.nothing_open()
 mode.toggle(); mode.opened(nil)
 print(mode.active(), #log)
end
steps[arg[2]]()
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run float-all.lua")
class FloatAll(unittest.TestCase):
    def run_step(self, step):
        run = subprocess.run(["lua", "-", str(ROOT / "hypr/float-all.lua"), step], input=HARNESS,
                             text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        return run.stdout.strip()

    def test_floats_every_window_on_every_workspace(self):
        self.assertEqual(self.run_step("float_all"), "0xa=float 0xb=float 0xdialog=float\ttrue")

    def test_tiles_back_only_what_it_floated(self):
        self.assertEqual(self.run_step("tile_back"), "0xa=tile 0xb=tile 0xdialog=float\tfalse")

    def test_new_windows_float_only_while_on(self):
        self.assertEqual(self.run_step("new_windows"), "0xa=tile 0xnew=tile 0xrule=float 0xafter=tile")

    def test_closed_windows_are_forgotten(self):
        # A new window reusing a closed one's address isn't tiled by mistake:
        # the mode is off after the second press, and the new 0xa was tiled
        # already, so nothing is dispatched for it.
        self.assertEqual(self.run_step("closed"), "0xa=tile\tenable 0xa")

    def test_toggling_with_nothing_open(self):
        self.assertEqual(self.run_step("nothing_open"), "true\t0")

    def test_desktop_binds_it(self):
        text = (ROOT / "hypr/desktop.lua").read_text()
        self.assertIn('dofile(checkout .. "/hypr/float-all.lua").new(hl)', text)
        self.assertIn('hl.bind("SUPER + ALT + Space", float_all.toggle, { description = "Windows: Float or tile all" })', text)
        self.assertIn('hl.on("window.open", float_all.opened)', text)
        self.assertIn('hl.on("window.destroy", float_all.closed)', text)
        self.assertNotIn('hl.dsp.window.float({ action = "toggle" })', text)


if __name__ == "__main__":
    unittest.main()
