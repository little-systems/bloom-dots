-- Each app's floating size (owner's request), kept so Bloom remembers it
-- across Hyprland reloads and restarts. One line per app: class, width and
-- height, tab separated. Lines that don't read as that are skipped, and an
-- app whose name would break the file isn't kept. If the file can't be
-- written the sizes still last until the next reload.
local M = {}

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

function M.open(path)
    local sizes = {}
    local file = io.open(path, "r")
    if file then
        for line in file:lines() do
            local class, width, height = line:match("^([^\t]+)\t(%d+)\t(%d+)$")
            if class then sizes[class] = { width = tonumber(width), height = tonumber(height) } end
        end
        file:close()
    end

    local function write()
        local dir = path:match("^(.*)/[^/]*$")
        if dir and dir ~= "" then os.execute("mkdir -p " .. quote(dir) .. " 2>/dev/null") end
        local classes = {}
        for class in pairs(sizes) do classes[#classes + 1] = class end
        table.sort(classes)
        local temporary = path .. ".tmp"
        local out = io.open(temporary, "w")
        if not out then return end
        for _, class in ipairs(classes) do
            out:write(class, "\t", sizes[class].width, "\t", sizes[class].height, "\n")
        end
        out:close()
        os.rename(temporary, path)
    end

    local store = {}

    function store.get(class)
        return sizes[class]
    end

    function store.set(class, width, height)
        if type(class) ~= "string" or class == "" or class:find("[\t\n\r]") then return end
        sizes[class] = { width = math.floor(width + 0.5), height = math.floor(height + 0.5) }
        write()
    end

    return store
end

return M
