-- Bloom's integration. The installer loads this file once from hyprland.lua.
-- Custom files belong to the user and are never overwritten after editing.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
for _, name in ipairs({"bloom-settings", "bloom", "bloom-keybinds"}) do
    local path = config .. "/hypr/custom/" .. name .. ".lua"
    local file = io.open(path, "r")
    if file then
        file:close()
        dofile(path)
    end
end
hl.on("hyprland.start", function()
    local present = {}
    for _, name in ipairs({"WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE",
        "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
        "XDG_STATE_HOME", "XDG_DATA_DIRS", "PATH", "QT_QPA_PLATFORMTHEME",
        "QT_STYLE_OVERRIDE", "QS_ICON_THEME"}) do
        if os.getenv(name) then table.insert(present, name) end
    end
    hl.exec_cmd("systemctl --user import-environment " .. table.concat(present, " ")
        .. "; systemctl --user start bloom-shell.service")
end)
