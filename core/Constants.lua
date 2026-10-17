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

-- The main window (design spec §11.1; board 01's default size). Sizes are pixels at a 1.0 scale.
-- The chrome follows Ka0s Loot History's: a 30px title bar, a 26px tab strip, the filter bar, the
-- tab's body and a footer.
C.WINDOW = {
    NAME        = "DropWatcherWindow",
    -- The default width is the least (feedback-4 spec §4, recomputed by feedback-5 spec §4 and
    -- feedback-6 spec §1): the Drops table's every column at its width with a CELL_GAP after each, the
    -- Item column at ITEM_MIN, a drop row's indent and chevron lead, the scroll gutter and both insets:
    --   columns  Ilvl 40 + Slot 72 + Type 64 + Looter 104 + Me 127 + Them 127 + Trade 70
    --            + Trade window 76 + Actions 84 (ASK_W) = 764, + 10 gaps x 6 = 824,
    --            + Item 150 (ITEM_MIN) = 974 (Trade window is its widest answer plus its bar's
    --            padding, feedback-6 spec §0; Me and Them their widest cell, two worn icons, `321/308`
    --            and `Not wanted`, feedback-6 spec §1: tests/test_side_cells.lua measures both)
    --   lead     ROW_INDENT 12 + CHEVRON_X 4 + ROW_CHEVRON 10 + CHEVRON_GAP 4 = 30 (WindowGroup.LEAD)
    --   chrome   SCROLL_W 22 + 2 x INSET 6 = 34
    --   974 + 30 + 34 = 1038. History's columns (the same lead since feedback-15 spec §4) fit with room
    --   to spare.
    -- tests/test_drops_layout.lua pins that no tab sheds a column there and the filter bar fits.
    WIDTH       = 1038,
    HEIGHT      = 600,
    MIN_WIDTH   = 1038,   -- = WIDTH: sized wider and back, never narrower than a new profile's
    MIN_HEIGHT  = 260,
    -- Compact mode (compact spec §1, modules/WindowCompact.lua): its default size and the bounds
    -- its corner grip sizes it within. The full window keeps WIDTH/HEIGHT and MIN_WIDTH/MIN_HEIGHT.
    -- The compact least width (feedback-5 spec §4) fits a Drops card's fullest line 2: a twelve-letter
    -- looter, its realm mark, slot, type and a counted trade (about 220px at the small template's 5px a
    -- character) before the action button (ASK_W, line 2's right since feedback-10 spec §2; the
    -- countdown and its bar were there before), past the indent, chevron, icon, insets and scroll
    -- gutter (tests/test_compact_group.lua measures it). 380 cut it by about 57px.
    -- Line 3's fullest halves since feedback-6 spec §1 (`Them 321/308 ⊘ Not wanted`) end about 46px
    -- short of the card's edge there (measured too), so line 2 still sets it.
    COMPACT_WIDTH  = 440,
    COMPACT_HEIGHT = 460,
    COMPACT_MIN_W  = 440,  -- = COMPACT_WIDTH: never narrower than a new profile's (feedback-4 spec §4)
    COMPACT_MAX_W  = 520,
    COMPACT_MIN_H  = 220,
    COMPACT_MAX_H  = 900,
    TITLE_H     = 30,
    TAB_H       = 26,
    TAB_W       = 118,    -- one tab button; the strip's pitch adds TAB_GAP
    TAB_GAP     = 4,
    FILTER_H    = 30,
    BANNER_H    = 22,     -- the test-mode banner, above the tab's body while test mode is on
    FOOTER_H    = 22,
    INSET       = 6,      -- the body's side margin
    CONTROL_H   = 20,     -- a title-bar button, a dropdown, the search box
    ICON        = 18,     -- a title-bar control's square slot (the close mark's size)
    DOUBLE_CLICK = 0.4,   -- seconds between two clicks on the title bar that expand a minimized window
    FOOTER_TICK = 5,      -- seconds between footer repaints while shown ("Last loot 12s ago")
    COUNTDOWN_TICK = 1,   -- seconds between countdown repaints while Drops shows one running
    -- The drop tables (modules/WindowGroup.lua, design spec §11.1-§11.2).
    -- A drop row's height and text size are the Window page's Layout rows, `window.rowHeight` and
    -- `window.fontSize` (modules/WindowRows.lua; feedback-2 spec §8, FB2-9). Their defaults live in
    -- defaults/Profile.lua (savedvariables-§2); NS.WindowRows.ROW_H reads the row height from there.
    ROW_H_MIN   = 18,
    ROW_H_MAX   = 40,
    FONT_MIN    = 8,      -- the Font size row's least size; 0 is Default (the template's own)
    FONT_MAX    = 20,
    GROUP_H     = 20,     -- one encounter header row
    COLHEAD_H   = 18,     -- the column labels above the rows
    ROW_ICON    = 20,     -- a row's item button at most; a shorter row takes it 2px under its height
    EQ_ICON     = 16,     -- one worn item in the Me and Them cells
    CELL_GAP    = 6,      -- between two columns
    ITEM_MIN    = 150,    -- the Item column's least width (it takes the slack)
    SCROLL_W    = 22,     -- the scroll bar's gutter on the right of the rows
    -- The Ask button, and the Actions column it fills: every state's icon and word (Ask, Asked,
    -- Queued, Retry, Traded) fits with room on both sides (feedback-5 spec §0). Compact's is the same.
    ASK_W       = 84,
    -- The expand indicator (feedback-5 spec §0): a drop row is indented ROW_INDENT from its header's
    -- left edge, and draws the header's chevron (ROW_CHEVRON square) CHEVRON_X into the row, as the
    -- header does its own; the Item column starts CHEVRON_GAP after it. A compact card is indented
    -- the same, its chevron before the item button.
    ROW_INDENT  = 12,
    ROW_CHEVRON = 10,
    CHEVRON_X   = 4,
    CHEVRON_GAP = 4,
    -- The detail card, expanded inline under its row (modules/DetailCard.lua, design spec §11.3).
    CARD_H      = 248,    -- the whole card
    CARD_PAD    = 8,      -- its margin, and the gap between its boxes
    CARD_ICON   = 32,     -- the item button in its header
    CHIP_H      = 16,     -- one header or verdict chip
    SIDE_H      = 112,    -- a For you / For the looter box
    SIDE_ROW_H  = 16,     -- one comparison line
    SIDE_LABEL  = 78,     -- the comparison lines' label column
    TRADE_BOX_H = 44,     -- the trade estimate box
    ACTION_H    = 22,     -- an action button
    EDITOR_W    = 380,    -- the Edit message box
    EDITOR_H    = 156,
    -- The Drops table's empty state (board 06 D): its title and line (its two buttons gone, feedback-16).
    EMPTY_W     = 360,
    EMPTY_H     = 50,
    -- A Drops row with its Trade window column (feedback-5 spec §1), the Drops strip
    -- (modules/DropsStrip.lua, feedback-5 spec §3) and the Offer panel (modules/OfferPanel.lua),
    -- design spec §11.4, board 04.
    COUNTDOWN_EXTRA = 14, -- such a row's height over the row height (its countdown sits over its bar)
    COUNTDOWN_FONT = 10,  -- the small template's own text size, for such a row at Default
    COUNTDOWN_PAD = 12,   -- such a row's room around its two lines (the countdown and its bar)
    BAR_H       = 3,      -- the trade window's bar
    STRIP_H     = 26,     -- the Drops strip, with Post my tradeables (and History's, with Expand all)
    -- One footer button kind (feedback-15 spec §2, modules/FooterRow.lua): every button on a tab's
    -- strip (Post my tradeables, Scan group, Expand all / Collapse all) is this wide in the full
    -- layout, sized so `Post my tradeables` fits beside its icon; the tab's Sort takes it too
    -- (NS.WindowFooter.SORT_W). The compact layout draws them icon only, FOOTER_ICON_W wide, their
    -- tooltips naming them (feedback-16).
    FOOTER_BUTTON_W = 150,
    FOOTER_ICON_W = 24,
    OFFER_W     = 440,    -- the Offer panel
    OFFER_HEAD_H = 92,    -- its title, item header and column labels
    OFFER_FOOT_H = 32,    -- its Announce to group strip
    OFFER_ROW_H = 26,     -- one candidate
    OFFER_MIN_H = 320,    -- its least height beside the compact window (head, six candidates, foot)
    -- A candidate's Offer button: every state's icon and word (Offer, Offered, Queued, Retry) fits
    -- with room on both sides (feedback-7 spec §1); inside the row past the Actions column's x.
    PANEL_BTN_W = 80,     -- fits `No action` beside its icon (feedback-11 spec §1)
    DOCK_GAP    = 4,      -- between the window and the docked panel
    TIP_GAP     = 2,      -- between the window (or a docked panel) and an item tooltip beside it
    -- Where a fresh profile, and Reset position, put the window.
    POINT       = { "CENTER", "CENTER", 0, 0 },
}

