local _, NS = ...
-- modules/TestMode.lua — test mode (design spec §11.6, boards 03 and 06; ui spec §4): sample drops
-- in every verdict, trade, inspect and ask state the window draws, over REAL items, put in the test
-- feed when test mode turns on and cleared when it turns off, so the layout and position can be
-- checked anywhere, solo and out of an instance; and the History tab's sample groups.
--
-- THE DATA is modules/TestData.lua's (pure). This file is the edge: the items, the hooks the UI
-- reads, and populate and clear.
--
-- THE ITEMS (FB-9). Turning test mode on builds the simulator's item pool (modules/SimPool.lua,
-- BuildInto: the Encounter Journal at the current season's Mythic Keystone difficulty, every
-- class's loot, falling back to your own equipped and bag gear) into test mode's own holder
-- (State.testPool). The drops fill in when it is ready: at once when the journal has loaded, else
-- after EJ_LOOT_DATA_RECIEVED or the pool's timeout, never with an invented item meanwhile (the
-- Drops tab says it is gathering them). Each item's facts are the item cache's
-- (NS.ItemFacts.Get), else the pool's level and slot with the link's quality.
--
-- THE HISTORY (FB-10). While test mode is on, the History tab reads test mode's own session-only
-- log (State.testHistory, NS.History.Log): two sample groups covering every outcome. It is never
-- written to `global.history` and goes when test mode turns off.
--
-- THE HOOKS. A sample carries its own inspect entry (`testInspect`, read in place of
-- NS.Inspect.Get) and its own ask state (`testAsk`, shown while the messaging edge holds none for
-- it): TM.InspectOf and TM.AskState are what the Drops table and the detail card read. A click
-- on a sample's Ask, Offer or Announce goes through the messaging edge, which prints the text
-- instead of sending it (modules/Asks.lua): nothing is ever whispered in test mode.
--
-- THE GATES. Samples skip the situation and quality gates, ask for no inspect and are never
-- re-judged (modules/LootFeed.lua AddTest). While test mode is on, the Drops tab's View is
-- All, so every state is on screen; turning it off puts the player's View back.
--
-- NS.SetTestMode (core/DropWatcher.lua) calls Populate and Clear; the stand-down clears too.

NS.TestMode = NS.TestMode or {}
local TM    = NS.TestMode
local TD    = NS.TestData
local C     = NS.Constants
local L     = NS.L
local State = NS.State

local TAG = "State"

local savedView   -- the Drops tab's View before test mode set it to All

--- The pool test mode builds: the dungeons at Mythic Keystone, every class's loot.
TM.POOL = { situation = "mythicPlus", classFilter = "any" }

--- Every sample drop over `src` (modules/TestData.lua). Pure.
--- @param now number GetTime()
--- @param you table your looter
--- @param src table NS.TestData.Source's
--- @return table specs
function TM.Placeholders(now, you, src)
    return TD.Placeholders(now, you, src)
end

-- ── the hooks the UI reads ──────────────────────────────────────────────────────────────────

--- A drop's looter's inspect entry: a placeholder's own, else NS.Inspect.Get's. Nil for your own
--- drop or a looter with no GUID.
--- @param drop table
--- @return table|nil
function TM.InspectOf(drop)
    if type(drop) ~= "table" or drop.isMine then return nil end
    if drop.test then return drop.testInspect end
    local guid = type(drop.looter) == "table" and drop.looter.guid
    if not guid then return nil end
    return NS.Inspect.Get(guid)
end

