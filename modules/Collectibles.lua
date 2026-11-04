local _, NS = ...
-- modules/Collectibles.lua — which category a drop falls in, and the collection verdict of the
-- collectible ones (issue #13, categories design spec §1, §3.1, §3.2).
--
--   facts.category = "equipment" | "tierToken" | "mount" | "pet" | "toy" | "recipe" | "cosmetic" | nil
--   facts.collect  = { kind, mountID?, speciesID?, known = true | false | nil, count?, limit?,
--                      skillLine?, hasProfession? } | nil   (collectibles only; a cosmetic's
--                      known is always nil: its state is facts.transmogKnown)
--
-- THE PURE HALF. CategoryOf(facts, probe) reads the facts and the probe's collection answers
-- ({ mountID, speciesID, toy, cosmetic }, all optional) and names the category, first match wins:
-- tierToken, equipment, mount, pet, toy, recipe, cosmetic, else nil (not watched). Equipment is
-- armor and weapons that are not cosmetic (the Cosmetic armor subclass, or the client's cosmetic
-- flag, which cosmetic weapons carry); a cosmetic comes after the collectibles, so a toy or mount
-- that carries the flag keeps its own category. Verdict(facts, forced) answers the `me` evaluation
-- of a collectible (new, collected, unknown, or can't use for a recipe of a profession you lack),
-- or of a whitelisted item with no category; nil for anything else. IsCollectible says whether a
-- category gets that verdict (C.CATEGORIES' `collectible`).
--
-- THE EDGE. Read(facts) asks NS.Compat (core/CompatCollect.lua) for the probes and the collection
-- state and fills `category` and `collect`. The probes are spent where they can matter: the
-- cosmetic flag on armor and weapons, the mount, pet and toy probes on anything else (cosmetic gear
-- included), none on a tier token; the recipe's known line and the professions on recipes alone.
-- modules/ItemFacts.lua calls it on the facts it is building, before they are cached: the cached
-- tables stay ItemFacts' to write. A cosmetic's collection state is its `transmogKnown`, which
-- ItemFacts keeps current: its `collect.known` stays nil (a copy would go stale once the
-- appearance is learned), and Verdict and every later reader read `transmogKnown`.
--
-- Not read by the feed yet (DW-CAT1): the category is computed for the next items to consume.

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

--- The category an item falls in, or nil when it is not watched (see the header for the order).
--- @param facts table
--- @param probe table|nil { mountID, speciesID, toy, cosmetic }: the client's collection answers
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
    return nil
end

--- True when the facts' category gets a collection verdict (a mount, pet, toy, recipe or cosmetic).
--- @param facts table|nil
--- @return boolean
function CO.IsCollectible(facts)
    return type(facts) == "table" and COLLECTIBLE[facts.category] == true
end

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

--- The `me` evaluation of a collectible:
---   { verdict = "newCollect" | "collected" | "collectUnknown" | "cantUse", equip = "collect",
---     collect = true, category, count?, limit?, reasons = { { key, detail } } }
--- `forced` (the whitelist let the item through) adds the `whitelisted` reason; a forced item with
--- no category answers verdict `unknown`. Nil for an item that is neither.
--- @param facts table|nil
--- @param forced boolean|nil
--- @return table|nil
function CO.Verdict(facts, forced)
    if not CO.IsCollectible(facts) then
        if not forced then return nil end
        return { verdict = "unknown", equip = "collect", collect = true, reasons = { reason("whitelisted") } }
    end
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
    facts.collect = COLLECTIBLE[facts.category] and collectOf(facts.category, facts, probe) or nil
    return facts
end
