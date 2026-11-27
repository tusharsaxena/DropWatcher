-- LibKa0s-Verdict-1.0 -- an item link turned into the facts the kernel reads, cached per instance
-- (v:Facts, v:Request), and how complete a link is (lib.ItemRead). Moved from Ka0s Drop Watcher's
-- modules/ItemFacts.lua and core/ItemRead.lua (DropWatcher#19).
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
-- THE EDGE. Every client read goes through the instance's reads (`v.R`, Verdict.lua): the cached
-- fields, the effective level and the quality (v:EffectiveItemLevel, v:QualityOf: the detailed
-- level, else the base one; the quality the client answers for the link, else the link's color),
-- the upgrade track, the stats, the spec list, the uniqueness, the account binds, the class
-- restriction line and the appearance (Retail's alone: C.FeatureOn("transmog", client)).
--
-- THE TRACK. `tier` comes from the track's trackStringID through C.TRACK_TIER_BY_STRING_ID, else
-- from its enUS name through C.TRACK_TIER; a name matching neither leaves `tier` nil.
--
-- UNIQUE. An item unique in a category carries `{ cat = categoryID, max }`; one unique on its own
-- carries `{ cat = "item:<itemID>", max }`.
--
-- TIER TOKENS. An item with no slot plan for its raw equipLoc is a tier token when it names its
-- classes, when its use text makes a piece for your class, or when it is an omni Curio; so is an
-- item C.TIER_TOKENS lists (lib.TierTokens, the words from host.L). A use spell whose text has not
-- loaded leaves its id in `useSpellLoading`, and Request waits for it as for an item; SPELL_TEXT_UPDATE
-- re-reads a cached item still waiting on it. A concrete token slot becomes the facts' equipLoc.
--
-- CATEGORIES. `rawEquipLoc` is the client's own equipLoc; the appearance is read from it. Last,
-- lib.Collect.Read fills `category` and `collect`; a collection change re-reads them on every
-- cached collectible (v:RereadCollections, the cache's one writer).
--
-- THE CACHE AND THE LOAD (per instance). v:Facts(link) answers the cached facts, or builds them
-- when the client has the item, or nil. v:Request(link, callback) does the same and, on a miss,
-- asks the client to load the item (R.LoadItem); its callback retries up to MAX_LOAD_TRIES. Every
-- caller waiting on one link shares one load. The cache holds at most CACHE_CAP links; past that
-- the least recently used EVICT_SHARE goes. Stood down, the cache and every load are dropped, and a
-- load that answers late is ignored. The tables answered are the cache's own: read, never write.
--
-- THE LINK (lib.ItemRead, pure): `item:` then, colon-separated, itemID, enchant, four gems, suffix,
-- unique id, link level, spec, modifiers mask, context, the bonus id count and ids, the modifier
-- count and its pairs. An item's identity is its id and bonus ids. The client answers a link's
-- level and quality from the data in it, so the most complete link wins (BetterLink).
--
-- Depends on the Verdict shell (Verdict.lua), VerdictConstants.lua and VerdictTierTokens.lua;
-- VerdictCollect.lua is read at call time.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.C or not lib.TierTokens then return end

local FACTS_MINOR = 1
-- Minor 1 (DropWatcher#19, task B2): Drop Watcher's item facts and link reads, the cache per
-- instance.
if lib.__factsMinor and lib.__factsMinor >= FACTS_MINOR
  and lib.__factsShellMinor == lib.MINOR then return end
lib.__factsMinor      = FACTS_MINOR
lib.__factsShellMinor = lib.MINOR

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictFacts = FACTS_MINOR

local C = lib.C
local methods = lib.__methods

local IF = {}
lib.Facts = IF
IF.MAX_LOAD_TRIES = 5
IF.CACHE_CAP = 512
IF.EVICT_SHARE = 0.25
IF.SPELL_LOAD_WAIT = 0.4

local TAG = "ITEM"

local NO_APPEARANCE = { INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true }

-- ---------------------------------------------------------------------------------------------
-- The link (lib.ItemRead; pure)
-- ---------------------------------------------------------------------------------------------

local IR = {}
lib.ItemRead = IR

-- Enum.ItemClass.Weapon and .Armor: the classes whose level means something.
IR.GEAR_CLASSES = { [2] = true, [4] = true }

local F_ID, F_CONTEXT, F_BONUS_COUNT = 1, 12, 13

--- The `item:...` string inside a link, or nil.
--- @return string|nil
function IR.ItemString(link)
  if type(link) ~= "string" then return nil end
  return link:match("item:[%-%d:]*")
end

local function fields(itemString)
  local out = {}
  for v in (itemString:sub(6) .. ":"):gmatch("([^:]*):") do out[#out + 1] = v end
  return out
end

local function bonusAndModifiers(f)
  local bonus, at, count = {}, F_BONUS_COUNT + 1, math.max(tonumber(f[F_BONUS_COUNT]) or 0, 0)
  for i = 1, count do bonus[#bonus + 1] = tonumber(f[at + i - 1]) end
  at = at + count
  local mods, n = {}, tonumber(f[at]) or 0
  for i = 1, n do
    local t = tonumber(f[at + 2 * i - 1])
    if t then mods[t] = tonumber(f[at + 2 * i]) end
  end
  return bonus, mods, n
end

--- How complete a link is: `{ itemString, itemID, context, bonusIDs, modifiers, numModifiers,
--- complete, score }`, or nil for a string that holds no item.
--- @return table|nil
function IR.LinkDetail(link)
  local s = IR.ItemString(link)
  local f = s and fields(s)
  local id = f and tonumber(f[F_ID])
  if not id then return nil end
  local bonus, mods, n = bonusAndModifiers(f)
  local context = tonumber(f[F_CONTEXT])
  return {
    itemString = s, itemID = id, context = context, bonusIDs = bonus, modifiers = mods,
    numModifiers = n, complete = #bonus > 0 or n > 0,
    score = (#bonus + n) * 2 + (context and context > 0 and 1 or 0),
  }
end

--- The more complete of two links of one item (`b` when it scores higher, else `a`).
--- @return string|nil
function IR.BetterLink(a, b)
  local da, db = IR.LinkDetail(a), IR.LinkDetail(b)
  if not db then return da and a or nil end
  if not da then return b end
  return db.score > da.score and b or a
end

--- An item's identity, its id and sorted bonus ids (`"159617|6652,10390"`), or nil.
--- @return string|nil
function IR.IdentityKey(link)
  local d = IR.LinkDetail(link)
  if not d then return nil end
  local bonus = {}
  for i, id in ipairs(d.bonusIDs) do bonus[i] = id end
  table.sort(bonus)
  return d.itemID .. "|" .. table.concat(bonus, ",")
end

--- The tier of an upgrade track: by its string id, else by its enUS name; nil when neither.
--- @return number|nil
function IF.TrackTier(stringID, name)
  local tier = stringID and C.TRACK_TIER_BY_STRING_ID[stringID]
  if tier then return tier end
  return name and C.TRACK_TIER[name] or nil
end

-- ---------------------------------------------------------------------------------------------
-- Level and quality (the instance's reads)
-- ---------------------------------------------------------------------------------------------

local function isGearInfo(info)
  return IR.GEAR_CLASSES[info.classID] == true and type(info.equipLoc) == "string" and info.equipLoc ~= ""
end

--- The exact level of the item in bag `bag`, slot `slot`, and "current"; nil when none.
function methods:ItemLevelAt(bag, slot)
  local level = self.R.BagItemLevelQuality(bag, slot)
  if level then return level, "current" end
  return nil, nil
end

--- The exact quality of the item in bag `bag`, slot `slot`, and "location"; nil when none.
function methods:QualityAt(bag, slot)
  local _, quality = self.R.BagItemLevelQuality(bag, slot)
  if quality then return quality, "location" end
  return nil, nil
end

--- A gear item's level and its source: at `{ bag, slot }` the exact one ("current"); for a link the
--- detailed level ("detailed"), else the base one ("base"). Nil for an item that is not gear, an
--- uncached item, or no answer.
--- @param where string|table
function methods:EffectiveItemLevel(where)
  if type(where) == "table" then return self:ItemLevelAt(where.bag, where.slot) end
  local info = self.R.GetItemInfo(where)
  if not (info and isGearInfo(info)) then return nil, nil end
  local detailed = self.R.GetDetailedItemLevel(where)
  if detailed then return detailed, "detailed" end
  if info.itemLevel then return info.itemLevel, "base" end
  return nil, nil
end

--- A link's quality and its source: the client's answer for this link ("item"), else its color
--- ("link"). Nil when neither answers.
function methods:QualityOf(link)
  local info = self.R.GetItemInfo(link)
  if info and info.quality then return info.quality, "item" end
  local colored = self.R.QualityFromLink(link)
  if colored then return colored, "link" end
  return nil, nil
end

-- ---------------------------------------------------------------------------------------------
-- Building the facts
-- ---------------------------------------------------------------------------------------------

local function store(v)
  local s = v.__facts
  if not s then
    s = { cache = {}, used = {}, tick = 0, count = 0, loads = {}, evicted = 0, generation = v.__factsGen or 0 }
    v.__facts = s
  end
  return s
end

local function validLink(v, link)
  if v.R.IsSecret(link) or type(link) ~= "string" then return nil end
  return v.R.ItemIDFromLink(link)
end

local function readTrack(R, link)
  local info = R.GetItemUpgradeInfo(link)
  if not (info and info.trackString) then return nil end
  return {
    name = info.trackString, rank = info.currentLevel, max = info.maxLevel,
    tier = IF.TrackTier(info.trackStringID, info.trackString), stringID = info.trackStringID,
    maxItemLevel = info.maxItemLevel, source = info.source,
  }
end

local function readUnique(R, link, itemID)
  local cat, max = R.GetItemUniqueness(link)
  if not max then return nil end
  return { cat = cat or ("item:" .. itemID), max = max }
end

local function readTransmog(v, link, equipLoc)
  if not C.FeatureOn("transmog", v.client) then return nil end
  if not equipLoc or equipLoc == "" or NO_APPEARANCE[equipLoc] then return nil end
  return v.R.PlayerHasTransmog(link)
end

local function notGear(v, facts) return C.SlotPlanFor(v.client)[facts.rawEquipLoc or ""] == nil end

local function readUseText(v, facts)
  facts.useText, facts.useSpellLoading = nil, nil
  if notGear(v, facts) then facts.useText, facts.useSpellLoading = v.R.ItemUseText(facts.link) end
end

local function readClasses(v, facts)
  local TT, L = lib.TierTokens, v.host.L
  facts.classes = v.R.ItemClassRestriction(facts.link)
  local listed, token = TT.Listed(facts.itemID), notGear(v, facts)
  facts.tokenUsers = (token or listed) and TT.Users(facts, L) or nil
  facts.isTierToken = (token and (facts.classes ~= nil or facts.tokenUsers ~= nil)) or listed
end

local function readTokenSlot(v, facts)
  facts.equipLoc, facts.tokenSlot, facts.tokenSlotSource = facts.rawEquipLoc, nil, nil
  if not facts.isTierToken then return end
  local slot, source = lib.TierTokens.SlotOf(facts, function() return v.R.TierTokenSlot(facts.link) end, v.host.L)
  facts.tokenSlot, facts.tokenSlotSource = slot, source
  if slot and slot ~= "any" then facts.equipLoc = slot end
end

local function readStats(R, link)
  local stats = R.GetItemStats(link)
  for key, value in pairs(R.ItemPrimaryStats(link) or {}) do stats[key] = value end
  return stats
end

local function readSpecs(R, facts)
  facts.specs = R.GetItemSpecs(facts.link)
  if not facts.specs then return end
  local _, classFile = R.UnitClass("player")
  if not R.IsSecret(classFile) and type(classFile) == "string" then facts.specsClass = classFile end
end

local function readBinds(R, facts)
  local untilEquip = R.IsItemBindToAccountUntilEquip(facts.link)
  facts.warboundUntilEquip = untilEquip
  facts.warbound = untilEquip or R.IsItemBindToAccount(facts.link)
end

local function levelOf(v, link, info)
  local ilvl, source = v:EffectiveItemLevel(link)
  if ilvl then return ilvl, source end
  ilvl = v.R.GetDetailedItemLevel(link)
  if ilvl then return ilvl, "detailed" end
  return info.itemLevel, "base"
end

local function readCollect(v, facts)
  if lib.Collect then lib.Collect.Read(facts, v.R) end
end

--- The facts of a link read from the client now, uncached; nil while the client has not cached the
--- item, or for a link that names no item.
--- @param link string
--- @return table|nil
function methods:ReadFacts(link)
  local R = self.R
  local itemID = validLink(self, link)
  local info = itemID and R.GetItemInfo(link)
  if not info then return nil end
  local ilvl, ilvlSource = levelOf(self, link, info)
  local quality, qualitySource = self:QualityOf(link)
  local facts = {
    link = link, itemID = itemID, name = info.name, baseIlvl = info.itemLevel,
    ilvl = ilvl, ilvlSource = ilvlSource,
    equipLoc = info.equipLoc, rawEquipLoc = info.equipLoc, classID = info.classID, subClassID = info.subClassID,
    quality = quality, qualitySource = qualitySource, bindType = info.bindType,
    setID = info.setID, track = readTrack(R, link), stats = readStats(R, link),
    unique = readUnique(R, link, itemID), transmogKnown = readTransmog(self, link, info.equipLoc),
  }
  readSpecs(R, facts)
  readBinds(R, facts)
  readUseText(self, facts)
  readClasses(self, facts)
  readTokenSlot(self, facts)
  readCollect(self, facts)
  return facts
end

local function rereadToken(v, facts)
  readUseText(v, facts)
  readClasses(v, facts)
  readTokenSlot(v, facts)
  readCollect(v, facts)
end

local function spellLoading(v, facts)
  return facts.useSpellLoading ~= nil and v.R.CanRequestSpellLoad()
end

-- ---------------------------------------------------------------------------------------------
-- The cache
-- ---------------------------------------------------------------------------------------------

local function touch(s, link)
  s.tick = s.tick + 1
  s.used[link] = s.tick
end

local function evict(v, s)
  local links = {}
  for link in pairs(s.cache) do links[#links + 1] = link end
  table.sort(links, function(a, b) return s.used[a] < s.used[b] end)
  local n = math.max(1, math.floor(#links * IF.EVICT_SHARE))
  for i = 1, n do s.cache[links[i]], s.used[links[i]] = nil, nil end
  s.count, s.evicted = s.count - n, s.evicted + n
  v:Debug(TAG, "item facts: cache full at %d, %d least recently used dropped", IF.CACHE_CAP, n)
end

--- The facts of a link: cached, else read now and cached; nil while the client has not cached the
--- item (v:Request loads it), or for a link that names no item.
--- @param link string
--- @return table|nil
function methods:Facts(link)
  if not validLink(self, link) then return nil end
  local s = store(self)
  local hit = s.cache[link]
  if hit then
    touch(s, link)
    return hit
  end
  local facts = self:ReadFacts(link)
  if not facts then return nil end
  if s.count >= IF.CACHE_CAP then evict(self, s) end
  s.cache[link] = facts
  s.count = s.count + 1
  touch(s, link)
  return facts
end

-- ---------------------------------------------------------------------------------------------
-- Loading an uncached item
-- ---------------------------------------------------------------------------------------------

local attempt

local function finish(v, link, job, facts)
  store(v).loads[link] = nil
  for _, cb in ipairs(job.waiters) do cb(facts, link) end
end

local function onLoaded(v, link, job)
  if job.generation ~= (v.__factsGen or 0) then return end
  local facts = v:Facts(link)
  if facts and facts.useSpellLoading then rereadToken(v, facts) end
  if facts and not spellLoading(v, facts) then return finish(v, link, job, facts) end
  if job.tries < IF.MAX_LOAD_TRIES then return attempt(v, link, job) end
  v:Debug(TAG, "item facts: gave up on item %s after %d loads", job.itemID, job.tries)
  if facts then facts.useSpellLoading = nil end
  finish(v, link, job, facts)
end

attempt = function(v, link, job)
  job.tries = job.tries + 1
  local done = function() onLoaded(v, link, job) end
  local cached = store(v).cache[link]
  if cached and spellLoading(v, cached) and v.R.RequestSpellLoad(cached.useSpellLoading) then
    return C_Timer.After(IF.SPELL_LOAD_WAIT, done)
  end
  v.R.LoadItem(job.itemID, done)
end

--- The facts of a link now when the client has the item (and its use spell's text); else nil, and
--- `callback(facts, link)` runs once it has loaded or never does (after MAX_LOAD_TRIES), with nil
--- facts for an item never loaded. The second return: "ready", "loading", "invalid" (no item in the
--- link; no callback) or "unavailable" (the client cannot load items; no callback).
--- @param link string
--- @param callback function|nil
--- @return table|nil facts, string status
function methods:Request(link, callback)
  local itemID = validLink(self, link)
  if not itemID then return nil, "invalid" end
  local facts = self:Facts(link)
  if facts and not spellLoading(self, facts) then return facts, "ready" end
  if not (facts or self.R.CanRequestItemLoad()) then return nil, "unavailable" end
  local loads = store(self).loads
  local job = loads[link]
  if not job then
    job = { itemID = itemID, tries = 0, waiters = {}, generation = self.__factsGen or 0 }
    loads[link] = job
    attempt(self, link, job)
  end
  if callback then job.waiters[#job.waiters + 1] = callback end
  return nil, "loading"
end

--- How many links are cached, and how many are loading.
--- @return number cached, number loading
function methods:FactsCounts()
  local s, loading = store(self), 0
  for _ in pairs(s.loads) do loading = loading + 1 end
  return s.count, loading
end

--- Read the collection state again on every cached collectible (lib.Collect.Read on the cache's
--- own tables). Answers how many were read.
--- @return number
function methods:RereadCollections()
  local CO, n = lib.Collect, 0
  if not CO then return 0 end
  for _, facts in pairs(store(self).cache) do
    if CO.IsCollectible(facts) then
      CO.Read(facts, self.R)
      n = n + 1
    end
  end
  return n
end

-- ---------------------------------------------------------------------------------------------
-- Events and the lifecycle
-- ---------------------------------------------------------------------------------------------

-- A spell's text arrived: every cached item still waiting on it is read again.
lib.__events["facts:SPELL_TEXT_UPDATE"] = { event = "SPELL_TEXT_UPDATE", fn = function(v, _, spellID)
  if v.R.IsSecret(spellID) or type(spellID) ~= "number" then return end
  for _, facts in pairs(store(v).cache) do
    if facts.useSpellLoading == spellID then rereadToken(v, facts) end
  end
end }

-- An appearance was learned (or lost): re-read the flag on every cached link, then the collections.
lib.__events["facts:TRANSMOG_COLLECTION_UPDATED"] = { event = "TRANSMOG_COLLECTION_UPDATED",
  clients = C.FEATURE_CLIENTS.transmog, fn = function(v)
    for link, facts in pairs(store(v).cache) do
      facts.transmogKnown = readTransmog(v, link, facts.rawEquipLoc)
    end
    if v.CollectionsChanged then v:CollectionsChanged() end
  end }

lib.__lifecycle.facts = { order = 20, down = function(v)
  v.__factsGen = (v.__factsGen or 0) + 1
  v.__facts = nil
end }
