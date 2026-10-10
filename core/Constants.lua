local _, NS = ...
-- core/Constants.lua — fixed values the addon reads: fonts, window geometry, colors, game ids.
--
-- Data only: the item, quality, bind, slot, difficulty and situation ids, the slot plans, the trade
-- rules and the message templates (design spec §4, §5.2, §6.1, §6.2, §7.2, §9.1). The class and
-- spec tables are core/ClassData.lua.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's monospace face, from the shared payload (core/MediaSetup.lua, which loads
-- first). A real client font when the library is absent, never nil and never a dead path.
C.FONT_MONO_NAME = "JetBrains Mono"
C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

-- The main window (design spec §11.1). Sizes are pixels at a 1.0 scale.
C.WINDOW = {
    NAME        = "DropWatcherWindow",
    WIDTH       = 760,
    HEIGHT      = 380,
    MIN_WIDTH   = 520,
    MIN_HEIGHT  = 260,
    TITLE_H     = 30,
    -- Where a fresh profile, and Reset position, put the window.
    POINT       = { "CENTER", "CENTER", 0, 0 },
}

-- The gold of the title, the active tab and the test-mode banner (design spec §2).
C.GOLD = { r = 1.0, g = 0.82, b = 0.0 }

-- ---------------------------------------------------------------------------------------------
-- Item ids (design spec §5.2). Read from the client's Enum tables when present; each literal beside
-- its member is the documented 12.x value, used when Enum (or that member) is absent: the headless
-- harness, or a client that renamed the member. Never compare against a localized type name
-- (anti-pattern #37).
-- ---------------------------------------------------------------------------------------------

local Enum = _G.Enum or {}

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
C.ITEM_CLASS = fromEnum(Enum.ItemClass, {
    CONSUMABLE    = { "Consumable", 0 },
    WEAPON        = { "Weapon", 2 },
    ARMOR         = { "Armor", 4 },
    MISCELLANEOUS = { "Miscellaneous", 15 },
})

-- Enum.ItemArmorSubclass. GENERIC is jewelry, trinkets and held off hands; COSMETIC is never gear.
C.ARMOR_SUBCLASS = fromEnum(Enum.ItemArmorSubclass, {
    GENERIC  = { "Generic", 0 },
    CLOTH    = { "Cloth", 1 },
    LEATHER  = { "Leather", 2 },
    MAIL     = { "Mail", 3 },
    PLATE    = { "Plate", 4 },
    COSMETIC = { "Cosmetic", 5 },
    SHIELD   = { "Shield", 6 },
})

-- Enum.ItemWeaponSubclass.
C.WEAPON_SUBCLASS = fromEnum(Enum.ItemWeaponSubclass, {
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
    CROSSBOW  = { "Crossbow", 18 },
    WAND      = { "Wand", 19 },
})

-- Enum.ItemQuality.
C.QUALITY = fromEnum(Enum.ItemQuality, {
    POOR      = { "Poor", 0 },
    COMMON    = { "Common", 1 },
    UNCOMMON  = { "Uncommon", 2 },
    RARE      = { "Rare", 3 },
    EPIC      = { "Epic", 4 },
    LEGENDARY = { "Legendary", 5 },
    ARTIFACT  = { "Artifact", 6 },
    HEIRLOOM  = { "Heirloom", 7 },
})

-- Minimum quality (design spec §6.2): the modes in display order, and the two defaults.
C.QUALITY_MODES = { "fixed", "dynamicSlot", "dynamicCharacter" }
C.QUALITY_DEFAULT = { FIXED = C.QUALITY.RARE, FLOOR = C.QUALITY.UNCOMMON }

-- Upgrade tracks in ascending order (design spec §5.2, step 3). The evaluation kernel compares a
-- track's numeric `tier` first; ItemFacts fills it from the track's string id where the client has
-- one. These enUS names are the fallback for a track that carries only its name, so a localized
-- name that matches none of them leaves the track delta unset rather than guessed.
C.TRACK_TIER = { Explorer = 1, Adventurer = 2, Veteran = 3, Champion = 4, Hero = 5, Myth = 6 }

-- ---------------------------------------------------------------------------------------------
-- Inventory slots and slot plans (design spec §5.2)
-- ---------------------------------------------------------------------------------------------

-- The client's inventory slot ids (the INVSLOT_* FrameXML constants). Slot 18, the old ranged
-- slot, is unused on Retail: bows, guns, crossbows and wands are main-hand items.
C.SLOT = {
    HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6, LEGS = 7, FEET = 8,
    WRIST = 9, HANDS = 10, FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14, BACK = 15,
    MAINHAND = 16, OFFHAND = 17, TABARD = 19,
}
local S = C.SLOT

-- The comparison kinds the evaluation kernel knows. `unique` is applied on top of a plan when the
-- drop carries a unique-equipped category; no equip location maps to it directly.
C.SLOT_KIND = {
    single = true, pair = true, weapon1H = true, weapon2H = true, offhand = true, ranged = true,
    unique = true,
}

-- equipLoc -> { kind, slots }. An equip location absent here (shirt, tabard, bag, ammo,
-- non-equippable) is not gear the feed compares.
C.SLOT_PLAN = {
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
    -- Bows, guns and crossbows (RANGED) and wands (RANGEDRIGHT) fill both hands.
    INVTYPE_RANGED         = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
    INVTYPE_RANGEDRIGHT    = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
}

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

-- Slots the dynamic whole-character quality mode ignores (design spec §6.2).
C.QUALITY_IGNORED_SLOT = { [S.SHIRT] = true, [S.TABARD] = true }

-- ---------------------------------------------------------------------------------------------
-- Situations and difficulties (design spec §6.1)
-- ---------------------------------------------------------------------------------------------

-- Every situation key in display order, with its default `track` and `autoOpen`.
C.SITUATIONS = {
    { key = "mythicPlus",      track = true,  autoOpen = true },
    { key = "dungeon",         track = true,  autoOpen = true },
    { key = "followerDungeon", track = false, autoOpen = false },
    { key = "raidLFR",         track = true,  autoOpen = false },
    { key = "raid",            track = true,  autoOpen = true },
    { key = "delve",           track = false, autoOpen = false },
    { key = "scenario",        track = false, autoOpen = false },
    { key = "pvp",             track = false, autoOpen = false },
    { key = "openWorldGroup",  track = false, autoOpen = false },
    { key = "solo",            track = false, autoOpen = false },
}
C.SITUATION = {}
for _, s in ipairs(C.SITUATIONS) do C.SITUATION[s.key] = s end

-- Difficulty ids (the DifficultyID column GetInstanceInfo and GetDifficultyInfo answer). The
-- classifier reads them through DIFFICULTY_KIND only; core/Compat.lua confirms an id with
-- GetDifficultyInfo before trusting it, so a retired or renumbered id degrades to the
-- instanceType fallback instead of misclassifying.
C.DIFFICULTY = {
    NORMAL_DUNGEON      = 1,
    HEROIC_DUNGEON      = 2,
    RAID_10_NORMAL      = 3,
    RAID_25_NORMAL      = 4,
    RAID_10_HEROIC      = 5,
    RAID_25_HEROIC      = 6,
    LFR_LEGACY          = 7,
    MYTHIC_KEYSTONE     = 8,
    RAID_40             = 9,
    NORMAL_RAID         = 14,
    HEROIC_RAID         = 15,
    MYTHIC_RAID         = 16,
    LFR                 = 17,
    MYTHIC_DUNGEON      = 23,
    TIMEWALKING_DUNGEON = 24,
    TIMEWALKING_RAID    = 33,
    LFR_TIMEWALKING     = 151,
    FOLLOWER_DUNGEON    = 205,
    DELVE               = 208,
}
local D = C.DIFFICULTY

-- difficultyID -> the situation it implies. Ids not listed here fall back to instanceType.
C.DIFFICULTY_KIND = {
    [D.MYTHIC_KEYSTONE]     = "mythicPlus",
    [D.NORMAL_DUNGEON]      = "dungeon",
    [D.HEROIC_DUNGEON]      = "dungeon",
    [D.MYTHIC_DUNGEON]      = "dungeon",
    [D.TIMEWALKING_DUNGEON] = "dungeon",
    [D.FOLLOWER_DUNGEON]    = "followerDungeon",
    [D.LFR_LEGACY]          = "raidLFR",
    [D.LFR]                 = "raidLFR",
    [D.LFR_TIMEWALKING]     = "raidLFR",
    [D.RAID_10_NORMAL]      = "raid",
    [D.RAID_25_NORMAL]      = "raid",
    [D.RAID_10_HEROIC]      = "raid",
    [D.RAID_25_HEROIC]      = "raid",
    [D.RAID_40]             = "raid",
    [D.NORMAL_RAID]         = "raid",
    [D.HEROIC_RAID]         = "raid",
    [D.MYTHIC_RAID]         = "raid",
    [D.TIMEWALKING_RAID]    = "raid",
    [D.DELVE]               = "delve",
}

-- ---------------------------------------------------------------------------------------------
-- Trade rules (design spec §7.2). modules/TradeRules.lua reads them; Settings › Trade overrides
-- CONTENT_RULE per situation, and a reset restores these.
-- ---------------------------------------------------------------------------------------------

-- Enum.ItemBind. ItemFacts reports a drop's bindType; TradeRules reads it through the two sets below.
C.BIND = fromEnum(Enum.ItemBind, {
    NONE                     = { "None", 0 },
    ON_ACQUIRE               = { "OnAcquire", 1 },
    ON_EQUIP                 = { "OnEquip", 2 },
    ON_USE                   = { "OnUse", 3 },
    QUEST                    = { "Quest", 4 },
    TO_WOW_ACCOUNT           = { "ToWoWAccount", 7 },
    TO_BNET_ACCOUNT          = { "ToBnetAccount", 8 },
    TO_BNET_ACCOUNT_EQUIPPED = { "ToBnetAccountUntilEquipped", 9 },
})
-- Binds that leave a fresh drop free to trade (`yes boe`), and binds to the account (`no warbound`).
C.TRADE_BOE_BIND = { [C.BIND.ON_EQUIP] = true, [C.BIND.ON_USE] = true }
C.TRADE_ACCOUNT_BIND = {
    [C.BIND.TO_WOW_ACCOUNT] = true, [C.BIND.TO_BNET_ACCOUNT] = true,
    [C.BIND.TO_BNET_ACCOUNT_EQUIPPED] = true,
}

C.TRADE_WINDOW = 7200   -- seconds a tradeable drop stays tradeable

-- The rule names in Settings › Trade's display order, and the rule an unknown situation takes.
C.TRADE_RULE_NAMES = { "personal", "group", "legacy" }
C.TRADE_RULE_DEFAULT = "personal"

C.TRADE_RULES = {
    personal = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "notUpgradeForLooter" },
    group    = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "none" },
    legacy   = { tradeable = false },
}

