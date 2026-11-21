#!/usr/bin/env python3
"""Super + Alt + Space floats every window on every workspace, and tiles back
the ones it floated. Windows it floats get the app's remembered size and
place, or a default size, centred. Runs hypr/float-all.lua in plain Lua with a stand-in hl
whose windows change state as the dispatches arrive, and a stand-in size
store."""
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
local windows = {}
local screen = { x = 0, y = 0, width = 1920, height = 1080, scale = 1 }
local function add(address, floating, workspace, class, size)
 local w = { address = address, floating = floating, workspace = { id = workspace }, class = class or "app",
  size = size or { x = 1900, y = 1000 }, at = { x = 10, y = 10 }, monitor = screen, pid = #windows + 101 }
 windows[#windows + 1] = w
 return w
end
local function find(address)
 for _, w in ipairs(windows) do if w.address == address then return w end end
end
local log = {}
local saved = {}
local store = {
 get = function(class) return saved[class] end,
 set = function(class, width, height, x, y)
  saved[class] = { width = width, height = height, x = x, y = y }
  log[#log + 1] = "save " .. class .. " " .. width .. "x" .. height .. (x and ("@" .. x .. ":" .. y) or "")
 end
}
local kept_on, kept_windows = false, {}
local kept_log = {}
local kept = {
 load = function() return kept_on, kept_windows end,
 save = function(on, windows)
  local list = {}
  for address, class in pairs(windows) do list[#list + 1] = address .. "=" .. class end
  table.sort(list)
  kept_log[#kept_log + 1] = (on and "on" or "off") .. " " .. table.concat(list, ",")
 end
}
local function target(args)
 local t = type(args.window) == "table" and args.window or find((args.window or ""):match("^address:(.*)$"))
 assert(t, "a dispatch must name its window")
 return t
end
hl = {
 get_windows = function() local copy = {} for i, w in ipairs(windows) do copy[i] = w end return copy end,
 dsp = { window = {
  float = function(args) return { kind = "float", args = args } end,
  resize = function(args) return { kind = "resize", args = args } end,
  center = function(args) return { kind = "center", args = args } end,
  move = function(args) return { kind = "move", args = args } end
 } },
 dispatch = function(d)
  local t = target(d.args)
  if d.kind == "float" then
   t.floating = d.args.action == "enable"
   log[#log + 1] = d.args.action .. " " .. t.address
  elseif d.kind == "resize" then
   assert(not d.args.relative)
   t.size = { x = d.args.x, y = d.args.y }
   log[#log + 1] = "resize " .. t.address .. " " .. d.args.x .. "x" .. d.args.y
  elseif d.kind == "center" then log[#log + 1] = "center " .. t.address
  elseif d.args.relative then log[#log + 1] = "nudge " .. t.address .. " " .. d.args.x .. ":" .. d.args.y
  else
   t.at = { x = d.args.x, y = d.args.y }
   log[#log + 1] = "place " .. t.address .. " " .. d.args.x .. ":" .. d.args.y
  end
 end
}
local new = dofile(arg[1]).new
if arg[3] == "reloaded" then
 kept_on, kept_windows = true, { ["0xa"] = "101", ["0xgone"] = "200", ["0xc"] = "999" }
 add("0xa", true, 1, "Spotify"); add("0xb", true, 1, "dialog"); add("0xc", true, 1, "app")
end
local mode = new(hl, arg[3] ~= "memory" and store or nil, arg[3] ~= "memory" and kept or nil)
local function state()
 local out = {}
 for _, w in ipairs(windows) do out[#out + 1] = w.address .. "=" .. (w.floating and "float" or "tile") end
 return table.concat(out, " ")
end
local function only(prefix)
 local out = {}
 for _, line in ipairs(log) do if line:sub(1, #prefix) == prefix then out[#out + 1] = line end end
 return table.concat(out, ",")
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
 print(state(), only("enable"))
end
function steps.nothing_open()
 mode.toggle(); mode.opened(nil)
 print(mode.active(), #log)
end
function steps.default_size()
 add("0xa", false, 1); add("0xb", false, 1); add("0xc", false, 1); add("0xd", false, 2); add("0xdialog", true, 1, "app", { x = 400, y = 300 })
 mode.toggle()
 print(table.concat(log, ","))
end
function steps.small_screen()
 screen.width, screen.height, screen.scale = 2560, 1440, 2
 add("0xa", false, 1)
 mode.toggle()
 print(only("resize"))
end
function steps.remembered()
 saved.firefox = { width = 1000, height = 640 }
 saved.huge = { width = 5000, height = 4000 }
 add("0xa", false, 1, "firefox"); add("0xb", false, 2, "huge")
 mode.toggle()
 print(only("resize"))
end
function steps.remember_on_tile()
 local a = add("0xa", false, 1, "firefox"); add("0xdialog", true, 1, "dialog", { x = 400, y = 300 })
 mode.toggle()
 a.size = { x = 1111, y = 777 }; a.at = { x = 300, y = 200 } -- resized and moved by hand
 mode.toggle()
 print(only("save"))
end
function steps.remember_on_close()
 local a = add("0xa", false, 1, "firefox")
 mode.toggle()
 a.size = { x = 1111, y = 777 }; a.at = { x = 300, y = 200 }
 a.mapped = false; mode.hidden(a) -- window.close
 mode.closed(a) -- then window.destroy
 print(only("save"))
end
-- Apps like Spotify hide to the tray and come back as the same window,
-- still floating: Hyprland reports the hide as window.close.
function steps.tray_while_on()
 local a = add("0xa", false, 1, "Spotify")
 mode.toggle()
 a.mapped = false; mode.hidden(a)
 a.mapped = true; mode.opened(a)
 mode.toggle()
 print(state(), only("disable"))
end
function steps.tray_while_off()
 local a = add("0xa", false, 1, "Spotify"); add("0xb", false, 1, "kitty")
 mode.toggle()
 a.mapped = false; mode.hidden(a)
 mode.toggle() -- turned off while Spotify is hidden
 local tiled_while_hidden = only("disable")
 a.mapped = true; mode.opened(a)
 print(tiled_while_hidden, only("disable"), state())
end
function steps.tray_tiled_by_hand()
 local a = add("0xa", false, 1, "Spotify")
 mode.toggle()
 a.mapped = false; mode.hidden(a)
 mode.toggle()
 a.floating = false -- tiled some other way meanwhile
 a.mapped = true; mode.opened(a)
 mode.opened(a)
 print("[" .. only("disable") .. "]")
end
function steps.remember_on_reload()
 local a = add("0xa", false, 1, "firefox"); local b = add("0xb", false, 1, "kitty")
 mode.toggle()
 a.size = { x = 1111, y = 777 }; a.at = { x = 300, y = 200 }; b.at = { x = 10, y = 10 }
 mode.unloading()
 print(only("save"))
end
function steps.nonsense_not_kept()
 local a = add("0xa", false, 1, ""); local b = add("0xb", false, 1, "tiny")
 mode.toggle()
 a.size = { x = 1111, y = 777 }; b.size = { x = 40, y = 30 }
 mode.toggle()
 print("[" .. only("save") .. "]")
end
function steps.new_window_size()
 saved.kitty = { width = 900, height = 600 }
 add("0xa", false, 1)
 mode.toggle()
 log = {}
 mode.opened(add("0xnew", false, 1, "kitty"))
 print(table.concat(log, ","))
end
function steps.placed()
 saved.firefox = { width = 1000, height = 640, x = 300, y = 200 }
 saved.kitty = { width = 900, height = 600, x = 1500, y = 700 } -- would hang off the screen
 saved.old = { width = 800, height = 500 }
 add("0xa", false, 1, "firefox"); add("0xb", false, 1, "firefox"); add("0xc", false, 1, "kitty"); add("0xd", false, 1, "old")
 mode.toggle()
 print(table.concat(log, ","))
end
function steps.placed_other_screen()
 screen.x = 1920
 saved.firefox = { width = 1000, height = 640, x = 300, y = 200 }
 add("0xa", false, 1, "firefox")
 mode.toggle()
 print(table.concat(log, ","))
end
function steps.new_window_placed()
 saved.kitty = { width = 900, height = 600, x = 40, y = 60 }
 add("0xa", false, 1)
 mode.toggle()
 log = {}
 mode.opened(add("0xnew", false, 1, "kitty"))
 print(table.concat(log, ","))
end
function steps.reloaded()
 local was = mode.active()
 mode.toggle()
 print(tostring(was), state(), only("disable"))
end
function steps.kept()
 local a = add("0xa", false, 1, "firefox"); add("0xdialog", true, 1, "dialog")
 mode.toggle()
 local new = add("0xnew", false, 1, "kitty"); mode.opened(new)
 mode.closed(a)
 mode.toggle()
 print(table.concat(kept_log, "|"))
end
function steps.memory() local a = add("0xa", false, 1, "firefox"); mode.toggle(); a.size = { x = 1111, y = 777 }; mode.toggle(); mode.toggle(); print(only("resize")) end
steps[arg[2]]()
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run float-all.lua")
class FloatAll(unittest.TestCase):
    def run_step(self, step):
        run = subprocess.run(["lua", "-", str(ROOT / "hypr/float-all.lua"), step, step], input=HARNESS,
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

    def test_floated_windows_get_a_default_size_centred_and_nudged_apart(self):
        self.assertEqual(self.run_step("default_size").split(","), [
            "enable 0xa", "resize 0xa 1280x800", "center 0xa",
            "enable 0xb", "resize 0xb 1280x800", "center 0xb", "nudge 0xb 32:32",
            "enable 0xc", "resize 0xc 1280x800", "center 0xc", "nudge 0xc 64:64",
            "enable 0xd", "resize 0xd 1280x800", "center 0xd"])

    def test_the_default_fits_a_small_screen(self):
        # 2560 x 1440 at 200% is 1280 x 720 to lay out in; 80% of that.
        self.assertEqual(self.run_step("small_screen"), "resize 0xa 1024x576")

    def test_an_app_gets_its_remembered_size_capped_to_the_screen(self):
        self.assertEqual(self.run_step("remembered"), "resize 0xa 1000x640,resize 0xb 1536x864")

    def test_tiling_back_remembers_each_apps_size(self):
        self.assertEqual(self.run_step("remember_on_tile"), "save firefox 1111x777@300:200")

    def test_a_window_hidden_to_the_tray_is_still_tiled_back(self):
        self.assertEqual(self.run_step("tray_while_on"), "0xa=tile\tdisable 0xa")

    def test_a_window_hidden_when_tiling_back_is_tiled_when_it_returns(self):
        self.assertEqual(self.run_step("tray_while_off"), "disable 0xb\tdisable 0xb,disable 0xa\t0xa=tile 0xb=tile")

    def test_a_returning_window_already_tiled_is_left_alone(self):
        self.assertEqual(self.run_step("tray_tiled_by_hand"), "[]")

    def test_closing_remembers_the_size(self):
        self.assertEqual(self.run_step("remember_on_close"), "save firefox 1111x777@300:200")

    def test_a_reload_remembers_the_sizes(self):
        self.assertEqual(self.run_step("remember_on_reload"), "save firefox 1111x777@300:200,save kitty 1280x800@10:10")

    def test_nameless_and_tiny_windows_are_not_remembered(self):
        self.assertEqual(self.run_step("nonsense_not_kept"), "[]")

    def test_a_new_window_gets_its_apps_size_without_a_nudge(self):
        self.assertEqual(self.run_step("new_window_size"), "enable 0xnew,resize 0xnew 900x600,center 0xnew")

    def test_an_app_goes_back_where_it_was(self):
        # A second window of the same app is nudged off the first; an app
        # whose place would hang off the screen, or that has none, is centred.
        self.assertEqual(self.run_step("placed").split(","), [
            "enable 0xa", "resize 0xa 1000x640", "place 0xa 300:200",
            "enable 0xb", "resize 0xb 1000x640", "place 0xb 300:200", "nudge 0xb 32:32",
            "enable 0xc", "resize 0xc 900x600", "center 0xc",
            "enable 0xd", "resize 0xd 800x500", "center 0xd", "nudge 0xd 32:32"])

    def test_a_place_on_another_screen_is_centred_instead(self):
        self.assertEqual(self.run_step("placed_other_screen"), "enable 0xa,resize 0xa 1000x640,center 0xa")

    def test_a_new_window_goes_where_its_app_was(self):
        self.assertEqual(self.run_step("new_window_placed"), "enable 0xnew,resize 0xnew 900x600,place 0xnew 40:60")

    def test_a_reload_keeps_the_mode_and_the_windows_it_floated(self):
        # A window is only taken back if it's still there, floating, and the
        # same process (an app's name can change, Spotify sets its late); one
        # that floated on its own stays floating.
        self.assertEqual(self.run_step("reloaded"), "true\t0xa=tile 0xb=float 0xc=float\tdisable 0xa")

    def test_the_mode_is_kept_as_it_changes(self):
        self.assertEqual(self.run_step("kept").split("|"), [
            "on 0xa=101", "on 0xa=101,0xnew=103", "on 0xnew=103", "off"])

    def test_without_a_store_sizes_last_until_reload(self):
        self.assertEqual(self.run_step("memory"), "resize 0xa 1280x800,resize 0xa 1111x777")

    def test_desktop_binds_it(self):
        text = (ROOT / "hypr/desktop.lua").read_text()
        self.assertIn('local float_sizes = dofile(checkout .. "/hypr/float-sizes.lua").open(state .. "/bloom/floating-sizes")', text)
        self.assertIn('local float_mode = dofile(checkout .. "/hypr/float-mode.lua").open(state .. "/bloom/float-all", os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "")', text)
        self.assertIn('dofile(checkout .. "/hypr/float-all.lua").new(hl, float_sizes, float_mode)', text)
        self.assertIn('hl.on("window.close", float_all.hidden)', text)
        self.assertIn('hl.on("config.unload", float_all.unloading)', text)
        self.assertIn('hl.bind("SUPER + ALT + Space", float_all.toggle, { description = "Windows: Float or tile all" })', text)
        self.assertIn('hl.on("window.open", float_all.opened)', text)
        self.assertIn('hl.on("window.destroy", float_all.closed)', text)
        self.assertNotIn('hl.dsp.window.float({ action = "toggle" })', text)


if __name__ == "__main__":
    unittest.main()
