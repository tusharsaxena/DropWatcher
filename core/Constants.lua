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
    -- feedback-6 spec §1, and feedback-22's wider Trade): the Drops table's every column at its width with a CELL_GAP after each, the
    -- Item column at ITEM_MIN, a drop row's indent and chevron lead, the scroll gutter and both insets:
    --   columns  Ilvl 40 + Slot 72 + Type 64 + Looter 104 + Me 127 + Them 127 + Trade 112
    --            + Trade window 76 + Actions 84 (ASK_W) = 806, + 10 gaps x 6 = 866,
    --            + Item 150 (ITEM_MIN) = 1016 (Trade is its widest word and reason, `Yes Not their
    --            upgrade`, feedback-22; Trade window is its widest answer plus its bar's
    --            padding, feedback-6 spec §0; Me and Them their widest cell, two worn icons, `321/308`
    --            and `Not wanted`, feedback-6 spec §1: tests/test_side_cells.lua measures both;
    --            a dual mark, `321 ▼10 / 324 ▼23`, is 125 inside them, feedback-21 H7)
    --   lead     ROW_INDENT 12 + CHEVRON_X 4 + ROW_CHEVRON 10 + CHEVRON_GAP 4 = 30 (WindowGroup.LEAD)
    --   chrome   SCROLL_W 22 + 2 x INSET 6 = 34
    --   1016 + 30 + 34 = 1080. History's columns (the same lead since feedback-15 spec §4) fit with room
    --   to spare.
    -- tests/test_drops_layout.lua pins that no tab sheds a column there and the filter bar fits.
    WIDTH       = 1080,
    HEIGHT      = 600,
    MIN_WIDTH   = 1080,   -- = WIDTH: sized wider and back, never narrower than a new profile's
    MIN_HEIGHT  = 260,
    -- Compact mode (compact spec §1, modules/WindowCompact.lua): its default size and the bounds
    -- its corner grip sizes it within. The full window keeps WIDTH/HEIGHT and MIN_WIDTH/MIN_HEIGHT.
    -- The compact least width (feedback-5 spec §4) fits a Drops card's fullest line 2: a twelve-letter
    -- looter, its realm mark, slot and type (about 180px at the small template's 5px a character)
    -- before the action button (ASK_W, lines 2 and 3's right since feedback-23), past the indent,
    -- chevron, icon, insets and scroll gutter (tests/test_compact_group.lua measures it). 440 until
    -- feedback-23: line 2 lost its trade to line 4 in feedback-22, and 360 cuts it by about 13px.
    -- Line 3 holds Trade beside the button, line 4 You and Them under it to the card's right inset
    -- (feedback-25), so a dual mark (feedback-21 H7, `You 321 ▼10 / 324 ▼13`) on both halves still
    -- reads both rings at 400 (measured too).
    COMPACT_WIDTH  = 400,
    COMPACT_HEIGHT = 560,  -- 460 until feedback-22 made a card four lines (Trade on its own), its icon taller
    COMPACT_MIN_W  = 400,  -- = COMPACT_WIDTH: never narrower than a new profile's (feedback-4 spec §4)
    COMPACT_MAX_W  = 520,
    COMPACT_MIN_H  = 220,
    COMPACT_MAX_H  = 900,
    TITLE_H     = 30,
    TAB_H       = 26,
    TAB_W       = 118,    -- one tab button; the strip's pitch adds TAB_GAP
    TAB_GAP     = 4,
    FILTER_H    = 30,
    BANNER_H    = 22,     -- = Widgets.TEST_STRIP.HEIGHT + 4: a 2 px gap above and below the strip
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
    -- A popover's content top (the Edit message box's field, the Offer panel's item): under its
    -- title band (1 + TITLE_H, 2 + TITLE_H under a 2 px edge) with a gap, as Ka0s Loot History (R5-WIN).
    POPOVER_TOP = 36,
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

-- The frame-layering map (frame-layering-§5; item 030). Every SetFrameStrata and SetFrameLevel in the
-- addon reads this table, and every level is relative to the frame's parent. The whole stack, low
-- to high (W is the main window's own level):
--   MEDIUM     the main window, full and compact (WINDOW, toplevel, clamped) at W; its chrome W+1
--              (title bar, tab strip, body, strips, and the Offer panel docked beside it, DOCKED);
--              its content W+2 to W+8 (tables, cards, the detail card, item buttons: an icon's
--              border at button + BORDER, its glow at button + EFFECT; the detail card's deepest glow
--              reaches W+10, beside the grip in the footer corner, which the scroll keeps clear);
--              the library's resize grip W+10 (LibKa0s-Core-1.0 sets it; GRIP names it); the
--              floating Offer panel W+30, a popover over the window's own content in the window's
--              strata (a level, never a strata jump)
--   HIGH       the toast (ALERT): over the window and its popovers, under any modal
--   DIALOG     the Edit message box (MODAL, W+40, toplevel); the library's debug console, perf and
--              sim panels; Blizzard's StaticPopups
--   FULLSCREEN the library's Copy window, over the debug console that opens it
--   FULLSCREEN_DIALOG  the library's dropdown menu, over every tier it opens from (the compact
--              Filters ▾ cascade included, each level 10 above the one it opens from)
--   TOOLTIP    GameTooltip and the TipGrid holder
C.LAYERS = {
    STRATA = {
        WINDOW = "MEDIUM",
        ALERT  = "HIGH",
        MODAL  = "DIALOG",
    },
    LEVEL = {
        BORDER          = 1,    -- an item button's border frame, over the icon's art
        EFFECT          = 2,    -- the upgrade glow (modules/Glow.lua), over the border
        DOCKED          = 1,    -- the Offer panel docked beside the window
        CONTENT_MAX     = 8,    -- the window's content stays at or below W+8 (frame-layering-§3)
        GRIP            = 10,   -- the library's resize grip: named here, set by LibKa0s-Core-1.0
        POPOVER_OFFER   = 30,   -- the floating Offer panel
        MODAL           = 40,   -- the Edit message box, belt and braces over its DIALOG strata
    },
}

-- THE PALETTE IS THE SKIN'S (skinning-§4, anti-pattern #107). The window's gold, its idle gray and a
-- drop row's chevron are painted at each call site from the token that names their role
-- (`text.heading`, `dw.idle`, `dw.chevron`, ...; core/SkinSetup.lua), so no value is kept here. The
-- drop tables' tones keep their table shape, because ~15 files index C.TONE[key] at paint time:
-- each key names the owner or library token it is drawn in (C.TONE_TOKEN), and core/SkinSetup.lua
-- FILLS the `r, g, b` of each C.TONE entry from that token at load and refills it, in place, on
-- every skin switch, before any surface repaints (its OnLooksChanged listener is the first one). Under
-- Ka0s Default each is the exact value it was before skins (X1).
--
-- `good` an upgrade, a tradeable estimate or an action done; `bad` gray (not wanted, not tradeable);
-- `warn` amber (a trade window ending soon); `plain` plain text; `muted` what is not known yet.
-- `yellow` the verdicts' sidegrade and an action waiting on someone else (feedback-4 spec §0, §1), a
-- yellow kept apart from the headers' gold; `red` the downgrade and an action that is your move;
-- `cyan` Offer while it is your move (feedback-6 spec §2); `offspec` an off-spec verdict
-- (feedback-19 spec §1), close to Offer's cyan by the owner's choice, so the two can part later;
-- `redMuted` the Can't use verdict and Trade's Can't use, and a stat lost on the Stats row
-- (feedback-21, H5); `greenMuted` a stat gained (feedback-21 H5), dimmer than `good`; `mutedGold` a
-- tooltip row's label and bullet (feedback-21 H3).
C.TONE_TOKEN = {
    good = "dw.upgrade", bad = "dw.notWanted", warn = "dw.urgent", yellow = "dw.sidegrade",
    red = "dw.downgrade", cyan = "dw.offer", offspec = "dw.offSpec", redMuted = "dw.cantUse",
    greenMuted = "dw.statGain", mutedGold = "dw.tipLabel", plain = "dw.plain", muted = "text.muted",
}

C.TONE = {}
for key in pairs(C.TONE_TOKEN) do C.TONE[key] = {} end

-- NOT SKIN COLORS (docs/ARCHITECTURE.md, Skins > Intentional exceptions): the four secondary stats'
-- names tell one stat from another by hue (E5), and the upgrade glows' two defaults tell the main
-- spec from an off-spec (E6, and they are the player's stored swatches). Kept as values.
local FIXED_TONE = {
    -- Each secondary stat's name on the detail card's Stats row (feedback-21 H5; C.STAT_TONE): four
    -- hues apart from one another and from the values' green and red, readable on the dark card.
    statCrit    = { r = 1.00, g = 0.62, b = 0.30 },
    statHaste   = { r = 1.00, g = 0.88, b = 0.45 },
    statMastery = { r = 0.74, g = 0.58, b = 1.00 },
    statVers    = { r = 0.45, g = 0.75, b = 1.00 },
    -- The upgrade glows' default colors: the main spec's #19FF19 (DW-03, owner ruling D-18, image-39;
    -- #FFF468 from feedback-21 H6 until then) and the off-spec's #3FC7EB, their own tokens so the
    -- glows part from the verdicts' `good` and `offspec`, each channel the hex byte over 255.
    glowMain    = { r = 25 / 255,  g = 255 / 255, b = 25 / 255 },
    glowOffSpec = { r = 63 / 255,  g = 199 / 255, b = 235 / 255 },
}
for key, c in pairs(FIXED_TONE) do C.TONE[key] = c end

-- The C.TONE key of each stat the detail card's Stats row names, by its C_Item.GetItemStats key
-- (modules/DetailCells.lua's SECONDARY): one fixed color per stat (feedback-21 H5).
C.STAT_TONE = {
    ITEM_MOD_CRIT_RATING_SHORT    = "statCrit",
    ITEM_MOD_HASTE_RATING_SHORT   = "statHaste",
    ITEM_MOD_MASTERY_RATING_SHORT = "statMastery",
    ITEM_MOD_VERSATILITY          = "statVers",
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
    CONTAINER     = { "Container", 1 },
    REAGENT       = { "Reagent", 5 },
    RECIPE        = { "Recipe", 9 },
    MISCELLANEOUS = { "Miscellaneous", 15 },
})

-- Enum.ItemMiscellaneousSubclass: a mount or companion pet item's class rung (categories design
-- spec §1), the fallback when the journal does not answer. Mount Equipment is not a mount.
C.MISC_SUBCLASS = fromEnum(Enum.ItemMiscellaneousSubclass, {
    JUNK            = { "Junk", 0 },
    REAGENT         = { "Reagent", 1 },
    COMPANION_PET   = { "CompanionPet", 2 },
    HOLIDAY         = { "Holiday", 3 },
    OTHER           = { "Other", 4 },
    MOUNT           = { "Mount", 5 },
    MOUNT_EQUIPMENT = { "MountEquipment", 6 },
})

-- Enum.ItemRecipeSubclass: the profession a recipe teaches, by subclass.
C.RECIPE_SUBCLASS = fromEnum(Enum.ItemRecipeSubclass, {
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

-- Enum.ItemArmorSubclass. GENERIC is jewelry, trinkets and held off hands; COSMETIC is never gear.
-- LIBRAM, IDOL and TOTEM are WoW Forever's relics (the ranged slot, core/ClassDataForever.lua).
C.ARMOR_SUBCLASS = fromEnum(Enum.ItemArmorSubclass, {
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
    THROWN    = { "Thrown", 16 },   -- WoW Forever's ranged slot (core/ClassDataForever.lua)
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
-- Watched categories (issue #13, categories design spec §1)
-- ---------------------------------------------------------------------------------------------

-- Every category a drop can fall in, in display order. `collectible` ones get a collection verdict
-- (new or collected) instead of a gear one, and are feed-only. NS.Collectibles.CategoryOf decides
-- which one an item is, in its own precedence order. `kind` ones (RX-04, rolls UX design §3.5) are
-- not gear and not collected: their verdict is their kind word (Lockbox, Container, Item), and they
-- are feed-only too. `container` is a lockbox or a bag; `other` is no item's category: the feed's
-- filter takes an item of no kind under it when it is rolled on (NS.FeedFilter), its catch-all.
C.CATEGORIES = {
    { key = "equipment", collectible = false }, { key = "tierToken", collectible = false },
    { key = "mount", collectible = true }, { key = "pet", collectible = true },
    { key = "toy", collectible = true }, { key = "recipe", collectible = true },
    { key = "cosmetic", collectible = true },
    { key = "container", collectible = false, kind = true }, { key = "other", collectible = false, kind = true },
}

-- The kind History records for a drop the Always watch list let in that fits no category (a reagent,
-- a quest item): History-only, never a CATEGORIES key or a feed filter's, so Insights files it as
-- its own Watched item, sorted after every category, not as equipment (the pre-#13 fallback).
C.CATEGORY_WATCHED = "watched"

-- The slots a tier token can make, in the order an omni token's slots are tried.
C.TIER_SLOTS = { "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_HAND", "INVTYPE_LEGS" }

-- itemID -> { slot = "INVTYPE_HEAD" | ... | "any" }: an override for a token whose own text misreads;
-- the first rung of NS.TierTokens.SlotOf, ahead of the Use text and the name, and a token on its own
-- (TierTokens.Listed). Empty by default: since TT-1 a token's slot is read from its text, so no
-- table is kept up per season (docs/common-tasks.md, "Add a season's tier tokens").
C.TIER_TOKENS = {}

-- ---------------------------------------------------------------------------------------------
-- Inventory slots and slot plans (design spec §5.2)
-- ---------------------------------------------------------------------------------------------

-- The client picked once (clients-§5): the slot ids and the slot plans below are per client.
local FOREVER = NS.Compat.ClientKey() == "forever"

-- The Retail-only features (Forever port design §4.4), each declared with the clients it serves
-- (clients-§4) and gated where it registers by C.FEATURE, its ForClient answer read once: the
-- Encounter Journal source of the simulator's pool (modules/SimPool.lua), transmog (the look read,
-- its event, chips, ask and rows), upgrade tracks (the Track row, the track in the item level chip
-- and tooltip, the {track} token), off-spec (modules/OffSpec.lua, its glow, ask and words) and the
-- simulator's bonus rolls (modules/SimEvents.lua), your own BoP drop's trade countdown and its
-- warning (modules/TradeTimer.lua, the `trade.warnAt` row) and the per-situation loot rule rows
-- (`trade.rules.<situation>`, Drops › Situations' Loot rule column): WoW Forever has one rule,
-- `soulbound` (design §4.6). docs/ARCHITECTURE.md's per-client feature table names each one's gate.
C.FEATURE_CLIENTS = {
    journalPool   = { "retail" },
    transmog      = { "retail" },
    tracks        = { "retail" },
    offSpec       = { "retail" },
    bonusRollSim  = { "retail" },
    tradeTimer    = { "retail" },
    tradeRuleRows = { "retail" },
}
C.FEATURE = {}
for name, clients in pairs(C.FEATURE_CLIENTS) do C.FEATURE[name] = NS.Compat.ForClient(clients) end

-- The client's inventory slot ids (the INVSLOT_* FrameXML constants). Slot 18, the old ranged
-- slot, is unused on Retail: bows, guns, crossbows and wands are main-hand items. WoW Forever keeps
-- it (INVSLOT_RANGED, research R4 §9) for ranged and thrown weapons, wands and relics.
C.SLOT = {
    HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6, LEGS = 7, FEET = 8,
    WRIST = 9, HANDS = 10, FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14, BACK = 15,
    MAINHAND = 16, OFFHAND = 17, RANGED = FOREVER and 18 or nil, TABARD = 19,
}
local S = C.SLOT

-- The comparison kinds the evaluation kernel knows. `unique` is applied on top of a plan when the
-- drop carries a unique-equipped category; no equip location maps to it directly.
C.SLOT_KIND = {
    single = true, pair = true, weapon1H = true, weapon2H = true, offhand = true, ranged = true,
    unique = true,
}

-- equipLoc -> { kind, slots }. An equip location absent here (shirt, tabard, bag, ammo,
-- non-equippable) is not gear the feed compares. The rows both clients share; each client's own
-- ranged rows follow (SLOT_PLAN_RANGED), and the two are joined once, by ClientKey().
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

-- Each client's ranged rows: two lists, one per client, picked once (clients-§5).
local SLOT_PLAN_RANGED = {
    -- Retail: bows (RANGED) and guns, crossbows and wands (RANGEDRIGHT) fill both hands; there are
    -- no thrown weapons or relics.
    retail = {
        INVTYPE_RANGED      = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
        INVTYPE_RANGEDRIGHT = { kind = "ranged", slots = { S.MAINHAND, S.OFFHAND } },
    },
    -- WoW Forever: bows, guns, crossbows, wands, thrown weapons and relics (a libram, idol or totem)
    -- go in the ranged slot, compared with what is worn there (research R4 §9).
    forever = {
        INVTYPE_RANGED      = { kind = "single", slots = { S.RANGED } },
        INVTYPE_RANGEDRIGHT = { kind = "single", slots = { S.RANGED } },
        INVTYPE_THROWN      = { kind = "single", slots = { S.RANGED } },
        INVTYPE_RELIC       = { kind = "single", slots = { S.RANGED } },
    },
}

C.SLOT_PLAN = {}
for loc, plan in pairs(SLOT_PLAN_SHARED) do C.SLOT_PLAN[loc] = plan end
for loc, plan in pairs(SLOT_PLAN_RANGED[FOREVER and "forever" or "retail"]) do C.SLOT_PLAN[loc] = plan end

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

-- Every situation key in display order, one list per client, picked once (clients-§5). Each
-- one's `track`, `autoOpen` and `quality` defaults are defaults/Profile.lua's `situations`. WoW
-- Forever has no Mythic+, follower dungeons, Raid Finder, delves or scenarios (Forever port design
-- §4.4), so its list is the five situations it has.
local SITUATION_LISTS = {
    retail = {
        { key = "mythicPlus" }, { key = "dungeon" }, { key = "followerDungeon" }, { key = "raidLFR" },
        { key = "raid" }, { key = "delve" }, { key = "scenario" }, { key = "pvp" },
        { key = "openWorldGroup" }, { key = "solo" },
    },
    forever = {
        { key = "dungeon" }, { key = "raid" }, { key = "pvp" }, { key = "openWorldGroup" }, { key = "solo" },
    },
}
C.SITUATIONS = SITUATION_LISTS[FOREVER and "forever" or "retail"]
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
    RAID_CLASSIC_20     = 242,   -- WoW Forever's 20-player raids (DifficultyUtil.ID, research R4 §12)
    RAID_CLASSIC_10     = 243,   -- WoW Forever's 10-player raids
}
local D = C.DIFFICULTY

-- difficultyID -> the situation it implies, one map per client, picked once (clients-§5). Ids not
-- listed here fall back to instanceType.
local DIFFICULTY_KINDS = {}
DIFFICULTY_KINDS.retail = {
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
-- WoW Forever: a dungeon's one difficulty, the 40-player raids and the classic 20- and 10-player
-- ones. None of its ids implies a situation Retail alone has.
DIFFICULTY_KINDS.forever = {
    [D.NORMAL_DUNGEON]  = "dungeon",
    [D.RAID_40]         = "raid",
    [D.RAID_CLASSIC_20] = "raid",
    [D.RAID_CLASSIC_10] = "raid",
}
C.DIFFICULTY_KIND = DIFFICULTY_KINDS[FOREVER and "forever" or "retail"]

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

-- The rule names in Settings › Trade's display order, and the rule an unknown situation takes, one
-- list per client, picked once (clients-§5). WoW Forever has no personal loot and no trade window:
-- a looted Bind on Pickup item is soulbound (Forever port design §4.6), so its one rule is
-- `soulbound` and only a BoE drop changes hands.
local TRADE_RULE_LISTS = {
    retail  = { "personal", "group", "legacy" },
    forever = { "soulbound" },
}
C.TRADE_RULE_NAMES = TRADE_RULE_LISTS[FOREVER and "forever" or "retail"]
C.TRADE_RULE_DEFAULT = C.TRADE_RULE_NAMES[1]

-- Every rule's data. TradeRules takes only the client's own names (C.TRADE_RULE_NAMES) as rules.
-- `bopOnly`: every drop the bind checks did not answer (anything not BoE) is `no soulbound`.
C.TRADE_RULES = {
    personal  = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "notUpgradeForLooter" },
    group     = { tradeable = true,  window = C.TRADE_WINDOW, ilvlRule = "none" },
    legacy    = { tradeable = false },
    soulbound = { tradeable = false, bopOnly = true },
}

-- ---------------------------------------------------------------------------------------------
-- Messaging (design spec §9.1-§9.2). modules/Messaging.lua reads them; the templates are the
-- `messages.templates.<kind>` settings (defaults/Profile.lua holds their defaults).
-- ---------------------------------------------------------------------------------------------

-- The message kinds, in Settings › Messages' display order. Their default templates are
-- defaults/Profile.lua's `messages.templates`. `askML` (Forever port design §6, both clients) is the
-- polite whisper to the master looter for an item awaiting them: its own kind, because it goes to
-- the master looter, is filed against a pending item (modules/PendingML.lua), not a feed drop, and
-- auto-ask never sends it.
C.MESSAGE_KINDS = { "ask", "offer", "announce", "askML" }
-- The templates, in Settings › Messages' display order: one per kind, plus two more wordings of
-- the ask, each sent as an `ask` and filed under the ask's one-ask key (NS.Messaging.AskTemplate
-- picks them): `transmog`, for a drop that is no gain for you but whose appearance you have not
-- collected, and `askOffSpec` (feedback-19 spec §2), for a drop your spec cannot use but another
-- spec of your class gains from.
-- One list per client, picked once (clients-§5): WoW Forever has no transmog and no off-spec
-- (Forever port design §4.4), so it has neither of their templates.
-- The master-loot ask's template follows the ask's wordings on both.
local TEMPLATE_LISTS = {
    retail  = { "ask", "transmog", "askOffSpec", "askML", "offer", "announce" },
    forever = { "ask", "askML", "offer", "announce" },
}
C.MESSAGE_TEMPLATES = TEMPLATE_LISTS[FOREVER and "forever" or "retail"]
-- The tokens a template may name, in the token chips' order, per client: WoW Forever has no
-- upgrade tracks, so no {track} (Forever port design §4.4).
local TOKEN_LISTS = {
    retail  = { "player", "item", "ilvl", "slot", "track", "gain", "mygain" },
    forever = { "player", "item", "ilvl", "slot", "gain", "mygain" },
}
C.MESSAGE_TOKENS = TOKEN_LISTS[FOREVER and "forever" or "retail"]
C.MESSAGE_MAX_LEN = 255          -- the chat limit, in bytes of the raw text (a link counts whole)
C.MESSAGE_FLUSH_INTERVAL = 1.5   -- seconds between two queued sends
-- What empties the queue once the player can send: the restriction lift and these events, one set
-- per client, picked once (a key's completion is Retail's alone).
local FLUSH_TRIGGERS = {
    retail  = { restrictionLifted = true, ENCOUNTER_END = true, CHALLENGE_MODE_COMPLETED = true },
    forever = { restrictionLifted = true, ENCOUNTER_END = true },
}
C.MESSAGE_FLUSH_TRIGGERS = FLUSH_TRIGGERS[FOREVER and "forever" or "retail"]
