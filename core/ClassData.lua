local _, NS = ...
-- core/ClassData.lua — class armor types, weapon proficiencies and the spec table, one list per
-- client (Forever port design §4.2, clients-§5): Retail 12.x's here, WoW Forever's in
-- core/ClassDataForever.lua (the next file).
--
-- Pure data plus lookups (design spec §4, §5.2). The evaluation kernel trusts an item's own spec
-- list (C_Item.GetItemSpecInfo) whenever it has one and the candidate's spec is known; these
-- tables are the FALLBACK for a candidate whose spec is not known yet, and for the dual-wield and
-- Titan's Grip slot plans. Every lookup answers true, false, or nil for "cannot tell", and never
-- throws. Keys are classFile tokens and specIDs, never localized names (anti-pattern #37).
--
-- TWO LISTS, PICKED ONCE. CD.Build(data) turns a list's data into a list: the data plus every
-- lookup, bound to that list alone. CD.LISTS holds both lists (Retail's built here, Forever's by
-- the next file), so the suite reads each one on either kit profile. The ACTIVE list is copied onto
-- NS.ClassData itself at file load, by NS.Compat.ClientKey(): this file installs Retail's unless the
-- client is WoW Forever, and core/ClassDataForever.lua installs Forever's when it is. Never a
-- filtered Retail list. Every reader keeps reading NS.ClassData's members (CD.SPECS, CD.Spec, ...)
-- as before.
--
-- THE SHAPE, both lists: CLASS_ID (classFile -> classID), ARMOR (classFile -> the armor subclass of
-- its loot at the level cap), WEAPONS (classFile -> { [subClassID] = true }), SPECS (spec key ->
-- row), SPEC_INDEX (Retail: specID -> Pawn's spec index), CLASS_SPECS (classFile -> its spec keys,
-- sorted; derived from SPECS), RELIC (Forever only: classFile -> its relic subclass), STAT_GATE ("hard": a primary stat the spec cannot use is "can't
-- use"; "soft": it never is by itself, Forever port design §4.5), PAWN_BY_TREE (Forever only: Pawn's
-- scale is the talent tree's, design §4.3). A spec row is { class, stat,
-- dualWield, titanGrip, shield, offhand } plus, on Forever, { tree, pawn, pawnTank }.
--
-- Retail's spec key is the specID. Forever's is "<classFile>:<tree>" (its spec ID is class-wide,
-- the talent tree tells the specs apart): every lookup that takes `specID` also takes the talent
-- tree index `tree`, and reads the row the specID names, else the class's row for that tree.
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

-- Builds a { [subClassID] = true } set.
function CD.Set(...)
    local out = {}
    for i = 1, select("#", ...) do out[select(i, ...)] = true end
    return out
end
local set = CD.Set

-- Spec row: class, primary stat, and four flags. `dualWield`: one-handers compare against the lower
-- hand. `titanGrip`: two-handers too (Fury). `shield`: shields are this spec's loot. `offhand`:
-- held off hands ("frills") are.
function CD.SpecRow(class, stat, flags)
    flags = flags or ""
    return {
        class = class, stat = stat,
        dualWield = flags:find("D", 1, true) ~= nil,
        titanGrip = flags:find("T", 1, true) ~= nil,
        shield    = flags:find("S", 1, true) ~= nil,
        offhand   = flags:find("O", 1, true) ~= nil,
    }
end
local spec = CD.SpecRow

-- ---------------------------------------------------------------------------------------------
-- Retail 12.x
-- ---------------------------------------------------------------------------------------------

local RETAIL = { STAT_GATE = "hard" }

-- classFile -> the client's classID.
RETAIL.CLASS_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7,
    MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12, EVOKER = 13,
}

-- classFile -> the armor subclass its loot comes in.
RETAIL.ARMOR = {
    WARRIOR = A.PLATE, PALADIN = A.PLATE, DEATHKNIGHT = A.PLATE,
    HUNTER = A.MAIL, SHAMAN = A.MAIL, EVOKER = A.MAIL,
    ROGUE = A.LEATHER, MONK = A.LEATHER, DRUID = A.LEATHER, DEMONHUNTER = A.LEATHER,
    PRIEST = A.CLOTH, MAGE = A.CLOTH, WARLOCK = A.CLOTH,
}

