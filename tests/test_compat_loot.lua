-- tests/test_compat_loot.lua — core/CompatLoot.lua, the loot history and group-loot roll reads on
-- NS.Compat (Forever port design §5.1, plan DW-FP13): a drop's whole roll table, plain field by
-- plain field, a secret field dropping that field or that row and never the table (Review Focus 2);
-- the drop key read under either client's name (lootListID on Retail, lootListKey on Forever);
-- LootHistoryDrop unchanged as a view over the roll table; an encounter's drops, its name and the
-- history clock; the open rolls and one roll's item; the simulator's seam wrapping every member; and
-- no other shipped file naming the APIs. Rolls are a both-clients feature, so every case runs on
-- both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LINK = "|Hitem:9::|h[Band]|h"
local BRAKK, LYRA = "Player-1-0000000A", "Player-1-0000000B"

local function fresh(opts)
    local NS, _, m = T.newAddon(opts)
    m.issecretvalue = function(v) return T.isSecret(v) end
    return NS.Compat, m, NS
end

-- An open drop with two rollers, Brakk at Need 87 (the leader) and Lyra not chosen yet.
local function openDrop()
    return {
        itemHyperlink = LINK, playerRollState = 4, isTied = false, allPassed = false,
        startTime = 100, duration = 60,
        currentLeader = { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", roll = 87 },
        rollInfos = {
            { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false,
                state = 0, roll = 87, isWinner = false },
            { playerName = "Lyra", playerGUID = LYRA, playerClass = "PRIEST", isSelf = true,
                state = 4, isWinner = false },
        },
    }
end

-- ---------------------------------------------------------------------------------------------
-- LootHistoryRolls
-- ---------------------------------------------------------------------------------------------

test("compat loot: rolls answer every row with its state and number", function()
    local Compat, m = fresh()
    m.lootHistory["1:2"] = openDrop()
    local r = Compat.LootHistoryRolls(1, 2)
    assertEqual(r.link, LINK); assertEqual(r.key, 2)
    assertEqual(r.startTime, 100); assertEqual(r.duration, 60)
    assertFalse(r.allPassed); assertFalse(r.isTied); assertEqual(r.myState, 4)
    assertEqual(r.leader.name, "Brakk"); assertEqual(r.leader.guid, BRAKK)
    assertEqual(r.leader.classFile, "WARRIOR"); assertEqual(r.leader.roll, 87)
    assertNil(r.winner, "nobody has won it yet")
    assertEqual(#r.rolls, 2)
    local a, b = r.rolls[1], r.rolls[2]
    assertEqual(a.name, "Brakk"); assertEqual(a.guid, BRAKK); assertEqual(a.classFile, "WARRIOR")
    assertFalse(a.isSelf); assertEqual(a.state, 0); assertEqual(a.roll, 87); assertFalse(a.isWinner)
    assertEqual(b.name, "Lyra"); assertTrue(b.isSelf); assertEqual(b.state, 4)
    -- the close: a winner, its row flagged
    local d = m.lootHistory["1:2"]
    d.rollInfos[1].isWinner = true
    d.winner = { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false, roll = 87 }
    r = Compat.LootHistoryRolls(1, 2)
    assertEqual(r.winner.name, "Brakk"); assertEqual(r.winner.roll, 87); assertFalse(r.winner.isSelf)
    assertTrue(r.rolls[1].isWinner)
    -- copied out once: the answer is not Blizzard's table
    assertTrue(r.rolls[1] ~= d.rollInfos[1])
    assertNil(Compat.LootHistoryRolls(1, 3), "no such drop")
    assertNil(Compat.LootHistoryRolls("1", 2), "the ids must be numbers")
    assertNil(Compat.LootHistoryRolls(1, T.secret(2)), "a secret key is never passed on")
end)

test("compat loot: a secret playerName drops the name, keeps the row", function()
    local Compat, m = fresh()
    local d = openDrop()
    d.rollInfos[1].playerName = T.secret("Brakk")
    d.rollInfos[2].playerGUID = T.secret(LYRA)
    d.rollInfos[2].state = T.secret(4)
    d.currentLeader.playerName = T.secret("Brakk")
    d.winner = { playerName = T.secret("Brakk"), playerGUID = BRAKK, isSelf = T.secret(false) }
    d.isTied, d.startTime = T.secret(true), T.secret(100)
    m.lootHistory["1:2"] = d
    local r = Compat.LootHistoryRolls(1, 2)
    assertEqual(#r.rolls, 2, "no row lost")
    assertNil(r.rolls[1].name); assertEqual(r.rolls[1].guid, BRAKK); assertEqual(r.rolls[1].roll, 87)
    assertEqual(r.rolls[2].name, "Lyra"); assertNil(r.rolls[2].guid, "never keyed on a secret")
    assertNil(r.rolls[2].state)
    assertNil(r.leader.name); assertEqual(r.leader.guid, BRAKK)
    assertNil(r.winner.name); assertEqual(r.winner.guid, BRAKK); assertFalse(r.winner.isSelf)
    assertFalse(r.isTied); assertNil(r.startTime)
    -- a secret row drops that row only; a winner with nothing plain is no winner
    d.rollInfos[3] = T.secret({})
    d.rollInfos[4] = "not a row"
    d.winner = { playerName = T.secret("Brakk"), playerGUID = T.secret(BRAKK) }
    d.currentLeader = T.secret({})
    r = Compat.LootHistoryRolls(1, 2)
    assertEqual(#r.rolls, 2)
    assertNil(r.winner); assertNil(r.leader)
    -- a secret link keeps the table, with no link
    d.itemHyperlink = T.secret(LINK)
    r = Compat.LootHistoryRolls(1, 2)
    assertNil(r.link); assertEqual(#r.rolls, 2)
end)

test("compat loot: a secret rollInfos answers rolls = {}", function()
    local Compat, m = fresh()
    local d = openDrop()
    d.rollInfos = T.secret({})
    m.lootHistory["1:2"] = d
    local r = Compat.LootHistoryRolls(1, 2)
    assertEqual(type(r.rolls), "table"); assertEqual(#r.rolls, 0)
    assertEqual(r.link, LINK)
    d.rollInfos = nil
    assertEqual(#Compat.LootHistoryRolls(1, 2).rolls, 0, "an empty list")
    m.lootHistory["1:2"] = T.secret({})
    assertNil(Compat.LootHistoryRolls(1, 2), "a secret drop answers nothing")
    m.lootHistory["1:2"] = "garbage"
    assertNil(Compat.LootHistoryRolls(1, 2))
    m.C_LootHistory = nil
    assertNil(Compat.LootHistoryRolls(1, 2), "no API")
end)

test("compat loot: a nil roll stays nil", function()
    local Compat, m = fresh()
    local d = openDrop()
    d.rollInfos[1].roll = nil
    d.rollInfos[2].roll = T.secret(12)
    d.currentLeader.roll = nil
    m.lootHistory["1:2"] = d
    local r = Compat.LootHistoryRolls(1, 2)
    assertNil(r.rolls[1].roll); assertNil(r.rolls[2].roll); assertNil(r.leader.roll)
    assertEqual(r.rolls[1].state, 0, "the row keeps its state")
end)

test("compat loot: lootListKey is read on Forever-shaped drops", function()
    local Compat, m = fresh()
    -- the mock stamps the running profile's field name (lootListID on Retail, lootListKey on Forever)
    m.lootHistory["5:3"] = openDrop()
    m.lootHistory["5:1"] = openDrop()
    m.lootHistory["5:1"].winner = { playerName = "Brakk", playerGUID = BRAKK }
    local forever = Compat.ClientKey() == "forever"
    local served = m.C_LootHistory.GetSortedInfoForDrop(5, 3)
    assertEqual(served[forever and "lootListKey" or "lootListID"], 3, "the client's own field name")
    assertNil(served[forever and "lootListID" or "lootListKey"], "never the other client's")
    local drops = Compat.LootHistoryDropsFor(5)
    assertEqual(#drops, 2)
    assertEqual(drops[1].key, 1); assertFalse(drops[1].open, "won")
    assertEqual(drops[2].key, 3); assertTrue(drops[2].open); assertEqual(drops[2].link, LINK)
    -- either name read on either client, the key in the table winning over the argument
    m.lootHistory["6:9"] = openDrop(); m.lootHistory["6:9"].lootListKey = 9
    m.lootHistory["6:8"] = openDrop(); m.lootHistory["6:8"].lootListID = 8
    assertEqual(Compat.LootHistoryRolls(6, 9).key, 9)
    assertEqual(Compat.LootHistoryRolls(6, 8).key, 8)
    drops = Compat.LootHistoryDropsFor(6)
    assertEqual(drops[1].key, 8); assertEqual(drops[2].key, 9)
    -- a drop whose key is secret or missing drops from the walk, never the walk
    m.lootHistory["6:9"].lootListKey = T.secret(9)
    m.lootHistory["6:7"] = T.secret({})
    drops = Compat.LootHistoryDropsFor(6)
    assertEqual(#drops, 1); assertEqual(drops[1].key, 8)
    m.lootHistory["6:8"].allPassed = true
    assertFalse(Compat.LootHistoryDropsFor(6)[1].open, "everyone passed: not open")
    assertEqual(#Compat.LootHistoryDropsFor(99), 0, "no drops")
    assertEqual(#Compat.LootHistoryDropsFor("6"), 0, "the id must be a number")
    m.C_LootHistory.GetSortedDropsForEncounter = function() return T.secret({}) end
    assertEqual(#Compat.LootHistoryDropsFor(6), 0)
    m.C_LootHistory = nil
    assertEqual(#Compat.LootHistoryDropsFor(6), 0, "no API")
end)

test("compat loot: LootHistoryDrop is unchanged", function()
    local Compat, m = fresh()
    assertNil(Compat.LootHistoryDrop(1, 2), "no answer")
    m.lootHistory["1:2"] = { itemHyperlink = LINK, winner = { playerName = "Brakk",
        playerGUID = "Player-1-0000000A", playerClass = "WARRIOR", isSelf = false } }
    local d = Compat.LootHistoryDrop(1, 2)
    assertEqual(d.link, LINK); assertEqual(d.name, "Brakk"); assertEqual(d.guid, "Player-1-0000000A")
    assertEqual(d.classFile, "WARRIOR"); assertFalse(d.isSelf)
    m.lootHistory["1:2"].winner = {}
    assertNil(Compat.LootHistoryDrop(1, 2), "rolls still open: nobody won it")
    m.lootHistory["1:2"].winner = nil
    assertNil(Compat.LootHistoryDrop(1, 2))
    assertNil(Compat.LootHistoryDrop("1", 2), "the ids must be numbers")
    m.lootHistory["1:2"] = { itemHyperlink = T.secret(LINK), winner = { playerName = "Brakk" } }
    assertNil(Compat.LootHistoryDrop(1, 2), "a secret link")
    m.lootHistory["1:2"] = { itemHyperlink = LINK, winner = { playerName = T.secret("Brakk"),
        playerGUID = T.secret("Player-1-0000000A"), isSelf = T.secret(true) } }
    assertNil(Compat.LootHistoryDrop(1, 2), "a winner with nothing plain")
    m.lootHistory["1:2"].winner.playerName = "Brakk"
    d = Compat.LootHistoryDrop(1, 2)
    assertEqual(d.name, "Brakk"); assertNil(d.guid); assertFalse(d.isSelf)
    local keys = 0
    for _ in pairs(d) do keys = keys + 1 end
    assertEqual(keys, 3, "today's shape: link, name, isSelf (guid and classFile absent here)")
    m.lootHistory["1:2"] = T.secret({})
    assertNil(Compat.LootHistoryDrop(1, 2))
    m.C_LootHistory = nil
    assertNil(Compat.LootHistoryDrop(1, 2), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- The encounter, the clock
-- ---------------------------------------------------------------------------------------------

test("compat loot: LootHistoryEncounter answers the encounter's name, else nil", function()
    local Compat, m = fresh()
    m.lootEncounters[1] = { encounterID = 2900, encounterName = "Vexie", startTime = 1, duration = 60 }
    assertEqual(Compat.LootHistoryEncounter(2900), "Vexie")
    assertNil(Compat.LootHistoryEncounter(2901), "unknown")
    assertNil(Compat.LootHistoryEncounter("2900"), "the id must be a number")
    m.lootEncounters[1].encounterName = ""
    assertNil(Compat.LootHistoryEncounter(2900), "an empty name")
    m.lootEncounters[1].encounterName = T.secret("Vexie")
    assertNil(Compat.LootHistoryEncounter(2900), "a secret name")
    m.C_LootHistory = nil
    assertNil(Compat.LootHistoryEncounter(2900), "no API")
end)

test("compat loot: LootHistoryEncounters lists the encounter ids", function()
    local Compat, m = fresh()
    m.lootEncounters[1] = { encounterID = 2900, encounterName = "Vexie" }
    m.lootEncounters[2] = { encounterID = T.secret(2901) }
    m.lootEncounters[3] = T.secret({})
    m.lootEncounters[4] = { encounterID = 2902, encounterName = "Trash" }
    local ids = Compat.LootHistoryEncounters()
    assertEqual(#ids, 2); assertEqual(ids[1], 2900); assertEqual(ids[2], 2902)
    m.C_LootHistory.GetAllEncounterInfos = function() return T.secret({}) end
    assertEqual(#Compat.LootHistoryEncounters(), 0)
    m.C_LootHistory = nil
    assertEqual(#Compat.LootHistoryEncounters(), 0, "no API")
end)

test("compat loot: LootHistoryNow answers the history clock, else nil", function()
    local Compat, m = fresh()
    assertNil(Compat.LootHistoryNow(), "no answer")
    m.lootHistoryTime = 160
    assertEqual(Compat.LootHistoryNow(), 160)
    m.lootHistoryTime = T.secret(160)
    assertNil(Compat.LootHistoryNow())
    m.C_LootHistory = nil
    assertNil(Compat.LootHistoryNow(), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- Your own rolls
-- ---------------------------------------------------------------------------------------------

test("compat loot: ActiveLootRolls answers the open roll ids, plain ones only", function()
    local Compat, m = fresh()
    assertEqual(#Compat.ActiveLootRolls(), 0)
    m.activeLootRolls = { 11, T.secret(12), 13, "x" }
    local ids = Compat.ActiveLootRolls()
    assertEqual(#ids, 2); assertEqual(ids[1], 11); assertEqual(ids[2], 13)
    m.activeLootRolls = T.secret({})
    assertEqual(#Compat.ActiveLootRolls(), 0)
    m.GetActiveLootRollIDs = nil
    assertEqual(#Compat.ActiveLootRolls(), 0, "no API")
end)

test("compat loot: LootRollInfo answers bop from bindOnPickUp", function()
    local Compat, m = fresh()
    m.lootRolls[11] = { link = LINK, name = "Band", quality = 4, bop = true, canNeed = true,
        canGreed = true, canTransmog = false }
    local r = Compat.LootRollInfo(11)
    assertEqual(r.link, LINK); assertEqual(r.quality, 4)
    assertTrue(r.bop); assertTrue(r.canNeed); assertTrue(r.canGreed); assertFalse(r.canTransmog)
    m.lootRolls[11].bop, m.lootRolls[11].canNeed = false, false
    r = Compat.LootRollInfo(11)
    assertFalse(r.bop, "bind on equip"); assertFalse(r.canNeed)
    m.lootRolls[11].bop, m.lootRolls[11].quality = T.secret(true), T.secret(4)
    r = Compat.LootRollInfo(11)
    assertNil(r.bop, "a secret flag drops that field"); assertNil(r.quality); assertEqual(r.link, LINK)
    m.lootRolls[11].link = T.secret(LINK)
    assertNil(Compat.LootRollInfo(11), "no plain link: nothing to show")
    assertNil(Compat.LootRollInfo(12), "no such roll")
    assertNil(Compat.LootRollInfo(T.secret(11)), "a secret id is never passed on")
    m.GetLootRollItemInfo, m.GetLootRollItemLink = nil, nil
    assertNil(Compat.LootRollInfo(11), "no API")
end)

test("compat loot: LootRollTimeLeft answers your popup's time left in seconds", function()
    -- RX-02 (rolls UX design §3.4): GetLootRollTimeLeft answers milliseconds; the reader answers
    -- seconds, plain ones only.
    -- red under: no LootRollTimeLeft, or the milliseconds passed on as seconds
    local Compat, m = fresh()
    m.lootRolls[11] = { link = LINK, timeLeft = 42000 }
    assertEqual(Compat.LootRollTimeLeft(11), 42)
    m.lootRolls[11].timeLeft = 0
    assertEqual(Compat.LootRollTimeLeft(11), 0)
    m.lootRolls[11].timeLeft = T.secret(42000)
    assertNil(Compat.LootRollTimeLeft(11), "a secret answer")
    m.lootRolls[11].timeLeft = -5
    assertNil(Compat.LootRollTimeLeft(11), "a negative answer")
    assertNil(Compat.LootRollTimeLeft(12), "no such roll")
    assertNil(Compat.LootRollTimeLeft(T.secret(11)), "a secret id is never passed on")
    assertNil(Compat.LootRollTimeLeft(nil), "no id")
    m.GetLootRollTimeLeft = nil
    assertNil(Compat.LootRollTimeLeft(11), "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- The loot method and the loot window (DW-FP18, design §6)
-- ---------------------------------------------------------------------------------------------

local DOOM = "Player-1-0000000D"

test("loot method: ML unit and name from masterLooterRaidID", function()
    local Compat, m = fresh()
    assertNil(Compat.LootMethod(), "no answer")
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" },
        { guid = DOOM, name = "Doom", realm = "Dock", class = "HUNTER", classFile = "HUNTER" } }, true)
    m.lootMethod = { 2, nil, 3 }
    local lm = Compat.LootMethod()
    assertEqual(lm.method, "master"); assertEqual(lm.mlUnit, "raid3"); assertFalse(lm.isML)
    assertEqual(lm.mlGUID, DOOM, "the master looter's GUID, the ask's whisper target (DW-FP19)")
    if Compat.ClientKey() == "forever" then
        assertEqual(lm.mlName, "Doom Dock", "a Forever two-word name kept whole (Review Focus 4)")
        assertNil(lm.mlRealm)
    else
        assertEqual(lm.mlName, "Doom"); assertEqual(lm.mlRealm, "Dock")
    end
    m.lootMethod = { 2, nil, 1 }
    lm = Compat.LootMethod()
    assertEqual(lm.mlUnit, "raid1"); assertTrue(lm.isML, "raid1 is you")
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    m.lootMethod = { 2, 1, nil }
    lm = Compat.LootMethod()
    assertEqual(lm.mlUnit, "party1"); assertEqual(lm.mlName, "Brakk"); assertFalse(lm.isML)
    m.lootMethod = { 2, 0, nil }
    lm = Compat.LootMethod()
    assertEqual(lm.mlUnit, "player"); assertTrue(lm.isML)
    m.lootMethod = { 3, nil, nil }
    lm = Compat.LootMethod()
    assertEqual(lm.method, "group"); assertNil(lm.mlUnit); assertFalse(lm.isML)
    m.lootMethod = { 2, nil, T.secret(3) }
    lm = Compat.LootMethod()
    assertEqual(lm.method, "master"); assertNil(lm.mlUnit, "a secret id is never read"); assertFalse(lm.isML)
    m.lootMethod = { T.secret(2) }
    assertNil(Compat.LootMethod(), "a secret method answers nothing")
    m.C_PartyInfo.GetLootMethod = nil
    assertNil(Compat.LootMethod(), "no API")
end)

test("loot method: threshold falls back to 4", function()
    local Compat, m = fresh()
    m.lootMethod = { 2, 0, nil }
    m.Constants = { LootConsts = { MasterLootQualityThreshold = 5 }, LootConsts_Camelot = { MasterLootQualityThreshold = 4 } }
    assertEqual(Compat.LootMethod().threshold, 5, "LootConsts first: the runtime key on both clients")
    m.Constants = { LootConsts_Camelot = { MasterLootQualityThreshold = 4 } }
    assertEqual(Compat.LootMethod().threshold, 4, "then LootConsts_Camelot")
    m.Constants = { LootConsts = { MasterLootQualityThreshold = T.secret(3) } }
    local fallback = Compat.ClientKey() == "forever" and 4 or 5
    assertEqual(Compat.LootMethod().threshold, fallback, "a secret is skipped")
    m.Constants = nil
    assertEqual(Compat.LootMethod().threshold, fallback, "4 on Forever, 5 on Retail")
end)

test("loot slots: every slot with its link, quality, lock and source", function()
    local Compat, m = fresh()
    assertEqual(#Compat.LootSlots(), 0, "no loot window")
    m.lootSlots = { { link = LINK, quality = 4, locked = true, source = "Creature-0-1-2-3-4-5" },
        { link = T.secret(LINK), quality = 4, source = T.secret("Creature-0-1-2-3-4-6") },
        { quality = 0 } }
    local slots = Compat.LootSlots()
    assertEqual(#slots, 3)
    local a = slots[1]
    assertEqual(a.slot, 1); assertEqual(a.link, LINK); assertEqual(a.quality, 4); assertTrue(a.locked)
    assertEqual(a.sourceGUID, "Creature-0-1-2-3-4-5")
    assertNil(slots[2].link); assertNil(slots[2].sourceGUID, "never keyed on a secret")
    assertEqual(slots[2].quality, 4); assertFalse(slots[2].locked)
    assertNil(slots[3].link)
    m.GetNumLootItems = nil
    assertEqual(#Compat.LootSlots(), 0, "no API")
end)

-- ---------------------------------------------------------------------------------------------
-- The family's contract
-- ---------------------------------------------------------------------------------------------

local MEMBERS = { "LootHistoryRolls", "LootHistoryDrop", "LootHistoryDropsFor", "LootHistoryEncounter",
    "LootHistoryEncounters", "LootHistoryNow", "ActiveLootRolls", "LootRollInfo", "LootMethod", "LootSlots" }

test("compat loot: no member raises with every API gone", function()
    local Compat, m = fresh()
    m.C_LootHistory, m.GetActiveLootRollIDs, m.GetLootRollItemInfo, m.GetLootRollItemLink = nil, nil, nil, nil
    m.C_PartyInfo, m.GetNumLootItems, m.GetLootSlotLink, m.GetLootSlotInfo, m.GetLootSourceInfo = nil, nil, nil, nil, nil
    for _, name in ipairs(MEMBERS) do
        for _, arg in ipairs({ 1, LINK, false, {} }) do
            assertTrue(pcall(Compat[name], arg, arg), name .. " raised")
        end
    end
end)

test("compat loot: the simulator's seam wraps every loot member (the TOC order)", function()
    local _, _, NS = fresh()
    local wrapped = {}
    for _, key in ipairs(NS.SimSeam:Keys()) do wrapped[key] = true end
    for _, name in ipairs(MEMBERS) do assertTrue(wrapped[name], name .. " is not wrapped") end
end)

local LOOT_APIS = { "C_LootHistory", "GetActiveLootRollIDs", "GetLootRollItemInfo", "GetLootRollItemLink",
    "GetLootMethod", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo" }

test("compat loot: no other shipped file names a loot roll API in code", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if rel ~= "core/CompatLoot.lua" then
            local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
            local src = fh:read("*a"); fh:close()
            local code = src:gsub("%-%-[^\r\n]*", ""):gsub('"[^"\r\n]*"', '""')
            for _, api in ipairs(LOOT_APIS) do
                -- red under: modules/LootFeed.lua calling C_LootHistory.GetSortedInfoForDrop itself
                assertNil(code:find("[^%w_.]" .. api), rel .. " names " .. api .. " outside core/CompatLoot.lua")
            end
        end
    end
end)

-- M4 review: a winner the client names but that reads nothing plain (secret) is still a winner,
-- so the drop is closed, never left open for Pending to hold forever.
test("compat loot: a secret winner counts as closed", function()
    local Compat, m = fresh()
    local d = openDrop()
    m.lootHistory["1:2"] = d
    assertFalse(Compat.LootHistoryRolls(1, 2).won, "nobody has won it yet")
    assertTrue(Compat.LootHistoryDropsFor(1)[1].open)
    d.winner = { playerName = T.secret("Brakk"), playerGUID = T.secret(BRAKK) }
    local r = Compat.LootHistoryRolls(1, 2)
    assertNil(r.winner, "nothing plain to name"); assertTrue(r.won, "but it was won")
    assertFalse(Compat.LootHistoryDropsFor(1)[1].open, "closed, not open")
    d.winner = T.secret({})
    assertTrue(Compat.LootHistoryRolls(1, 2).won)
    assertFalse(Compat.LootHistoryDropsFor(1)[1].open)
    d.winner = { playerName = "Brakk", playerGUID = BRAKK }
    assertTrue(Compat.LootHistoryRolls(1, 2).won)
end)
