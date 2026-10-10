local _, NS = ...
-- modules/ItemFacts.lua — an item link turned into the facts the verdict kernel reads (design spec
-- §4, §5.1), cached by link.
--
--   facts = { link, itemID, name, ilvl, baseIlvl, equipLoc, classID, subClassID, quality,
--             bindType, setID, warbound, warboundUntilEquip,
--             track = { name, rank, max, tier, stringID, maxItemLevel, source } | nil,
--             stats = { [STAT_KEY] = n }, specs = { [specID] = true } | nil,
--             unique = { cat, max } | nil, isTierToken, classes = { [classFile] = true } | nil,
--             transmogKnown = true | false | nil }
--
-- THE EDGE. Every client read goes through NS.Compat: the cached fields (GetItemInfo), the
-- effective level (GetDetailedItemLevel, else the base level), the upgrade track
-- (GetItemUpgradeInfo: the API, else the tooltip's ItemUpgradeLevel line), the stats, the spec
-- list, the uniqueness, the account binds, the class restriction line and the appearance.
--
-- THE TRACK. `tier` comes from the track's trackStringID through C.TRACK_TIER_BY_STRING_ID, else
-- from its enUS name through C.TRACK_TIER; a localized name that matches neither leaves `tier` nil,
-- and the kernel then leaves the track delta unset rather than guessing.
--
-- UNIQUE. An item unique in a category carries `{ cat = categoryID, max }`; an item unique on its
-- own carries `{ cat = "item:<itemID>", max }`, so two copies of it share a category.
--
-- TIER TOKENS. An item that names its classes (the RestrictedRaceClass tooltip line) and is not
-- gear (no slot plan for its equipLoc) is a tier token, with `classes` set. Class-restricted gear
-- carries `classes` too, without the flag. Which slot a token makes is not read in v1, so the
-- token's verdict is the kernel's `unknown` for the slot (a follow-up, design spec §14).
--
-- THE CACHE AND THE LOAD. Get(link) answers the cached facts, or builds them when the client has
-- the item cached, or nil. Request(link, callback) does the same and, on a miss, asks the client
-- to load the item through LibKa0s-Item-1.0's LoadItem; its callback is the retry: it reads again
-- and, still uncached, asks again, up to MAX_LOAD_TRIES, then gives up. Every caller waiting on
-- one link shares one load and is called back once, with the facts or with nil. The cache holds
-- at most CACHE_CAP links; when it would pass that, the least recently used EVICT_SHARE of it is
-- dropped (a hit or a store marks a link used), so a raid's inspected gear and your own, read on
-- every judgment, stay while old drops and bag clutter go. Learning an appearance re-reads
-- `transmogKnown` on the cached facts.
-- Stood down, the cache and every load are dropped, and a load that answers late is ignored.
--
-- The tables answered are the cache's own: read them, never write them.
--
-- The bonus-roll flag of spec §4 is the loot line's (the parser's `kind`), not the item's, so the
-- drop record carries it, not these cached facts.

NS.ItemFacts = NS.ItemFacts or {}
local IF = NS.ItemFacts
local C = NS.Constants
local State = NS.State

local TAG = "ITEM"

IF.MAX_LOAD_TRIES = 5
IF.CACHE_CAP = 512
IF.EVICT_SHARE = 0.25

-- Equip locations without an appearance to collect.
local NO_APPEARANCE = { INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true }

-- Bumped at every stand-down: a load started before it is ignored when it answers.
local generation = 0

local function store()
    local s = State.itemFacts
    if not s then
        s = { cache = {}, used = {}, tick = 0, count = 0, loads = {}, evicted = 0 }
        State.itemFacts = s
    end
    return s
end

-- A link that can key the cache: a plain string carrying an item id.
local function validLink(link)
    if NS.Compat.IsSecret(link) or type(link) ~= "string" then return nil end
    local id = NS.Item.ItemIDFromLink(link)
    if not id then return nil end
    return id
end

-- ── building the facts ──────────────────────────────────────────────────────────────────────

--- The tier of an upgrade track: by its string id, else by its enUS name; nil when neither is known.
--- @param stringID number|nil
--- @param name string|nil
--- @return number|nil
function IF.TrackTier(stringID, name)
    local tier = stringID and C.TRACK_TIER_BY_STRING_ID[stringID]
    if tier then return tier end
    return name and C.TRACK_TIER[name] or nil
end

local function readTrack(link)
    local info = NS.Compat.GetItemUpgradeInfo(link)
    if not (info and info.trackString) then return nil end
    return {
        name = info.trackString, rank = info.currentLevel, max = info.maxLevel,
        tier = IF.TrackTier(info.trackStringID, info.trackString), stringID = info.trackStringID,
        maxItemLevel = info.maxItemLevel, source = info.source,
    }
end

local function readUnique(link, itemID)
    local cat, max = NS.Compat.GetItemUniqueness(link)
    if not max then return nil end
    return { cat = cat or ("item:" .. itemID), max = max }
end

local function readTransmog(link, equipLoc)
    if not equipLoc or equipLoc == "" or NO_APPEARANCE[equipLoc] then return nil end
    return NS.Compat.PlayerHasTransmog(link)
end

-- The tier-token flag and the class set.
local function readClasses(facts)
    facts.classes = NS.Compat.ItemClassRestriction(facts.link)
    facts.isTierToken = facts.classes ~= nil and C.SLOT_PLAN[facts.equipLoc or ""] == nil
end

