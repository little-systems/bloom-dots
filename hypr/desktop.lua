-- Bloom's desktop: Hyprland settings and shortcuts for machines where Bloom is
-- the whole desktop (no ii). hyprland.lua loads this first, so anything set
-- after it there, or in custom/bloom-keybinds.lua, wins. Updated by bloom update.
local checkout = debug.getinfo(1, "S").source:match("^@(.*)/hypr/[^/]*$") or "."
local bloom = "'" .. (checkout .. "/bin/bloom"):gsub("'", "'\\''") .. "'"
local function ipc(args) return hl.dsp.exec_cmd(bloom .. " ipc " .. args) end

local terminal = "kitty"
local files = "dolphin --new-window"
local browser = "firefox"

-- 100% on every screen; Settings > Display changes it per screen.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Qt apps (and Bloom's shell, for its icon theme) follow KDE's platform
-- theme: Bloom's kdeglobals colours and Breeze icons. KDE apps such as
-- Dolphin find their Open With menu through Arch's application menu.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "arch-")
-- Electron apps run on Wayland when they can.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 1,
        col = { active_border = "rgba(ffffff40)", inactive_border = "rgba(ffffff14)" },
        layout = "dwindle",
    },
    decoration = {
        rounding = 14,
        rounding_power = 2,
        shadow = { enabled = true, range = 18, render_power = 3, color = 0x40000000 },
        blur = { enabled = true, size = 6, passes = 2 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
    -- Bloom draws the wallpaper; Hyprland's own would flash in first.
    misc = { force_default_wallpaper = 0, disable_hyprland_logo = true, disable_splash_rendering = true },
})
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.window_rule({ name = "bloom-suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "bloom-fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- File dialogs, pickers and small settings tools float in the middle instead
-- of squeezing the tiled windows.
local floating = {
    { name = "bloom-float-file-dialogs",
      match = { title = "^(Open|Open Files?|Open Folder|Save|Save File|Save As|Save Image|Select a File|Choose Files?|File Upload)( [-–—] .*)?$" } },
    { name = "bloom-float-browser-prompts", match = { title = "^(Library|.* wants to (save|open))$" } },
    { name = "bloom-float-portals", match = { class = "^(xdg-desktop-portal-(gtk|kde)|org\\.freedesktop\\.impl\\.portal\\..*)$" } },
    { name = "bloom-float-tools",
      match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|\\.blueman-manager-wrapped)$" } },
}
for _, rule in ipairs(floating) do
    hl.window_rule({ name = rule.name, match = rule.match, float = true, center = true })
end

-- Clipboard history for the launcher's ";" mode.
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Shell
-- The cheatsheet shows one row per description, from the first bind with it.
hl.bind("SUPER + Space", ipc("launcher toggle"), { description = "Bloom: Launcher (or tap Super)" })
hl.bind("SUPER + SUPER_L", ipc("launcher toggle"), { release = true, description = "Bloom: Launcher (or tap Super)" })
hl.bind("SUPER + Slash", ipc("cheatsheet toggle"), { description = "Bloom: Cheatsheet" })
hl.bind("SUPER + Tab", ipc("overview toggle"), { description = "Bloom: Overview" })
hl.bind("SUPER + N", ipc("notch openPanel command-center"), { description = "Bloom: Command Center" })
hl.bind("SUPER + M", ipc("notch openMusic"), { description = "Bloom: Music" })
hl.bind("SUPER + V", ipc("launcher mode ';'"), { description = "Bloom: Clipboard history" })
hl.bind("SUPER + Period", ipc("launcher mode ':'"), { description = "Bloom: Emoji" })
hl.bind("SUPER + W", ipc("wallpaper toggle"), { description = "Bloom: Wallpaper picker" })
hl.bind("SUPER + I", hl.dsp.exec_cmd(bloom .. " settings"), { description = "Bloom: Settings" })
hl.bind("SUPER + K", ipc("osk toggle"), { description = "Bloom: On-screen keyboard" })
hl.bind("SUPER + G", ipc("overlay toggle"), { description = "Bloom: Widget overlay" })
hl.bind("SUPER + L", ipc("lock lock"), { description = "Bloom: Lock" })
hl.bind("CTRL + ALT + Delete", ipc("session toggle"), { description = "Bloom: Session menu" })

-- Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "Apps: Terminal" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal), { description = "Apps: Terminal" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(files), { description = "Apps: Files" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser), { description = "Apps: Browser" })

-- Screen
hl.bind("Print", ipc("region run screenshot"), { description = "Screen: Screenshot a region" })
hl.bind("SUPER + SHIFT + S", ipc("region run screenshot"), { description = "Screen: Screenshot a region" })
hl.bind("SUPER + SHIFT + A", ipc("region run annotate"), { description = "Screen: Screenshot and annotate" })
hl.bind("SUPER + SHIFT + T", ipc("region run ocr"), { description = "Screen: Copy text from the screen" })
hl.bind("SUPER + SHIFT + R", ipc("region run record"), { description = "Screen: Record a region" })

-- Windows
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Windows: Close" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Windows: Fullscreen" })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Windows: Float or tile" })
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }), { description = "Windows: Focus (arrow keys)" })
    hl.bind("SUPER + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }), { description = "Windows: Move (arrow keys)" })
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Windows: Drag to move" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows: Drag to resize" })

-- Workspaces and the dock
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }), { description = "Workspaces: Go to workspace 1–9" })
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Workspaces: Send window to 1–9" })
    hl.bind("SUPER + ALT + " .. i, hl.dsp.global("bloom:dock-" .. i), { description = "Dock: Open dock app 1–9" })
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous" })
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratch"), { description = "Workspaces: Scratch" })

-- Keys (Bloom's OSD shows the change)
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), held)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