-- The gold of the title, the active tab and the test-mode banner (design spec §2), and the gray of
-- an idle tab and the footer's text.
C.GOLD = { r = 1.0, g = 0.82, b = 0.0 }
C.IDLE = { r = 0.62, g = 0.62, b = 0.64 }

-- A drop row's chevron (feedback-5 spec §0): muted white, as its vertex color, and the same on hover.
-- A group header's chevron is C.GOLD, as its text.
C.CHEVRON_ROW = { r = 1.0, g = 1.0, b = 1.0, a = 0.55 }

-- The drop tables' tones (design spec §11.2; feedback-4 spec §0 and §1): `good` an upgrade, a
-- tradeable estimate or an action done, `bad` gray (not wanted, not tradeable), `warn` amber (a trade
-- window ending soon), `plain` plain text, `muted` what is not known yet; `yellow`, `red`, `cyan`
-- `redMuted` and `offspec` below.
C.TONE = {
    good  = { r = 0.30, g = 0.85, b = 0.40 },
    bad   = { r = 0.55, g = 0.55, b = 0.58 },
    warn  = { r = 1.00, g = 0.65, b = 0.15 },
    -- The verdicts' sidegrade and an action waiting on someone else (feedback-4 spec §0, §1): a
    -- yellow kept apart from the headers' gold.
    yellow = { r = 1.00, g = 0.96, b = 0.42 },
    -- The verdicts' downgrade and an action that is your move.
    red   = { r = 1.00, g = 0.36, b = 0.32 },
    -- Offer while it is your move (feedback-6 spec §2): a cyan at the palette's saturation and
    -- brightness, so giving an item away reads apart from Ask's red.
    cyan  = { r = 0.35, g = 0.82, b = 0.95 },
    -- An off-spec verdict (feedback-19 spec §1): your current spec can't use it, another of your
    -- specs can. Its own token, close to Offer's cyan by the owner's choice, so the two can part later.
    offspec = { r = 0.30, g = 0.85, b = 0.85 },
    -- The Can't use verdict and Trade's Can't use (feedback-21): a dim red, read beside the
    -- downgrade's `red` and the gray `bad`, so a drop you cannot use reads apart from one not wanted.
    redMuted = { r = 0.72, g = 0.36, b = 0.34 },
    plain = { r = 0.92, g = 0.92, b = 0.92 },
    muted = { r = 0.70, g = 0.70, b = 0.72 },
}

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

