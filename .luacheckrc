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
}

read_globals = {
  "_G", "LibStub", "C_AddOns", "C_Item", "C_Timer",
  "CreateFrame", "UIParent", "UISpecialFrames", "STANDARD_TEXT_FONT", "ITEM_QUALITY_COLORS",
  "InCombatLockdown", "UnitAffectingCombat", "debugprofilestop", "tinsert",
  "Settings", "StaticPopup_Show", "StaticPopup_Hide", "YES", "NO",
  "GetInstanceInfo", "GetDifficultyInfo", "IsInInstance", "IsInGroup", "IsInRaid", "C_ChallengeMode",
  "GetNumGroupMembers", "UnitGUID", "UnitName", "UnitClass", "UnitIsConnected", "UNKNOWNOBJECT",
  "GetTime", "time", "date", "LE_PARTY_CATEGORY_INSTANCE", "GameTooltip", "IsShiftKeyDown", "IsControlKeyDown",
}

-- The harness global, declared for tests/ only so no shipped file can reach for it. The
-- SavedVariables names are cleared by tests/loader.lua before each instance.
files["tests/"] = {
  globals = {
    "_G.DW_TEST",
    "_G.DropWatcherDB",
    "_G.DropWatcherPerfDB",
  },
}

-- The client APIs only core/Compat.lua may name (compat): declared for that file alone, so a
-- feature module that reaches for one directly fails lint.
files["core/Compat.lua"] = {
  read_globals = {
    "Enum", "issecretvalue", "canaccessvalue",
    "C_ChatInfo", "SendChatMessage", "C_TooltipInfo", "C_RestrictedActions", "C_Container",
    "ItemLocation", "DropItemOnUnit", "InitiateTrade", "CursorHasItem", "ClearCursor",
    "PawnIsInitialized", "PawnGetItemData", "PawnIsItemAnUpgrade", "PawnFindScaleForSpec",
    "PawnGetSingleValueFromItem", "CanIMogIt", "GetNormalizedRealmName", "GetRealmName",
    "C_TransmogCollection", "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE",
    "GetInventoryItemLink",
    "GetInventoryItemID", "CanInspect", "CheckInteractDistance", "NotifyInspect", "ClearInspectPlayer",
    "GetInspectSpecialization", "InspectFrame", "hooksecurefunc", "C_LootHistory",
    "C_ClassColor", "RAID_CLASS_COLORS", "ChatFrameUtil", "ChatEdit_InsertLink", "DressUpItemLink",
    "DressUpLink", "GetSpecializationInfoByID", "GetTradePlayerItemLink", "GetTradeTargetItemLink", "LE_GAME_ERR_TRADE_COMPLETE", "ERR_TRADE_COMPLETE",
    "MenuUtil", "PlaySound", "SOUNDKIT",
    "EncounterJournal", "C_EncounterJournal", "EJ_GetNumTiers", "EJ_GetCurrentTier", "EJ_SelectTier",
    "EJ_GetInstanceByIndex", "EJ_SelectInstance", "EJ_SelectEncounter", "EJ_GetDifficulty", "EJ_SetDifficulty",
    "EJ_GetLootFilter", "EJ_SetLootFilter", "EJ_GetNumLoot",
  },
}

-- core/CompatItem.lua's one client namespace beyond the shared globals: the ItemLocation of a bag
-- slot (DW-80).
files["core/CompatItem.lua"] = {
  read_globals = { "ItemLocation" },
}

-- DW:SlashEnabled and DW:OnSlashCommand are methods on the addon object by calling convention;
-- neither body reads the receiver.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
