local _, NS = ...
-- modules/SimPool.lua — the simulator's item pool (simulator spec §3): real items from the
-- Encounter Journal, so the item facts, the tooltip readers and the comparisons work for real.
--
-- THE SOURCE. A scenario's situation names the journal's side and difficulty (SOURCES): the
-- dungeons of the newest journal tier (the current season's on a live client) at Mythic Keystone
-- for a key, Mythic for a dungeon and Heroic for a delve or an open-world group; its raids at
-- Heroic for a raid and Raid Finder for LFR. Drops come from that difficulty. The pool reads every
-- difficulty of the side (FAMILY), so the members' gear (modules/SimRoster.lua) has a spread of
-- item levels to draw a band from. Every read goes through NS.Compat's journal shims (compat-§1).
--
-- THE JOURNAL'S SELECTION is the player's: each read saves it (tier, instance, encounter,
-- difficulty, class and slot filters) and restores it afterward, even when the read raises. The
-- journal is not read while its frame is shown: the build looks again every RETRY seconds.
--
-- THE WAIT. An entry the client has not loaded has no link yet; it answers with
-- EJ_LOOT_DATA_RECIEVED (the client's spelling). The build reads again SETTLE seconds after the
-- last such event, until nothing is pending or TIMEOUT seconds have passed; then it keeps what
-- has loaded.
--
-- THE CLASS FILTER. `mine` sets the journal's class and spec filter to yours (the loot it lists
-- for you); `any` clears it.
--
-- THE FALLBACK. A journal that yields nothing (an API change, a flavor without the data, a frame
-- shown the whole time) gives way to your own equipped and bag gear, so a simulation always has
-- something to drop. It is reported in chat once per session of play, and its source reads
-- `fallback` in the pool.
--
--   pool  = { sim = true, source = "journal"|"fallback", difficulty, raid, pending, entries }
--   entry = { link, itemID, encounterID, difficulty, instance, equipLoc, ilvl, classID, subClassID }
--
-- The build lives on the running session (State.sim.pool, State.sim.poolBuild) and its timers are
-- the session's (NS.Sim.After), so the stop ends both.

NS.SimPool = NS.SimPool or {}
local P = NS.SimPool
local C = NS.Constants
local CD = NS.ClassData
local State = NS.State
local L = NS.L
local D = C.DIFFICULTY

local TAG = "SIM"

--- Seconds the build waits for the journal's loot data before it keeps what it has.
P.TIMEOUT = 5
--- Seconds between reads while the journal's frame is shown.
P.RETRY = 0.5
--- Seconds after the last EJ_LOOT_DATA_RECIEVED before reading again.
P.SETTLE = 0.2

--- situation -> the journal's side (`raid`) and the difficulty its drops come from.
P.SOURCES = {
    mythicPlus     = { raid = false, difficulty = D.MYTHIC_KEYSTONE },
    dungeon        = { raid = false, difficulty = D.MYTHIC_DUNGEON },
    delve          = { raid = false, difficulty = D.HEROIC_DUNGEON },
    openWorldGroup = { raid = false, difficulty = D.HEROIC_DUNGEON },
    raid           = { raid = true,  difficulty = D.HEROIC_RAID },
    raidLFR        = { raid = true,  difficulty = D.LFR },
}

--- Every difficulty the pool reads, per side, lowest first.
P.FAMILY = {
    dungeon = { D.NORMAL_DUNGEON, D.HEROIC_DUNGEON, D.MYTHIC_DUNGEON, D.MYTHIC_KEYSTONE },
    raid    = { D.LFR, D.NORMAL_RAID, D.HEROIC_RAID, D.MYTHIC_RAID },
}

-- Whether the fallback was reported this session of play.
local reported = false

-- ── pure ───────────────────────────────────────────────────────────────────────────────────

--- The journal source of a situation: SOURCES' row, the dungeon's for anything else.
--- @param situation string|nil
--- @return table { raid, difficulty }
function P.Source(situation)
    return P.SOURCES[situation] or P.SOURCES.dungeon
end

--- The journal's class filter for `mode`: `mine` is your class and spec, anything else is every
--- class (classID 0).
--- @param mode string|nil
--- @param classFile string|nil yours
--- @param specID number|nil yours
--- @return table { classID, specID }
function P.Filter(mode, classFile, specID)
    local classID = mode == "mine" and CD.CLASS_ID[classFile] or nil
    if not classID then return { classID = 0, specID = 0 } end
    return { classID = classID, specID = specID or 0 }
end

--- The pool's drops: the entries at the pool's own difficulty, every entry for a fallback pool.
--- @param pool table|nil
--- @return table
function P.Drops(pool)
    if not pool then return {} end
    if pool.difficulty == nil then return pool.entries end
    local out = {}
    for _, e in ipairs(pool.entries) do
        if e.difficulty == pool.difficulty then out[#out + 1] = e end
    end
    return out
end

-- ── item facts ─────────────────────────────────────────────────────────────────────────────

--- Fill an entry's facts from the client (equip location, item level, class and subclass), once
--- each is known. Answers the entry.
--- @param e table
--- @return table
function P.Facts(e)
    local Compat = NS.Compat
    e.equipLoc = e.equipLoc or Compat.ItemEquipLoc(e.link)
    e.ilvl = e.ilvl or Compat.GetDetailedItemLevel(e.link)
    if e.classID == nil then
        local info = Compat.GetItemInfo(e.link)
        if info then e.classID, e.subClassID = info.classID, info.subClassID end
    end
    return e
end

--- The pool's gear: its entries with an equip location the comparisons know and a known item
--- level, facts filled. Empty for no pool.
--- @param pool table|nil
--- @return table
function P.GearEntries(pool)
    local out = {}
    for _, e in ipairs(pool and pool.entries or {}) do
        P.Facts(e)
        if C.SLOT_PLAN[e.equipLoc] and type(e.ilvl) == "number" then out[#out + 1] = e end
    end
    return out
end

--- Your average equipped item level (the gear snapshot's worn items with a known level), or nil
--- while nothing is known.
--- @return number|nil
function P.PlayerAverageLevel()
    local sum, n = 0, 0
    for _, e in pairs(NS.Gear.Snapshot().equipped) do
        if type(e) == "table" and type(e.ilvl) == "number" then sum, n = sum + e.ilvl, n + 1 end
    end
    if n == 0 then return nil end
    return math.floor(sum / n + 0.5)
end

-- ── reading the journal ────────────────────────────────────────────────────────────────────

-- Every loot entry of the newest tier's instances on `side`, at each of the side's difficulties.
local function readAll(tiers, source, filter)
    local Compat = NS.Compat
    local out, pending, seen = {}, 0, {}
    Compat.JournalSelect({ tier = tiers })
    local instances = Compat.JournalInstances(source.raid)
    for _, difficulty in ipairs(P.FAMILY[source.raid and "raid" or "dungeon"]) do
        for _, inst in ipairs(instances) do
            Compat.JournalSelect({ instanceID = inst.id, difficulty = difficulty,
                classID = filter.classID, specID = filter.specID })
            local loot, waiting = Compat.JournalLoot()
            pending = pending + waiting
            for _, e in ipairs(loot) do
                if not seen[e.link] then
                    seen[e.link] = true
                    out[#out + 1] = { link = e.link, itemID = e.itemID, encounterID = e.encounterID,
                        difficulty = difficulty, instance = inst.name }
                end
            end
        end
    end
    return out, pending
end

--- Read the journal once for `source` under `filter`, the player's selection saved and restored
--- around it. Answers (entries, pending) or (nil, 0, why): `absent` (no journal API), `shown` (its
--- frame is open: not read), `noTier` or `error` (the read raised; the selection is restored).
--- @param source table P.Source's row
--- @param filter table P.Filter's answer
--- @return table|nil entries, number pending, string|nil why
function P.ReadJournal(source, filter)
    local Compat = NS.Compat
    local sel = Compat.JournalSelection()
    if not sel then return nil, 0, "absent" end
    if sel.shown then return nil, 0, "shown" end
    if not sel.tiers or sel.tiers < 1 then return nil, 0, "noTier" end
    local ok, entries, pending = pcall(readAll, sel.tiers, source, filter)
    Compat.JournalSelect(sel)
    if not ok then
        NS.Debug(TAG, "journal read failed: %s", NS.SafeToString(entries))
        return nil, 0, "error"
    end
    return entries, pending
end

-- ── the fallback ───────────────────────────────────────────────────────────────────────────

local function addOwn(out, seen, link)
    if link and not seen[link] and C.SLOT_PLAN[NS.Compat.ItemEquipLoc(link)] then
        seen[link] = true
        out[#out + 1] = { link = link }
    end
end

-- Your equipped and bag gear, read past the seam (it is yours, never the simulation's).
local function ownItems()
    local Compat, out, seen = NS.Compat, {}, {}
    for _, slot in pairs(C.SLOT) do
        if not C.QUALITY_IGNORED_SLOT[slot] then addOwn(out, seen, Compat.InventoryItemLink("player", slot)) end
    end
    for _, bag in ipairs(C.BAG_IDS) do
        for slot = 1, Compat.BagSlotCount(bag) do addOwn(out, seen, Compat.BagItemLink(bag, slot)) end
    end
    table.sort(out, function(a, b) return a.link < b.link end)
    return out
end

--- The own-items fallback pool (spec §3), reported in chat once per session of play.
--- @return table pool
function P.Fallback()
    local entries = NS.Sim.Live(ownItems)
    if not reported then
        reported = true
        NS.Print(L["The Encounter Journal gave no items, so this simulation drops your own gear instead."])
    end
    return { sim = true, source = "fallback", entries = entries, pending = 0 }
end

-- ── the build ──────────────────────────────────────────────────────────────────────────────

local function finish(b)
    local s = b.session
    s.poolBuild = nil
    local pool
    if b.entries and #b.entries > 0 then
        pool = { sim = true, source = "journal", difficulty = b.source.difficulty, raid = b.source.raid,
            pending = b.pending or 0, entries = b.entries }
    else
        pool = P.Fallback()
    end
    for _, e in ipairs(pool.entries) do P.Facts(e) end
    s.pool = pool
    NS.Debug(TAG, "pool: %d items from the %s (%d still loading)", #pool.entries, pool.source, pool.pending)
    if b.done then b.done(pool) end
end

local attempt

-- Whether a read ends the build: all loaded, the time is up, or the journal cannot be read at all
-- (absent, no tier, a read that raised). A shown frame is waited out.
local function settled(entries, pending, why, left)
    if entries and pending == 0 then return true end
    return left <= 0.01 or (why ~= nil and why ~= "shown")
end

-- Read again after `delay` seconds, unless a read is already set for then.
local function again(b, delay)
    if b.timer then return end
    b.timer = NS.Sim.After(delay, function()
        b.timer = nil
        attempt(b)
    end)
end

-- One read; then done, or the wait (the frame shown: poll; data loading: the event or the timeout).
attempt = function(b)
    if State.sim ~= b.session or b.session.poolBuild ~= b then return end
    local entries, pending, why = P.ReadJournal(b.source, b.filter)
    if entries then b.entries, b.pending = entries, pending end
    local left = b.deadline - GetTime()
    if settled(entries, pending, why, left) then return finish(b) end
    b.waiting = why or "loot"
    if why == "shown" then return again(b, math.min(P.RETRY, left)) end
    b.timeout = b.timeout or NS.Sim.After(left, function() attempt(b) end)
end

--- Build the running simulation's pool (spec §3) and call `done(pool)` when it is ready (at once
--- when nothing has to load). `opts` = { situation, classFilter = `mine`|`any`, timeout }. False
--- when no simulation runs.
--- @param opts table|nil
--- @param done function|nil
--- @return boolean
function P.Build(opts, done)
    local s = State.sim
    if not s then return false end
    opts = type(opts) == "table" and opts or {}
    local snap = NS.Gear.Snapshot()
    local b = {
        session = s, done = done, source = P.Source(opts.situation),
        filter = P.Filter(opts.classFilter, snap.classFile, snap.specID),
        deadline = GetTime() + (tonumber(opts.timeout) or P.TIMEOUT),
    }
    s.pool, s.poolBuild = nil, b
    attempt(b)
    return true
end

--- The running simulation's pool, or nil (none runs, or it is still building).
--- @return table|nil
function P.Get()
    local s = State.sim
    return s and s.pool or nil
end

--- The pool at a glance, for the diagnostics: { building, waiting, source, size, drops, pending }.
--- @return table
function P.Status()
    local s = State.sim or {}
    local b, pool = s.poolBuild, s.pool
    local out = { building = b ~= nil, waiting = b and b.waiting, size = 0, drops = 0, pending = 0 }
    if pool then
        out.source, out.size, out.drops, out.pending = pool.source, #pool.entries, #P.Drops(pool), pool.pending
    end
    return out
end

-- ── the loot-data event ────────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "EJ_LOOT_DATA_RECIEVED", "OnSimPoolLoot" }

--- EJ_LOOT_DATA_RECIEVED: a journal entry loaded. A build waiting for its data reads again once
--- the burst settles; with no build waiting it does nothing.
function NS.addon.OnSimPoolLoot()
    local s = State.sim
    local b = s and s.poolBuild
    if b and b.waiting == "loot" then again(b, P.SETTLE) end
end
