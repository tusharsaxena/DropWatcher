local _, NS = ...
-- modules/WindowAutoClose.lua — auto-close (rolls UX design §3.6, owner ruling 4, RX-10): a window
-- that opened by itself closes X seconds after nothing is rolling and no new drop has arrived.
--
-- ARMED only by an auto-open (modules/Window.lua's maybeAutoOpen calls Arm after its Open). Window.Open
-- and Window.Close disarm first, so a manual show over an auto-open, and a manual open, never close
-- by themselves; the window's drag (Cancel, from its onDragStart) and a press anywhere in it (an
-- OnMouseDown hook on the frame and on every frame under it, but the read-only Rolls panel's,
-- AC.PointerOnly) cancel it for that show too.
--
-- THE COUNT is one C_Timer.NewTimer handle of `window.autoClose.seconds` (5 to 120, default 10).
-- A new drop (DropAdded) and a roll or pending item opening, changing or closing (PendingChanged)
-- start it over; so does the pointer entering or leaving the frame or any frame under it (OnEnter
-- and OnLeave hooks), so the window closes a full count after the pointer left it.
-- When it runs out it closes the window only while nothing in Rolling now is a roll still open (a
-- master-loot item awaiting the master looter, and an everyone-passed or expired roll lingering
-- P.LINGER seconds, do not count: RX-29), the Rolls panel holds no block (RX-17: the panel
-- starts the count over when its last block leaves, AC.Bump; one its close button put away holds
-- nothing, RX-28) and the pointer is not over it;
-- otherwise it starts over, so the window closes a full count after the last roll closed, the
-- panel's last block left or the pointer left. `window.autoClose.enabled` off, or the master `autoOpen` off, and
-- the count lets go when it runs out. Combat does not matter: the close is a Hide of an owned frame
-- with no protected child (events-frames-taint), the same as the auto-open's Show. A window the
-- visibility ladder hides (General visibility, in or out of combat), or one off screen with a hidden
-- parent (Alt-Z, a cinematic), is never closed by the count: its OnHide stops the count, which
-- starts over when the window shows (RX-29). Escape or the close mark, a hide of the frame itself,
-- disarms it at once (Window's onHide). A test drop's auto-open (test mode on) arms nothing: test
-- mode's window stays until test mode goes off, which closes it (RX-29). Test mode turned on over a
-- live auto-open lets the count go when it runs out, and the window stays open after (RX-29).

NS.WindowAutoClose = NS.WindowAutoClose or {}
local AC = NS.WindowAutoClose

local TAG = "UI"
local MIN, MAX, DEFAULT = 5, 120, 10

local armed = false
local timer          -- the count's C_Timer handle, nil when none runs
local hooked = setmetatable({}, { __mode = "k" })   -- frames the hover and click hooks are on
local kids = setmetatable({}, { __mode = "k" })     -- frame -> its children as the last walk read them
local seen = setmetatable({}, { __mode = "k" })     -- frame -> the walk stamp that last visited it
local stamp = 0
local pointerOnly = setmetatable({}, { __mode = "k" })   -- subtrees a press does not cancel in (AC.PointerOnly)

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

-- On screen: shown, under a shown parent.
local function onScreen()
    local f = NS.Window.Frame()
    if not f then return false end
    if f.IsVisible then return f:IsVisible() == true end
    return f:IsShown() == true
end

-- A count runs only while the window is on screen; off screen it waits for the show's Bump.
local function restart()
    cancelTimer()
    if armed and onScreen() then timer = C_Timer.NewTimer(seconds(), function() fire() end) end
end

-- Whether anything in the shown feed's pending store is a roll. A master-loot item awaiting the
-- master looter (kind `ml`, modules/PendingML.lua, held up to 900 s) is listed in Rolling now but
-- rolls nothing, so it does not hold the window open (ruling 4: "after nothing is rolling"), nor
-- does a roll everyone passed or whose time ran out, shown P.LINGER seconds in that state (RX-29);
-- with `rolls.show` off Rolling now lists nothing, and a roll the window does not show holds nothing.
local OVER = { allPassed = true, expired = true }

local function rolling()
    local feed = NS.Window.FeedName()
    if NS.WindowPending.None() then return false end   -- the common case builds no list
    for _, item in ipairs(NS.Pending.All(feed)) do
        if item.kind ~= "ml" and not OVER[item.state] then return true end
    end
    return false
end

-- On screen, nothing rolling, no block in the Rolls panel (a finished roll lingering there holds
-- the window open, rolls panel design §3.4, RX-17), and the pointer elsewhere. A window the
-- visibility ladder hides (General visibility, in or out of combat) keeps NS.State.windowOpen true
-- and is not idle: it waits, and the count starts over when it shows (the visibility listener below).
local function idle(f)
    if not (f and f:IsShown()) then return false end
    if rolling() then return false end
    if NS.RollsPanel and NS.RollsPanel.HoldsWindow() then return false end
    return not (f and f:IsMouseOver())
end

fire = function()
    timer = nil
    if not armed then return end
    -- Test mode on over a live auto-open: test mode's window is the player's to look at.
    if not enabled() or NS.State.windowOpen ~= true or NS.State.testMode == true then
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
-- the window and every frame under it hear the press and the pointer entering and leaving: one-way
-- HookScripts on frames this addon made, none of them protected. A frame is hooked once (`hooked`);
-- the walk runs at Arm and after each repaint while armed (AC.OnRefresh), so a row a repaint built
-- after the open is reached too. The walk keeps each frame's children as it last read them (`kids`)
-- and reads them again only when GetNumChildren moved, so a repaint that built nothing builds no
-- GetChildren table (RX-29); `seen` is stamped per walk, so a walk allocates nothing either. Only a frame that already takes the mouse is hooked: one the
-- window leaves mouse-transparent on purpose (a row's text cells, an icon's border and glow, a
-- pane) is skipped, since a mouse script on it can mouse-enable it and steal the hover and the
-- press from the control beneath; the pointer over it is over a mouse-enabled frame anyway.
-- Under a frame AC.PointerOnly named (the Rolls panel, a read-only companion docked beside the
-- window, RX-20) the pointer still starts the count over, but a press does not cancel it: a click
-- there reads a roll or puts the panel away, and is no use of the window.
local function hookOne(f, passive)
    if hooked[f] or not f.HookScript then return end
    if f.IsMouseEnabled and not f:IsMouseEnabled() then return end
    if f.HasScript and not (f:HasScript("OnMouseDown") and f:HasScript("OnEnter") and f:HasScript("OnLeave")) then
        return
    end
    hooked[f] = true
    f:HookScript("OnEnter", function() AC.Bump() end)
    f:HookScript("OnLeave", function() AC.Bump() end)
    if not passive then f:HookScript("OnMouseDown", function() AC.Cancel() end) end
end

-- The frame's children: the cached list while their count has not moved.
local function childrenOf(f)
    local list = kids[f]
    local n = f.GetNumChildren and f:GetNumChildren() or nil
    if list == nil or n == nil or n ~= #list then
        list = { f:GetChildren() }
        kids[f] = list
    end
    return list
end

-- Each frame is visited once per walk (its `seen` stamp) whatever its children answer.
local function hookTree(f, passive)
    if type(f) ~= "table" or seen[f] == stamp then return end
    seen[f] = stamp
    passive = passive or pointerOnly[f] == true
    hookOne(f, passive)
    if not f.GetChildren then return end
    for _, child in ipairs(childrenOf(f)) do hookTree(child, passive) end
end

local function walk()
    stamp = stamp + 1
    hookTree(NS.Window.Frame(), false)
end

--- Name a frame under the window whose subtree only hears the pointer: a press there keeps the
--- count (the Rolls panel, RX-20).
--- @param f table
function AC.PointerOnly(f)
    if type(f) == "table" then pointerOnly[f] = true end
end

--- The window has just auto-opened (modules/Window.lua): count, when auto-close is on.
function AC.Arm()
    if not enabled() or NS.State.testMode == true then return end
    walk()
    armed = true
    NS.Debug(TAG, "auto-close armed: %d s", seconds())
    restart()
end

--- The window repainted (Window.Refresh): while armed, reach the frames it built since the walk.
function AC.OnRefresh()
    if armed then walk() end
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

-- The window went off screen (the ladder, a parent's hide): the count stops, and a full count runs
-- from when it is on screen again (Bump checks armed). A hide of the frame itself disarms instead
-- (Window's onHide calls AC.Disarm first).
NS.Window.AddVisibilityListener(function(shown)
    if shown then AC.Bump() else cancelTimer() end
end)

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    AC.Disarm()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
