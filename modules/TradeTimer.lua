local _, NS = ...
-- modules/TradeTimer.lua — the exact trade countdown on your own drops (design spec §7.4).
--
--   entry = { guid, dropID, itemID, link, bag, slot, expiresAt | nil, expired, warned }
--
-- One entry per bag item that matches one of your recorded drops, keyed by the item's GUID
-- (NS.Compat.GetBagItemGUID), so a moved item keeps its timer. `expiresAt` is in GetTime()
-- seconds; `expired` is true once the window has passed, and when the item's tooltip carries no
-- trade-time line at all (a BoP upgrade you cannot trade, or a window already gone): spec §7.4's
-- `no expired`. `warned` is set once the item has warned. Entries are the module's own: read them,
-- never write them.
--
-- THE SCAN. BAG_UPDATE_DELAYED, LOOT_CLOSED and a DropAdded for one of your own drops each ask for
-- a scan; scans run at most once per THROTTLE seconds, the asks inside it sharing one. A scan walks
-- the bags only while you have own drops in the live feed (test drops never), matching a bag item
-- to a drop by its exact link first, then by its item id, each drop taken by one item at most. The
-- remaining time is read from the item's TradeTimeRemaining tooltip line, or the
-- BIND_TRADE_TIME_REMAINING sentence decoded with the client's duration globals
-- (NS.Compat.TradeTimeRemaining); the tooltip shows whole minutes, so a re-read within a minute of
-- the stored expiry keeps it. An entry whose item has left the bags is dropped.
--
-- THE TICKER. One shared C_Timer.NewTicker, alive only while at least one entry is live (not
-- expired): every FAST second while the window is shown, else every SLOW seconds. Each tick
-- expires what has run out, warns, and sends TradeTimerTick (no payload); a scan that found own
-- drops, or dropped the last entries, sends it too.
-- The ticker follows the window through NS.Window.AddVisibilityListener (the frame's OnShow and
-- OnHide), so showing the window moves it to FAST at once and hiding it back to SLOW.
--
-- THE WARNING. Once per item, when its remaining time first falls to `trade.warnAt` seconds or
-- less (C.TRADE_WARN_AT when not stored; 0 turns it off): TradeTimerExpiring(dropID, guid,
-- remaining) is sent, and one line is printed to chat.
--
-- Stood down, the ticker and the throttle timer are canceled; the entries are kept (their warned
-- flags with them), and the stand-up scans again.

NS.TradeTimer = NS.TradeTimer or {}
local TT = NS.TradeTimer
local C = NS.Constants
local L = NS.L
local State = NS.State
local Perf = NS.Perf

local TAG = "TRADE"

TT.THROTTLE = 2
TT.FAST = 1
TT.SLOW = 60

local scanTimer          -- the throttled scan, when armed
local ticker, tickerPeriod
local listeningToWindow = false   -- the window's visibility listener is registered

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function now() return GetTime() end

local function store()
    local s = State.tradeTimer
    if not s then
        s = { timers = {}, scans = 0 }
        State.tradeTimer = s
    end
    return s
end

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

--- Seconds left on an entry, 0 once expired.
--- @param e table
--- @return number
function TT.Remaining(e)
    if e.expired or not e.expiresAt then return 0 end
    local left = e.expiresAt - now()
    return left > 0 and left or 0
end

local function isLive(e)
    return not e.expired and e.expiresAt ~= nil
end

--- How many entries are live (not expired).
--- @return number
function TT.LiveCount()
    local n = 0
    for _, e in pairs(store().timers) do
        if isLive(e) then n = n + 1 end
    end
    return n
end

--- The entry of an item GUID, or nil.
--- @param guid string
--- @return table|nil
function TT.Get(guid)
    return store().timers[guid]
end

--- The entry of one of your drops, or nil when no bag item has been matched to it.
--- @param dropID number
--- @return table|nil
function TT.ForDrop(dropID)
    for _, e in pairs(store().timers) do
        if e.dropID == dropID then return e end
    end
    return nil
end

--- Every entry, keyed by item GUID. Read it, never write it.
--- @return table
function TT.Entries()
    return store().timers
end

--- The warning threshold in seconds: `profile.trade.warnAt` when stored (DW-40 adds the row),
--- else C.TRADE_WARN_AT. 0 or less turns the warning off.
--- @return number
function TT.WarnAt()
    local p = NS.db and NS.db.profile
    local t = p and p.trade
    local v = type(t) == "table" and t.warnAt or nil
    if type(v) == "number" and v == v then return v end
    return C.TRADE_WARN_AT
