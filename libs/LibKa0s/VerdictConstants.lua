-- LibKa0s-Verdict-1.0 -- the constants: the item, slot and quality numbers the kernel reads, as
-- `lib.C`. Moved from Ka0s Drop Watcher's core/Constants.lua (DropWatcher#19), the values verbatim.
--
-- READ THEM, NEVER WRITE THEM. `lib.C` is one table shared by every addon that loads the major, so
-- a write is a write into another addon's verdicts.
--
-- Item ids are read from the client's Enum tables when present; each literal beside its member is
-- the documented value, used when Enum (or that member) is absent: the headless harness, or a
-- client that renamed the member. Never compare against a localized type name.
--
-- PER CLIENT. Drop Watcher picked the slot ids and the ranged slot plans once, at file load. Here
-- both clients' are kept, and the caller names one: `C.SlotsFor(client)` and
-- `C.SlotPlanFor(client)` answer Retail's for any client but "forever", nil included. `C.SLOT` is
-- the slots both clients share (the ranged slot is WoW Forever's alone), and every slot the kernel
-- names is in it.
--
-- Depends on the Verdict shell (Verdict.lua) and nothing else.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib then return end

local CONSTANTS_MINOR = 1
local ORDER = 10   -- its place in LibKa0s.xml (Verdict.lua, lib.__Stale)
-- Minor 1 (DropWatcher#19, task B1): the subset of Drop Watcher's core/Constants.lua the kernel
-- reads, both clients' slot plans kept.
if lib.__constantsMinor and lib.__constantsMinor >= CONSTANTS_MINOR
  and lib.__constantsShellMinor == lib.MINOR and not lib.__Stale(ORDER) then return end
lib.__constantsMinor      = CONSTANTS_MINOR
lib.__constantsShellMinor = lib.MINOR
lib.__Ran(ORDER)

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictConstants = CONSTANTS_MINOR

local C = {}
lib.C = C

local EnumTable = Enum or {}

-- Copies `spec` ({ KEY = { "EnumMember", literal } }) into { KEY = id }, reading `enumTable`.
local function fromEnum(enumTable, spec)
  local out = {}
  enumTable = enumTable or {}
  for key, pair in pairs(spec) do
    local v = enumTable[pair[1]]
    out[key] = type(v) == "number" and v or pair[2]
  end
  return out
end

-- Enum.ItemClass.
C.ITEM_CLASS = fromEnum(EnumTable.ItemClass, {
  CONSUMABLE    = { "Consumable", 0 },
  WEAPON        = { "Weapon", 2 },
  ARMOR         = { "Armor", 4 },
  CONTAINER     = { "Container", 1 },
  REAGENT       = { "Reagent", 5 },
  RECIPE        = { "Recipe", 9 },
  MISCELLANEOUS = { "Miscellaneous", 15 },
  QUIVER        = { "Quiver", 11 },     -- WoW Forever's quivers and ammo pouches
  TRADEGOODS    = { "Tradegoods", 7 },  -- crafting reagents: Trade Goods
})

-- Enum.ItemMiscellaneousSubclass: a mount or companion pet item's class rung, the fallback when the
-- journal does not answer. Mount Equipment is not a mount.
C.MISC_SUBCLASS = fromEnum(EnumTable.ItemMiscellaneousSubclass, {
  JUNK            = { "Junk", 0 },
  REAGENT         = { "Reagent", 1 },
  COMPANION_PET   = { "CompanionPet", 2 },
  HOLIDAY         = { "Holiday", 3 },
  OTHER           = { "Other", 4 },
  MOUNT           = { "Mount", 5 },
  MOUNT_EQUIPMENT = { "MountEquipment", 6 },
})

-- Enum.ItemArmorSubclass. GENERIC is jewelry, trinkets and held off hands; COSMETIC is never gear.
-- LIBRAM, IDOL and TOTEM are WoW Forever's relics (the ranged slot, VerdictClassData.lua).
C.ARMOR_SUBCLASS = fromEnum(EnumTable.ItemArmorSubclass, {
  GENERIC  = { "Generic", 0 },
  CLOTH    = { "Cloth", 1 },
  LEATHER  = { "Leather", 2 },
  MAIL     = { "Mail", 3 },
  PLATE    = { "Plate", 4 },
  COSMETIC = { "Cosmetic", 5 },
  SHIELD   = { "Shield", 6 },
  LIBRAM   = { "Libram", 7 },
  IDOL     = { "Idol", 8 },
  TOTEM    = { "Totem", 9 },
})

-- Enum.ItemWeaponSubclass.
C.WEAPON_SUBCLASS = fromEnum(EnumTable.ItemWeaponSubclass, {
  AXE_1H    = { "Axe1H", 0 },
  AXE_2H    = { "Axe2H", 1 },
  BOWS      = { "Bows", 2 },
  GUNS      = { "Guns", 3 },
  MACE_1H   = { "Mace1H", 4 },
  MACE_2H   = { "Mace2H", 5 },
  POLEARM   = { "Polearm", 6 },
  SWORD_1H  = { "Sword1H", 7 },
  SWORD_2H  = { "Sword2H", 8 },
  WARGLAIVE = { "Warglaive", 9 },
  STAFF     = { "Staff", 10 },
  FIST      = { "Unarmed", 13 },
  GENERIC   = { "Generic", 14 },
  DAGGER    = { "Dagger", 15 },
  THROWN    = { "Thrown", 16 },   -- WoW Forever's ranged slot (VerdictClassData.lua)
  CROSSBOW  = { "Crossbow", 18 },
  WAND      = { "Wand", 19 },
})

-- Enum.ItemQuality.
C.QUALITY = fromEnum(EnumTable.ItemQuality, {
  POOR      = { "Poor", 0 },
  COMMON    = { "Common", 1 },
  UNCOMMON  = { "Uncommon", 2 },
  RARE      = { "Rare", 3 },
  EPIC      = { "Epic", 4 },
  LEGENDARY = { "Legendary", 5 },
  ARTIFACT  = { "Artifact", 6 },
  HEIRLOOM  = { "Heirloom", 7 },
})

-- Upgrade tracks in ascending order. The kernel compares a track's numeric `tier` first; the facts
-- reader fills it from the track's string id where the client has one. These enUS names are the
-- fallback for a track that carries only its name, so a localized name that matches none of them
-- leaves the track delta unset rather than guessed.
C.TRACK_TIER = { Explorer = 1, Adventurer = 2, Veteran = 3, Champion = 4, Hero = 5, Myth = 6 }

-- The slots a tier token can make, in the order an omni token's slots are tried.
C.TIER_SLOTS = { "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_HAND", "INVTYPE_LEGS" }

-- itemID -> { slot = "INVTYPE_HEAD" | ... | "any" }: an override for a token whose own text misreads;
-- the first rung of TierTokens.SlotOf, ahead of the Use text and the name, and a token on its own
-- (TierTokens.Listed). Empty: a token's slot is read from its text, so no table is kept up per
-- season.
C.TIER_TOKENS = {}

-- The clients each client-gated part of the engine serves: the off-spec pass is Retail's alone
-- (WoW Forever's spec is class-wide, so it has no other spec to judge; OffSpec.Enabled reads it),
-- and so is the appearance read (WoW Forever has no transmog; VerdictFacts.lua reads it).
C.FEATURE_CLIENTS = {
  offSpec  = { "retail" },
  transmog = { "retail" },
}

--- Whether feature `name` (a C.FEATURE_CLIENTS key) serves `client`: pure; a nil or unknown client,
--- or an unknown feature, answers false.
--- @param name string
--- @param client string|nil
--- @return boolean
function C.FeatureOn(name, client)
  for _, token in ipairs(C.FEATURE_CLIENTS[name] or {}) do
    if token == "both" or token == client then return true end
  end
  return false
end

-- trackStringID (C_Item.GetItemUpgradeInfo) -> tier, the locale-proof key the facts reader tries
-- first. Empty until the client's ids are recorded in game; until then every track's tier comes
-- from the enUS names of C.TRACK_TIER.
C.TRACK_TIER_BY_STRING_ID = {}

-- Enum.ItemRecipeSubclass.
C.RECIPE_SUBCLASS = fromEnum(EnumTable.ItemRecipeSubclass, {
  BOOK           = { "Book", 0 },
  LEATHERWORKING = { "Leatherworking", 1 },
  TAILORING      = { "Tailoring", 2 },
  ENGINEERING    = { "Engineering", 3 },
  BLACKSMITHING  = { "Blacksmithing", 4 },
  COOKING        = { "Cooking", 5 },
  ALCHEMY        = { "Alchemy", 6 },
  FIRST_AID      = { "FirstAid", 7 },
  ENCHANTING     = { "Enchanting", 8 },
  FISHING        = { "Fishing", 9 },
  JEWELCRAFTING  = { "Jewelcrafting", 10 },
  INSCRIPTION    = { "Inscription", 11 },
})

-- A recipe subclass -> the skill line of the profession it needs (GetProfessionInfo's 7th return).
-- Book and First Aid (retired) are absent, so no profession is checked for them.
local RS = C.RECIPE_SUBCLASS
C.RECIPE_SKILL_LINE = {
  [RS.LEATHERWORKING] = 165, [RS.TAILORING] = 197, [RS.ENGINEERING] = 202, [RS.BLACKSMITHING] = 164,
  [RS.COOKING] = 185, [RS.ALCHEMY] = 171, [RS.ENCHANTING] = 333, [RS.FISHING] = 356,
  [RS.JEWELCRAFTING] = 755, [RS.INSCRIPTION] = 773,
}

-- Every category an item can fall in, in display order. `collectible` ones get a collection
-- verdict (new or collected) instead of a gear one. `kind` ones are not gear and not collected:
-- their verdict is their kind word. `lockbox` is Miscellaneous Junk that opens; `container` a bag,
-- or on WoW Forever a quiver or ammo pouch; `reagent` a Trade Goods item; `other` is no item's
-- category (a host's catch-all). Collect.CategoryOf decides, in its own precedence order.
C.CATEGORIES = {
  { key = "equipment", collectible = false }, { key = "tierToken", collectible = false },
  { key = "mount", collectible = true }, { key = "pet", collectible = true },
  { key = "toy", collectible = true }, { key = "recipe", collectible = true },
  { key = "cosmetic", collectible = true },
  { key = "lockbox", collectible = false, kind = true }, { key = "container", collectible = false, kind = true },
  { key = "reagent", collectible = false, kind = true }, { key = "other", collectible = false, kind = true },
}

-- The bags the gear snapshot reads for the best item owned per slot: the backpack (0) and the four
-- bag slots. The reagent bag (5) holds no gear, and the bank is not readable away from it.
C.BAG_IDS = { 0, 1, 2, 3, 4 }

-- ---------------------------------------------------------------------------------------------
-- Inventory slots and slot plans
-- ---------------------------------------------------------------------------------------------

-- The client's inventory slot ids (the INVSLOT_* FrameXML constants). Slot 18, the old ranged
-- slot, is unused on Retail: bows, guns, crossbows and wands are main-hand items. WoW Forever keeps
-- it (INVSLOT_RANGED) for ranged and thrown weapons, wands and relics.
local function slots(ranged)
  return {
    HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6, LEGS = 7, FEET = 8,
    WRIST = 9, HANDS = 10, FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14, BACK = 15,
    MAINHAND = 16, OFFHAND = 17, RANGED = ranged, TABARD = 19,
  }
end
C.SLOTS = { retail = slots(nil), forever = slots(18) }
C.SLOT = C.SLOTS.retail   -- the slots both clients share
local S, SF = C.SLOTS.retail, C.SLOTS.forever

-- The comparison kinds the kernel knows. `unique` is applied on top of a plan when the drop
-- carries a unique-equipped category; no equip location maps to it directly.
C.SLOT_KIND = {
  single = true, pair = true, weapon1H = true, weapon2H = true, offhand = true, ranged = true,
  unique = true,
}

-- equipLoc -> { kind, slots }. An equip location absent here (shirt, tabard, bag, ammo,
-- non-equippable) is not gear the kernel compares. The rows both clients share; each client's own
-- ranged rows follow.
local SLOT_PLAN_SHARED = {
  INVTYPE_HEAD           = { kind = "single", slots = { S.HEAD } },
  INVTYPE_NECK           = { kind = "single", slots = { S.NECK } },
  INVTYPE_SHOULDER       = { kind = "single", slots = { S.SHOULDER } },
  INVTYPE_CHEST          = { kind = "single", slots = { S.CHEST } },
  INVTYPE_ROBE           = { kind = "single", slots = { S.CHEST } },
  INVTYPE_WAIST          = { kind = "single", slots = { S.WAIST } },
  INVTYPE_LEGS           = { kind = "single", slots = { S.LEGS } },
  INVTYPE_FEET           = { kind = "single", slots = { S.FEET } },
  INVTYPE_WRIST          = { kind = "single", slots = { S.WRIST } },
  INVTYPE_HAND           = { kind = "single", slots = { S.HANDS } },
  INVTYPE_CLOAK          = { kind = "single", slots = { S.BACK } },
  INVTYPE_FINGER         = { kind = "pair",   slots = { S.FINGER1, S.FINGER2 } },
  INVTYPE_TRINKET        = { kind = "pair",   slots = { S.TRINKET1, S.TRINKET2 } },
  -- A one-hander goes in either hand: main hand only, unless the candidate dual wields.
  INVTYPE_WEAPON         = { kind = "weapon1H", slots = { S.MAINHAND, S.OFFHAND } },
  -- A main-hand-only weapon can go nowhere else.
  INVTYPE_WEAPONMAINHAND = { kind = "single", slots = { S.MAINHAND } },
  -- Off-hand-only weapons, shields and held off hands share the "vs a 2H" rule.
  INVTYPE_WEAPONOFFHAND  = { kind = "offhand", slots = { S.OFFHAND } },
  INVTYPE_SHIELD         = { kind = "offhand", slots = { S.OFFHAND } },
  INVTYPE_HOLDABLE       = { kind = "offhand", slots = { S.OFFHAND } },
  INVTYPE_2HWEAPON       = { kind = "weapon2H", slots = { S.MAINHAND, S.OFFHAND } },
}

-- Each client's ranged rows.
local SLOT_PLAN_RANGED = {
  -- Retail: bows (RANGED) and guns, crossbows and wands (RANGEDRIGHT) fill both hands; there are
  -- no thrown weapons or relics.
  retail = {
    INVTYPE_RANGED      = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
    INVTYPE_RANGEDRIGHT = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
  },
  -- WoW Forever: bows, guns, crossbows, wands, thrown weapons and relics (a libram, idol or totem)
  -- go in the ranged slot, compared with what is worn there.
  forever = {
    INVTYPE_RANGED      = { kind = "single", slots = { SF.RANGED } },
    INVTYPE_RANGEDRIGHT = { kind = "single", slots = { SF.RANGED } },
    INVTYPE_THROWN      = { kind = "single", slots = { SF.RANGED } },
    INVTYPE_RELIC       = { kind = "single", slots = { SF.RANGED } },
  },
}

C.SLOT_PLANS = {}
for client, ranged in pairs(SLOT_PLAN_RANGED) do
  local plan = {}
  for loc, row in pairs(SLOT_PLAN_SHARED) do plan[loc] = row end
  for loc, row in pairs(ranged) do plan[loc] = row end
  C.SLOT_PLANS[client] = plan
end

local function clientOf(client) return client == "forever" and "forever" or "retail" end

--- The inventory slot ids of `client`: WoW Forever's (with the ranged slot) for "forever",
--- Retail's for any other value, nil included.
--- @param client string|nil
--- @return table
function C.SlotsFor(client) return C.SLOTS[clientOf(client)] end

--- The slot plans of `client` (equipLoc -> { kind, slots }): WoW Forever's for "forever", Retail's
--- for any other value, nil included.
--- @param client string|nil
--- @return table
function C.SlotPlanFor(client) return C.SLOT_PLANS[clientOf(client)] end

-- Equip locations any class can use whatever their armor subclass (cloaks are cloth for everyone).
C.UNIVERSAL_EQUIPLOC = {
  INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true, INVTYPE_CLOAK = true,
}

-- Equip locations whose armor subclass must match the class's armor type.
C.ARMOR_TYPED_EQUIPLOC = {
  INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
  INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true,
  INVTYPE_HAND = true,
}
