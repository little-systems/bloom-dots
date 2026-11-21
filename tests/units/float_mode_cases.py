#!/usr/bin/env python3
"""hypr/float-mode.lua keeps whether float-all is on and which windows it
floated, so a Hyprland config reload (which resets Lua) doesn't strand them
floating. A new Hyprland session starts fresh. Runs it in plain Lua against a
temporary directory."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local mode = dofile(arg[1])
local path, instance = arg[2], arg[4]
local function show(m)
 local on, windows = m.load()
 local list = {}
 for address, class in pairs(windows) do list[#list + 1] = address .. "=" .. class end
 table.sort(list)
 print(tostring(on), table.concat(list, ","))
end
local steps = {}
function steps.save() mode.open(path, instance).save(true, { ["0xa"] = "Spotify", ["0xb"] = "kitty" }) end
function steps.save_off() mode.open(path, instance).save(false, {}) end
function steps.load() show(mode.open(path, instance)) end
function steps.bad_names() mode.open(path, instance).save(true, { ["0xa"] = "a\tb", ["nope"] = "kitty", ["0xc"] = "kitty" }) end
steps[arg[3]]()
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run float-mode.lua")
class FloatMode(unittest.TestCase):
    def run_step(self, step, path, instance="one"):
        run = subprocess.run(["lua", "-", str(ROOT / "hypr/float-mode.lua"), str(path), step, instance],
                             input=HARNESS, text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        return run.stdout.strip()

    def test_a_reload_gets_the_mode_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state/bloom/float-all"
            self.run_step("save", path)
            self.assertEqual(self.run_step("load", path), "true\t0xa=Spotify,0xb=kitty")

    def test_turning_it_off_is_kept_too(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "float-all"
            self.run_step("save", path)
            self.run_step("save_off", path)
            self.assertEqual(self.run_step("load", path), "false")

    def test_a_new_hyprland_session_starts_fresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "float-all"
            self.run_step("save", path, "one")
            self.assertEqual(self.run_step("load", path, "two"), "false")

    def test_no_file_or_a_damaged_one_is_off(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "float-all"
            self.assertEqual(self.run_step("load", path), "false")
            path.write_text("garbage\n")
            self.assertEqual(self.run_step("load", path), "false")

    def test_entries_that_would_break_the_file_are_not_kept(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "float-all"
            self.run_step("bad_names", path)
            self.assertEqual(self.run_step("load", path), "true\t0xc=kitty")


if __name__ == "__main__":
    unittest.main()
