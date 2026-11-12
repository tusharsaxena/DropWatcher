local _, NS = ...
-- core/ClassDataForever.lua — WoW Forever's class list (Forever port design §4.2, research R4 §3,
-- §5): its own list, never a filtered Retail one (clients-§5), built by core/ClassData.lua's
-- CD.Build and installed as the active list when NS.Compat.ClientKey() is "forever".
--
-- WHAT DIFFERS FROM RETAIL. Nine classes (CLASS_SORT_ORDER: no Death Knight, Monk, Demon Hunter or
-- Evoker), each with one class-wide spec ID; the classic talent trees are what tell its specs
-- apart, so a spec row is keyed "<classFile>:<tree>" (tree 1-3, in the talent frame's order, the
-- order LibKa0s-Role-1.0's Groups() and TALENT_GROUP_ROLE use). The vanilla armor rule: Warrior
-- and Paladin wear plate from level 40 and mail below, Hunter and Shaman mail from 40 and leather
-- below (ARMOR_EARLY below ARMOR_LEVEL), and with no armor specialization a lighter type is
-- wearable too (ARMOR_LOWER_OK). The vanilla weapon proficiencies, thrown weapons included. The
-- hands: dual wield for Warrior, Rogue and Hunter, shields for Warrior, Paladin and Shaman, held
-- off hands for the caster trees, and no Titan's Grip. The primary stat is a hint only: the stat
-- gate is soft (STAT_GATE), since vanilla items carry several stats and the score weighs them
-- (design §4.5).
--
-- PAWN. Each row's `pawn` is its Classic scale's SpecID (the tree index); the Druid's Feral is 2
-- for damage and 3 (`pawnTank`) for a tank, and its Restoration is 4 (design §4.3).
--
-- INFERRED, not probed: the rows are vanilla-era game knowledge (R4 §5). Relics (libram, idol,
-- totem) come with the ranged slot (DW-FP06).

local CD = NS.ClassData
local C = NS.Constants
local A, W = C.ARMOR_SUBCLASS, C.WEAPON_SUBCLASS
local S = CD.STAT
local STR, AGI, INT = S.STRENGTH, S.AGILITY, S.INTELLECT
local set = CD.Set

-- A talent tree's row: the class row, its tree index and its Pawn scale index.
local function tree(class, index, stat, flags, pawn, pawnTank)
    local row = CD.SpecRow(class, stat, flags)
    row.tree, row.pawn, row.pawnTank = index, pawn or index, pawnTank
    return row
end

local FOREVER = { STAT_GATE = "soft", ARMOR_LOWER_OK = true, ARMOR_LEVEL = 40 }

-- classFile -> the client's classID (the same ids as Retail's, for the nine classes there are).
FOREVER.CLASS_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9,
    DRUID = 11,
}

-- classFile -> the armor subclass of its loot from ARMOR_LEVEL on.
FOREVER.ARMOR = {
    WARRIOR = A.PLATE, PALADIN = A.PLATE, HUNTER = A.MAIL, SHAMAN = A.MAIL,
    ROGUE = A.LEATHER, DRUID = A.LEATHER, PRIEST = A.CLOTH, MAGE = A.CLOTH, WARLOCK = A.CLOTH,
}

-- classFile -> the armor subclass below ARMOR_LEVEL, for the classes whose type changes.
FOREVER.ARMOR_EARLY = { WARRIOR = A.MAIL, PALADIN = A.MAIL, HUNTER = A.LEATHER, SHAMAN = A.LEATHER }

