-- Alt + Tab (owner's request): switches between the windows on the current
-- workspace, most recent first, as on Windows. Holding Alt, Tab steps further
-- back and Shift + Tab forward; Esc goes back to where it started.
--
-- Tiled windows take focus as Tab steps, with no card. When every window is
-- floating, `notify` tells the shell to draw its card instead (`open <seq>
-- <addresses> <index>`, or `reveal` to skip the shell's wait; `hide <seq>`), and letting go of Alt focuses the
-- choice and brings it to the front. Each `bloom ipc` runs as its own
-- process, so messages can land out of order: every one carries the whole
-- state and a rising seq, and the shell drops older ones. A tile the shell
-- focused on click wins over the choice here.
--
-- Alt's release bind can be missed (Alt let go while another key is held, a
-- grab), so while a cycle runs a timer also watches for Alt being let go.
--
-- A three-finger horizontal swipe (owner's request) drives the same cycle
-- through `gesture` ({ start, update, finish }, Hyprland's gesture
-- callbacks): a quick swipe goes back to the last window, as a quick Alt +
-- Tab does. Keeping the fingers down HOLD_MS shows the card, tiled windows
-- too, starting on the focused window, and every STEP of travel moves the
-- choice (right is next, the owner's choice); lifting switches to it. A
-- cancelled swipe or Esc changes nothing.
local M = {}

local WATCH_MS = 30
local HOLD_TICK_MS = 20
local HOLD_MS = 100
local STEP = 80

function M.new(hl, notify)
    local cycle = nil
    local seq = 0
    local watch = nil
    local holder = nil
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

    -- `reveal` shows the card at once (a held swipe has waited already);
    -- `open` lets the shell wait, so a quick Alt + Tab never flashes it.
    local function open(verb)
        local addresses = {}
        for i, window in ipairs(cycle.windows) do addresses[i] = window.address end
        send((verb or "open") .. " " .. table.concat(addresses, ",") .. " " .. (cycle.index - 1))
    end

    local function finish()
        local done = cycle
        cycle = nil
        if watch then watch:set_enabled(false) end
        if holder then holder:set_enabled(false) end
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
        if not done.card and not done.swipe and done.start then focus(done.start) end
    end

    local function move(direction)
        cycle.index = (cycle.index - 1 + direction) % #cycle.windows + 1
        -- Tiled Alt + Tab focuses as it goes; a swipe switches when lifted.
        if cycle.card then open() elseif not cycle.swipe then focus(cycle.windows[cycle.index]) end
    end

    -- Focuses the choice unless a tile was clicked (the shell focused it).
    local function switch(done)
        local active = hl.get_active_window()
        if (active and active.address) ~= (done.start and done.start.address) then return end
        focus(done.windows[done.index])
    end

    function mode.step(direction)
        if cycle then
            if not cycle.swipe then move(direction) end
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
        if not cycle or cycle.swipe then return end
        local done = finish()
        if done.card then switch(done) end
    end

    local function held()
        if not cycle or not cycle.swipe or cycle.card then return end
        cycle.held = cycle.held + HOLD_TICK_MS
        if cycle.held < HOLD_MS then return end
        cycle.card = true
        holder:set_enabled(false)
        open("reveal")
    end

    mode.gesture = {}

    function mode.gesture.start()
        if cycle then return end
        local list = windows()
        if #list < 2 then return end
        -- Starts on the focused window, so a held swipe steps from there.
        cycle = { windows = list, index = 1, start = hl.get_active_window(), card = false, swipe = true, held = 0, travel = 0 }
        cycle.escape = hl.bind("Escape", mode.cancel, { ignore_mods = true })
        if holder then holder:set_enabled(true)
        else holder = hl.timer(held, { timeout = HOLD_TICK_MS, type = "repeat" }) end
    end

    function mode.gesture.update(event)
        if not cycle or not cycle.swipe then return end
        cycle.travel = cycle.travel + ((event and event.delta and event.delta.x) or 0)
        while cycle.travel >= STEP do
            cycle.travel = cycle.travel - STEP
            move(1)
        end
        while cycle.travel <= -STEP do
            cycle.travel = cycle.travel + STEP
            move(-1)
        end
    end

    function mode.gesture.finish(event)
        if not cycle or not cycle.swipe then return end
        if event and event.cancelled then return mode.cancel() end
        local done = finish()
        -- A quick swipe that didn't step goes back to the last window.
        if not done.card and done.index == 1 then done.index = 2 end
        switch(done)
    end

    return mode
end

return M