end

--- The ticker's period in seconds, or nil while no ticker runs.
--- @return number|nil
function TT.TickerPeriod()
    return tickerPeriod
end

--- Diagnostics: { live, expired, scans, lastScanAt, period }, or nil before the first scan.
--- @return table|nil
function TT.Stats()
    local s = State.tradeTimer
    if not s then return nil end
    local live, expired = 0, 0
    for _, e in pairs(s.timers) do
        if isLive(e) then live = live + 1 else expired = expired + 1 end
    end
    return { live = live, expired = expired, scans = s.scans, lastScanAt = s.lastScanAt, period = tickerPeriod }
end

-- ── the warning and the expiry ──────────────────────────────────────────────────────────────

local function warn(e, left)
    e.warned = true
    NS.Debug(TAG, "expiring: drop %s %s, %ds left", tostring(e.dropID), e.link, math.floor(left))
    NS.Print(L["%s: %d min left to trade it."]:format(e.link, math.ceil(left / 60)))
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_EXPIRING, e.dropID, e.guid, left)
end

-- Expires what has run out and warns what has reached the threshold.
local function sweep()
    local warnAt = TT.WarnAt()
    for _, e in pairs(store().timers) do
        if isLive(e) then
            local left = TT.Remaining(e)
            if left <= 0 then
                e.expired = true
            elseif not e.warned and warnAt > 0 and left <= warnAt then
                warn(e, left)
            end
        end
    end
end

-- ── the ticker ──────────────────────────────────────────────────────────────────────────────

local function windowShown()
    return NS.Window ~= nil and NS.Window.IsShown() == true
end

-- Follow the window's visibility: registered once, on the first retune (modules/Window.lua loads
-- after this file).
local function listenToWindow()
    if listeningToWindow or not (NS.Window and NS.Window.AddVisibilityListener) then return end
    listeningToWindow = true
    NS.Window.AddVisibilityListener(function() TT.Retune() end)
end

local function wantedPeriod()
    if stoodDown() or TT.LiveCount() == 0 then return nil end
    return windowShown() and TT.FAST or TT.SLOW
end

local function stopTicker()
    if ticker then ticker:Cancel() end
    ticker, tickerPeriod = nil, nil
end

local onTick

--- Start, stop or re-period the shared ticker to match the live entries and the window.
function TT.Retune()
    listenToWindow()
    local want = wantedPeriod()
    if want == tickerPeriod then return end
    stopTicker()
    if want then
        ticker, tickerPeriod = C_Timer.NewTicker(want, function() onTick() end), want
    end
end

onTick = function()
    if stoodDown() then return stopTicker() end
    sweep()
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    TT.Retune()
end

-- ── the scan ────────────────────────────────────────────────────────────────────────────────

-- Your own live drops, by exact link and by item id.
local function ownDrops()
    local own = { byLink = {}, byItemID = {}, byId = {}, n = 0 }
    for _, rec in ipairs(NS.LootFeed.Drops()) do
        if rec.isMine and not rec.test then
            own.n = own.n + 1
            own.byId[rec.id] = rec
            own.byLink[rec.link] = own.byLink[rec.link] or {}
            table.insert(own.byLink[rec.link], rec)
            own.byItemID[rec.itemID] = own.byItemID[rec.itemID] or {}
            table.insert(own.byItemID[rec.itemID], rec)
        end
    end
    return own
end

