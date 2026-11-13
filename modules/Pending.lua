local _, NS = ...
-- modules/Pending.lua — the drops seen but not yet assigned (Forever port design §5.2, plan
-- DW-FP14): every group-loot drop whose roll is still open, held beside the feed and never in it,
-- because a rolling drop has no looter yet and every feed consumer assumes one.
--
--   item = { id, kind = "roll", key = "encounterID:dropKey", encounterID, dropKey, link, itemID, at,
--            state = open | won | allPassed | expired, facts, me, roll, rollID }
--
-- `roll` is NS.Compat.LootHistoryRolls' plain table (core/CompatLoot.lua), replaced whole on each
-- change; `facts` is the item facts cache's table and `me` your verdict through the feed's own
-- judge (NS.LootFeed.GateFor); `rollID` is your own roll popup's id once claimed (START_LOOT_ROLL,
-- joined by item ID, the oldest unclaimed item first, so two copies of one item keep their own
-- popup: Review Focus 1). An item's tables are the store's own: read them, never write them.
-- (`kind = "ml"`, the master-loot drops of design §6, lands with DW-FP18.)
--
-- THE LIFECYCLE (design §5.2). LOOT_HISTORY_UPDATE_ENCOUNTER walks the encounter's drops and opens
-- each open one that passes the feed's pre-looter gates (design §11.1, NS.FeedFilter.PassesForMe
-- through LootFeed.GateFor): PendingChanged(id, "open"). LOOT_HISTORY_UPDATE_DROP re-reads one
-- drop: a changed table sends PendingChanged(id, "rolls") once; a winner hands the final table to
-- the feed (LootFeed.OnLootHistoryDrop with `roll` and `pendingKey`, the feed's `history` source,
-- which merges it into a chat or encounter receipt that came first) and closes the item:
-- PendingChanged(id, "closed"). Everyone passing, or the roll's time running out with no winner
-- read, keeps the item LINGER seconds in that state, then closes it; nothing reaches the feed or
-- History, because there is no looter. A drop with a winner and no item (gated, or never seen
-- open) goes to the feed as it always did. A key once closed or gated is not opened again until
-- LOOT_HISTORY_CLEAR_HISTORY drops the live mapping.
--
-- THE TICKER. One TICK-second C_Timer ticker, alive only while an open roll exists: it re-reads
-- each open drop and closes it on a winner, everyone passing, or startTime + duration elapsed on
-- the history's own clock (Compat.LootHistoryNow). A drop the history no longer answers (cleared)
-- expires.
--
-- RELOAD (Review Focus 3). Nothing is saved: PLAYER_ENTERING_WORLD and the stand-up rebuild the
-- store from the client (every encounter's open drops, and your ActiveLootRolls), and the key
-- index keeps a second walk from opening a drop twice. The stand-down drops the store, stops the
-- ticker and cancels every linger timer.

NS.Pending = NS.Pending or {}
local P = NS.Pending
local State = NS.State

local TAG = "PENDING"

P.LINGER = 60   -- seconds an all-passed or expired roll stays shown
P.TICK = 1      -- the fallback ticker's period

local ticker
local lingers = {}
local generation = 0   -- bumped at every stand-down: an item load answering after it is ignored

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function now() return GetTime() end

local function store()
    local s = State.pending
    if not s then
        s = { seq = 0, items = {}, byId = {}, byKey = {}, done = {}, loading = {}, mine = {} }
        State.pending = s
    end
    return s
end

local function send(id, cause)
    NS.Debug(TAG, "item %s: %s", tostring(id), cause)
    NS.addon:SendMessage(NS.MSG.PENDING_CHANGED, id, cause)
end

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

local function byAge(a, b)
    if a.at ~= b.at then return a.at < b.at end
    return a.id < b.id
end

--- Every pending item, oldest first (by `at`, then id).
--- @return table[]
function P.All()
    local out = {}
    for _, item in ipairs(State.pending and State.pending.items or {}) do out[#out + 1] = item end
    table.sort(out, byAge)
    return out
end

--- One pending item by its id, or nil.
function P.Get(id)
    return State.pending and State.pending.byId[id] or nil
end

--- The pending item that holds your roll popup `rollID`, or nil.
function P.ForRoll(rollID)
    for _, item in ipairs(State.pending and State.pending.items or {}) do
        if item.rollID == rollID then return item end
    end
    return nil
end

-- What a roll table shows, as one string: a change is a different string.
local function signature(roll)
    local parts = { tostring(roll.allPassed), tostring(roll.isTied), tostring(roll.myState),
        roll.leader and (tostring(roll.leader.name) .. "=" .. tostring(roll.leader.roll)) or "-" }
    for _, r in ipairs(roll.rolls or {}) do
        parts[#parts + 1] = ("%s/%s/%s/%s"):format(tostring(r.guid or r.name), tostring(r.state),
            tostring(r.roll), tostring(r.isWinner))
    end
    return table.concat(parts, ",")
end

-- Whether the roll's time has run out on the history's own clock.
local function timedOut(roll)
    local t = NS.Compat.LootHistoryNow()
    return t ~= nil and roll.startTime ~= nil and roll.duration ~= nil and t >= roll.startTime + roll.duration
end

-- ── the ticker ──────────────────────────────────────────────────────────────────────────────

local function anyOpen()
    for _, item in ipairs(State.pending and State.pending.items or {}) do
        if item.state == "open" then return true end
    end
    return false
end

local function stopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local tick

-- The ticker runs exactly while an open roll exists.
local function retune()
    local want = anyOpen() and not stoodDown()
    if want and not ticker then
        ticker = C_Timer.NewTicker(P.TICK, function() tick() end)
    elseif not want then
        stopTicker()
    end
end

-- ── the lifecycle ───────────────────────────────────────────────────────────────────────────

local function remove(item)
    local s = store()
    for i, it in ipairs(s.items) do
        if it == item then table.remove(s.items, i) break end
    end
    s.byId[item.id] = nil
    if s.byKey[item.key] == item then
        s.byKey[item.key] = nil
        s.done[item.key] = true
    end
    if lingers[item.id] then lingers[item.id]:Cancel() end
    lingers[item.id] = nil
    send(item.id, "closed")
    retune()
end

-- Everyone passed, or the time ran out: shown LINGER seconds in that state, then closed.
local function linger(item, state)
    item.state = state
    local gen = generation
    lingers[item.id] = C_Timer.NewTimer(P.LINGER, function()
        lingers[item.id] = nil
        if gen == generation and P.Get(item.id) == item then remove(item) end
    end)
    send(item.id, "rolls")
    retune()
end

-- A winner: the final table goes to the feed, and the item (if any) closes.
local function resolve(item, encounterID, dropKey, roll)
    store().done[encounterID .. ":" .. dropKey] = true
    if not item then return NS.LootFeed.OnLootHistoryDrop(encounterID, dropKey, roll) end
    item.state, item.roll = "won", roll
    NS.LootFeed.OnLootHistoryDrop(encounterID, dropKey, roll, item.id)
    remove(item)
end

-- A fresh read of an open item's table.
local function update(item, roll)
    if item.state ~= "open" then return end
    local sig = signature(roll)
    local changed = sig ~= item.sig
    item.roll, item.sig = roll, sig
    if roll.allPassed then return linger(item, "allPassed") end
    if timedOut(roll) then return linger(item, "expired") end
    if changed then send(item.id, "rolls") end
end

-- Your open roll popups claim their items: by item ID, the oldest unclaimed item first.
local function claimRolls()
    local s = store()
    local ids = {}
    for rollID in pairs(s.mine) do ids[#ids + 1] = rollID end
    table.sort(ids)
    for _, rollID in ipairs(ids) do
        if not P.ForRoll(rollID) then
            for _, item in ipairs(P.All()) do
                if item.rollID == nil and item.state == "open" and item.itemID == s.mine[rollID].itemID then
                    item.rollID = rollID
                    break
                end
            end
        end
    end
end

-- An open drop past the item load: the gates, then the item.
local function admit(encounterID, dropKey, roll, facts)
    local s, key = store(), encounterID .. ":" .. dropKey
    local ok, why, out = NS.LootFeed.GateFor(facts, NS.Situations.Current())
    if not ok then
        s.done[key] = true
        return NS.Debug(TAG, "drop %s: %s not pending (%s)", key, tostring(roll.link), tostring(why))
    end
    s.seq = s.seq + 1
    local item = { id = s.seq, kind = "roll", key = key, encounterID = encounterID, dropKey = dropKey,
        link = roll.link, itemID = NS.Item.ItemIDFromLink(roll.link), at = now(), state = "open",
        facts = facts, me = out.me, roll = roll, sig = signature(roll) }
    s.items[#s.items + 1], s.byId[item.id], s.byKey[key] = item, item, item
    send(item.id, "open")
    claimRolls()
    retune()
end

-- An open drop not yet held: load its item, then admit it (a load that answers after the drop
-- resolved, or after a stand-down, is dropped).
local function open(encounterID, dropKey, roll)
    local s, key = store(), encounterID .. ":" .. dropKey
    if s.byKey[key] or s.done[key] or s.loading[key] or not roll.link or timedOut(roll) then return end
    local gen = generation
    local facts, status = NS.ItemFacts.Request(roll.link, function(f)
        s.loading[key] = nil
        if gen ~= generation or stoodDown() then return end
        local again = NS.Compat.LootHistoryRolls(encounterID, dropKey)
        if again and not (again.winner or again.allPassed) then admit(encounterID, dropKey, again, f) end
    end)
    if status == "loading" then
        s.loading[key] = true
        return
    end
    if status == "ready" then admit(encounterID, dropKey, roll, facts) end
end

--- LOOT_HISTORY_UPDATE_DROP(encounterID, dropKey): re-read one drop. A winner goes to the feed (with
--- the item's table and id when it was pending); an open drop opens or updates its item; anything
--- else goes to the feed, which refuses it as it always did.
function P.OnDrop(encounterID, dropKey)
    if stoodDown() then return end
    local roll = NS.Compat.LootHistoryRolls(encounterID, dropKey)
    if not roll then return NS.LootFeed.OnLootHistoryDrop(encounterID, dropKey) end
    local item = store().byKey[encounterID .. ":" .. dropKey]
    if roll.winner then return resolve(item, encounterID, dropKey, roll) end
    if item then return update(item, roll) end
    if roll.allPassed then return NS.LootFeed.OnLootHistoryDrop(encounterID, dropKey) end
    open(encounterID, dropKey, roll)
end

--- LOOT_HISTORY_UPDATE_ENCOUNTER(encounterID): open every open drop of the encounter.
function P.OnEncounter(encounterID)
    if stoodDown() then return end
    for _, d in ipairs(NS.Compat.LootHistoryDropsFor(encounterID)) do
        if d.open then P.OnDrop(encounterID, d.key) end
    end
end

--- LOOT_HISTORY_CLEAR_HISTORY: the live mapping goes (the keys may be reused); the items stay
--- until the ticker finds their drops gone.
function P.OnClearHistory()
    if stoodDown() then return end
    local s = store()
    s.byKey, s.done, s.loading = {}, {}, {}
end

--- START_LOOT_ROLL(rollID): your own roll popup, claimed by its item.
function P.OnStartRoll(rollID)
    if stoodDown() then return end
    local info = NS.Compat.LootRollInfo(rollID)
    if not info then return end
    store().mine[rollID] = { itemID = NS.Item.ItemIDFromLink(info.link), link = info.link, bop = info.bop }
    claimRolls()
end

--- CANCEL_LOOT_ROLL(rollID): that popup is gone.
function P.OnCancelRoll(rollID)
    if stoodDown() then return end
    local s = store()
    s.mine[rollID] = nil
    local item = P.ForRoll(rollID)
    if item then item.rollID = nil end
end

--- Rebuild from the client (a reload, the stand-up): every encounter's open drops, then your open
--- roll popups. Idempotent: a drop already held is not opened again.
function P.Rebuild()
    if stoodDown() then return end
    for _, encounterID in ipairs(NS.Compat.LootHistoryEncounters()) do P.OnEncounter(encounterID) end
    for _, rollID in ipairs(NS.Compat.ActiveLootRolls()) do P.OnStartRoll(rollID) end
end

tick = function()
    if stoodDown() then return stopTicker() end
    local open_ = {}
    for _, item in ipairs(store().items) do
        if item.state == "open" then open_[#open_ + 1] = item end
    end
    for _, item in ipairs(open_) do
        local roll = NS.Compat.LootHistoryRolls(item.encounterID, item.dropKey)
        if not roll then
            linger(item, "expired")
        elseif roll.winner then
            resolve(item, item.encounterID, item.dropKey, roll)
        else
            update(item, roll)
        end
    end
    retune()
end

--- Whether the ticker is running (the diagnostics and the tests).
function P.Ticking() return ticker ~= nil end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- Both clients (design §5.1). LOOT_HISTORY_UPDATE_DROP was the feed's; it comes here and the feed
-- takes its won drops from P.OnDrop. PLAYER_ENTERING_WORLD is shared (core/DropWatcher.lua's
-- dispatcher).
local EVENTS = {
    { "LOOT_HISTORY_UPDATE_ENCOUNTER", "OnPendingEncounter", P.OnEncounter },
    { "LOOT_HISTORY_UPDATE_DROP", "OnPendingDrop", P.OnDrop },
    { "LOOT_HISTORY_CLEAR_HISTORY", "OnPendingClear", P.OnClearHistory },
    { "START_LOOT_ROLL", "OnPendingStartRoll", P.OnStartRoll },
    { "CANCEL_LOOT_ROLL", "OnPendingCancelRoll", P.OnCancelRoll },
    { "PLAYER_ENTERING_WORLD", "OnPendingWorldEvent", P.Rebuild },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function(_, _, ...) fn(...) end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    stopTicker()
    for _, t in pairs(lingers) do t:Cancel() end
    lingers = {}
    State.pending = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() P.Rebuild() end
