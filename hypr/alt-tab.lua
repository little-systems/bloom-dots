-- Alt + Tab (owner's request): switches between the windows on the current
-- workspace, most recent first, as on Windows. Holding Alt, Tab steps further
-- back and Shift + Tab forward; releasing Alt focuses the choice and brings a
-- floating one to the front. Esc cancels. The switching lives here, where it
-- is immediate; `notify` tells the shell what to draw (`open <addresses>
-- <index>`, `select <index>`, `hide`), and the shell finds titles and live
-- previews itself. A tile the shell focused on click wins over the choice here.
local M = {}

function M.new(hl, notify)
    local cycle = nil

    local function windows()
        local workspace = hl.get_active_workspace()
        local list = {}
        if not workspace then return list end
        for _, window in ipairs(hl.get_windows()) do
            if window.workspace and window.workspace.id == workspace.id and window.mapped ~= false and not window.hidden then
                list[#list + 1] = window
            end
        end
        table.sort(list, function(a, b) return a.focus_history_id < b.focus_history_id end)
        return list
    end

    local function finish()
        local done = cycle
        cycle = nil
        notify("hide")
        done.escape:unbind()
        return done
    end

    local mode = {}

    function mode.cycling()
        return cycle ~= nil
    end

    function mode.cancel()
        if cycle then finish() end
    end

    function mode.step(direction)
        if cycle then
            cycle.index = (cycle.index - 1 + direction) % #cycle.windows + 1
            notify("select " .. (cycle.index - 1))
            return
        end
        local list = windows()
        if #list < 2 then return end
        local addresses = {}
        for i, window in ipairs(list) do addresses[i] = window.address end
        local active = hl.get_active_window()
        cycle = { windows = list, index = direction > 0 and 2 or #list, start = active and active.address }
        notify("open " .. table.concat(addresses, ",") .. " " .. (cycle.index - 1))
        cycle.escape = hl.bind("Escape", mode.cancel, { ignore_mods = true })
    end

    function mode.commit()
        if not cycle then return end
        local done = finish()
        local active = hl.get_active_window()
        if (active and active.address) ~= done.start then return end
        local window = done.windows[done.index]
        hl.dispatch(hl.dsp.focus({ window = window }))
        if window.floating then hl.dispatch(hl.dsp.window.bring_to_top()) end
    end

    return mode
end

return M
