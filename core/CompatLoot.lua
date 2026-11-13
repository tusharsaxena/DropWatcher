local _, NS = ...
-- core/CompatLoot.lua — the loot history and group-loot roll reads (Forever port design §5.1, plan
-- DW-FP13): a drop's whole roll table, an encounter's drops and its name, the history clock, your
-- open rolls and one roll's item, published on NS.Compat like the rest of the compat family, split
-- out of core/Compat.lua to keep it under its cap. LootHistoryDrop (the feed's won drop) lives here
-- as a view over LootHistoryRolls, so the history has one call path. Both clients have the same
-- C_LootHistory surface but one field name: a drop table's key is `lootListID` on Retail and
-- `lootListKey` on Forever (R2 §2.2), so every read of it takes either name.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises. C_LootHistory's getters take only plain numbers (SecretArguments = AllowedWhenUntainted,
-- R2 §7), so every id is checked plain before it is passed on. The client's tables are copied out
-- once, field by field: a secret field drops that field, a secret row drops that row, and neither
-- ever drops the table (Review Focus 2). A GUID is kept only when it is a safe key.

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

-- A plain true is true; anything else (false, nil, a secret) is false.
local function isTrue(v)
    return not Compat.IsSecret(v) and v == true
end

-- A plain table, or nil.
local function plainTable(v)
    if Compat.IsSecret(v) or type(v) ~= "table" then return nil end
    return v
end

-- A GUID kept only as a safe key.
local function plainGUID(v)
    if not (Compat.IsSafeKey(v) and type(v) == "string") then return nil end
    return v
end

-- Whether a drop names a winner at all: a secret or half-filled winner still means the roll is
-- over (M4 review), even when nothing of it reads plain.
local function hasWinner(v)
    return Compat.IsSecret(v) or v ~= nil
end

-- A drop table's key under either client's name (Retail lootListID, Forever lootListKey).
local function dropKey(drop)
    return plainNumber(drop.lootListID) or plainNumber(drop.lootListKey)
end

-- A player of a roll (the leader, the winner): { name, guid, classFile, isSelf, roll }, or nil
-- when it names nobody plain.
local function rollPlayer(p)
    p = plainTable(p)
    if not p then return nil end
    local out = { name = plainString(p.playerName), guid = plainGUID(p.playerGUID),
        classFile = plainString(p.playerClass), isSelf = isTrue(p.isSelf), roll = plainNumber(p.roll) }
    if not (out.name or out.guid) then return nil end
    return out
end

-- One rollInfos row: { name, guid, classFile, isSelf, state, roll, isWinner }; nil for a secret or
-- malformed row. A secret field inside it drops that field only.
local function rollRow(r)
    r = plainTable(r)
    if not r then return nil end
    return { name = plainString(r.playerName), guid = plainGUID(r.playerGUID),
        classFile = plainString(r.playerClass), isSelf = isTrue(r.isSelf), state = plainNumber(r.state),
        roll = plainNumber(r.roll), isWinner = isTrue(r.isWinner) }
end

