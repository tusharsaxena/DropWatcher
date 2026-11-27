-- LibKa0s-Verdict-1.0 -- which category an item falls in, and the collection verdict of the
-- collectible ones, as `lib.Collect`; the instance's collection re-read. Moved from Ka0s Drop
-- Watcher's modules/Collectibles.lua (its pure verdict and its read; the feed's own re-read pass
-- stays in Drop Watcher's modules/CollectFeed.lua) (DropWatcher#19).
--
--   facts.category = "equipment" | "tierToken" | "mount" | "pet" | "toy" | "recipe" | "cosmetic"
--                    | "lockbox" | "container" | "reagent" | nil
--   facts.collect  = { kind, mountID?, speciesID?, known = true | false | nil, count?, limit?,
--                      skillLine?, hasProfession? } | nil   (collectibles only; a cosmetic's
--                      known is always nil: its state is facts.transmogKnown)
--
-- THE PURE HALF. CategoryOf(facts, probe) reads the facts and the probe's collection answers
-- ({ mountID, speciesID, toy, cosmetic, opens }, all optional) and names the category, first match
-- wins: tierToken, equipment, mount, pet, toy, recipe, cosmetic, lockbox, container, reagent, else
-- nil. Equipment is armor and weapons that are not cosmetic (the Cosmetic armor subclass, or the
-- client's cosmetic flag); a cosmetic comes after the collectibles, so a toy or mount carrying the
-- flag keeps its own category. A lockbox is Miscellaneous Junk that opens; a container is a bag or,
-- on WoW Forever, a quiver or ammo pouch; a reagent is the Trade Goods class.
-- Verdict(facts, forced) answers the `me` verdict of a collectible (new, collected, unknown, or
-- can't use for a recipe of a profession you lack), of a lockbox, container or reagent (its kind
-- word), of an item of no kind (`item`, category `other`); nil for gear and a tier token (the
-- kernel judges them). `forced` (the host let the item through on its own list) adds the
-- `whitelisted` reason, and answers `unknown` for an item of no category only while its class is
-- not read or when it reads as gear. IsCollectible says whether a category gets a collection
-- verdict (C.CATEGORIES' `collectible`).
--
-- THE READ. Collect.Read(facts, R) asks the reads `R` (an instance's `v.R`) for the probes and the
-- collection state and fills `category` and `collect`. The probes are spent where they can
-- matter: the cosmetic flag on armor and weapons, the mount, pet and toy probes on anything else,
-- none on a tier token; the recipe's known line and the professions on recipes alone; the opens
-- read on Miscellaneous Junk alone. The facts reader calls it on the facts it is building, before
-- they are cached.
--
-- THE RE-READ (the instance's). A mount, pet, toy or recipe learned, or a profession gained or
-- lost (NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED, NEW_RECIPE_LEARNED, SKILL_LINES_CHANGED),
-- and an appearance learned (VerdictFacts.lua's TRANSMOG_COLLECTION_UPDATED handler, through
-- v:CollectionsChanged), arm one REREAD_DELAY timer per instance, so a burst reads once: it reads
-- every cached collectible again (v:RereadCollections, VerdictFacts.lua) and tells the host
-- onChange("collection"). The stand-down cancels it.
--
-- Depends on the Verdict shell (Verdict.lua) and VerdictConstants.lua.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.C then return end

local COLLECT_MINOR = 1
-- Minor 1 (DropWatcher#19, task B2): Drop Watcher's category, collection verdict and read, the
-- reads the instance's.
if lib.__collectMinor and lib.__collectMinor >= COLLECT_MINOR
  and lib.__collectShellMinor == lib.MINOR then return end
lib.__collectMinor      = COLLECT_MINOR
lib.__collectShellMinor = lib.MINOR

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictCollect = COLLECT_MINOR

local CO = {}
lib.Collect = CO
local C = lib.C
local methods = lib.__methods

local IC, AS, MS = C.ITEM_CLASS, C.ARMOR_SUBCLASS, C.MISC_SUBCLASS

-- Seconds a burst of collection events waits before one re-read.
CO.REREAD_DELAY = 0.5

local COLLECTIBLE = {}
-- The categories whose verdict is their kind word: C.CATEGORIES' `kind` ones but `other`.
local KIND_CATEGORY = {}
for _, cat in ipairs(C.CATEGORIES) do
  COLLECTIBLE[cat.key] = cat.collectible
  if cat.kind and cat.key ~= "other" then KIND_CATEGORY[cat.key] = true end
end

-- Whether an equip location has a slot plan: `client`'s, or with no client named either client's.
local function hasSlotPlan(equipLoc, client)
  local key = equipLoc or ""
  if client ~= nil then return C.SlotPlanFor(client)[key] ~= nil end
  return C.SlotPlanFor("retail")[key] ~= nil or C.SlotPlanFor("forever")[key] ~= nil
end

-- ---------------------------------------------------------------------------------------------
-- The pure half
-- ---------------------------------------------------------------------------------------------

local function isGearClass(facts)
  return facts.classID == IC.ARMOR or facts.classID == IC.WEAPON
end

local function isCosmetic(facts, probe)
  if not isGearClass(facts) then return false end
  return (facts.classID == IC.ARMOR and facts.subClassID == AS.COSMETIC) or probe.cosmetic == true
end

local function isMisc(facts, subClassID)
  return facts.classID == IC.MISCELLANEOUS and facts.subClassID == subClassID
end

local function containerOf(facts, probe)
  if facts.classID == IC.CONTAINER or facts.classID == IC.QUIVER then return "container" end
  if probe.opens and isMisc(facts, MS.JUNK) then return "lockbox" end
  if facts.classID == IC.TRADEGOODS then return "reagent" end
  return nil
end

--- The category an item falls in, or nil when it has none (see the header for the order).
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

local function reason(key, detail)
  return { key = key, detail = detail }
end

local function knownVerdict(known)
  if known == true then return "collected", "collectKnown" end
  if known == false then return "newCollect", "collectNew" end
  return "collectUnknown", "collectNoAnswer"
end

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

local function readsAsGear(facts, client) return isGearClass(facts) or hasSlotPlan(facts.equipLoc, client) end

local function forcedUnknown()
  return { verdict = "unknown", equip = "collect", collect = true, reasons = { reason("whitelisted") } }
end

-- The verdict of an item that is not gear and not collected: a lockbox's, container's or
-- reagent's kind word, an item of no kind's `item`; nil for gear and a token.
local function kindVerdict(facts, forced, client)
  if type(facts) ~= "table" then return nil end
  local category = facts.category
  if category ~= nil and not KIND_CATEGORY[category] then return nil end
  if category == nil and readsAsGear(facts, client) then return forced and forcedUnknown() or nil end
  if category == nil and forced and facts.classID == nil then return forcedUnknown() end
  local out = { verdict = category or "item", equip = "collect", collect = true,
    category = category or "other", reasons = { reason("notGear") } }
  if forced then out.reasons[2] = reason("whitelisted") end
  return out
end

--- The `me` verdict of an item that is not gear (see the header):
---   { verdict, equip = "collect", collect = true, category, count?, limit?, reasons }
--- Nil for gear and a tier token (the kernel judges them) and for no facts. `client` names whose
--- slot plans say an item of no category reads as gear (either client's when nil).
--- @param facts table|nil
--- @param forced boolean|nil
--- @param client string|nil "retail" | "forever"
--- @return table|nil
function CO.Verdict(facts, forced, client)
  if not CO.IsCollectible(facts) then return kindVerdict(facts, forced, client) end
  local category, collect = facts.category, facts.collect or {}
  local known = collect.known
  if category == "cosmetic" then known = facts.transmogKnown end
  local verdict, reasons = judge(category, collect, known)
  if forced then reasons[#reasons + 1] = reason("whitelisted") end
  return { verdict = verdict, equip = "collect", collect = true, category = category,
    count = collect.count, limit = collect.limit, reasons = reasons }
end

-- ---------------------------------------------------------------------------------------------
-- The read
-- ---------------------------------------------------------------------------------------------

local function probeOf(facts, R)
  local probe = {}
  if facts.isTierToken then return probe end
  if isGearClass(facts) then
    probe.cosmetic = R.IsCosmeticItem(facts.link)
    if not isCosmetic(facts, probe) then return probe end
  end
  probe.mountID = R.MountFromItem(facts.itemID)
  if probe.mountID then return probe end
  probe.speciesID = R.PetSpeciesFromItem(facts.itemID)
  if probe.speciesID then return probe end
  probe.toy = R.IsToy(facts.itemID)
  if not probe.toy and isMisc(facts, MS.JUNK) then probe.opens = R.ItemOpens(facts.link) end
  return probe
end

-- Whether you have the profession a skill line names: false with none at all, nil with no answer.
local function hasProfession(skillLine, R)
  if not skillLine then return nil end
  local lines = R.ProfessionSkillLines()
  if type(lines) ~= "table" then return nil end
  return lines[skillLine] == true
end

local function collectOf(category, facts, probe, R)
  local collect = { kind = category }
  if category == "mount" then
    collect.mountID = probe.mountID
    if probe.mountID then collect.known = R.MountCollected(probe.mountID) end
  elseif category == "pet" then
    collect.speciesID = probe.speciesID
    if probe.speciesID then
      collect.count, collect.limit = R.PetCollected(probe.speciesID)
      if collect.count then collect.known = collect.count > 0 end
    end
  elseif category == "toy" then
    collect.known = R.ToyCollected(facts.itemID)
  elseif category == "recipe" then
    collect.skillLine = C.RECIPE_SKILL_LINE[facts.subClassID]
    collect.hasProfession = hasProfession(collect.skillLine, R)
    collect.known = R.RecipeKnown(facts.link)
  end
  return collect
end

--- Fill `facts.category` and, for a collectible, `facts.collect`, through the reads `R` (an
--- instance's `v.R`, else lib.Reads). Answers the same table.
--- @param facts table
--- @param R table|nil
--- @return table
function CO.Read(facts, R)
  if type(facts) ~= "table" then return facts end
  R = R or lib.Reads
  local probe = probeOf(facts, R)
  facts.category = CO.CategoryOf(facts, probe)
  facts.collect = COLLECTIBLE[facts.category] and collectOf(facts.category, facts, probe, R) or nil
  return facts
end

-- ---------------------------------------------------------------------------------------------
-- The instance's re-read
-- ---------------------------------------------------------------------------------------------

--- Read the collections again, once, CO.REREAD_DELAY seconds from the first call of a burst, then
--- tell the host onChange("collection"). Nothing arms while stood down.
function methods:CollectionsChanged()
  if self.down or self.__collectTimer or not (C_Timer and C_Timer.NewTimer) then return end
  self.__collectTimer = C_Timer.NewTimer(CO.REREAD_DELAY, function()
    self.__collectTimer = nil
    local n = self.RereadCollections and self:RereadCollections() or 0
    self:Debug("EVAL", "collections read again: %d cached collectibles", n)
    self:Changed("collection")
  end)
end

for _, event in ipairs({ "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED", "NEW_RECIPE_LEARNED",
  "SKILL_LINES_CHANGED" }) do
  lib.__events["collect:" .. event] = { event = event, fn = function(v) v:CollectionsChanged() end }
end

lib.__lifecycle.collect = { order = 10, down = function(v)
  if v.__collectTimer then v.__collectTimer:Cancel() end
  v.__collectTimer = nil
end }