-- classFile -> the weapon subclasses whose loot the class can use. Loot-relevant proficiency: a
-- skill the class technically has but no loot of its primary stat drops for (a warrior's bow) is
-- left out, so a ranged weapon reads as the hunter's alone.
RETAIL.WEAPONS = {
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

-- specID -> row, every Retail 12.x specialization.
RETAIL.SPECS = {
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
RETAIL.SPEC_INDEX = {
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

-- ---------------------------------------------------------------------------------------------
-- Lookups (bound to one list by CD.Build)
-- ---------------------------------------------------------------------------------------------

local ARMOR_TYPES = { [A.CLOTH] = true, [A.LEATHER] = true, [A.MAIL] = true, [A.PLATE] = true }
-- Each armor type's weight, lightest first: a lower one is wearable where the list allows it.
local ARMOR_RANK = { [A.CLOTH] = 1, [A.LEATHER] = 2, [A.MAIL] = 3, [A.PLATE] = 4 }

local function isKey(v)
    return (type(v) == "number" and v == v) or type(v) == "string"
end

-- classFile -> its spec keys, sorted (numbers before strings, each in order).
local function classSpecs(specs)
    local out = {}
    for key, row in pairs(specs) do
        local list = out[row.class] or {}
        list[#list + 1] = key
        out[row.class] = list
    end
    for _, list in pairs(out) do
        table.sort(list, function(a, b)
            if type(a) ~= type(b) then return type(a) == "number" end
            return a < b
        end)
    end
    return out
end

-- The lookups that read a list's spec rows.
local function bindSpecs(L)
    --- The spec row for `key` (a specID, or on Forever "<classFile>:<tree>"), or nil.
    function L.Spec(key)
        if not isKey(key) then return nil end
        return L.SPECS[key]
    end

    -- The row `specID` names when it belongs to `classFile`, else the class's row for `tree`; a
    -- spec of another class is ignored.
    local function ownSpec(classFile, specID, tree)
        if type(classFile) ~= "string" then return nil end
        local row = L.Spec(specID)
        if row and row.class == classFile then return row end
        if type(tree) == "number" then return L.SPECS[classFile .. ":" .. tree] end
        return nil
    end
    L.OwnSpec = ownSpec

    --- The key a candidate's per-spec settings are stored under (`comparison.weights`,
    --- `comparison.undesired`): the spec key `specID` names when the list has a row for it (Retail's
    --- specID), else "<classFile>:<tree>" for the class's talent tree (Forever), else nil.
    function L.SpecKey(classFile, specID, tree)
        if L.Spec(specID) then return specID end
        if type(classFile) ~= "string" or type(tree) ~= "number" then return nil end
        local key = classFile .. ":" .. tree
        return L.SPECS[key] and key or nil
    end

    -- A field across every spec of a class: the shared value, or nil when the specs disagree or
    -- the class is unknown.
    local function classShared(classFile, field)
        local list = type(classFile) == "string" and L.CLASS_SPECS[classFile]
        if not list then return nil end
        local first = L.SPECS[list[1]][field]
        for i = 2, #list do
            if L.SPECS[list[i]][field] ~= first then return nil end
        end
        return first
    end

    -- The spec's own value for `field`, else the class-wide one (nil when it varies by spec).
    local function bySpecOrClass(classFile, specID, tree, field)
        local row = ownSpec(classFile, specID, tree)
        if row then return row[field] end
        return classShared(classFile, field)
    end

    --- The primary stat key (ITEM_MOD_*_SHORT) for the spec (or talent tree), or for the class
    --- when every spec shares one; nil otherwise.
    function L.PrimaryStat(classFile, specID, tree) return bySpecOrClass(classFile, specID, tree, "stat") end

    --- Whether the candidate dual wields: the spec's flag, or the class's when every spec shares
    --- it; nil when it depends on the spec.
    function L.DualWieldFor(classFile, specID, tree) return bySpecOrClass(classFile, specID, tree, "dualWield") end

    --- Whether the candidate has Titan's Grip, the same way as DualWieldFor.
    function L.TitanGripFor(classFile, specID, tree) return bySpecOrClass(classFile, specID, tree, "titanGrip") end

    --- Whether shields are this candidate's loot: true, false, or nil when it depends on the spec.
    function L.CanUseShield(classFile, specID, tree) return bySpecOrClass(classFile, specID, tree, "shield") end

    --- Whether held off hands are this candidate's loot: true, false, or nil when it depends on
    --- the spec.
    function L.CanUseOffhand(classFile, specID, tree) return bySpecOrClass(classFile, specID, tree, "offhand") end
end

-- The Pawn index: Retail's by specID; Forever's by the talent tree's row.
local function bindSpecIndex(L)
    --- A spec's place in its class's list (1-4), the numbering Pawn's scales use; nil when
    --- unknown. Retail: SPEC_INDEX[specID]. Forever: the row's `pawn` (`pawnTank` when `role` is
    --- "TANK": the Druid's Feral), for a spec key "<classFile>:<tree>", or for `specID` a class's
    --- spec ID and `tree` its talent tree, `classFile` naming the class (tree alone otherwise).
    function L.SpecIndex(specID, tree, role, classFile)
        local row = L.Spec(specID)
        if row == nil and type(classFile) == "string" and type(tree) == "number" then
            row = L.SPECS[classFile .. ":" .. tree]
        end
        if row and row.pawn then return (role == "TANK" and row.pawnTank) or row.pawn end
        local index = type(specID) == "number" and L.SPEC_INDEX[specID]
        if index then return index end
        if type(tree) == "number" then return tree end
        return nil
    end
end

-- The armor and weapon lookups.
local function bindGear(L)
    --- The armor subclass `classFile` wears at `level`: the list's early type below its
    --- ARMOR_LEVEL (Forever: mail or leather below 40), else its ARMOR. An unknown level is the
    --- cap's type. nil for an unknown class.
    function L.ArmorFor(classFile, level)
        local armor = type(classFile) == "string" and L.ARMOR[classFile]
        if not armor then return nil end
        local early = L.ARMOR_EARLY and L.ARMOR_EARLY[classFile]
        if early and type(level) == "number" and level < L.ARMOR_LEVEL then return early end
        return armor
    end

    --- Whether an armor piece of `subClassID` is the class's to wear: true, false (and on Forever
    --- the reason "armorLevel" when the class wears it from a later level), or nil for an unknown
    --- class or a subclass that is not an armor type (generic, cosmetic, shield: the caller
    --- decides those). Retail is exact. Forever (ARMOR_LOWER_OK) takes any lighter type too: there
    --- is no armor specialization there.
    function L.CanWearArmor(classFile, subClassID, level)
        local now = L.ArmorFor(classFile, level)
        if not now or not ARMOR_TYPES[subClassID] then return nil end
        if not L.ARMOR_LOWER_OK then return now == subClassID end
        if ARMOR_RANK[subClassID] <= ARMOR_RANK[now] then return true end
        if ARMOR_RANK[subClassID] <= ARMOR_RANK[L.ARMOR[classFile]] then return false, "armorLevel" end
        return false
    end

    --- Whether the class can use a relic of `subClassID` (WoW Forever's libram, idol or totem, the
    --- list's RELIC: classFile -> its relic subclass): true for its own, false for any other or a
    --- class with none; nil for an unknown class or subclass, or a list with no relics (Retail).
    function L.CanUseRelic(classFile, subClassID)
        if not L.RELIC or type(subClassID) ~= "number" then return nil end
        if type(classFile) ~= "string" or not L.ARMOR[classFile] then return nil end
        return L.RELIC[classFile] == subClassID
    end

    --- Whether the class can use a weapon of `subClassID`; nil for an unknown class or subclass.
    function L.CanUseWeapon(classFile, subClassID)
        local weapons = type(classFile) == "string" and L.WEAPONS[classFile]
        if not weapons or type(subClassID) ~= "number" then return nil end
        return weapons[subClassID] == true
    end
end

--- A list from its data: CLASS_SPECS derived from SPECS (so the two cannot disagree), SPEC_INDEX
--- defaulted, and every lookup bound to this list.
--- @param data table
--- @return table
function CD.Build(data)
    local L = data
    L.SPEC_INDEX = L.SPEC_INDEX or {}
    L.CLASS_SPECS = classSpecs(L.SPECS)
    bindSpecs(L)
    bindSpecIndex(L)
    bindGear(L)
    return L
end

--- Make `list` the active one: its members copied onto NS.ClassData, the last list's own members
--- cleared first. Called once per load, by the file whose client ClientKey() names (a suite may
--- call it to pin the list a case is written against).
--- @param list table
function CD.Install(list)
    local last = CD.ACTIVE
    if last then
        for k in pairs(last) do CD[k] = nil end
    end
    for k, v in pairs(list) do CD[k] = v end
    CD.ACTIVE = list
end

CD.LISTS = CD.LISTS or {}
CD.LISTS.retail = CD.Build(RETAIL)
if NS.Compat.ClientKey() ~= "forever" then CD.Install(CD.LISTS.retail) end
