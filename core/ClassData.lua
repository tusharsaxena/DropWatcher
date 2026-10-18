local _, NS = ...
-- core/ClassData.lua — class armor types, weapon proficiencies and the Retail 12.x spec table.
--
-- Pure data plus lookups (design spec §4, §5.2). The evaluation kernel trusts an item's own spec
-- list (C_Item.GetItemSpecInfo) whenever it has one and the candidate's spec is known; these
-- tables are the FALLBACK for a candidate whose spec is not known yet, and for the dual-wield and
-- Titan's Grip slot plans. Every lookup answers true, false, or nil for "cannot tell", and never
-- throws. Keys are classFile tokens and specIDs, never localized names (anti-pattern #37).
--
-- Devourer (specID 1480) is the Midnight Intellect Demon Hunter spec. The id is the one the
-- collection's spell research read from the client's TraitTreeLoadout data, beside Havoc (577) and
-- Vengeance (581) (AuraMaster defaults/Categories.lua). Its weapon and off-hand rules are recorded
-- as a known limitation until smoke-checked; the item spec list overrides them in the meantime.

NS.ClassData = NS.ClassData or {}
local CD = NS.ClassData
local C = NS.Constants
local A, W = C.ARMOR_SUBCLASS, C.WEAPON_SUBCLASS

local STR, AGI, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT"
CD.STAT = { STRENGTH = STR, AGILITY = AGI, INTELLECT = INT }

-- classFile -> the client's classID.
CD.CLASS_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7,
    MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12, EVOKER = 13,
}

-- classFile -> the armor subclass its loot comes in.
CD.ARMOR = {
    WARRIOR = A.PLATE, PALADIN = A.PLATE, DEATHKNIGHT = A.PLATE,
    HUNTER = A.MAIL, SHAMAN = A.MAIL, EVOKER = A.MAIL,
    ROGUE = A.LEATHER, MONK = A.LEATHER, DRUID = A.LEATHER, DEMONHUNTER = A.LEATHER,
    PRIEST = A.CLOTH, MAGE = A.CLOTH, WARLOCK = A.CLOTH,
}

-- Builds a { [subClassID] = true } set.
local function set(...)
    local out = {}
    for i = 1, select("#", ...) do out[select(i, ...)] = true end
    return out
end

-- classFile -> the weapon subclasses whose loot the class can use. Loot-relevant proficiency: a
-- skill the class technically has but no loot of its primary stat drops for (a warrior's bow) is
-- left out, so a ranged weapon reads as the hunter's alone.
CD.WEAPONS = {
    WARRIOR     = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H,
                      W.STAFF, W.FIST, W.DAGGER),
    PALADIN     = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H),
    HUNTER      = set(W.AXE_1H, W.AXE_2H, W.BOWS, W.GUNS, W.CROSSBOW, W.POLEARM, W.SWORD_1H,
                      W.SWORD_2H, W.STAFF, W.FIST, W.DAGGER),
    ROGUE       = set(W.AXE_1H, W.MACE_1H, W.SWORD_1H, W.FIST, W.DAGGER),
    PRIEST      = set(W.MACE_1H, W.STAFF, W.DAGGER, W.WAND),
    DEATHKNIGHT = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.POLEARM, W.SWORD_1H, W.SWORD_2H),
    SHAMAN      = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.STAFF, W.FIST, W.DAGGER),
    MAGE        = set(W.SWORD_1H, W.STAFF, W.DAGGER, W.WAND),
    WARLOCK     = set(W.SWORD_1H, W.STAFF, W.DAGGER, W.WAND),
    MONK        = set(W.AXE_1H, W.MACE_1H, W.SWORD_1H, W.POLEARM, W.STAFF, W.FIST),
    DRUID       = set(W.MACE_1H, W.MACE_2H, W.POLEARM, W.STAFF, W.FIST, W.DAGGER),
    DEMONHUNTER = set(W.AXE_1H, W.SWORD_1H, W.WARGLAIVE, W.FIST),
    EVOKER      = set(W.AXE_1H, W.AXE_2H, W.MACE_1H, W.MACE_2H, W.SWORD_1H, W.SWORD_2H, W.STAFF,
                      W.FIST, W.DAGGER),
}

-- Spec row: class, primary stat, and four flags. `dualWield`: one-handers compare against the lower
-- hand. `titanGrip`: two-handers too (Fury). `shield`: shields are this spec's loot. `offhand`:
-- held off hands ("frills") are.
local function spec(class, stat, flags)
    flags = flags or ""
    return {
        class = class, stat = stat,
        dualWield = flags:find("D", 1, true) ~= nil,
        titanGrip = flags:find("T", 1, true) ~= nil,
        shield    = flags:find("S", 1, true) ~= nil,
        offhand   = flags:find("O", 1, true) ~= nil,
    }
