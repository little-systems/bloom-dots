-- Float or tile every window (owner's request): one press floats every window
-- on every workspace, and windows that open while it's on float too; the
-- next press tiles back the ones it floated. Windows that were floating
-- already (dialogs, rule-floated or floated by hand) stay as they were.
-- Hyprland resets Lua state on a config reload, which ends the mode.
--
-- A window it floats gets its app's remembered size, or 1280 x 800, never
-- more than 80% of the screen, and is centred; windows floated together on
-- one workspace are nudged apart. An app's size is remembered when its
-- window is tiled back, closed, or Hyprland reloads. `sizes` keeps them
-- ({ get(class), set(class, width, height) }); without one they last until
-- the reload.
local M = {}

local DEFAULT = { width = 1280, height = 800 }
local MOST = 0.8
local NUDGE = 32
local SMALLEST = 100

local function memory()
    local saved = {}
    return {
        get = function(class) return saved[class] end,
        set = function(class, width, height) saved[class] = { width = width, height = height } end
    }
end

function M.new(hl, sizes)
    sizes = sizes or memory()
    local on = false
    local floated = {}

    local function class(window)
        local name = window.class
        if not name or name == "" then name = window.initial_class end
        if name and name ~= "" then return name end
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

    local function float(window, nudge)
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = window }))
        floated[window.address] = true
        local name = class(window)
        local width, height = fit(name and sizes.get(name) or DEFAULT, window.monitor)
        hl.dispatch(hl.dsp.window.resize({ x = width, y = height, relative = false, window = window }))
        hl.dispatch(hl.dsp.window.center({ window = window }))
        if nudge > 0 then
            hl.dispatch(hl.dsp.window.move({ x = nudge * NUDGE, y = nudge * NUDGE, relative = true, window = window }))
        end
    end

    local function remember(window)
        local name = class(window)
        local size = window.size
        if not name or type(size) ~= "table" or not size.x or not size.y then return end
        if size.x < SMALLEST or size.y < SMALLEST then return end
        sizes.set(name, size.x, size.y)
    end

    local mode = {}

    function mode.active()
        return on
    end

    function mode.toggle()
        if on then
            for _, window in ipairs(hl.get_windows()) do
                if floated[window.address] and window.floating then
                    remember(window)
                    hl.dispatch(hl.dsp.window.float({ action = "disable", window = window }))
                end
            end
            floated = {}
            on = false
        else
            local nudges = {}
            for _, window in ipairs(hl.get_windows()) do
                if not window.floating then
                    local workspace = window.workspace and window.workspace.id or 0
                    float(window, nudges[workspace] or 0)
                    nudges[workspace] = (nudges[workspace] or 0) + 1
                end
            end
            on = true
        end
    end

    function mode.opened(window)
        if on and window and not window.floating then float(window, 0) end
    end

    function mode.closed(window)
        if not window or not floated[window.address] then return end
        if window.floating then remember(window) end
        floated[window.address] = nil
    end

    function mode.unloading()
        for _, window in ipairs(hl.get_windows()) do
            if floated[window.address] and window.floating then remember(window) end
        end
    end

    return mode
end

return M
