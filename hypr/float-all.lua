-- Float or tile every window (owner's request): one press floats every window
-- on every workspace, and windows that open while it's on float too; the
-- next press tiles back the ones it floated. Windows that were floating
-- already (dialogs, rule-floated or floated by hand) stay as they were.
-- Hyprland resets Lua state on a config reload, which ends the mode.
local M = {}

function M.new(hl)
    local on = false
    local floated = {}

    local function float(window, action)
        hl.dispatch(hl.dsp.window.float({ action = action, window = window }))
    end

    local mode = {}

    function mode.active()
        return on
    end

    function mode.toggle()
        if on then
            for _, window in ipairs(hl.get_windows()) do
                if floated[window.address] and window.floating then float(window, "disable") end
            end
            floated = {}
            on = false
        else
            for _, window in ipairs(hl.get_windows()) do
                if not window.floating then
                    float(window, "enable")
                    floated[window.address] = true
                end
            end
            on = true
        end
    end

    function mode.opened(window)
        if on and window and not window.floating then
            float(window, "enable")
            floated[window.address] = true
        end
    end

    function mode.closed(window)
        if window then floated[window.address] = nil end
    end

    return mode
end

return M