-- Minimum quality (design spec §6.2): the modes in display order. Their settings' defaults are
-- defaults/Profile.lua's `feed.quality`.
C.QUALITY_MODES = { "fixed", "dynamicSlot", "dynamicCharacter" }

-- Upgrade tracks in ascending order (design spec §5.2, step 3). The evaluation kernel compares a
-- track's numeric `tier` first; ItemFacts fills it from the track's string id where the client has
-- one. These enUS names are the fallback for a track that carries only its name, so a localized
-- name that matches none of them leaves the track delta unset rather than guessed.
C.TRACK_TIER = { Explorer = 1, Adventurer = 2, Veteran = 3, Champion = 4, Hero = 5, Myth = 6 }

-- trackStringID (C_Item.GetItemUpgradeInfo) -> tier, the locale-proof key ItemFacts tries first.
-- Empty until FEED-5 records the client's ids in game (the research names the field, not its
-- values); until then every track's tier comes from the enUS names above.
C.TRACK_TIER_BY_STRING_ID = {}

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
    -- Bows (RANGED) and guns, crossbows and wands (RANGEDRIGHT) fill both hands.
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

-- The bags the gear snapshot reads for the best item owned per slot (design spec §4): the backpack
-- (0) and the four bag slots. The reagent bag (5) holds no gear, and the bank is not readable away
-- from it.
C.BAG_IDS = { 0, 1, 2, 3, 4 }

