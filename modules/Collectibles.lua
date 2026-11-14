local _, NS = ...
-- modules/Collectibles.lua — which category a drop falls in, and the collection verdict of the
-- collectible ones (issue #13, categories design spec §1, §3.1, §3.2).
--
--   facts.category = "equipment" | "tierToken" | "mount" | "pet" | "toy" | "recipe" | "cosmetic"
--                    | "container" | nil
--   facts.collect  = { kind, mountID?, speciesID?, known = true | false | nil, count?, limit?,
--                      skillLine?, hasProfession? } | nil   (collectibles only; a cosmetic's
--                      known is always nil: its state is facts.transmogKnown)
--
-- THE PURE HALF. CategoryOf(facts, probe) reads the facts and the probe's collection answers
-- ({ mountID, speciesID, toy, cosmetic }, all optional) and names the category, first match wins:
-- tierToken, equipment, mount, pet, toy, recipe, cosmetic, container, else nil (no kind). Equipment is
-- armor and weapons that are not cosmetic (the Cosmetic armor subclass, or the client's cosmetic
-- flag, which cosmetic weapons carry); a cosmetic comes after the collectibles, so a toy or mount
-- that carries the flag keeps its own category. A container (RX-04, rolls UX design §3.5) is a bag
-- (the Container class) or Miscellaneous Junk that opens (the probe's `opens`: its tooltip reads
-- Locked, a lockbox, or <Right Click to Open>), the class the client gives a lockbox; other Junk has
-- no kind. Verdict(facts, forced) answers the `me` evaluation of a collectible (new,
-- collected, unknown, or can't use for a recipe of a profession you lack), of a container (its kind
-- word, `lockbox` or `container`), of an item of no kind (`item`, category `other`: the feed shows
-- one only through its rolled-on catch-all, and your roll popup judges every roll; a whitelisted
-- one reads `item` too, and `unknown` only while its class is not read, RX-12); nil for gear. None of these carries a gain, and
-- each is feed-only. IsCollectible says whether a category gets a collection verdict (C.CATEGORIES'
-- `collectible`).
--
-- THE EDGE. Read(facts) asks NS.Compat (core/CompatCollect.lua) for the probes and the collection
-- state and fills `category` and `collect`. The probes are spent where they can matter: the
-- cosmetic flag on armor and weapons, the mount, pet and toy probes on anything else (cosmetic gear
-- included), none on a tier token; the recipe's known line and the professions on recipes alone;
-- the opens read (NS.Compat.ItemOpens) on Miscellaneous Junk alone, the class a lockbox has.
-- modules/ItemFacts.lua calls it on the facts it is building, before they are cached: the cached
-- tables stay ItemFacts' to write. A cosmetic's collection state is its `transmogKnown`, which
-- ItemFacts keeps current: its `collect.known` stays nil (a copy would go stale once the
-- appearance is learned), and Verdict and every later reader read `transmogKnown`.
--
-- The feed's filter reads `category` against the item kinds (NS.FeedFilter, DW-CAT2). The feed
-- judges a collectible through Verdict, not NS.Evaluate (modules/LootFeed.lua's judgeMe), and a
-- feed-only drop (IsFeedOnly: `me.collect`) has no action: no Ask, toast, AutoAsk, Offer,
-- Announce, Post my tradeables or glow, and no inspect (spec §6.2).
--
-- THE RE-READ (spec §4.6). NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED, NEW_RECIPE_LEARNED,
-- SKILL_LINES_CHANGED and ItemFacts' TRANSMOG_COLLECTION_UPDATED handler (Changed) arm one
-- REREAD_DELAY timer, so a burst reads once. It runs NS.ItemFacts.RereadCollections (the cache is
-- ItemFacts' to write), then sends each live collectible whose verdict moved through
-- NS.LootFeed.Refresh(rec, "collection"), which re-judges it and sends DropUpdated(id,
-- "collection"). PLAYER_REGEN_ENABLED arms the same timer for the drops still at collectUnknown
-- alone (a protected answer reads once combat ends). The stand-down cancels the timer.

NS.Collectibles = NS.Collectibles or {}
local CO = NS.Collectibles
local C = NS.Constants

local IC, AS, MS = C.ITEM_CLASS, C.ARMOR_SUBCLASS, C.MISC_SUBCLASS

local COLLECTIBLE = {}
for _, cat in ipairs(C.CATEGORIES) do COLLECTIBLE[cat.key] = cat.collectible end

-- ── the pure half ───────────────────────────────────────────────────────────────────────────

local function isGearClass(facts)
    return facts.classID == IC.ARMOR or facts.classID == IC.WEAPON
end

-- Cosmetic gear: the Cosmetic armor subclass, or an armor or weapon item the client flags cosmetic.
local function isCosmetic(facts, probe)
    if not isGearClass(facts) then return false end
    return (facts.classID == IC.ARMOR and facts.subClassID == AS.COSMETIC) or probe.cosmetic == true
end

local function isMisc(facts, subClassID)
    return facts.classID == IC.MISCELLANEOUS and facts.subClassID == subClassID
end

-- A bag, or Junk that opens (a lockbox): `container`; nil for anything else (RX-04).
local function containerOf(facts, probe)
    if facts.classID == IC.CONTAINER then return "container" end
    if probe.opens and isMisc(facts, MS.JUNK) then return "container" end
    return nil
end

--- The category an item falls in, or nil when it is not watched (see the header for the order).
--- @param facts table
--- @param probe table|nil { mountID, speciesID, toy, cosmetic, opens }: the client's answers
--- @return string|nil
function CO.CategoryOf(facts, probe)
    if type(facts) ~= "table" then return nil end
    probe = type(probe) == "table" and probe or {}
    if facts.isTierToken then return "tierToken" end
    local cosmetic = isCosmetic(facts, probe)
    if isGearClass(facts) and not cosmetic then return "equipment" end
    if probe.mountID or isMisc(facts, MS.MOUNT) then return "mount" end
    if probe.speciesID or isMisc(facts, MS.COMPANION_PET) then return "pet" end
    if probe.toy then return "toy" end
    if facts.classID == IC.RECIPE then return "recipe" end
    if cosmetic then return "cosmetic" end
    return containerOf(facts, probe)
end

--- True when the facts' category gets a collection verdict (a mount, pet, toy, recipe or cosmetic).
--- @param facts table|nil
--- @return boolean
function CO.IsCollectible(facts)
    return type(facts) == "table" and COLLECTIBLE[facts.category] == true
end

local kindVerdict

local function reason(key, detail)
    return { key = key, detail = detail }
end

-- The verdict and its reason key for a known flag (true, false or nil: no answer).
local function knownVerdict(known)
    if known == true then return "collected", "collectKnown" end
    if known == false then return "newCollect", "collectNew" end
    return "collectUnknown", "collectNoAnswer"
end

-- The verdict and its reasons of a collectible whose category and collection state are read.
local function judge(category, collect, known)
    if category == "recipe" and collect.hasProfession == false then
        return "cantUse", { reason("notYourProfession") }
    end
    local verdict, key = knownVerdict(known)
    local reasons = { reason(key) }
    local count, limit = collect.count, collect.limit
    if category == "pet" and count and limit and count > 0 and count < limit then
        reasons[2] = reason("petPartial", ("%d/%d"):format(count, limit))
    end
    return verdict, reasons
end

-- A lockbox's kind word (its tooltip read Locked: `facts.lockbox`), else a bag's or a box's.
local function containerWord(facts) return facts.lockbox == true and "lockbox" or "container" end

local function readsAsGear(facts) return isGearClass(facts) or C.SLOT_PLAN[facts.equipLoc or ""] ~= nil end

-- An Always watch item of no kind whose class is not read yet, or that reads as gear.
local function forcedUnknown()
    return { verdict = "unknown", equip = "collect", collect = true, reasons = { reason("whitelisted") } }
end

-- The verdict of an item that is not gear and not collected (RX-04): a container's kind word, an
-- item of no kind's `item` (an Always watch one too, ruling 3: never Unknown, RX-12); nil for gear
-- and a token. An Always watch item of no category answers `unknown` only while its class is not
-- read, or when it reads as gear.
kindVerdict = function(facts, forced)
    if type(facts) ~= "table" then return nil end
    local category = facts.category
    if category ~= nil and category ~= "container" then return nil end
    if category == nil and readsAsGear(facts) then return forced and forcedUnknown() or nil end
    if category == nil and forced and facts.classID == nil then return forcedUnknown() end
    local out = { verdict = category and containerWord(facts) or "item", equip = "collect", collect = true,
        category = category or "other", reasons = { reason("notGear") } }
    if forced then out.reasons[2] = reason("whitelisted") end
    return out
end

--- The `me` evaluation of a collectible:
---   { verdict = "newCollect" | "collected" | "collectUnknown" | "cantUse", equip = "collect",
---     collect = true, category, count?, limit?, reasons = { { key, detail } } }
--- `forced` (the whitelist let the item through) adds the `whitelisted` reason; a forced item with
--- no category answers its kind word like any other (`item`), and verdict `unknown` only while its
--- class is not read or when it reads as gear. A container answers its kind word (`lockbox`, `container`)
--- and an unforced item of no kind `item` (category `other`), reason `notGear`. Nil for gear and a
--- tier token (the gear kernel judges them) and for no facts.
--- @param facts table|nil
--- @param forced boolean|nil
--- @return table|nil
function CO.Verdict(facts, forced)
    if not CO.IsCollectible(facts) then return kindVerdict(facts, forced) end
    local category, collect = facts.category, facts.collect or {}
    local known = collect.known
    if category == "cosmetic" then known = facts.transmogKnown end
    local verdict, reasons = judge(category, collect, known)
    if forced then reasons[#reasons + 1] = reason("whitelisted") end
    return { verdict = verdict, equip = "collect", collect = true, category = category,
        count = collect.count, limit = collect.limit, reasons = reasons }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- The client's collection answers CategoryOf needs, each asked only where it can decide.
local function probeOf(facts)
    local Compat, probe = NS.Compat, {}
    if facts.isTierToken then return probe end
    if isGearClass(facts) then
        probe.cosmetic = Compat.IsCosmeticItem(facts.link)
        if not isCosmetic(facts, probe) then return probe end
    end
    probe.mountID = Compat.MountFromItem(facts.itemID)
    if probe.mountID then return probe end
    probe.speciesID = Compat.PetSpeciesFromItem(facts.itemID)
    if probe.speciesID then return probe end
    probe.toy = Compat.IsToy(facts.itemID)
    if not probe.toy and isMisc(facts, MS.JUNK) then probe.opens = Compat.ItemOpens(facts.link) end
    return probe
end

-- Whether you have the profession a skill line names: false with no profession at all (a real
-- answer, common on alts), nil only when the client gave no answer (not "none of yours").
local function hasProfession(skillLine)
    if not skillLine then return nil end
    local lines = NS.Compat.ProfessionSkillLines()
    if type(lines) ~= "table" then return nil end
    return lines[skillLine] == true
end

local function readMount(collect, probe)
    collect.mountID = probe.mountID
    if probe.mountID then collect.known = NS.Compat.MountCollected(probe.mountID) end
end

local function readPet(collect, probe)
    collect.speciesID = probe.speciesID
    if not probe.speciesID then return end
    collect.count, collect.limit = NS.Compat.PetCollected(probe.speciesID)
    if collect.count then collect.known = collect.count > 0 end
end

local function readRecipe(collect, facts)
    collect.skillLine = C.RECIPE_SKILL_LINE[facts.subClassID]
    collect.hasProfession = hasProfession(collect.skillLine)
    collect.known = NS.Compat.RecipeKnown(facts.link)
end

-- The collection state of a collectible category.
local function collectOf(category, facts, probe)
    local collect = { kind = category }
    if category == "mount" then readMount(collect, probe)
    elseif category == "pet" then readPet(collect, probe)
    elseif category == "toy" then collect.known = NS.Compat.ToyCollected(facts.itemID)
    elseif category == "recipe" then readRecipe(collect, facts) end
    return collect
end

--- Fill `facts.category` and, for a collectible, `facts.collect`, through NS.Compat. Called by
--- modules/ItemFacts.lua on the facts it is building; answers the same table.
--- @param facts table
--- @return table
function CO.Read(facts)
    if type(facts) ~= "table" then return facts end
    local probe = probeOf(facts)
    facts.category = CO.CategoryOf(facts, probe)
    facts.lockbox = facts.category == "container" and probe.opens == "locked" or nil
    facts.collect = COLLECTIBLE[facts.category] and collectOf(facts.category, facts, probe) or nil
    return facts
end

--- Whether a drop is feed-only (categories design spec §6.2): its verdict for you is a collection
--- verdict (`me.collect`), so it is watched and never asked for, toasted, auto-asked, offered,
--- announced, posted or glowed. Pure: reads the drop record alone.
--- @param drop table|nil a feed record
--- @return boolean
function CO.IsFeedOnly(drop)
    return type(drop) == "table" and type(drop.me) == "table" and drop.me.collect == true
end

-- ── reading the collections again (spec §4.6) ──────────────────────────────────────────────

CO.REREAD_DELAY = 0.5

-- The one coalescing timer, and whether the pass it runs is the full one (`all`) or the regen pass
-- (`unknown`: only the drops still at collectUnknown).
local pending = { timer = nil, scope = nil }

-- A verdict's state as the re-read compares it: the verdict and a pet's count.
local function stateOf(me)
    return type(me) == "table" and (tostring(me.verdict) .. ":" .. tostring(me.count)) or nil
end

-- Whether a live drop's collection verdict may be read again by a pass of `scope`.
local function wanted(rec, scope)
    if rec.test or not CO.IsFeedOnly(rec) then return false end
    return scope == "all" or rec.me.verdict == "collectUnknown"
end

-- The pass: the cache's collectibles read again (ItemFacts writes its own cache), then each live
-- collectible whose verdict moved is re-judged through the feed's Refresh (DropUpdated `collection`).
local function reread(scope)
    NS.ItemFacts.RereadCollections()
    local n = 0
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        local facts = wanted(rec, scope) and NS.ItemFacts.Get(rec.link)
        local now = facts and CO.Verdict(facts, rec.forced)
        if now and stateOf(now) ~= stateOf(rec.me) then
            NS.LootFeed.Refresh(rec, "collection")
            n = n + 1
        end
    end
    NS.Debug("EVAL", "collections read again (%s): %d drops moved", scope, n)
    return n
end

-- Arm the one timer; a full pass asked for while the regen pass waits widens it.
local function arm(scope)
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if scope == "all" or not pending.scope then pending.scope = scope end
    if pending.timer then return end
    pending.timer = C_Timer.NewTimer(CO.REREAD_DELAY, function()
        local s = pending.scope
        pending.timer, pending.scope = nil, nil
        reread(s)
    end)
end

--- A collection changed (a mount, pet, toy or recipe learned, a profession gained or lost, an
--- appearance learned): read the collectibles again, once, CO.REREAD_DELAY seconds from the first
--- call of a burst. ItemFacts' transmog handler calls it too.
function CO.Changed() arm("all") end

for _, event in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED", "NEW_RECIPE_LEARNED",
    "SKILL_LINES_CHANGED" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnCollectionEvent" }
end
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnCollectRegenEvent" }

function NS.addon.OnCollectionEvent() CO.Changed() end

-- Combat ended: a protected answer may read now, so the drops still at collectUnknown are read again.
function NS.addon.OnCollectRegenEvent()
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        if wanted(rec, "unknown") then return arm("unknown") end
    end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending.timer then pending.timer:Cancel() end
    pending.timer, pending.scope = nil, nil
end
