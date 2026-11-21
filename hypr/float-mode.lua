-- Whether float-all is on and which windows it floated, kept in a small file
-- because a Hyprland config reload resets Lua: without it, windows floated
-- before a reload stay floating and the next press can't tile them back.
-- The first line is the Hyprland instance and "on" or "off", then one line
-- per window: address and the process it was floated for, tab separated. A
-- file from another Hyprland session (a restart or a new login) reads as off
-- with no windows, since addresses don't carry over. If the file can't be written the mode
-- still works until the next reload.
local M = {}

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

function M.open(path, instance)
    local kept = {}

    function kept.load()
        local windows = {}
        local file = io.open(path, "r")
        if not file then return false, windows end
        local session, state = (file:read("l") or ""):match("^([^\t]*)\t(%a+)$")
        local on = session == instance and state == "on"
        if session == instance then
            for line in file:lines() do
                local address, owner = line:match("^(0x%x+)\t([^\t]+)$")
                if address then windows[address] = owner end
            end
        end
        file:close()
        return on, windows
    end

    function kept.save(on, windows)
        local dir = path:match("^(.*)/[^/]*$")
        if dir and dir ~= "" then os.execute("mkdir -p " .. quote(dir) .. " 2>/dev/null") end
        local temporary = path .. ".tmp"
        local out = io.open(temporary, "w")
        if not out then return end
        out:write(instance, "\t", on and "on" or "off", "\n")
        local addresses = {}
        for address, owner in pairs(windows) do
            if address:match("^0x%x+$") and type(owner) == "string" and owner ~= "" and not owner:find("[\t\n\r]") then
                addresses[#addresses + 1] = address
            end
        end
        table.sort(addresses)
        for _, address in ipairs(addresses) do out:write(address, "\t", windows[address], "\n") end
        out:close()
        os.rename(temporary, path)
    end

    return kept
end

return M
