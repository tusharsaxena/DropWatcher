local _, NS = ...
-- modules/SimPool.lua — the simulator's item pool (simulator spec §3): real items from the
-- Encounter Journal, so the item facts, the tooltip readers and the comparisons work for real.
--
-- THE SOURCE. A scenario's situation names the journal's side and difficulty (SOURCES): the
-- dungeons of the newest journal tier (the current season's on a live client) at Mythic Keystone
-- for a key, Mythic for a dungeon and Heroic for a delve or an open-world group; its raids at
-- Heroic for a raid and Raid Finder for LFR. Drops come from that difficulty. The pool reads every
-- difficulty of the side (FAMILY), so the members' gear (modules/SimRoster.lua) has a spread of
-- item levels to draw a band from. Every read goes through NS.Compat's journal shims (compat).
-- `everything` (test mode's) reads both sides, and a build's `keystoneLevel` sets the journal's
-- Mythic+ loot preview while it reads the Mythic Keystone difficulty, so those links carry that
-- key level's item level where the client supports the preview.
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
--   entry = { link, itemID, encounterID, encounter, difficulty, instance, raid, worldBoss, equipLoc,
--             ilvl, classID, subClassID }   (encounter: the boss's name; worldBoss: the tier's
--             world bosses, Compat.JournalInstances)
--
-- The build lives on the running session (its pool and poolBuild) and its timers are
-- the session's (NS.Sim:After), so the stop ends both. Test mode (modules/TestMode.lua) builds the
-- same pool into its own holder (BuildInto), for real items in its sample drops (ui spec §4, FB-9).

NS.SimPool = NS.SimPool or {}
local P = NS.SimPool
local C = NS.Constants
local CD = NS.ClassData
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
    everything     = { both = true },
}

--- Every difficulty the pool reads, per side, lowest first.
P.FAMILY = {
    dungeon = { D.NORMAL_DUNGEON, D.HEROIC_DUNGEON, D.MYTHIC_DUNGEON, D.MYTHIC_KEYSTONE },
    raid    = { D.LFR, D.NORMAL_RAID, D.HEROIC_RAID, D.MYTHIC_RAID },
}

-- The fallback lines already printed this session of play.
local reported = {}

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

--- What a loot burst draws from (modules/SimEvents.lua): the pool's drops that are gear (an equip
--- location the comparisons know, facts filled), or every drop when none is. The journal also
--- lists recipes and consumables, which the feed hides as not gear, so a burst drawn from those
--- alone shows nothing (the owner's /dw sim on 2026-10-23).
--- @param pool table|nil
--- @return table
function P.LootDrops(pool)
    local drops, gear = P.Drops(pool), {}
    for _, e in ipairs(drops) do
        P.Facts(e)
        if C.SLOT_PLAN[e.equipLoc] then gear[#gear + 1] = e end
    end
    if #gear == 0 then return drops end
    return gear
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

-- Every loot entry of the selected tier's instances on one side, at each of the side's
-- difficulties, into `out`; answers how many entries are still loading.
local function readSide(out, seen, isRaid, filter, keystoneLevel)
    local Compat = NS.Compat
    local pending, names = 0, {}
    local function nameOf(id)
        if id and names[id] == nil then names[id] = Compat.JournalEncounterName(id) or false end
        return id and names[id] or nil
    end
    local instances = Compat.JournalInstances(isRaid)
    for _, difficulty in ipairs(P.FAMILY[isRaid and "raid" or "dungeon"]) do
        for _, inst in ipairs(instances) do
            Compat.JournalSelect({ instanceID = inst.id, difficulty = difficulty,
                classID = filter.classID, specID = filter.specID,
                keystoneLevel = difficulty == D.MYTHIC_KEYSTONE and keystoneLevel or nil })
            local loot, waiting = Compat.JournalLoot()
            pending = pending + waiting
            for _, e in ipairs(loot) do
                if not seen[e.link] then
                    seen[e.link] = true
                    out[#out + 1] = { link = e.link, itemID = e.itemID, encounterID = e.encounterID,
                        encounter = nameOf(e.encounterID) or nil, difficulty = difficulty, instance = inst.name,
                        raid = isRaid, worldBoss = inst.worldBoss }
                end
            end
        end
    end
    return pending
end

-- Every loot entry of the newest tier on the source's side (both sides for `everything`).
local function readAll(tiers, source, filter, keystoneLevel)
    local out, pending, seen = {}, 0, {}
    NS.Compat.JournalSelect({ tier = tiers })
    local sides = source.both and { false, true } or { source.raid == true }
    for _, isRaid in ipairs(sides) do
        pending = pending + readSide(out, seen, isRaid, filter, keystoneLevel)
    end
    return out, pending
end

--- Read the journal once for `source` under `filter`, the player's selection saved and restored
--- around it. Answers (entries, pending) or (nil, 0, why): `absent` (no journal API), `shown` (its
--- frame is open: not read), `noTier` or `error` (the read raised; the selection is restored).
--- @param source table P.Source's row
--- @param filter table P.Filter's answer
--- @param keystoneLevel number|nil the Mythic+ level the Mythic Keystone loot is previewed at
--- @return table|nil entries, number pending, string|nil why
function P.ReadJournal(source, filter, keystoneLevel)
    local Compat = NS.Compat
    local sel = Compat.JournalSelection()
    if not sel then return nil, 0, "absent" end
    if sel.shown then return nil, 0, "shown" end
    if not sel.tiers or sel.tiers < 1 then return nil, 0, "noTier" end
    local ok, entries, pending = pcall(readAll, sel.tiers, source, filter, keystoneLevel)
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

P.FALLBACK_LINE = L["The Encounter Journal gave no items, so this simulation drops your own gear instead."]

--- The own-items fallback pool (spec §3). `line` (the simulation's by default) is printed once per
--- session of play.
--- @param line string|nil
--- @return table pool
function P.Fallback(line)
    line = line or P.FALLBACK_LINE
    local entries = NS.SimSeam:Live(ownItems)
    if not reported[line] then
        reported[line] = true
        NS.Print(line)
    end
    return { sim = true, source = "fallback", entries = entries, pending = 0 }
end

-- ── the build ──────────────────────────────────────────────────────────────────────────────
--
-- A build fills a HOLDER's `pool` and `poolBuild` fields: the running simulation's session
-- (Build), or test mode's own holder (BuildInto, modules/TestMode.lua). Its host says whether the
-- holder still wants it (`alive`), how to wait (`after(delay, fn)`, a timer its owner cancels) and
-- the fallback's chat line. A build its holder replaced or let go does nothing more.

-- The builds that may be waiting for EJ_LOOT_DATA_RECIEVED.
local builds = {}

local function current(b)
    return b.host.alive() and b.holder.poolBuild == b
end

local function finish(b)
    builds[b] = nil
    local holder = b.holder
    holder.poolBuild = nil
    local pool
    if b.entries and #b.entries > 0 then
        pool = { sim = true, source = "journal", difficulty = b.source.difficulty, raid = b.source.raid,
            pending = b.pending or 0, entries = b.entries }
    else
        pool = P.Fallback(b.host.fallbackLine)
    end
    for _, e in ipairs(pool.entries) do P.Facts(e) end
    holder.pool = pool
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
    b.timer = b.host.after(delay, function()
        b.timer = nil
        attempt(b)
    end)
end

-- One read; then done, or the wait (the frame shown: poll; data loading: the event or the timeout).
attempt = function(b)
    if not current(b) then
        builds[b] = nil
        return
    end
    local entries, pending, why = P.ReadJournal(b.source, b.filter, b.keystoneLevel)
    if entries then b.entries, b.pending = entries, pending end
    local left = b.deadline - GetTime()
    if settled(entries, pending, why, left) then return finish(b) end
    b.waiting = why or "loot"
    if why == "shown" then return again(b, math.min(P.RETRY, left)) end
    b.timeout = b.timeout or b.host.after(left, function() attempt(b) end)
end

--- Build a pool into `holder` (its `pool` and `poolBuild`) and call `done(pool)` when it is ready
--- (at once when nothing has to load). `host` = { alive = fn() -> boolean, after = fn(delay, fn),
--- fallbackLine }; `opts` = { situation (`everything`: both sides), classFilter = `mine`|`any`,
--- timeout, keystoneLevel }.
--- @param holder table
--- @param host table
--- @param opts table|nil
--- @param done function|nil
function P.BuildInto(holder, host, opts, done)
    opts = type(opts) == "table" and opts or {}
    local snap = NS.Gear.Snapshot()
    local b = {
        holder = holder, host = host, done = done, source = P.Source(opts.situation),
        filter = P.Filter(opts.classFilter, snap.classFile, snap.specID), keystoneLevel = tonumber(opts.keystoneLevel),
        deadline = GetTime() + (tonumber(opts.timeout) or P.TIMEOUT),
    }
    holder.pool, holder.poolBuild = nil, b
    builds[b] = true
    attempt(b)
end

--- Build the running simulation's pool (spec §3) and call `done(pool)` when it is ready (at once
--- when nothing has to load). `opts` = { situation, classFilter = `mine`|`any`, timeout }. False
--- when no simulation runs.
--- @param opts table|nil
--- @param done function|nil
--- @return boolean
function P.Build(opts, done)
    local s = NS.Sim:Session()
    if not s then return false end
    local host = { alive = function() return NS.Sim:Session() == s end,
        after = function(d, fn) return NS.Sim:After(d, fn) end }
    P.BuildInto(s, host, opts, done)
    return true
end

--- The running simulation's pool, or nil (none runs, or it is still building).
--- @return table|nil
function P.Get()
    local s = NS.Sim:Session()
    return s and s.pool or nil
end

--- The pool at a glance, for the diagnostics: { building, waiting, source, size, drops, pending }.
--- @return table
function P.Status()
    local s = NS.Sim:Session() or {}
    local b, pool = s.poolBuild, s.pool
    local out = { building = b ~= nil, waiting = b and b.waiting, size = 0, drops = 0, pending = 0 }
    if pool then
        out.source, out.size, out.drops, out.pending = pool.source, #pool.entries, #P.Drops(pool), pool.pending
    end
    return out
end

-- ── the loot-data event ────────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "EJ_LOOT_DATA_RECIEVED", "OnSimPoolLoot" }

--- EJ_LOOT_DATA_RECIEVED: a journal entry loaded. Every build waiting for its data reads again
--- once the burst settles; with no build waiting it does nothing.
function NS.addon.OnSimPoolLoot()
    for b in pairs(builds) do
        if current(b) and b.waiting == "loot" then again(b, P.SETTLE) end
    end
end
