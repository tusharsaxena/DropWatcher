-- tests/wow_mock_loot.lua
--
-- The loot surface core/CompatLoot.lua reads (Forever port design §5.1, plan DW-FP13): the loot
-- history, the group-loot roll globals, the loot method, the loot-window slot globals and the four
-- roll popups, split out of tests/wow_mock.lua as its own mock family. tests/wow_mock.lua's builder
-- calls this with the mock; every field is settable by a case.
--
-- Mock fields:
--   lootHistory    C_LootHistory.GetSortedInfoForDrop's answers, keyed "encounterID:key"
--                  ({ itemHyperlink, winner = { playerName, playerGUID, playerClass, isSelf, roll },
--                  currentLeader, rollInfos, allPassed, isTied, playerRollState, startTime,
--                  duration }). A plain answer gets the client's drop-key field stamped on it when it
--                  names neither: lootListID on Retail, lootListKey on Forever (R2 §2.2), so a case
--                  reads the key the way the running kit profile's client names it.
--                  GetSortedDropsForEncounter(encounterID) answers that encounter's drops, in key order
--   lootEncounters the encounters, in GetAllEncounterInfos' order: { encounterID, encounterName,
--                  startTime, duration }; GetInfoForEncounter(id) answers the one with that id
--   lootHistoryTime  GetLootHistoryTime()'s answer (the clock startTime is on)
--   lootRolls      the open group-loot rolls by rollID: { link, texture, name, count, quality, bop,
--                  canNeed, canGreed, canDisenchant, canTransmog, timeLeft }, read by GetLootRollItemInfo
--                  (its thirteen returns), GetLootRollItemLink and GetLootRollTimeLeft (timeLeft, in
--                  milliseconds as the client answers it); activeLootRolls is
--                  GetActiveLootRollIDs()'s list
--   lootMethod     C_PartyInfo.GetLootMethod()'s three answers as { method, masterLootPartyID,
--                  masterLooterRaidID } (nil: a case that leaves it unset)
--   lootSlots      the open loot window's slots: { link, texture, name, count, quality, locked,
--                  source }; GetNumLootItems is their count, GetLootSlotLink / GetLootSlotInfo read
--                  one, GetLootSourceInfo answers its `source` GUID and the count
--   GroupLootFrame1..4  plain stand-ins for Blizzard's roll popups: rollID, Show / Hide / IsShown,
--                  and HookScript recording each hook in .hooks[script]. Show runs the popup's own
--                  handler first (`.blizzOnShow(self)`, a case's stand-in for Blizzard's
--                  GroupLootFrame_OnShow, which can hide it again at once), then the OnShow hooks;
--                  Hide runs the OnHide hooks when it was shown (DW-FP20)
--   gamepadUI      InputUtil.IsGamepadUIEnabled()'s answer (WoW Forever's gamepad roll list)

local function isForever(M)
    return M.WOW_PROJECT_CAMELOT ~= nil and M.WOW_PROJECT_ID == M.WOW_PROJECT_CAMELOT
end

-- Stamp the client's key field on a plain drop answer that names neither (a secret proxy has a
-- metatable and is left alone).
local function stampKey(M, drop, key)
    if type(drop) ~= "table" or getmetatable(drop) ~= nil then return drop end
    if drop.lootListID == nil and drop.lootListKey == nil then
        drop[isForever(M) and "lootListKey" or "lootListID"] = key
    end
    return drop
end

local function popup(i)
    local f = { rollID = nil, shown = false, hooks = {} }
    local function run(self, script)
        for _, fn in ipairs(self.hooks[script] or {}) do fn(self) end
    end
    function f.Show(self)
        if self.shown then return end
        self.shown = true
        if self.blizzOnShow then self.blizzOnShow(self) end
        run(self, "OnShow")
    end
    function f.Hide(self)
        if not self.shown then return end
        self.shown = false
        run(self, "OnHide")
    end
    function f.IsShown(self) return self.shown end
    function f.GetName() return "GroupLootFrame" .. i end
    function f.HookScript(self, script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    return f
end

return function(M)
    M.lootHistory, M.lootEncounters = {}, {}
    M.C_LootHistory = {
        GetSortedInfoForDrop = function(encounterID, key)
            return stampKey(M, M.lootHistory[encounterID .. ":" .. key], key)
        end,
        GetSortedDropsForEncounter = function(encounterID)
            local keys, prefix = {}, encounterID .. ":"
            for k in pairs(M.lootHistory) do
                if k:sub(1, #prefix) == prefix then keys[#keys + 1] = tonumber(k:sub(#prefix + 1)) end
            end
            table.sort(keys)
            local out = {}
            for _, key in ipairs(keys) do
                out[#out + 1] = stampKey(M, M.lootHistory[prefix .. key], key)
            end
            return out
        end,
        GetInfoForEncounter = function(encounterID)
            for _, e in ipairs(M.lootEncounters) do
                if e.encounterID == encounterID then return e end
            end
            return nil
        end,
        GetAllEncounterInfos = function() return M.lootEncounters end,
        GetLootHistoryTime = function() return M.lootHistoryTime end,
    }

    M.lootRolls, M.activeLootRolls = {}, {}
    M.GetActiveLootRollIDs = function() return M.activeLootRolls end
    M.GetLootRollItemLink = function(rollID)
        local r = M.lootRolls[rollID]
        return r and r.link
    end
    M.GetLootRollTimeLeft = function(rollID)
        local r = M.lootRolls[rollID]
        return r and r.timeLeft
    end
    M.GetLootRollItemInfo = function(rollID)
        local r = M.lootRolls[rollID]
        if not r then return nil end
        return r.texture, r.name, r.count or 1, r.quality, r.bop, r.canNeed, r.canGreed, r.canDisenchant,
            nil, nil, nil, nil, r.canTransmog
    end

    M.C_PartyInfo = M.C_PartyInfo or {}
    M.C_PartyInfo.GetLootMethod = function()
        local lm = M.lootMethod
        if type(lm) ~= "table" then return lm end
        return lm[1], lm[2], lm[3]
    end

    M.lootSlots = {}
    M.GetNumLootItems = function() return #M.lootSlots end
    M.GetLootSlotLink = function(slot)
        local s = M.lootSlots[slot]
        return s and s.link
    end
    M.GetLootSlotInfo = function(slot)
        local s = M.lootSlots[slot]
        if not s then return nil end
        return s.texture, s.name, s.count or 1, nil, s.quality, s.locked
    end
    M.GetLootSourceInfo = function(slot)
        local s = M.lootSlots[slot]
        if not (s and s.source) then return nil end
        return s.source, s.count or 1
    end

    for i = 1, 4 do M["GroupLootFrame" .. i] = popup(i) end
    M.InputUtil = { IsGamepadUIEnabled = function() return M.gamepadUI == true end }
end
