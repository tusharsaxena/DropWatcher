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
-- `kind = "ml"`, the master-loot drops of design §6, is modules/PendingML.lua's: it holds and
-- closes its items through P.Hold / P.Close, and P.Held answers whether a key is held or closed.
--
-- TEST MODE (DW-FP17) keeps its sample items in a store of their own (State.pendingTest, AddTest
-- and ClearTest; All("test") reads it), never read from the client, never ticked, never handed to
-- the feed; the window reads the store of the feed it shows.
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
-- open) goes to the feed as it always did; a winner the client names but that reads nothing plain
-- (`roll.won` without `roll.winner`) closes the item all the same. A key once closed or gated is
-- not opened again until LOOT_HISTORY_CLEAR_HISTORY drops the live mapping, which also detaches
-- every open item from its key (a reused key never resolves the wrong drop). A roll that is over
-- releases its popup's rollID.
--
-- YOUR VERDICT (`me`) is judged again as the feed judges a shown drop: on GearChanged, and on the
-- feed's score retry schedule while the scorer is not ready (LootFeed.SCORE_RETRY, SCORE_TRIES),
-- each sending PendingChanged(id, "verdict").
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

local ticker, scoreTimer
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

-- A store by name: `test` reads test mode's own and nothing else, even before its first sample (a
-- bare `name == "test" and State.pendingTest or State.pending` fell through to the live store then).
local function named(name)
    if name == "test" then return State.pendingTest end
    return State.pending
end