--- The ask state a row shows: the messaging edge's, or a placeholder's own while the edge holds
--- none for it (a click on it is the edge's from then on).
--- @param drop table
--- @param state string NS.Asks.StateOf's state
--- @param reason string|nil
--- @return string state, string|nil reason
function TM.AskState(drop, state, reason)
    local own = type(drop) == "table" and drop.test and drop.testAsk
    if state == "ready" and type(own) == "table" then return own.state, own.reason end
    return state, reason
end

-- ── the items ───────────────────────────────────────────────────────────────────────────────

local function you()
    local Compat = NS.Compat
    local name = Compat.UnitName("player")
    local _, classFile = Compat.UnitClass("player")
    return { name = name or L["You"], guid = Compat.UnitGUID("player"), classFile = classFile, isSelf = true,
        seenBy = NS.CharFilter.CurrentKey() }
end

-- An entry's facts: the item cache's, else the pool's level and slot with the link's quality.
local function factsOf(e)
    local f = NS.ItemFacts.Get(e.link)
    if f then return f end
    return { link = e.link, itemID = e.itemID, ilvl = e.ilvl, equipLoc = e.equipLoc,
        quality = (NS.ItemRead.QualityOf(e.link)) }
end

--- The item source over a built pool: its drops (the entries at its own difficulty, every gear
--- entry when none is) and its gear.
--- @param pool table|nil
--- @return table src
function TM.Source(pool)
    local P = NS.SimPool
    local gear, atLevel = P.GearEntries(pool), {}
    for _, e in ipairs(P.Drops(pool)) do atLevel[e] = true end
    local drops = {}
    for _, e in ipairs(gear) do
        if atLevel[e] then drops[#drops + 1] = e end
    end
    return TD.Source(#drops > 0 and drops or gear, gear, factsOf)
end

--- Samples for a message template's preview (the settings' Messages page) when the feed holds no
--- drop: over test mode's pool while it has one, else over your own equipped gear. No pool is built.
--- @return table specs
function TM.PreviewSpecs()
    local holder = State.testPool
    local now = GetTime()
    if holder and holder.pool then return TD.Placeholders(now, you(), TM.Source(holder.pool)) end
    local worn = {}
    for _, e in pairs(NS.Gear.Snapshot().equipped) do
        if type(e) == "table" and e.link and C.SLOT_PLAN[e.equipLoc] then worn[#worn + 1] = e end
    end
    table.sort(worn, function(a, b) return a.link < b.link end)
    return TD.Placeholders(now, you(), TD.Source(worn, worn, function(e) return e end))
end

--- True while test mode's pool is still being built (the Drops tab says so).
--- @return boolean
function TM.IsLoading()
    local holder = State.testPool
    return holder ~= nil and holder.poolBuild ~= nil
end

--- The History tab's log while test mode is on (NS.History.Log): its session-only sample groups.
--- @return table log
function TM.HistoryLog()
    State.testHistory = State.testHistory or { v = 1, groups = {} }
    return State.testHistory
end

-- ── populate and clear ──────────────────────────────────────────────────────────────────────

local function showEverything()
    local FB = NS.WindowFilterBar
    if not FB then return end
    savedView = savedView or FB.State("group").view
    FB.Set("group", "view", {})
end

local function restoreView()
    local FB, v = NS.WindowFilterBar, savedView
    savedView = nil
    if FB and v then FB.Set("group", "view", v) end
end

-- The pool's timers: each runs only while its holder is still test mode's; Clear cancels them.
local function afterFor(holder)
    return function(delay, fn)
        local t
        t = C_Timer.NewTimer(delay, function()
            holder.timers[t] = nil
            if State.testPool == holder then fn() end
        end)
        holder.timers[t] = true
        return t
    end
end

-- Let the pool go: its timers canceled, its build left behind.
local function releasePool()
    local holder = State.testPool
    State.testPool = nil
    if not holder then return end
    for t in pairs(holder.timers) do t:Cancel() end
    holder.timers = {}
end

local function changed()
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
end

-- The pool is ready: the samples into the test feed, the sample groups into the History tab.
local function fill(pool)
    local LF, n = NS.LootFeed, 0
    for _, spec in ipairs(TD.Placeholders(GetTime(), you(), TM.Source(pool))) do
        if LF.AddTest(spec) then n = n + 1 end
    end
    TM.HistoryLog().groups = TD.History(time(), you(), TM.Source(pool)).groups
    changed()
    if n == 0 then NS.Print(L["Test mode found no items to show."]) end
    NS.Debug(TAG, "test mode: %d sample drops from %d pool items (%s)", n, #pool.entries, tostring(pool.source))
    return n
end

--- Fill the test feed with the samples (test mode turned on): the test feed is emptied, then the
--- item pool is built and the samples added once it is ready (at once when nothing has to load).
--- @return number the drops added so far
function TM.Populate()
    NS.LootFeed.Clear("test")
    releasePool()
    State.testHistory = { v = 1, groups = {} }
    showEverything()
    local holder = { timers = {} }
    State.testPool = holder
    local host = {
        alive = function() return State.testPool == holder and State.testMode == true end,
        after = afterFor(holder),
        fallbackLine = L["The Encounter Journal gave no items, so test mode shows your own gear instead."],
    }
    NS.SimPool.BuildInto(holder, host, TM.POOL, fill)
    return #NS.LootFeed.Drops("test")
end

--- Empty the test feed and the sample history (test mode turned off), let the pool go and put the
--- Drops tab's View back.
function TM.Clear()
    releasePool()
    NS.LootFeed.Clear("test")
    if State.testHistory then
        State.testHistory = nil
        changed()
    end
    restoreView()
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    TM.Clear()
end
