-- Each app's floating size and place (owner's request), kept so Bloom
-- remembers them across Hyprland reloads and restarts. One line per app:
-- class, width, height and then x and y, tab separated; lines from before
-- places were kept have no x and y. Lines that don't read as that are
-- skipped, and an app whose name would break the file isn't kept. If the
-- file can't be written they still last until the next reload.
local M = {}

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

function M.open(path)
    local sizes = {}
    local file = io.open(path, "r")
    if file then
        for line in file:lines() do
            local class, width, height, rest = line:match("^([^\t]+)\t(%d+)\t(%d+)(.*)$")
            local x, y
            if rest then x, y = rest:match("^\t(-?%d+)\t(-?%d+)$") end
            if class and (rest == "" or x) then
                sizes[class] = { width = tonumber(width), height = tonumber(height), x = tonumber(x), y = tonumber(y) }
            end
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
            local size = sizes[class]
            out:write(class, "\t", size.width, "\t", size.height)
            if size.x then out:write("\t", size.x, "\t", size.y) end
            out:write("\n")
        end
        out:close()
        os.rename(temporary, path)
    end

    local store = {}

    function store.get(class)
        return sizes[class]
    end

    local function round(n)
        return n and math.floor(n + 0.5)
    end

    function store.set(class, width, height, x, y)
        if type(class) ~= "string" or class == "" or class:find("[\t\n\r]") then return end
        if not (x and y) then x, y = nil, nil end
        sizes[class] = { width = round(width), height = round(height), x = round(x), y = round(y) }
        write()
    end

    return store
end

return M