-- ---------------------------------------------------------------------------------------------
-- Situations and difficulties (design spec §6.1)
-- ---------------------------------------------------------------------------------------------

-- Every situation key in display order. Each one's `track`, `autoOpen` and `quality` defaults are
-- defaults/Profile.lua's `situations`.
C.SITUATIONS = {
    { key = "mythicPlus" }, { key = "dungeon" }, { key = "followerDungeon" }, { key = "raidLFR" },
    { key = "raid" }, { key = "delve" }, { key = "scenario" }, { key = "pvp" },
    { key = "openWorldGroup" }, { key = "solo" },
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
-- Trade rules (design spec §7.2). modules/TradeRules.lua reads them; the rule each situation takes
-- is the `trade.rules.<situation>` setting (defaults/Profile.lua holds its default).
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

C.TRADE_WINDOW = 14400  -- seconds a tradeable drop stays tradeable (four hours since 12.1.5, seen in game 2026-10-16)

-- The rule names in Settings › Trade's display order, and the rule an unknown situation takes.
C.TRADE_RULE_NAMES = { "personal", "group", "legacy" }
C.TRADE_RULE_DEFAULT = "personal"

C.TRADE_RULES = {
    personal = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "notUpgradeForLooter" },
    group    = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "none" },
    legacy   = { tradeable = false },
}

-- ---------------------------------------------------------------------------------------------
-- Messaging (design spec §9.1-§9.2). modules/Messaging.lua reads them; the templates are the
-- `messages.templates.<kind>` settings (defaults/Profile.lua holds their defaults).
-- ---------------------------------------------------------------------------------------------

-- The message kinds, in Settings › Messages' display order. Their default templates are
-- defaults/Profile.lua's `messages.templates`.
C.MESSAGE_KINDS = { "ask", "offer", "announce" }
-- The templates, in Settings › Messages' display order: one per kind, plus two more wordings of
-- the ask, each sent as an `ask` and filed under the ask's one-ask key (NS.Messaging.AskTemplate
-- picks them): `transmog`, for a drop that is no gain for you but whose appearance you have not
-- collected, and `askOffSpec` (feedback-19 spec §2), for a drop your spec cannot use but another
-- spec of your class gains from.
C.MESSAGE_TEMPLATES = { "ask", "transmog", "askOffSpec", "offer", "announce" }
-- The tokens a template may name, in the token chips' order.
C.MESSAGE_TOKENS = { "player", "item", "ilvl", "slot", "track", "gain", "mygain" }
C.MESSAGE_MAX_LEN = 255          -- the chat limit, in bytes of the raw text (a link counts whole)
C.MESSAGE_FLUSH_INTERVAL = 1.5   -- seconds between two queued sends
-- What empties the queue once the player can send: the restriction lift and these two events.
C.MESSAGE_FLUSH_TRIGGERS = { restrictionLifted = true, ENCOUNTER_END = true, CHALLENGE_MODE_COMPLETED = true }