end

-- specID -> row, every Retail 12.x specialization.
CD.SPECS = {
    [71]   = spec("WARRIOR", STR),             -- Arms
    [72]   = spec("WARRIOR", STR, "DT"),       -- Fury
    [73]   = spec("WARRIOR", STR, "S"),        -- Protection
    [65]   = spec("PALADIN", INT, "SO"),       -- Holy
    [66]   = spec("PALADIN", STR, "S"),        -- Protection
    [70]   = spec("PALADIN", STR),             -- Retribution
    [253]  = spec("HUNTER", AGI),              -- Beast Mastery
    [254]  = spec("HUNTER", AGI),              -- Marksmanship
    [255]  = spec("HUNTER", AGI),              -- Survival
    [259]  = spec("ROGUE", AGI, "D"),          -- Assassination
    [260]  = spec("ROGUE", AGI, "D"),          -- Outlaw
    [261]  = spec("ROGUE", AGI, "D"),          -- Subtlety
    [256]  = spec("PRIEST", INT, "O"),         -- Discipline
    [257]  = spec("PRIEST", INT, "O"),         -- Holy
    [258]  = spec("PRIEST", INT, "O"),         -- Shadow
    [250]  = spec("DEATHKNIGHT", STR),         -- Blood
    [251]  = spec("DEATHKNIGHT", STR, "D"),    -- Frost
    [252]  = spec("DEATHKNIGHT", STR),         -- Unholy
    [262]  = spec("SHAMAN", INT, "SO"),        -- Elemental
    [263]  = spec("SHAMAN", AGI, "D"),         -- Enhancement
    [264]  = spec("SHAMAN", INT, "SO"),        -- Restoration
    [62]   = spec("MAGE", INT, "O"),           -- Arcane
    [63]   = spec("MAGE", INT, "O"),           -- Fire
    [64]   = spec("MAGE", INT, "O"),           -- Frost
    [265]  = spec("WARLOCK", INT, "O"),        -- Affliction
    [266]  = spec("WARLOCK", INT, "O"),        -- Demonology
    [267]  = spec("WARLOCK", INT, "O"),        -- Destruction
    [268]  = spec("MONK", AGI, "D"),           -- Brewmaster
    [269]  = spec("MONK", AGI, "D"),           -- Windwalker
    [270]  = spec("MONK", INT, "O"),           -- Mistweaver
    [102]  = spec("DRUID", INT, "O"),          -- Balance
    [103]  = spec("DRUID", AGI),               -- Feral
    [104]  = spec("DRUID", AGI),               -- Guardian
    [105]  = spec("DRUID", INT, "O"),          -- Restoration
    [577]  = spec("DEMONHUNTER", AGI, "D"),    -- Havoc
    [581]  = spec("DEMONHUNTER", AGI, "D"),    -- Vengeance
    [1480] = spec("DEMONHUNTER", INT, "D"),    -- Devourer (Midnight)
    [1467] = spec("EVOKER", INT, "O"),         -- Devastation
    [1468] = spec("EVOKER", INT, "O"),         -- Preservation
    [1473] = spec("EVOKER", INT, "O"),         -- Augmentation
}

-- specID -> its place in its class's list (GetSpecialization()'s index, 1-4): the spec numbering
-- Pawn's scales carry (Pawn 2.13.6 ScaleTemplates.lua, PawnFindScaleForSpec), not the specID.
-- Not the specIDs' sort order: Monk is Brewmaster 1, Mistweaver 2, Windwalker 3.
CD.SPEC_INDEX = {
    [71] = 1, [72] = 2, [73] = 3,                   -- Warrior
    [65] = 1, [66] = 2, [70] = 3,                   -- Paladin
    [253] = 1, [254] = 2, [255] = 3,                -- Hunter
    [259] = 1, [260] = 2, [261] = 3,                -- Rogue
    [256] = 1, [257] = 2, [258] = 3,                -- Priest
    [250] = 1, [251] = 2, [252] = 3,                -- Death Knight
    [262] = 1, [263] = 2, [264] = 3,                -- Shaman
    [62] = 1, [63] = 2, [64] = 3,                   -- Mage
    [265] = 1, [266] = 2, [267] = 3,                -- Warlock
    [268] = 1, [270] = 2, [269] = 3,                -- Monk
    [102] = 1, [103] = 2, [104] = 3, [105] = 4,     -- Druid
    [577] = 1, [581] = 2, [1480] = 3,               -- Demon Hunter
    [1467] = 1, [1468] = 2, [1473] = 3,             -- Evoker
}

