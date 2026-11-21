-- Alt + Tab (owner's request): switches between the windows on the current
-- workspace, most recent first, as on Windows. Holding Alt, Tab steps further
-- back and Shift + Tab forward; Esc goes back to where it started.
--
-- Tiled windows take focus as Tab steps, with no card. When every window is
-- floating, `notify` tells the shell to draw its card instead (`open <seq>
-- <addresses> <index>`, `hide <seq>`), and letting go of Alt focuses the
-- choice and brings it to the front. Each `bloom ipc` runs as its own
-- process, so messages can land out of order: every one carries the whole
-- state and a rising seq, and the shell drops older ones. A tile the shell
-- focused on click wins over the choice here.
--
-- Alt's release bind can be missed (Alt let go while another key is held, a
-- grab), so while a cycle runs a timer also watches for Alt being let go.
local M = {}

local WATCH_MS = 30

function M.new(hl, notify)
    local cycle = nil
    local seq = 0
    local watch = nil
    local mode = {}

    local function send(message)
        seq = seq + 1
        local verb, rest = message:match("^(%a+)(.*)$")
        notify(verb .. " " .. seq .. rest)
    end

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

    local function alt_down()
        return hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")
    end

    local function focus(window)
        hl.dispatch(hl.dsp.focus({ window = window }))
        if window.floating then hl.dispatch(hl.dsp.window.bring_to_top()) end
    end

    local function open()
        local addresses = {}
        for i, window in ipairs(cycle.windows) do addresses[i] = window.address end
        send("open " .. table.concat(addresses, ",") .. " " .. (cycle.index - 1))
    end

    local function finish()
        local done = cycle
        cycle = nil
        if watch then watch:set_enabled(false) end
        if done.card then send("hide") end
        done.escape:unbind()
        return done
    end

    function mode.cycling()
        return cycle ~= nil
    end

    function mode.cancel()
        if not cycle then return end
        local done = finish()
        if not done.card and done.start then focus(done.start) end
    end

    function mode.step(direction)
        if cycle then
            cycle.index = (cycle.index - 1 + direction) % #cycle.windows + 1
            if cycle.card then open() else focus(cycle.windows[cycle.index]) end
            return
        end
        local list = windows()
        if #list < 2 then return end
        local card = true
        for _, window in ipairs(list) do card = card and window.floating end
        cycle = { windows = list, index = direction > 0 and 2 or #list, start = hl.get_active_window(), card = card }
        if card then open() end
        cycle.escape = hl.bind("Escape", mode.cancel, { ignore_mods = true })
        if not card then focus(cycle.windows[cycle.index]) end
        -- Only watch when Hyprland reports Alt held, so a key name it doesn't
        -- know can't end every cycle at once; the release bind still ends it.
        if alt_down() then
            if watch then watch:set_enabled(true)
            else watch = hl.timer(function() if cycle and not alt_down() then mode.commit() end end, { timeout = WATCH_MS, type = "repeat" }) end
        end
    end

    function mode.commit()
        if not cycle then return end
        local done = finish()
        if not done.card then return end
        local active = hl.get_active_window()
        if (active and active.address) ~= (done.start and done.start.address) then return end
        focus(done.windows[done.index])
    end

    return mode
end

return M
