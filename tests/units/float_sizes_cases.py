#!/usr/bin/env python3
"""hypr/float-sizes.lua keeps each app's floating size in a small file, so
Bloom remembers it across Hyprland reloads and restarts. Runs it in plain Lua
against a temporary directory."""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local sizes = dofile(arg[1])
local path = arg[2]
local steps = {}
local function show(s, class) local v = s.get(class) print(v and (v.width .. "x" .. v.height) or "none") end
function steps.round_trip()
 local s = sizes.open(path)
 s.set("firefox", 1000, 640); s.set("org.kde.dolphin", 900, 700); s.set("firefox", 1100, 650)
 local again = sizes.open(path)
 show(again, "firefox"); show(again, "org.kde.dolphin"); show(again, "kitty")
end
function steps.read() local s = sizes.open(path) show(s, "firefox") show(s, "kitty") end
function steps.bad_names()
 local s = sizes.open(path)
 s.set("a\tb", 900, 700); s.set("a\nb", 900, 700); s.set("", 900, 700)
 s.set("kitty", 900.6, 700.2)
 local again = sizes.open(path)
 show(again, "a\tb"); show(again, "kitty")
end
function steps.unwritable() local s = sizes.open(path) s.set("kitty", 900, 700) show(s, "kitty") end
steps[arg[3]]()
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run float-sizes.lua")
class FloatSizes(unittest.TestCase):
    def run_step(self, step, path):
        run = subprocess.run(["lua", "-", str(ROOT / "hypr/float-sizes.lua"), str(path), step], input=HARNESS,
                             text=True, capture_output=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        return run.stdout.split()

    def test_sizes_survive_a_reload_and_the_latest_wins(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state/bloom/floating-sizes"
            self.assertEqual(self.run_step("round_trip", path), ["1100x650", "900x700", "none"])
            self.assertTrue(path.exists())

    def test_a_damaged_file_keeps_the_good_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "floating-sizes"
            path.write_text("firefox\t1000\t640\ngarbage\nkitty\tbig\t2\n\t5\t5\n")
            self.assertEqual(self.run_step("read", path), ["1000x640", "none"])

    def test_names_that_would_break_the_file_are_not_kept(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "floating-sizes"
            self.assertEqual(self.run_step("bad_names", path), ["none", "901x700"])
            self.assertEqual(path.read_text(), "kitty\t901\t700\n")

    def test_an_unwritable_file_still_remembers_until_reload(self):
        with tempfile.TemporaryDirectory() as tmp:
            blocker = Path(tmp) / "file"
            blocker.write_text("")
            self.assertEqual(self.run_step("unwritable", blocker / "floating-sizes"), ["900x700"])


if __name__ == "__main__":
    unittest.main()
