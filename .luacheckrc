-- .luacheckrc — lint config for Ka0s Drop Watcher (lint).
-- `luacheck .` must report 0 warnings / 0 errors before every commit.

std = "lua51"
max_line_length = false
codes = true

-- libs/ is vendored (LibKa0s is linted in its own repo); tests/_kit/ is a byte copy of the
-- library's testkit/. Under docs/ only the frozen bundle stores are excluded. Everything else under
-- tests/ is ours and is linted.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }

-- No top-level `ignore`: a blanket suppression reaches every file (lint).

-- The SavedVariables write targets and the one Blizzard table the addon writes to.
globals = {
  "DropWatcherDB",       -- AceDB
  "DropWatcherPerfDB",   -- the diagnostics capture ring (performance-§5)
  "StaticPopupDialogs",
  "BINDING_HEADER_DROPWATCHER",  -- the Keybindings section title: the category every binding names (launcher-§6)
}

-- C_AddOns stays shared for core/EnvSetup.lua's metadata read, C_Item for core/ItemSetup.lua and the
-- load-time tables; the world reads are scoped to the Compat family below.
read_globals = {
  "_G", "LibStub", "C_AddOns", "C_Item", "C_Timer",
  "CreateFrame", "UIParent", "UISpecialFrames", "STANDARD_TEXT_FONT", "ITEM_QUALITY_COLORS",
  "debugprofilestop", "tinsert",
  "Settings", "StaticPopup_Show", "StaticPopup_Hide", "YES", "NO",
  "GetTime", "time", "date", "GameTooltip", "IsShiftKeyDown", "IsControlKeyDown",
}

-- The harness global, declared for tests/ only so no shipped file can reach for it. The
-- SavedVariables names are cleared by tests/loader.lua before each instance.
files["tests/"] = {
  globals = {
    "_G.DW_TEST",
    "_G.DropWatcherDB",
    "_G.DropWatcherPerfDB",
    "_G.BINDING_HEADER_DROPWATCHER",  -- test_bindings clears it before a load writes it
  },
}

-- The client APIs only core/Compat.lua may name (compat): declared for that file alone, so a
-- feature module that reaches for one directly fails lint.
files["core/Compat.lua"] = {
  read_globals = {
    "Enum", "issecretvalue", "canaccessvalue",
    "C_ChatInfo", "SendChatMessage", "C_TooltipInfo", "C_RestrictedActions", "C_Container",
    "ItemLocation", "DropItemOnUnit", "InitiateTrade", "CursorHasItem", "ClearCursor",
    "PawnIsReady", "PawnIsInitialized", "PawnGetItemData", "PawnIsItemAnUpgrade", "PawnFindScaleForSpec",
    "PawnGetSingleValueFromItem", "PawnCommon", "PawnIsScaleVisible", "CanIMogIt",
    "C_TransmogCollection", "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE",
    "GetInventoryItemLink",
    "GetInventoryItemID", "CanInspect", "CheckInteractDistance", "NotifyInspect", "ClearInspectPlayer",
    "InspectFrame", "hooksecurefunc",
    "C_ClassColor", "RAID_CLASS_COLORS", "ChatFrameUtil", "ChatEdit_InsertLink", "DressUpItemLink",
    "DressUpLink", "GetTradePlayerItemLink", "GetTradeTargetItemLink", "LE_GAME_ERR_TRADE_COMPLETE", "ERR_TRADE_COMPLETE",
    "MenuUtil", "PlaySound", "SOUNDKIT", "PixelUtil",
    "C_ChallengeMode", "UnitName",
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CAMELOT",  -- the client stub (clients-§3)
    "RegionalUniqueNamesEnabled",  -- the regional-names stub (client-quirks-§5)
  },
}

-- The character's client-variant reads (Forever port design §4.1): core/CompatClient.lua alone names
-- the realm, a spec's name, the inspected spec and the group role (the trade partner's name goes
-- through the root's UnitCharacterName).
files["core/CompatClient.lua"] = {
  read_globals = { "GetNormalizedRealmName", "GetRealmName", "GetSpecializationInfoByID",
    "C_SpecializationInfo", "GetInspectSpecialization", "UnitGroupRolesAssigned" },
}

-- The loot history and the group-loot rolls (Forever port design §5.1), the loot method and the
-- loot window (§6), the roll popups' gamepad switch (§7): core/CompatLoot.lua alone names C_LootHistory,
-- C_PartyInfo, InputUtil and those globals.
files["core/CompatLoot.lua"] = {
  read_globals = { "C_LootHistory", "GetActiveLootRollIDs", "GetLootRollItemInfo", "GetLootRollItemLink",
    "C_PartyInfo", "Constants", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo",
    "InputUtil" },
}

-- The Encounter Journal: core/CompatJournal.lua alone names it, for the simulator's item pool.
files["core/CompatJournal.lua"] = {
  read_globals = {
    "EncounterJournal", "C_EncounterJournal", "EJ_GetNumTiers", "EJ_GetCurrentTier", "EJ_SelectTier",
    "EJ_GetInstanceByIndex", "EJ_SelectInstance", "EJ_SelectEncounter", "EJ_GetDifficulty", "EJ_SetDifficulty",
    "EJ_GetLootFilter", "EJ_SetLootFilter", "EJ_GetNumLoot", "EJ_GetInstanceInfo", "EJ_GetEncounterInfo",
  },
}

-- The collection reads (issue #13): core/CompatCollect.lua alone names the mount, pet and toy
-- journals, the toy and profession globals, the hyperlink tooltip it reads a recipe's line and a
-- tier token's slot line from, the client's class names (a tier token's classes, DW-CAT4), and the
-- spell namespace an item's use text is read from (TT-1).
files["core/CompatCollect.lua"] = {
  read_globals = { "C_MountJournal", "C_PetJournal", "C_ToyBox", "PlayerHasToy", "C_TooltipInfo",
    "GetProfessions", "GetProfessionInfo", "LOCALIZED_CLASS_NAMES_MALE", "C_Spell" },
}

-- The stable world reads (the group, its units, the instance, combat, optional-addon presence):
-- core/CompatWorld.lua alone names them, so a module that reads one directly fails lint as well as
-- tests/test_sim_e2e.lua's scan.
files["core/CompatWorld.lua"] = {
  read_globals = {
    "GetInstanceInfo", "GetDifficultyInfo", "IsInInstance", "IsInGroup", "IsInRaid", "C_ChallengeMode",
    "GetNumGroupMembers", "UnitGUID", "UnitClass", "UnitLevel", "UnitIsConnected",
    "UnitIsPlayer", "LE_PARTY_CATEGORY_INSTANCE", "InCombatLockdown", "UnitAffectingCombat",
  },
}

-- core/CompatItem.lua's one client namespace beyond the shared globals: the ItemLocation of a bag
-- slot (DW-80).
files["core/CompatItem.lua"] = {
  read_globals = { "ItemLocation" },
}

-- core/SkinSetup.lua's NS.ScaledFont makes the named, scaled font objects the upgrade toast draws in
-- (DW-05): the client's font-object constructor.
files["core/SkinSetup.lua"] = {
  read_globals = { "CreateFont" },
}

-- modules/WindowRows.lua's table font makes one named font object per look of the Tables font block
-- (DW-01), so a 12.0.7 client draws its shadow: the same constructor.
files["modules/WindowRows.lua"] = {
  read_globals = { "CreateFont" },
}

-- DW:SlashEnabled and DW:OnSlashCommand are methods on the addon object by calling convention;
-- neither body reads the receiver.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
