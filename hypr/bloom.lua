-- Bloom's integration. The installer loads this file once from hyprland.lua.
-- Custom files belong to the user and are never overwritten after editing.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
-- bloom-colors is written by Bloom's theme; the user's own files come after it.
for _, name in ipairs({"bloom-colors", "bloom-settings", "bloom", "bloom-keybinds"}) do
    local path = config .. "/hypr/custom/" .. name .. ".lua"
    local file = io.open(path, "r")
    if file then
        file:close()
        dofile(path)
    end
end
-- Session profile, from where Hyprland itself runs (not from what is installed):
-- under UWSM it is a wayland-wm@ unit, and UWSM imports the environment and
-- starts graphical-session.target, which starts Bloom. Native sessions start it here.
local function uwsm()
    local file = io.open(os.getenv("BLOOM_CGROUP_FILE") or "/proc/self/cgroup", "r")
    if not file then return false end
    local text = file:read("*a") or ""
    file:close()
    return text:find("wayland%-wm@", 1) ~= nil
end
-- After an install from arch-chroot or a console, the first session finishes
-- what needed a running user manager (see bloom first-login).
local checkout = debug.getinfo(1, "S").source:match("^@(.*)/hypr/[^/]*$") or "."
local function first_login(extra)
    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local marker = io.open(state .. "/bloom/first-login-pending", "r")
    if not marker then return "" end
    marker:close()
    return "'" .. (checkout .. "/bin/bloom"):gsub("'", "'\\''") .. "' first-login" .. extra
end
hl.on("hyprland.start", function()
    if uwsm() then
        local finish = first_login(" --start")
        if finish ~= "" then hl.exec_cmd(finish) end
        return
    end
    local finish = first_login("")
    local present = {}
    for _, name in ipairs({"WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
        "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
        "XDG_STATE_HOME", "XDG_DATA_DIRS", "PATH", "QT_QPA_PLATFORMTHEME",
        "QT_STYLE_OVERRIDE", "QS_ICON_THEME"}) do
        if os.getenv(name) then table.insert(present, name) end
    end
    -- A plain Hyprland logout can leave the user manager alive. Import this
    -- session first, clear its predecessor's crash limit, then replace any
    -- surviving process so it cannot retain the old display environment.
    hl.exec_cmd((finish ~= "" and finish .. "; " or "") .. "systemctl --user import-environment " .. table.concat(present, " ")
        .. " && systemctl --user reset-failed bloom-shell.service"
        .. " && systemctl --user restart bloom-shell.service")
end)