--- Every pending item of a store, oldest first (by `at`, then id): `live` (the default) or `test`
--- (test mode's samples, P.AddTest).
--- @param name string|nil
--- @return table[]
function P.All(name)
    local out, s = {}, named(name)
    for _, item in ipairs(s and s.items or {}) do out[#out + 1] = item end
    table.sort(out, byAge)
    return out
end

--- How many pending items a store holds (`live`, the default, or `test`), with no list built: the
--- repaint's empty check, so a window with nothing pending allocates nothing for it (tests/perf.lua).
--- @param name string|nil
--- @return number
function P.Count(name)
    local s = named(name)
    return s and #s.items or 0
end

--- One pending item by its id, from either store, or nil.
function P.Get(id)
    local live, test = State.pending, State.pendingTest
    return (live and live.byId[id]) or (test and test.byId[id]) or nil
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

-- A roll that is over lets its popup go (M4 review): its rollID leaves your open popups, so a
-- later copy of the item can never claim a stale one.
local function release(item)
    if item.rollID == nil then return end
    store().mine[item.rollID] = nil
    item.rollID = nil
end

local function remove(item)
    local s = store()
    release(item)
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
    release(item)
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
    -- Two loads of one key can answer (a history clear between them empties `loading`): the
    -- first admits, the second finds the key held or closed (M4 review).
    if s.byKey[key] or s.done[key] then return end
    local ok, why, out = NS.LootFeed.GateFor(facts, NS.Situations.Current())
    if not ok then
        s.done[key] = true
        return NS.Debug(TAG, "drop %s: %s not pending (%s)", key, tostring(roll.link), tostring(why))
    end
    s.seq = s.seq + 1
    local item = { id = s.seq, kind = "roll", key = key, encounterID = encounterID, dropKey = dropKey,
        link = roll.link, itemID = NS.Item.ItemIDFromLink(roll.link), at = now(), state = "open",
        facts = facts, forced = out.forced, me = out.me, roll = roll, sig = signature(roll) }
    s.items[#s.items + 1], s.byId[item.id], s.byKey[key] = item, item, item
    -- Claimed before the message, so a roll popup already up repaints with this item (DW-FP20 review).
    claimRolls()
    send(item.id, "open")
    P.NoteScore(item)
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
    if roll.winner or roll.won then return resolve(item, encounterID, dropKey, roll) end
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

--- LOOT_HISTORY_CLEAR_HISTORY: the live mapping goes (the keys may be reused). Each open roll
--- item is detached from its encounterID:dropKey, so a reused key can never resolve it into
--- another drop (M4 review); the ticker expires it on its next pass. A master-loot item's key is
--- not the history's (sourceGUID:itemID): it stays held, so a re-opened corpse adds nothing.
function P.OnClearHistory()
    if stoodDown() then return end
    local s = store()
    s.byKey, s.done, s.loading = {}, {}, {}
    for _, item in ipairs(s.items) do
        if item.kind == "roll" then
            if item.state == "open" then item.detached = true end
        else
            s.byKey[item.key] = item
        end
    end
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

--- Hold one item another kind built (modules/PendingML.lua): it takes the next id, enters the
--- store under its `key` and sends PendingChanged(id, "open"); its verdict joins the score retry.
--- @param item table { kind, key, link, itemID, at, state, facts, forced, me, ... }
--- @return table item
function P.Hold(item)
    local s = store()
    s.seq = s.seq + 1
    item.id = s.seq
    s.items[#s.items + 1], s.byId[item.id], s.byKey[item.key] = item, item, item
    send(item.id, "open")
    P.NoteScore(item)
    return item
end

--- Close one held item (PendingChanged(id, "closed")); its key stays closed until the history clears.
function P.Close(item)
    if P.Get(item.id) == item then remove(item) end
end

--- Whether a key is held now, or was closed (or gated) since the last history clear.
--- @param key string
--- @return boolean
function P.Held(key)
    local s = store()
    return s.byKey[key] ~= nil or s.done[key] == true
end

--- Mark a key closed without holding an item (a drop the gates refused).
function P.Refuse(key) store().done[key] = true end

--- Close every live item `pred(item)` answers true for, its key free again (the simulator's stop:
--- its rolls are no longer the client's to answer). Answers how many closed.
--- @param pred function
--- @return number
function P.RemoveWhere(pred)
    local gone = {}
    for _, item in ipairs(State.pending and State.pending.items or {}) do
        if pred(item) then gone[#gone + 1] = item end
    end
    for _, item in ipairs(gone) do
        remove(item)
        store().done[item.key] = nil
    end
    return #gone
end

-- ── test mode's samples ─────────────────────────────────────────────────────────────────────

--- Add one of test mode's sample items (modules/TestMode.lua) to the test store: `spec` = { kind,
--- link, facts, me, roll, state }. It is never read from the client, never ticks and never reaches
--- the feed; its id is a string (`test:<n>`), so it never meets a live one. Answers the item.
--- @param spec table
--- @return table|nil
function P.AddTest(spec)
    if stoodDown() or type(spec) ~= "table" or not spec.link then return nil end
    local s = State.pendingTest or { seq = 0, items = {}, byId = {} }
    State.pendingTest = s
    s.seq = s.seq + 1
    local id = "test:" .. s.seq
    local item = { id = id, kind = spec.kind or "roll", key = id, link = spec.link,
        itemID = NS.Item.ItemIDFromLink(spec.link), at = now() - (tonumber(spec.ago) or 0), state = spec.state or "open",
        facts = spec.facts, me = spec.me, roll = spec.roll, test = true }
    s.items[#s.items + 1], s.byId[id] = item, item
    send(id, "open")
    return item
end

--- Empty the test store (test mode turned off).
function P.ClearTest()
    local s = State.pendingTest
    State.pendingTest = nil
    for _, item in ipairs(s and s.items or {}) do send(item.id, "closed") end
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
        local roll = not item.detached and NS.Compat.LootHistoryRolls(item.encounterID, item.dropKey)
        if not roll then
            linger(item, "expired")
        elseif roll.winner or roll.won then
            resolve(item, item.encounterID, item.dropKey, roll)
        else
            update(item, roll)
        end
    end
    retune()
end

--- Whether the ticker is running (the diagnostics and the tests).
function P.Ticking() return ticker ~= nil end

-- ── your verdict, judged again ──────────────────────────────────────────────────────────────

-- The live items still waiting on their drop (not yet closed).
local function waiting()
    local out = {}
    for _, item in ipairs(State.pending and State.pending.items or {}) do
        if item.state == "open" or item.state == "awaiting" then out[#out + 1] = item end
    end
    return out
end

local function scorePending(item) return NS.FeedRecords.HasReason(item.me, "scorePending") end

-- Your verdict on an item judged again by the feed's own judge (M4 review: the feed re-judges a
-- drop on a score retry and a gear change, and a pending item is judged the same way).
local function rejudge(item)
    item.me = NS.LootFeed.JudgeMe(item.facts, item.forced)
    send(item.id, "verdict")
end

local retryScores

local function armScoreRetry()
    if scoreTimer or stoodDown() then return end
    local gen = generation
    scoreTimer = C_Timer.NewTimer(NS.LootFeed.SCORE_RETRY, function()
        scoreTimer = nil
        if gen == generation then retryScores() end
    end)
end

--- An item whose scorer is not ready yet starts its score retries (the feed's SCORE_RETRY and
--- SCORE_TRIES); one that has used them up keeps its answer.
function P.NoteScore(item)
    if item.scoreTries ~= nil or not scorePending(item) then return end
    item.scoreTries = 0
    armScoreRetry()
end

retryScores = function()
    local again = false
    for _, item in ipairs(waiting()) do
        if item.scoreTries and item.scoreTries < NS.LootFeed.SCORE_TRIES and scorePending(item) then
            item.scoreTries = item.scoreTries + 1
            rejudge(item)
            if scorePending(item) and item.scoreTries < NS.LootFeed.SCORE_TRIES then again = true end
        end
    end
    if again then armScoreRetry() end
end

--- Your gear moved: your verdict on every waiting item is judged again.
function P.OnGearChanged()
    if stoodDown() then return end
    for _, item in ipairs(waiting()) do rejudge(item) end
end

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

-- The bus receiver: tracked, so the stand-down takes it down and the stand-up replays it;
-- without the bus library it is a bare target, unregistered here instead (NS.Bus.tracked).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() P.OnGearChanged() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    stopTicker()
    if scoreTimer then scoreTimer:Cancel() end
    scoreTimer = nil
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
    for _, t in pairs(lingers) do t:Cancel() end
    lingers = {}
    State.pending, State.pendingTest = nil, nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    P.Rebuild()
end