-- Every bag item that may be one of your drops: { bag, slot, link, itemID, guid }.
local function bagItems(own)
    local out = {}
    for _, bag in ipairs(C.BAG_IDS) do
        for slot = 1, NS.Compat.BagSlotCount(bag) do
            local link = NS.Compat.BagItemLink(bag, slot)
            local itemID = link and NS.Item.ItemIDFromLink(link)
            local guid = itemID and own.byItemID[itemID] and NS.Compat.GetBagItemGUID(bag, slot)
            if guid then
                out[#out + 1] = { bag = bag, slot = slot, link = link, itemID = itemID, guid = guid }
            end
        end
    end
    return out
end

local function firstUnclaimed(list, claimed)
    for _, rec in ipairs(list or {}) do
        if not claimed[rec.id] then return rec end
    end
    return nil
end

-- One pass over the unassigned items, each taking the first unclaimed drop `listOf` names.
local function claimPass(items, claimed, listOf)
    for _, it in ipairs(items) do
        if not it.dropID then
            local rec = firstUnclaimed(listOf(it), claimed)
            if rec then it.dropID, claimed[rec.id] = rec.id, true end
        end
    end
end

-- Each bag item's drop: the one its entry already holds, else (over every item) an unclaimed drop
-- with its exact link, else (over the rest) one with its item id.
local function assign(items, own, timers)
    local claimed = {}
    for _, it in ipairs(items) do
        local e = timers[it.guid]
        if e and own.byId[e.dropID] and not claimed[e.dropID] then
            it.dropID, claimed[e.dropID] = e.dropID, true
        end
    end
    claimPass(items, claimed, function(it) return own.byLink[it.link] end)
    claimPass(items, claimed, function(it) return own.byItemID[it.itemID] end)
end

-- One matched bag item read into its entry.
local function readEntry(it, timers, t)
    local e = timers[it.guid]
    if not e or e.dropID ~= it.dropID then
        e = { guid = it.guid, dropID = it.dropID, warned = false }
    end
    e.itemID, e.link, e.bag, e.slot = it.itemID, it.link, it.bag, it.slot
    local left = NS.Compat.TradeTimeRemaining(it.bag, it.slot)
    if left and left > 0 then
        -- The tooltip shows whole minutes: a re-read within a minute of the stored expiry keeps it,
        -- so the countdown does not jump at every scan.
        local at = t + left
        if not (e.expiresAt and math.abs(at - e.expiresAt) < 60) then e.expiresAt = at end
        e.expired = false
    else
        e.expiresAt, e.expired = nil, true
    end
    return e
end

local function scan(cause)
    local s, t = store(), now()
    local own = ownDrops()
    local items = own.n > 0 and bagItems(own) or {}
    assign(items, own, s.timers)
    local timers = {}
    for _, it in ipairs(items) do
        if it.dropID then timers[it.guid] = readEntry(it, s.timers, t) end
    end
    local had = next(s.timers) ~= nil
    s.timers, s.lastScanAt, s.scans = timers, t, s.scans + 1
    if own.n > 0 then
        NS.Debug(TAG, "scan (%s): %d own drops, %d live timers", tostring(cause), own.n, TT.LiveCount())
    end
    return had or own.n > 0
end

--- Read every own drop's bag item now, then warn, tick and retune.
--- @param cause string|nil what asked (an event name, `drop`, `standUp`)
function TT.Scan(cause)
    if stoodDown() then return end
    local t0 = Perf.on and debugprofilestop()
    local relevant = scan(cause)
    if t0 then Perf.Note("tradeTimer.scan", debugprofilestop() - t0) end
    if relevant then
        sweep()
        NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    end
    TT.Retune()
end

--- Ask for a scan: at once on the next timer pass when none ran in the last THROTTLE seconds,
--- else when that time is up. Asks while one is armed share it.
--- @param cause string|nil
function TT.Schedule(cause)
    if scanTimer or stoodDown() then return end
    local last = State.tradeTimer and State.tradeTimer.lastScanAt
    local delay = last and math.max(0, last + TT.THROTTLE - now()) or 0
    scanTimer = C_Timer.NewTimer(delay, function()
        scanTimer = nil
        TT.Scan(cause)
    end)
end

--- Whether a scan is armed.
--- @return boolean
function TT.IsScheduled()
    return scanTimer ~= nil
end

-- ── events, messages and the lifecycle ──────────────────────────────────────────────────────

-- BAG_UPDATE_DELAYED is shared with modules/Gear.lua (core/DropWatcher.lua's dispatcher).
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "BAG_UPDATE_DELAYED", "OnTradeTimerEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "LOOT_CLOSED", "OnTradeTimerEvent" }

function NS.addon.OnTradeTimerEvent(_, event)
    TT.Schedule(event)
end

-- The DropAdded receiver: tracked, so the stand-down takes it down and the stand-up replays it.
-- Without the bus library it is a bare target, unregistered here instead.
local TRACKED = LibStub and LibStub("LibKa0s-Bus-1.0", true) ~= nil
local target = NS.Bus:NewTarget()

local function onDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if rec and rec.isMine and not rec.test then TT.Schedule("drop") end
end

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.DROP_ADDED, function(_, id) onDropAdded(id) end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if scanTimer then scanTimer:Cancel() end
    scanTimer = nil
    stopTicker()
    if target and not TRACKED then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not TRACKED then listen() end
    TT.Schedule("standUp")
end