-- classFile -> its specIDs, ascending; derived from SPECS so the two cannot disagree.
CD.CLASS_SPECS = {}
for specID, row in pairs(CD.SPECS) do
    local list = CD.CLASS_SPECS[row.class] or {}
    list[#list + 1] = specID
    CD.CLASS_SPECS[row.class] = list
end
for _, list in pairs(CD.CLASS_SPECS) do table.sort(list) end

-- ---------------------------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------------------------

--- The spec row for `specID`, or nil.
function CD.Spec(specID)
    if type(specID) ~= "number" then return nil end
    return CD.SPECS[specID]
end

--- A spec's place in its class's list (1-4), the numbering Pawn's scales use; nil when unknown.
function CD.SpecIndex(specID)
    if type(specID) ~= "number" then return nil end
    return CD.SPEC_INDEX[specID]
end

--- The classFile a spec belongs to, or nil.
function CD.ClassOf(specID)
    local row = CD.Spec(specID)
    return row and row.class
end

--- Whether `specID` dual wields; nil when the spec is unknown.
function CD.IsDualWield(specID)
    local row = CD.Spec(specID)
    if row then return row.dualWield end
    return nil
end

--- Whether `specID` has Titan's Grip; nil when the spec is unknown.
function CD.IsTitanGrip(specID)
    local row = CD.Spec(specID)
    if row then return row.titanGrip end
    return nil
end

-- The spec row when it belongs to `classFile`; a spec of another class is ignored.
local function ownSpec(classFile, specID)
    local row = CD.Spec(specID)
    if row and row.class == classFile then return row end
    return nil
end

-- A field across every spec of a class: the shared value, or nil when the specs disagree or the
-- class is unknown.
local function classShared(classFile, field)
    local list = type(classFile) == "string" and CD.CLASS_SPECS[classFile]
    if not list then return nil end
    local first = CD.SPECS[list[1]][field]
    for i = 2, #list do
        if CD.SPECS[list[i]][field] ~= first then return nil end
    end
    return first
end

-- The spec's own value for `field`, else the class-wide one (nil when it varies by spec).
local function bySpecOrClass(classFile, specID, field)
    local row = ownSpec(classFile, specID)
    if row then return row[field] end
    return classShared(classFile, field)
end

--- The primary stat key (ITEM_MOD_*_SHORT) for the spec, or for the class when every spec shares
--- one; nil otherwise.
function CD.PrimaryStat(classFile, specID)
    return bySpecOrClass(classFile, specID, "stat")
end

--- Whether the candidate dual wields: the spec's flag, or the class's when every spec shares it;
--- nil when it depends on the spec.
function CD.DualWieldFor(classFile, specID)
    return bySpecOrClass(classFile, specID, "dualWield")
end

--- Whether the candidate has Titan's Grip, the same way as DualWieldFor.
function CD.TitanGripFor(classFile, specID)
    return bySpecOrClass(classFile, specID, "titanGrip")
end

--- Whether shields are this candidate's loot: true, false, or nil when it depends on the spec.
function CD.CanUseShield(classFile, specID)
    return bySpecOrClass(classFile, specID, "shield")
end

--- Whether held off hands are this candidate's loot: true, false, or nil when it depends on the spec.
function CD.CanUseOffhand(classFile, specID)
    return bySpecOrClass(classFile, specID, "offhand")
end

local ARMOR_TYPES = { [A.CLOTH] = true, [A.LEATHER] = true, [A.MAIL] = true, [A.PLATE] = true }

--- Whether an armor piece of `subClassID` is the class's armor type. nil for an unknown class or a
--- subclass that is not an armor type (generic, cosmetic, shield: the caller decides those).
function CD.CanWearArmor(classFile, subClassID)
    local armor = type(classFile) == "string" and CD.ARMOR[classFile]
    if not armor or not ARMOR_TYPES[subClassID] then return nil end
    return armor == subClassID
end

--- Whether the class can use a weapon of `subClassID`; nil for an unknown class or subclass.
function CD.CanUseWeapon(classFile, subClassID)
    local weapons = type(classFile) == "string" and CD.WEAPONS[classFile]
    if not weapons or type(subClassID) ~= "number" then return nil end
    return weapons[subClassID] == true
end