-- situation -> rule. `raid` is the conservative `personal` until smoke check TRADE-3 confirms it.
C.CONTENT_RULE = {
    mythicPlus = "personal", dungeon = "personal", followerDungeon = "legacy", raid = "personal",
    raidLFR = "personal", delve = "personal", scenario = "personal", openWorldGroup = "personal",
    solo = "personal", pvp = "legacy",
}

-- ---------------------------------------------------------------------------------------------
-- Messaging (design spec §9.1-§9.2). modules/Messaging.lua reads them; Settings › Messages edits
-- the templates (`messages.templates.<kind>`), and an empty one falls back to these.
-- ---------------------------------------------------------------------------------------------

-- The message kinds, in Settings › Messages' display order, and their default templates.
C.MESSAGE_KINDS = { "ask", "offer", "announce" }
C.MESSAGE_TEMPLATES = {
    ask      = "Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!",
    offer    = "Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?",
    announce = "{item} is up for grabs, whisper me.",
}
-- The tokens a template may name, in the token chips' order.
C.MESSAGE_TOKENS = { "player", "item", "ilvl", "slot", "track", "gain", "mygain" }
C.MESSAGE_MAX_LEN = 255          -- the chat limit, in bytes of the raw text (a link counts whole)
C.MESSAGE_FLUSH_INTERVAL = 1.5   -- seconds between two queued sends
-- What empties the queue once the player can send: the restriction lift and these two events.
C.MESSAGE_FLUSH_TRIGGERS = { restrictionLifted = true, ENCOUNTER_END = true, CHALLENGE_MODE_COMPLETED = true }