local function rollRows(list)
    local out = {}
    list = plainTable(list)
    if not list then return out end
    for _, r in ipairs(list) do
        local row = rollRow(r)
        if row then out[#out + 1] = row end
    end
    return out
end

-- C_LootHistory, or nil when the API (or the one getter) is absent.
local function history(getter)
    local api = C_LootHistory
    if not (api and api[getter]) then return nil end
    return api
end

--- A group-loot drop's roll table from C_LootHistory.GetSortedInfoForDrop, every field plain:
--- { link, key, startTime, duration, allPassed, isTied, myState, won, leader, winner, rolls }, where
--- leader and winner are { name, guid, classFile, isSelf, roll } or nil (nobody plain, or nobody
--- yet), and rolls is { { name, guid, classFile, isSelf, state, roll, isWinner } } (the states are
--- Enum.EncounterLootDropRollState's plain numbers 0-5; a nil roll stays nil). `won` is true once the
--- client names a winner, even one that reads nothing plain (then `winner` is nil). Nil for a non-plain
--- id, a secret or malformed answer, or with no API.
--- @param encounterID number
--- @param key number
--- @return table|nil
function Compat.LootHistoryRolls(encounterID, key)
    local api = history("GetSortedInfoForDrop")
    if not (api and plainNumber(encounterID) and plainNumber(key)) then return nil end
    local d = plainTable(api.GetSortedInfoForDrop(encounterID, key))
    if not d then return nil end
    return {
        link = plainString(d.itemHyperlink), key = dropKey(d) or key,
        startTime = plainNumber(d.startTime), duration = plainNumber(d.duration),
        allPassed = isTrue(d.allPassed), isTied = isTrue(d.isTied), myState = plainNumber(d.playerRollState),
        won = hasWinner(d.winner),
        leader = rollPlayer(d.currentLeader), winner = rollPlayer(d.winner), rolls = rollRows(d.rollInfos),
    }
end

--- A group-loot drop that has a winner: { link, name, guid, classFile, isSelf }, every field plain
--- (a view over LootHistoryRolls). Nil while nobody has won it (rolls still open, or everyone
--- passed), for a secret or malformed answer, or with no API.
--- @param encounterID number
--- @param key number
--- @return table|nil
function Compat.LootHistoryDrop(encounterID, key)
    local r = Compat.LootHistoryRolls(encounterID, key)
    local w = r and r.winner
    if not (w and r.link) then return nil end
    return { link = r.link, name = w.name, guid = w.guid, classFile = w.classFile, isSelf = w.isSelf }
end

--- An encounter's drops from C_LootHistory.GetSortedDropsForEncounter, in the client's order:
--- { { key, link, open } }, open while no winner is named (a secret one counts) and not everyone
--- passed. A drop with no plain
--- key is left out; empty for a non-plain id, a secret answer, or with no API.
--- @param encounterID number
--- @return table
function Compat.LootHistoryDropsFor(encounterID)
    local out, api = {}, history("GetSortedDropsForEncounter")
    if not (api and plainNumber(encounterID)) then return out end
    local list = plainTable(api.GetSortedDropsForEncounter(encounterID))
    for _, raw in ipairs(list or {}) do
        local d = plainTable(raw)
        local key = d and dropKey(d)
        if key then
            out[#out + 1] = { key = key, link = plainString(d.itemHyperlink),
                open = not (hasWinner(d.winner) or isTrue(d.allPassed)) }
        end
    end
    return out
end

--- The ids of the encounters the loot history holds (C_LootHistory.GetAllEncounterInfos), in its
--- order; a secret or malformed entry is left out. Empty for a secret answer or with no API.
--- @return number[]
function Compat.LootHistoryEncounters()
    local out, api = {}, history("GetAllEncounterInfos")
    if not api then return out end
    for _, raw in ipairs(plainTable(api.GetAllEncounterInfos()) or {}) do
        local e = plainTable(raw)
        local id = e and plainNumber(e.encounterID)
        if id then out[#out + 1] = id end
    end
    return out
end

--- An encounter's name (C_LootHistory.GetInfoForEncounter's encounterName), or nil: a non-plain
--- id, an unknown encounter, an empty or secret name, or no API. Trash and open-world ids are
--- opaque (R2 §6), so this name is the one way to label them.
--- @param encounterID number
--- @return string|nil
function Compat.LootHistoryEncounter(encounterID)
    local api = history("GetInfoForEncounter")
    if not (api and plainNumber(encounterID)) then return nil end
    local e = plainTable(api.GetInfoForEncounter(encounterID))
    local name = e and plainString(e.encounterName)
    if name == "" then return nil end
    return name
end

--- The loot history's clock (C_LootHistory.GetLootHistoryTime, the one startTime is on), or nil.
--- @return number|nil
function Compat.LootHistoryNow()
    local api = history("GetLootHistoryTime")
    if not api then return nil end
    return plainNumber(api.GetLootHistoryTime())
end

--- Your open group-loot roll ids (GetActiveLootRollIDs), plain ones only; empty with no API.
--- @return number[]
function Compat.ActiveLootRolls()
    local out = {}
    if not GetActiveLootRollIDs then return out end
    for _, id in ipairs(plainTable(GetActiveLootRollIDs()) or {}) do
        if plainNumber(id) then out[#out + 1] = id end
    end
    return out
end

-- A plain boolean, or nil.
local function plainBool(v)
    if Compat.IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

--- One of your open rolls' item (GetLootRollItemLink, GetLootRollItemInfo): { link, bop, canNeed,
--- canGreed, canTransmog, quality }, bop from bindOnPickUp; a secret field drops that field. Nil for
--- a non-plain id, no plain link, or with no API.
--- @param rollID number
--- @return table|nil
function Compat.LootRollInfo(rollID)
    if not (GetLootRollItemLink and GetLootRollItemInfo and plainNumber(rollID)) then return nil end
    local link = plainString(GetLootRollItemLink(rollID))
    if not link then return nil end
    local _, _, _, quality, bop, canNeed, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)
    return { link = link, quality = plainNumber(quality), bop = plainBool(bop), canNeed = plainBool(canNeed),
        canGreed = plainBool(canGreed), canTransmog = plainBool(canTransmog) }
end
