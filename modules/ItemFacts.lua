local _, NS = ...
-- modules/ItemFacts.lua — an item link turned into the facts the verdict kernel reads (design spec
-- §4, §5.1), cached by link.
--
--   facts = { link, itemID, name, ilvl, ilvlSource, baseIlvl, equipLoc, classID, subClassID,
--             quality, qualitySource, bindType, setID, warbound, warboundUntilEquip,
--             track = { name, rank, max, tier, stringID, maxItemLevel, source } | nil,
--             stats = { [STAT_KEY] = n }, specs = { [specID] = true } | nil, specsClass,
--             unique = { cat, max } | nil, isTierToken, classes = { [classFile] = true } | nil,
--             transmogKnown = true | false | nil, rawEquipLoc, category, collect, useText | nil,
--             useSpellLoading = spellID | nil, tokenUsers = "every" | "yours" | nil,
--             tokenSlot = "INVTYPE_*" | "any" | nil, tokenSlotSource = "table" | "use" | "name" | "any" | nil }
--
-- THE EDGE. Every client read goes through NS.Compat: the cached fields (GetItemInfo), the
-- effective level and the quality through NS.ItemRead (core/ItemRead.lua: the detailed level, else
-- the base one; the quality the client answers for the link, else the link's color), the
-- upgrade track (GetItemUpgradeInfo: the API, else the tooltip's ItemUpgradeLevel line), the
-- stats, the spec list, the uniqueness, the account binds, the class restriction line and the
-- appearance.
--
-- THE TRACK. `tier` comes from the track's trackStringID through C.TRACK_TIER_BY_STRING_ID, else
-- from its enUS name through C.TRACK_TIER; a localized name that matches neither leaves `tier` nil,
-- and the kernel then leaves the track delta unset rather than guessing.
--
-- UNIQUE. An item unique in a category carries `{ cat = categoryID, max }`; an item unique on its
-- own carries `{ cat = "item:<itemID>", max }`, so two copies of it share a category.
--
-- TIER TOKENS. An item that is not gear (no slot plan for its raw equipLoc) is a tier token when it
-- names its classes (the RestrictedRaceClass tooltip line, `classes` set), when its use text makes a
-- piece "appropriate for your class" (TT-1), or when it is an omni Curio (an epic Miscellaneous or
-- Reagent item named "... Curio", which names no class; NS.TierTokens.IsCurio); so is an item the
-- C.TIER_TOKENS override lists. Class-restricted gear carries `classes` too, without the flag. A
-- token with no class list says who may use it in `tokenUsers` (NS.TierTokens.Users: `every` for a
-- Curio, `yours` for a Use text alone, nil when not read), which History keeps. The use text
-- (`useText`, NS.Compat.ItemUseText) is read here, for an item that is not gear only. A use spell
-- whose text the client has not loaded yet leaves its id in `useSpellLoading`: Request then waits
-- for the spell as it waits for an item (C_Spell.RequestLoadSpellData, IF.SPELL_LOAD_WAIT, up to
-- MAX_LOAD_TRIES), and SPELL_TEXT_UPDATE re-reads a cached item still waiting on it; each re-read
-- reads the use text, the flag, the slot and the category again (rereadToken).
-- NS.TierTokens.SlotOf (modules/TierTokens.lua) reads the slot the token makes, `tokenSlot`, with
-- `tokenSlotSource` naming the rung: `table`, `use` (its use text, else a tooltip slot line,
-- NS.Compat.TierTokenSlot), `name`, else `any`. A concrete slot then becomes the facts' `equipLoc`,
-- so the kernel and every gear reader judge the token as the piece it makes; `any` (a Curio, or a
-- token whose text named no slot) keeps the raw slot and the kernel folds over the tier slots
-- (categories design spec §3.1, §7).
--
-- CATEGORIES (issue #13). `rawEquipLoc` is the client's own equipLoc, kept on every item: the
-- appearance is read from it, never from a slot a later step may set. Last, NS.Collectibles.Read
-- (modules/Collectibles.lua) fills `category` and, for a collectible, `collect` on the facts being
-- built, before they are cached. A collection event re-reads them on every cached collectible
-- (RereadCollections, the cache's one writer; modules/Collectibles.lua arms it).
--
-- THE CACHE AND THE LOAD. Get(link) answers the cached facts, or builds them when the client has
-- the item cached, or nil. Request(link, callback) does the same and, on a miss, asks the client
-- to load the item through LibKa0s-Item-1.0's LoadItem; its callback is the retry: it reads again
-- and, still uncached, asks again, up to MAX_LOAD_TRIES, then gives up. Every caller waiting on
-- one link shares one load and is called back once, with the facts or with nil. The cache holds
-- at most CACHE_CAP links; when it would pass that, the least recently used EVICT_SHARE of it is
-- dropped (a hit or a store marks a link used), so a raid's inspected gear and your own, read on
-- every judgment, stay while old drops and bag clutter go. Learning an appearance re-reads
-- `transmogKnown` on the cached facts, from the raw equipLoc.
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
IF.SPELL_LOAD_WAIT = 0.4

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

-- An item that is not gear: no slot plan for its raw slot.
local function notGear(facts) return C.SLOT_PLAN[facts.rawEquipLoc or ""] == nil end

-- The use text, read for an item that is not gear (TT-1); gear's is never read. A use spell not
-- loaded yet leaves its id in `useSpellLoading`.
local function readUseText(facts)
    facts.useText, facts.useSpellLoading = nil, nil
    if notGear(facts) then facts.useText, facts.useSpellLoading = NS.Compat.ItemUseText(facts.link) end
end

-- The tier-token flag, the class set and who may use a token naming none (see the header): an item
-- that is not gear and names its classes, or whose use text makes a piece for your class, or an
-- omni Curio; or a listed item.
local function readClasses(facts)
    local TT = NS.TierTokens
    facts.classes = NS.Compat.ItemClassRestriction(facts.link)
    local listed, token = TT.Listed(facts.itemID), notGear(facts)
    facts.tokenUsers = (token or listed) and TT.Users(facts) or nil
    facts.isTierToken = (token and (facts.classes ~= nil or facts.tokenUsers ~= nil)) or listed
end

-- The slot a tier token makes; a concrete one becomes the equipLoc every gear reader takes.
local function readTokenSlot(facts)
    facts.equipLoc, facts.tokenSlot, facts.tokenSlotSource = facts.rawEquipLoc, nil, nil
    if not facts.isTierToken then return end
    local slot, source = NS.TierTokens.SlotOf(facts, function() return NS.Compat.TierTokenSlot(facts.link) end)
    facts.tokenSlot, facts.tokenSlotSource = slot, source
    if slot and slot ~= "any" then facts.equipLoc = slot end
end

-- GetItemStats answers the primary stat of the spec playing alone; the tooltip's lines add the
-- others, so the kernel judges a three-stat cloak for every spec (not the looter's or yours).
local function readStats(link)
    local stats = NS.Compat.GetItemStats(link)
    for key, value in pairs(NS.Compat.ItemPrimaryStats(link) or {}) do stats[key] = value end
    return stats
end

-- GetItemSpecInfo lists the specs of the class playing alone; `specsClass` says which, so the
-- kernel holds only that class to the list.
local function readSpecs(facts)
    facts.specs = NS.Compat.GetItemSpecs(facts.link)
    if not facts.specs then return end
    local _, classFile = NS.Compat.UnitClass("player")
    if not NS.Compat.IsSecret(classFile) and type(classFile) == "string" then facts.specsClass = classFile end
end

local function readBinds(facts)
    local untilEquip = NS.Compat.IsItemBindToAccountUntilEquip(facts.link)
    facts.warboundUntilEquip = untilEquip
    facts.warbound = untilEquip or NS.Compat.IsItemBindToAccount(facts.link)
end

-- The level and its source (ui spec §0): gear's through NS.ItemRead.EffectiveItemLevel; anything
-- else (a tier token) the detailed level all the same, else the base one.
local function levelOf(link, info)
    local ilvl, source = NS.ItemRead.EffectiveItemLevel(link)
    if ilvl then return ilvl, source end
    ilvl = NS.Compat.GetDetailedItemLevel(link)
    if ilvl then return ilvl, "detailed" end
    return info.itemLevel, "base"
end

--- The facts of a link read from the client now, uncached; nil while the client has not cached the
--- item, or for a link that names no item. `ilvlSource` (`detailed` or `base`) and `qualitySource`
--- (`item` or `link`) say where each came from (NS.ItemRead, the `drops` diagnostics).
--- @param link string
--- @return table|nil
function IF.Read(link)
    local itemID = validLink(link)
    local info = itemID and NS.Compat.GetItemInfo(link)
    if not info then return nil end
    local ilvl, ilvlSource = levelOf(link, info)
    local quality, qualitySource = NS.ItemRead.QualityOf(link)
    local facts = {
        link = link, itemID = itemID, name = info.name, baseIlvl = info.itemLevel,
        ilvl = ilvl, ilvlSource = ilvlSource,
        equipLoc = info.equipLoc, rawEquipLoc = info.equipLoc, classID = info.classID, subClassID = info.subClassID,
        quality = quality, qualitySource = qualitySource, bindType = info.bindType,
        setID = info.setID, track = readTrack(link), stats = readStats(link),
        unique = readUnique(link, itemID), transmogKnown = readTransmog(link, info.equipLoc),
    }
    readSpecs(facts)
    readBinds(facts)
    readUseText(facts)
    readClasses(facts)
    readTokenSlot(facts)
    if NS.Collectibles then NS.Collectibles.Read(facts) end
    return facts
end

-- The use text read again on built facts, and all that hangs on it: the token flag, its users and
-- slot, the category (a use spell's text that has loaded since; see the header).
local function rereadToken(facts)
    readUseText(facts)
    readClasses(facts)
    readTokenSlot(facts)
    if NS.Collectibles then NS.Collectibles.Read(facts) end
end

-- Facts waiting on their use spell's text, when the client can be asked to load it.
local function spellLoading(facts)
    return facts.useSpellLoading ~= nil and NS.Compat.CanRequestSpellLoad()
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

-- A load answered: the item read (or its use text read again), else another try, else the facts
-- as they stand (nil for an item that never loaded; a use text never loaded stops being waited on).
local function onLoaded(link, job)
    if job.generation ~= generation then return end
    local facts = IF.Get(link)
    if facts and facts.useSpellLoading then rereadToken(facts) end
    if facts and not spellLoading(facts) then return finish(link, job, facts) end
    if job.tries < IF.MAX_LOAD_TRIES then return attempt(link, job) end
    NS.Debug(TAG, "item facts: gave up on item %s after %d loads", job.itemID, job.tries)
    if facts then facts.useSpellLoading = nil end
    finish(link, job, facts)
end

-- One load: the use spell's when the item is cached and waits on it, else the item's.
attempt = function(link, job)
    job.tries = job.tries + 1
    local done = function() onLoaded(link, job) end
    local cached = store().cache[link]
    if cached and spellLoading(cached) and NS.Compat.RequestSpellLoad(cached.useSpellLoading) then
        return C_Timer.After(IF.SPELL_LOAD_WAIT, done)
    end
    NS.Item.LoadItem(job.itemID, done)
end

--- The facts of a link now, when the client has the item (and the text of its use spell, where it
--- has one the client can load); else nil, and `callback(facts, link)` runs once the item (or that
--- text) has loaded, or when it never does (after MAX_LOAD_TRIES loads), with nil facts for an item
--- never loaded and the facts as read for a use text never loaded. The second return says which:
--- "ready", "loading", "invalid" (no item in the link; the callback never runs) or "unavailable"
--- (the client cannot load items; nor does it).
--- @param link string
--- @param callback function|nil (facts|nil, link)
--- @return table|nil facts, string status
function IF.Request(link, callback)
    local itemID = validLink(link)
    if not itemID then return nil, "invalid" end
    local facts = IF.Get(link)
    if facts and not spellLoading(facts) then return facts, "ready" end
    if not (facts or NS.Compat.CanRequestItemLoad()) then return nil, "unavailable" end
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

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "TRANSMOG_COLLECTION_UPDATED", "OnTransmogCollectionUpdated" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "SPELL_TEXT_UPDATE", "OnSpellTextUpdate" }

-- A spell's text arrived: every cached item still waiting on it as its use spell is read again
-- (its use text, token flag, slot and category; see the header).
function NS.addon.OnSpellTextUpdate(_, _, spellID)
    if NS.Compat.IsSecret(spellID) or type(spellID) ~= "number" then return end
    for _, facts in pairs(store().cache) do
        if facts.useSpellLoading == spellID then rereadToken(facts) end
    end
end

-- An appearance was learned (or lost): re-read the flag on every cached link, then let the live
-- cosmetics be judged again (NS.Collectibles.Changed).
function NS.addon.OnTransmogCollectionUpdated()
    for link, facts in pairs(store().cache) do
        facts.transmogKnown = readTransmog(link, facts.rawEquipLoc)
    end
    if NS.Collectibles then NS.Collectibles.Changed() end
end

--- Read the collection state again on every cached collectible (NS.Collectibles.Read on the
--- cache's own tables: ItemFacts stays their one writer). Answers how many were read.
--- @return number
function IF.RereadCollections()
    local CO, n = NS.Collectibles, 0
    if not CO then return 0 end
    for _, facts in pairs(store().cache) do
        if CO.IsCollectible(facts) then
            CO.Read(facts)
            n = n + 1
        end
    end
    return n
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    State.itemFacts = nil
end