-- classFile -> the weapon subclasses the class can use (the vanilla proficiencies).
FOREVER.WEAPONS = {
    WARRIOR = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H,
                  W.STAFF, W.FIST, W.DAGGER, W.BOWS, W.GUNS, W.CROSSBOW, W.THROWN),
    PALADIN = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H),
    HUNTER  = set(W.AXE_1H, W.AXE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H, W.STAFF, W.FIST,
                  W.DAGGER, W.BOWS, W.GUNS, W.CROSSBOW, W.THROWN),
    ROGUE   = set(W.MACE_1H, W.SWORD_1H, W.FIST, W.DAGGER, W.BOWS, W.GUNS, W.CROSSBOW, W.THROWN),
    PRIEST  = set(W.MACE_1H, W.STAFF, W.DAGGER, W.WAND),
    SHAMAN  = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.STAFF, W.FIST, W.DAGGER),
    MAGE    = set(W.SWORD_1H, W.STAFF, W.DAGGER, W.WAND),
    WARLOCK = set(W.SWORD_1H, W.STAFF, W.DAGGER, W.WAND),
    DRUID   = set(W.MACE_1H, W.MACE_2H, W.STAFF, W.FIST, W.DAGGER),
}

-- "<classFile>:<tree>" -> row, every class's three talent trees (the Druid's Pawn scales are four).
FOREVER.SPECS = {
    ["WARRIOR:1"] = tree("WARRIOR", 1, STR, "DS"),        -- Arms
    ["WARRIOR:2"] = tree("WARRIOR", 2, STR, "DS"),        -- Fury
    ["WARRIOR:3"] = tree("WARRIOR", 3, STR, "DS"),        -- Protection
    ["PALADIN:1"] = tree("PALADIN", 1, INT, "SO"),        -- Holy
    ["PALADIN:2"] = tree("PALADIN", 2, STR, "S"),         -- Protection
    ["PALADIN:3"] = tree("PALADIN", 3, STR, "S"),         -- Retribution
    ["HUNTER:1"]  = tree("HUNTER", 1, AGI, "D"),          -- Beast Mastery
    ["HUNTER:2"]  = tree("HUNTER", 2, AGI, "D"),          -- Marksmanship
    ["HUNTER:3"]  = tree("HUNTER", 3, AGI, "D"),          -- Survival
    ["ROGUE:1"]   = tree("ROGUE", 1, AGI, "D"),           -- Assassination
    ["ROGUE:2"]   = tree("ROGUE", 2, AGI, "D"),           -- Combat
    ["ROGUE:3"]   = tree("ROGUE", 3, AGI, "D"),           -- Subtlety
    ["PRIEST:1"]  = tree("PRIEST", 1, INT, "O"),          -- Discipline
    ["PRIEST:2"]  = tree("PRIEST", 2, INT, "O"),          -- Holy
    ["PRIEST:3"]  = tree("PRIEST", 3, INT, "O"),          -- Shadow
    ["SHAMAN:1"]  = tree("SHAMAN", 1, INT, "SO"),         -- Elemental
    ["SHAMAN:2"]  = tree("SHAMAN", 2, STR, "S"),          -- Enhancement
    ["SHAMAN:3"]  = tree("SHAMAN", 3, INT, "SO"),         -- Restoration
    ["MAGE:1"]    = tree("MAGE", 1, INT, "O"),            -- Arcane
    ["MAGE:2"]    = tree("MAGE", 2, INT, "O"),            -- Fire
    ["MAGE:3"]    = tree("MAGE", 3, INT, "O"),            -- Frost
    ["WARLOCK:1"] = tree("WARLOCK", 1, INT, "O"),         -- Affliction
    ["WARLOCK:2"] = tree("WARLOCK", 2, INT, "O"),         -- Demonology
    ["WARLOCK:3"] = tree("WARLOCK", 3, INT, "O"),         -- Destruction
    ["DRUID:1"]   = tree("DRUID", 1, INT, "O"),           -- Balance
    ["DRUID:2"]   = tree("DRUID", 2, AGI, nil, 2, 3),     -- Feral: Pawn 2 for damage, 3 to tank
    ["DRUID:3"]   = tree("DRUID", 3, INT, "O", 4),        -- Restoration: Pawn 4
}

CD.LISTS.forever = CD.Build(FOREVER)
if NS.Compat.ClientKey() == "forever" then CD.Install(CD.LISTS.forever) end
