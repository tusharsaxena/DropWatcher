local _, NS = ...
-- core/CompatJournal.lua — the Encounter Journal's reads and selections (simulator spec §3),
-- published on NS.Compat like the rest of the compat family, split out of core/Compat.lua to keep it
-- under the 1000-line band. The simulator's item pool (modules/SimPool.lua) is the one caller.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- ── The Encounter Journal (the simulator's item pool, simulator spec §3) ────────────────────
-- Reads and selections only; the save and restore, the async wait and the fallback are SimPool's.

--- The journal's selection: { shown, tiers, tier, difficulty, classID, specID, slot, instanceID,
--- encounterID, keystoneLevel } (shown and the two ids are the frame's, nil before it loads;
--- keystoneLevel is the loot preview's Mythic+ level, nil without GetPreviewMythicPlusLevel). Nil
--- without EJ_*.
--- @return table|nil
function Compat.JournalSelection()
    if not (EJ_GetNumTiers and EJ_GetCurrentTier and EJ_GetDifficulty and EJ_GetLootFilter) then return nil end
    local ej, frame = C_EncounterJournal, EncounterJournal
    local shown = frame and frame.IsShown and frame:IsShown()
    local classID, specID = EJ_GetLootFilter()
    return { shown = not Compat.IsSecret(shown) and shown == true, tiers = plainNumber(EJ_GetNumTiers()),
        tier = EJ_GetCurrentTier(), difficulty = EJ_GetDifficulty(), classID = classID, specID = specID,
        slot = ej and ej.GetSlotFilter and ej.GetSlotFilter(), instanceID = frame and frame.instanceID,
        encounterID = frame and frame.encounterID,
        keystoneLevel = ej and ej.GetPreviewMythicPlusLevel and plainNumber(ej.GetPreviewMythicPlusLevel()) }
end

local function journalExtras(ej, sel)
    if sel.encounterID and EJ_SelectEncounter then EJ_SelectEncounter(sel.encounterID) end
    if sel.slot == nil and ej.ResetSlotFilter then ej.ResetSlotFilter() end
    if sel.slot ~= nil and ej.SetSlotFilter then ej.SetSlotFilter(sel.slot) end
    -- The preview level is set only where it can be read back, so a save and restore can undo it.
    if sel.keystoneLevel and ej.GetPreviewMythicPlusLevel and ej.SetPreviewMythicPlusLevel then
        ej.SetPreviewMythicPlusLevel(sel.keystoneLevel)
    end
end

--- Select what `sel` names, in the journal's order: tier, instanceID, difficulty, the class filter
--- (classID 0 or nil: every class), encounterID, the slot filter (nil: every slot), the loot
--- preview's Mythic+ level (`keystoneLevel`, when the client can read it back). False without.
--- @return boolean
function Compat.JournalSelect(sel)
    if not (EJ_SelectTier and EJ_SelectInstance and EJ_SetDifficulty and EJ_SetLootFilter) then return false end
    if sel.tier then EJ_SelectTier(sel.tier) end
    if sel.instanceID then EJ_SelectInstance(sel.instanceID) end
    if sel.difficulty then EJ_SetDifficulty(sel.difficulty) end
    EJ_SetLootFilter(sel.classID or 0, sel.specID or 0)
    journalExtras(C_EncounterJournal or {}, sel)
    return true
end

--- The selected tier's instances as { { id, name, worldBoss } }: its raids when `isRaid`, else its
--- dungeons. `worldBoss` is true for the tier's world bosses, the one raid entry the journal shows
--- without a difficulty (EJ_GetInstanceInfo's ninth return, shouldDisplayDifficulty, false).
--- @return table
function Compat.JournalInstances(isRaid)
    local out = {}
    for i = 1, EJ_GetInstanceByIndex and 200 or 0 do
        local id, name = EJ_GetInstanceByIndex(i, isRaid == true)
        if not plainNumber(id) then break end
        local shows
        if isRaid == true and EJ_GetInstanceInfo then shows = select(9, EJ_GetInstanceInfo(id)) end
        out[#out + 1] = { id = id, name = plainString(name), worldBoss = shows == false or nil }
    end
    return out
end

--- An encounter's name (EJ_GetEncounterInfo's first return), or nil for no API, an unknown id or a
--- secret or empty answer.
--- @param encounterID number|nil
--- @return string|nil
function Compat.JournalEncounterName(encounterID)
    if not (plainNumber(encounterID) and EJ_GetEncounterInfo) then return nil end
    local name = plainString((EJ_GetEncounterInfo(encounterID)))
    return name ~= "" and name or nil
end

--- The selected instance's loot under the filters, { { itemID, link, encounterID } }, and how many
--- entries are not loaded yet (no link; EJ_LOOT_DATA_RECIEVED follows). Empty without the API.
--- @return table loot, number pending
function Compat.JournalLoot()
    local ej, out, pending = C_EncounterJournal, {}, 0
    if not (EJ_GetNumLoot and ej and ej.GetLootInfoByIndex) then return out, 0 end
    for i = 1, plainNumber(EJ_GetNumLoot()) or 0 do
        local info = ej.GetLootInfoByIndex(i)
        local link = type(info) == "table" and plainString(info.link)
        if link then out[#out + 1] = { itemID = plainNumber(info.itemID), link = link,
            encounterID = plainNumber(info.encounterID) } else pending = pending + 1 end
    end
    return out, pending
end
