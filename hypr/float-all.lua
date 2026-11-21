-- Float or tile every window (owner's request): one press floats every window
-- on every workspace, and windows that open while it's on float too; the
-- next press tiles back the ones it floated. Windows that were floating
-- already (dialogs, rule-floated or floated by hand) stay as they were.
-- Hyprland resets Lua state on a config reload, so `kept` ({ load(), save(on,
-- windows) }) holds the mode and the windows it floated (address to process
-- id) through one; a window is taken back only if it's still floating and
-- the same process. Not the app's name: some, like Spotify, set it late.
-- Without `kept` a reload ends the mode.
--
-- Apps like Spotify hide to the tray and come back as the same window.
-- Hyprland reports the hide as window.close while the window still reads
-- mapped and floating, and may leave it out of hl.get_windows(), so a hide is
-- marked here ("away", kept through a reload too). Turning the mode off
-- leaves away and unlisted windows owed; each is tiled when it comes back.
--
-- A window it floats gets its app's remembered size, or 1280 x 800, never
-- more than 80% of the screen, and goes back where its app last was; with no
-- place, or one that no longer fits its screen, it's centred. Windows that
-- would land on the same spot on one workspace are nudged apart. An app's
-- size and place are remembered when its window is tiled back, closed, or
-- Hyprland reloads. `sizes` keeps them ({ get(class), set(class, width,
-- height, x, y) }); without one they last until the reload.
local M = {}

local DEFAULT = { width = 1280, height = 800 }
local MOST = 0.8
local NUDGE = 32
local SMALLEST = 100

local function memory()
    local saved = {}
    return {
        get = function(class) return saved[class] end,
        set = function(class, width, height, x, y) saved[class] = { width = width, height = height, x = x, y = y } end
    }
end

function M.new(hl, sizes, kept)
    sizes = sizes or memory()
    local on = false
    -- address -> process id of each window it floated and still owes a tile
    local floated = {}
    -- address -> true while one of those is hidden (in the tray)
    local away = {}

    local function class(window)
        local name = window.class
        if not name or name == "" then name = window.initial_class end
        if name and name ~= "" then return name end
    end

    local function keep()
        if not kept then return end
        local windows = {}
        for address, pid in pairs(floated) do windows[address] = away[address] and pid .. " away" or pid end
        kept.save(on, windows)
    end

    local function forget(address)
        floated[address] = nil
        away[address] = nil
    end

    if kept then
        local was, windows = kept.load()
        on = was
        local listed = {}
        for _, window in ipairs(hl.get_windows()) do listed[window.address] = window end
        for address, value in pairs(windows) do
            local pid, hidden = value:match("^(%S+)( away)$")
            pid = pid or value
            local window = listed[address]
            if hidden then
                floated[address], away[address] = pid, true
            elseif window and window.floating and pid == tostring(window.pid) then
                floated[address] = pid
            end
        end
    end

    local function fit(size, monitor)
        local width, height = size.width, size.height
        if monitor and monitor.width and monitor.height then
            local scale = monitor.scale or 1
            width = math.min(width, math.floor(monitor.width / scale * MOST))
            height = math.min(height, math.floor(monitor.height / scale * MOST))
        end
        return width, height
    end

    -- Whether a width x height window at x, y lies on the monitor.
    local function inside(x, y, width, height, monitor)
        if not (x and y and monitor and monitor.width and monitor.height) then return false end
        local scale = monitor.scale or 1
        local left, top = monitor.x or 0, monitor.y or 0
        return x >= left and y >= top
            and x + width <= left + monitor.width / scale and y + height <= top + monitor.height / scale
    end

    -- Floats the window. `nudges` counts the windows already put on each spot
    -- of its workspace, so one landing on a taken spot is nudged off it.
    local function float(window, nudges)
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = window }))
        floated[window.address] = tostring(window.pid)
        local name = class(window)
        local saved = name and sizes.get(name) or DEFAULT
        local width, height = fit(saved, window.monitor)
        hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))
        local spot = "centre"
        if inside(saved.x, saved.y, width, height, window.monitor) then
            spot = saved.x .. "," .. saved.y
            hl.dispatch(hl.dsp.window.move({ x = saved.x, y = saved.y, relative = false, window = window }))
        else
            hl.dispatch(hl.dsp.window.center({ window = window }))
        end
        local nudge = nudges and nudges[spot] or 0
        if nudges then nudges[spot] = nudge + 1 end
        if nudge > 0 then
            hl.dispatch(hl.dsp.window.move({ x = nudge * NUDGE, y = nudge * NUDGE, relative = true, window = window }))
        end
    end

    local function remember(window)
        local name = class(window)
        local size, at = window.size, window.at
        if not name or type(size) ~= "table" or not size.x or not size.y then return end
        if size.x < SMALLEST or size.y < SMALLEST then return end
        if type(at) ~= "table" then at = {} end
        sizes.set(name, size.x, size.y, at.x, at.y)
    end

    local mode = {}

    function mode.active()
        return on
    end

    function mode.toggle()
        if on then
            -- Away or unlisted windows stay owed: each is tiled when it's back.
            for _, window in ipairs(hl.get_windows()) do
                local address = window.address
                if floated[address] and not away[address] and window.mapped ~= false then
                    if window.floating then
                        remember(window)
                        hl.dispatch(hl.dsp.window.float({ action = "disable", window = window }))
                    end
                    forget(address)
                end
            end
            for address in pairs(floated) do away[address] = true end
            on = false
            keep()
        else
            local spots = {}
            for _, window in ipairs(hl.get_windows()) do
                if not window.floating and window.mapped ~= false then
                    local workspace = window.workspace and window.workspace.id or 0
                    spots[workspace] = spots[workspace] or {}
                    float(window, spots[workspace])
                end
            end
            on = true
            keep()
        end
    end

    -- Also a window coming back from the tray: Hyprland reopens the same one.
    function mode.opened(window)
        if not window then return end
        local address = window.address
        -- Hyprland reuses addresses: another process's window isn't ours.
        if floated[address] and floated[address] ~= tostring(window.pid) then forget(address) end
        if not on then
            if not floated[address] then return end
            if window.floating then hl.dispatch(hl.dsp.window.float({ action = "disable", window = window })) end
            forget(address)
            keep()
        elseif floated[address] then
            away[address] = nil
            if not window.floating then float(window, nil) end
            keep()
        elseif not window.floating then
            float(window, nil)
            keep()
        end
    end

    -- window.close, which is also a hide to the tray: the window stays owed.
    function mode.hidden(window)
        if not window or not floated[window.address] then return end
        if window.floating then remember(window) end
        away[window.address] = true
        keep()
    end

    -- window.destroy: gone for good.
    function mode.closed(window)
        if not window or not floated[window.address] then return end
        -- Saved already if it was hidden first.
        if window.floating and not away[window.address] and window.mapped ~= false then remember(window) end
        forget(window.address)
        keep()
    end

    function mode.unloading()
        for _, window in ipairs(hl.get_windows()) do
            if floated[window.address] and window.floating then remember(window) end
        end
    end

    return mode
end

return M
