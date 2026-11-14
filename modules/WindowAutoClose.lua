local _, NS = ...
-- modules/WindowAutoClose.lua — auto-close (rolls UX design §3.6, owner ruling 4, RX-10): a window
-- that opened by itself closes X seconds after nothing is rolling and no new drop has arrived.
--
-- ARMED only by an auto-open (modules/Window.lua's maybeAutoOpen calls Arm after its Open). Window.Open
-- and Window.Close disarm first, so a manual show over an auto-open, and a manual open, never close
-- by themselves; the window's drag (Cancel, from its onDragStart) and a press anywhere in it (an
-- OnMouseDown hook on the frame and on every frame under it) cancel it for that show too.
--
-- THE COUNT is one C_Timer.NewTimer handle of `window.autoClose.seconds` (5 to 120, default 10).
-- A new drop (DropAdded) and a roll or pending item opening, changing or closing (PendingChanged)
-- start it over; so does the pointer entering the frame or any frame under it (an OnEnter hook).
-- When it runs out it closes the window only while Rolling now is empty (NS.Pending.Count of the
-- shown feed) and the pointer is not over it; otherwise it starts over, so the window closes a full count after the last
-- roll closed or the pointer left. `window.autoClose.enabled` off, or the master `autoOpen` off, and
-- the count lets go when it runs out. Combat does not matter: the close is a Hide of an owned frame
-- with no protected child (events-frames-taint), the same as the auto-open's Show.

NS.WindowAutoClose = NS.WindowAutoClose or {}
local AC = NS.WindowAutoClose

local TAG = "UI"
local MIN, MAX, DEFAULT = 5, 120, 10

local armed = false
local timer          -- the count's C_Timer handle, nil when none runs
local hooked = setmetatable({}, { __mode = "k" })   -- frames the hover and click hooks are on

local function enabled()
    return NS.Setting("autoOpen") == true and NS.Setting("window.autoClose.enabled") == true
end

local function seconds()
    local v = NS.Setting("window.autoClose.seconds")
    if type(v) ~= "number" then return DEFAULT end
    return math.min(MAX, math.max(MIN, v))
end

local function cancelTimer()
    if timer then timer:Cancel() end
    timer = nil
end

local fire

local function restart()
    cancelTimer()
    if armed then timer = C_Timer.NewTimer(seconds(), function() fire() end) end
end

-- Nothing in Rolling now, and the pointer elsewhere.
local function idle(f)
    if NS.Pending.Count(NS.Window.FeedName()) > 0 then return false end
    return not (f and f:IsMouseOver())
end

fire = function()
    timer = nil
    if not armed then return end
    if not enabled() or NS.State.windowOpen ~= true then
        AC.Disarm()
        return
    end
    if not idle(NS.Window.Frame()) then
        restart()
        return
    end
    NS.Debug(TAG, "auto-close: %d s idle after an auto-open", seconds())
    NS.Window.Close()   -- disarms
end

--- Start the count over, while armed: a new drop, a roll, a pending item, the pointer entering.
function AC.Bump()
    if armed then restart() end
end

--- Stop counting for this show: a manual show, a close, a drag, a click inside, the stand-down.
function AC.Disarm()
    armed = false
    cancelTimer()
end
AC.Cancel = AC.Disarm

-- A press lands on the control under the pointer and never bubbles to its parent, and the window's
-- face is mostly controls (its tabs, the title bar and its buttons, the rows, the filter bar). So
-- the window and every frame under it hear the press and the pointer entering themselves: one-way
-- HookScripts on frames this addon made, none of them protected. A frame is hooked once (`hooked`);
-- the walk runs at Arm and after each repaint while armed (AC.OnRefresh), so a row a repaint built
-- after the open is reached too.
local function hookOne(f)
    if hooked[f] or not f.HookScript then return end
    if f.HasScript and not (f:HasScript("OnMouseDown") and f:HasScript("OnEnter")) then return end
    hooked[f] = true
    f:HookScript("OnEnter", function() AC.Bump() end)
    f:HookScript("OnMouseDown", function() AC.Cancel() end)
end

-- `seen` is this walk's own: each frame is visited once whatever its children answer.
local function hookTree(f, seen)
    if type(f) ~= "table" or seen[f] then return end
    seen[f] = true
    hookOne(f)
    if not f.GetChildren then return end
    for _, child in ipairs({ f:GetChildren() }) do hookTree(child, seen) end
end

--- The window has just auto-opened (modules/Window.lua): count, when auto-close is on.
function AC.Arm()
    if not enabled() then return end
    hookTree(NS.Window.Frame(), {})
    armed = true
    NS.Debug(TAG, "auto-close armed: %d s", seconds())
    restart()
end

--- The window repainted (Window.Refresh): while armed, reach the frames it built since the walk.
function AC.OnRefresh()
    if armed then hookTree(NS.Window.Frame(), {}) end
end

--- Whether the count is armed for this show (the suites and the diagnostics).
--- @return boolean
function AC.Armed() return armed end

--- The count's live C_Timer handle, or nil (the suites count it on the mock's queue).
function AC.Timer() return timer end

-- Tracked, so the stand-down takes it down and the stand-up replays it (Window.lua's pattern).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.DROP_ADDED, function() AC.Bump() end)
    target:RegisterMessage(NS.MSG.PENDING_CHANGED, function() AC.Bump() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    AC.Disarm()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