local function readBinds(facts)
    local untilEquip = NS.Compat.IsItemBindToAccountUntilEquip(facts.link)
    facts.warboundUntilEquip = untilEquip
    facts.warbound = untilEquip or NS.Compat.IsItemBindToAccount(facts.link)
end

--- The facts of a link read from the client now, uncached; nil while the client has not cached the
--- item, or for a link that names no item.
--- @param link string
--- @return table|nil
function IF.Read(link)
    local itemID = validLink(link)
    local info = itemID and NS.Compat.GetItemInfo(link)
    if not info then return nil end
    local facts = {
        link = link, itemID = itemID, name = info.name, baseIlvl = info.itemLevel,
        ilvl = NS.Compat.GetDetailedItemLevel(link) or info.itemLevel,
        equipLoc = info.equipLoc, classID = info.classID, subClassID = info.subClassID,
        quality = info.quality or NS.Item.QualityFromLink(link), bindType = info.bindType,
        setID = info.setID, track = readTrack(link), stats = NS.Compat.GetItemStats(link),
        specs = NS.Compat.GetItemSpecs(link), unique = readUnique(link, itemID),
        transmogKnown = readTransmog(link, info.equipLoc),
    }
    readBinds(facts)
    readClasses(facts)
    return facts
end

-- ── the cache ───────────────────────────────────────────────────────────────────────────────

local function touch(s, link)
    s.tick = s.tick + 1
    s.used[link] = s.tick
end

-- Drop the least recently used EVICT_SHARE of the cache (at least one link).
local function evict(s)
    local links = {}
    for link in pairs(s.cache) do links[#links + 1] = link end
    table.sort(links, function(a, b) return s.used[a] < s.used[b] end)
    local n = math.max(1, math.floor(#links * IF.EVICT_SHARE))
    for i = 1, n do
        s.cache[links[i]], s.used[links[i]] = nil, nil
    end
    s.count, s.evicted = s.count - n, s.evicted + n
    NS.Debug(TAG, "item facts: cache full at %d, %d least recently used dropped", IF.CACHE_CAP, n)
end

local function remember(link, facts)
    local s = store()
    if s.count >= IF.CACHE_CAP then evict(s) end
    s.cache[link] = facts
    s.count = s.count + 1
    touch(s, link)
    return facts
end

--- The facts of a link: cached, else read now and cached; nil while the client has not cached the
--- item (Request loads it), or for a link that names no item.
--- @param link string
--- @return table|nil
function IF.Get(link)
    if not validLink(link) then return nil end
    local s = store()
    local hit = s.cache[link]
    if hit then
        touch(s, link)
        return hit
    end
    local facts = IF.Read(link)
    if not facts then return nil end
    return remember(link, facts)
end

-- ── loading an uncached item ────────────────────────────────────────────────────────────────

local attempt

local function finish(link, job, facts)
    store().loads[link] = nil
    for _, cb in ipairs(job.waiters) do cb(facts, link) end
end

local function onLoaded(link, job)
    if job.generation ~= generation then return end
    local facts = IF.Get(link)
    if facts then return finish(link, job, facts) end
    if job.tries < IF.MAX_LOAD_TRIES then return attempt(link, job) end
    NS.Debug(TAG, "item facts: gave up on item %s after %d loads", job.itemID, job.tries)
    finish(link, job, nil)
end

attempt = function(link, job)
    job.tries = job.tries + 1
    NS.Item.LoadItem(job.itemID, function() onLoaded(link, job) end)
end

--- The facts of a link now, when the client has the item; else nil, and `callback(facts, link)`
--- runs once the item has loaded, or with nil facts when it never does (after MAX_LOAD_TRIES
--- loads). The second return says which: "ready", "loading", "invalid" (no item in the link; the
--- callback never runs) or "unavailable" (the client cannot load items; nor does it).
--- @param link string
--- @param callback function|nil (facts|nil, link)
--- @return table|nil facts, string status
function IF.Request(link, callback)
    local itemID = validLink(link)
    if not itemID then return nil, "invalid" end
    local facts = IF.Get(link)
    if facts then return facts, "ready" end
    if not NS.Compat.CanRequestItemLoad() then return nil, "unavailable" end
    local loads = store().loads
    local job = loads[link]
    if not job then
        job = { itemID = itemID, tries = 0, waiters = {}, generation = generation }
        loads[link] = job
        attempt(link, job)
    end
    if callback then job.waiters[#job.waiters + 1] = callback end
    return nil, "loading"
end

-- ── reading the cache's state ───────────────────────────────────────────────────────────────

--- How many links are cached, and how many are loading.
--- @return number cached, number loading
function IF.Counts()
    local s, loading = store(), 0
    for _ in pairs(s.loads) do loading = loading + 1 end
    return s.count, loading
end

--- Forget one link's facts, or every link's when `link` is nil. Loads in flight carry on.
--- @param link string|nil
function IF.Invalidate(link)
    local s = store()
    if link == nil then
        s.cache, s.used, s.count = {}, {}, 0
    elseif validLink(link) and s.cache[link] then
        s.cache[link], s.used[link] = nil, nil
        s.count = s.count - 1
    end
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "TRANSMOG_COLLECTION_UPDATED", "OnTransmogCollectionUpdated" }

-- An appearance was learned (or lost): re-read the flag on every cached link.
function NS.addon.OnTransmogCollectionUpdated()
    for link, facts in pairs(store().cache) do
        facts.transmogKnown = readTransmog(link, facts.equipLoc)
    end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    State.itemFacts = nil
end
