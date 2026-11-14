-- tests/test_pending.lua — modules/Pending.lua, the store of drops seen but not yet assigned
-- (Forever port design §5.2, plan DW-FP14): an open group-loot roll opens one item, a changed roll
-- table sends PendingChanged once, a winner hands the final table to the feed (rec.roll), a chat
-- receipt that came first takes the roll by merge, two identical items on one encounter stay apart
-- (Review Focus 1), a reload mid-roll rebuilds one item whose winner makes one drop (Review Focus
-- 3), everyone passing lingers 60 s and never reaches the feed, the feed's pre-looter gates keep a
-- drop out (spec §11.1), the 1 s ticker lives only while a roll is open, and the stand-down takes
-- every event and timer down. Rolls are a both-clients feature, so every case runs on both kit
-- profiles (the mock names the drop key per client).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK, LYRA = "Player-1-0000000A", "Player-2-0000000B"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, quality)
    return { name = "Item", quality = quality or 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled addon in a party in a Heroic dungeon: the player wears two 600 rings; Brakk and Lyra
-- are in the group. `seed(m)` runs on the mock before the load (a reload's surviving client state).
local function party(seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
        if seed then seed(m) end
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    NS.Roster.Refresh("test")
    return NS, m, NS.Pending
end

-- An open drop of item `id`: Brakk at Need 87 (the leader), Lyra not chosen yet.
local function openDrop(id)
    return {
        itemHyperlink = link(id), playerRollState = 4, isTied = false, allPassed = false,
        startTime = 100, duration = 60,
        currentLeader = { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", roll = 87 },
        rollInfos = {
            { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false,
                state = 0, roll = 87, isWinner = false },
            { playerName = "Lyra", playerGUID = LYRA, playerClass = "PRIEST", isSelf = false,
                state = 4, isWinner = false },
        },
    }
end

-- Brakk wins `drop` with his Need 87.
local function brakkWins(drop)
    drop.winner = { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false, roll = 87 }
    drop.rollInfos[1].isWinner = true
end

-- Every PendingChanged, as "id:cause", in order.
local function listen(NS)
    local seen = {}
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.PENDING_CHANGED, function(_, id, cause)
        seen[#seen + 1] = tostring(id) .. ":" .. tostring(cause)
    end)
    return seen
end

local function tickers(m)
    local n = 0
    for _, t in ipairs(m.__timers) do
        if t.ticker and not t.stopped then n = n + 1 end
    end
    return n
end

local function only(P)
    local all = P.All()
    assertEqual(#all, 1, "one pending item")
    return all[1]
end

-- ---------------------------------------------------------------------------------------------
-- Open, update, resolve
-- ---------------------------------------------------------------------------------------------

test("pending: an UPDATE_ENCOUNTER with an open drop opens one roll item", function()
    local NS, m, P = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local item = only(P)
    assertEqual(item.kind, "roll"); assertEqual(item.key, "2900:1"); assertEqual(item.state, "open")
    assertEqual(item.link, link(300)); assertEqual(item.itemID, 300)
    assertEqual(item.me.verdict, "upgrade", "judged for you: 620 against your 600 ring")
    assertEqual(#item.roll.rolls, 2); assertEqual(item.roll.leader.name, "Brakk")
    assertTrue(P.Get(item.id) == item)
    assertEqual(table.concat(seen, ","), item.id .. ":open")
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(#P.All(), 1, "the same drop is not opened twice")
    assertEqual(#seen, 1)
    assertEqual(#NS.LootFeed.Drops(), 0, "an open roll is not a feed record")
end)

test("pending: Count answers each store's size with no list built; a missing test store is empty", function()
    local NS, m, P = party()
    assertEqual(P.Count(), 0, "no store yet"); assertEqual(P.Count("test"), 0)
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(P.Count(), 1); assertEqual(P.Count("live"), 1)
    assertEqual(P.Count("test"), 0, "the test store is apart")
    assertEqual(#P.All("test"), 0, "no test store yet reads as empty, never as the live one")
    P.AddTest({ link = link(300) })
    assertEqual(P.Count("test"), 1); assertEqual(P.Count(), 1)
    assertEqual(P.Count("test"), #P.All("test")); assertEqual(P.Count(), #P.All())
    P.ClearTest()
    assertEqual(P.Count("test"), 0)
    assertNil(NS.State.pendingTest)
end)

test("pending: each UPDATE_DROP that changes the table sends PENDING_CHANGED rolls once", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    local drop = openDrop(300)
    m.lootHistory["2900:1"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local seen = listen(NS)
    local item = only(P)
    drop.rollInfos[2].state, drop.rollInfos[2].roll = 3, 40
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(table.concat(seen, ","), item.id .. ":rolls")
    assertEqual(item.roll.rolls[2].state, 3); assertEqual(item.roll.rolls[2].roll, 40)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#seen, 1, "an unchanged table sends nothing")
end)

test("pending: a winner hands the final table to the feed; the drop has rec.roll and the pending item closes", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    local drop = openDrop(300)
    m.lootHistory["2900:1"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local id = only(P).id
    local seen = listen(NS)
    brakkWins(drop)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#P.All(), 0); assertNil(P.Get(id))
    assertEqual(table.concat(seen, ","), id .. ":closed")
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1, "one drop")
    local rec = drops[1]
    assertEqual(rec.source, "history"); assertEqual(rec.looter.guid, BRAKK)
    assertEqual(rec.roll.winner.name, "Brakk"); assertEqual(rec.roll.winner.roll, 87)
    assertEqual(#rec.roll.rolls, 2); assertEqual(rec.pendingKey, id)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#NS.LootFeed.Drops(), 1, "taken once")
    assertEqual(#P.All(), 0, "a won drop never reopens")
end)

test("pending: a chat receipt that arrived first gets the roll attached by merge", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    local drop = openDrop(300)
    m.lootHistory["2900:1"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(300) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.source, "chat"); assertNil(rec.roll)
    brakkWins(drop)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#NS.LootFeed.Drops(), 1, "merged, not a second drop")
    assertTrue(rec.sources.history ~= nil)
    assertEqual(rec.roll.winner.name, "Brakk")
    assertEqual(#P.All(), 0)
end)

-- Review Focus 1: two copies of one item on one boss are two drops, each with its own table, its
-- own pending item and its own roll popup (joined by item ID, oldest unclaimed first).
test("pending: two identical items on one encounter stay two items with their own tables", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    local first, second = openDrop(300), openDrop(300)
    m.lootHistory["2900:1"], m.lootHistory["2900:2"] = first, second
    m.lootRolls[11], m.lootRolls[12] = { link = link(300), quality = 4 }, { link = link(300), quality = 4 }
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    local all = P.All()
    assertEqual(#all, 2, "two items")
    local a, b = all[1], all[2]
    assertEqual(a.key, "2900:1"); assertEqual(b.key, "2900:2")
    assertFalse(a.roll == b.roll, "each its own table")
    assertEqual(a.rollID, 11, "the oldest unclaimed takes the first popup"); assertEqual(b.rollID, 12)
    assertTrue(P.ForRoll(12) == b)
    local seen = listen(NS)
    second.rollInfos[2].state, second.rollInfos[2].roll = 0, 95
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 2)
    assertEqual(table.concat(seen, ","), b.id .. ":rolls", "only the second changed")
    assertEqual(a.roll.rolls[2].state, 4)
    brakkWins(first)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#P.All(), 1); assertTrue(P.All()[1] == b, "the second stays open")
    second.winner = { playerName = "Lyra", playerGUID = LYRA, playerClass = "PRIEST", roll = 95 }
    second.rollInfos[2].isWinner = true
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 2)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 2, "two drops")
    assertEqual(drops[1].roll.winner.name, "Brakk"); assertEqual(drops[1].pendingKey, a.id)
    assertEqual(drops[2].roll.winner.name, "Lyra"); assertEqual(drops[2].pendingKey, b.id)
    m.__fire("CANCEL_LOOT_ROLL", 12)
    assertNil(P.ForRoll(12))
end)

-- Review Focus 3: after a /reload the open roll comes back from the client, once, and its winner
-- makes exactly one drop with its table.
test("pending: reload mid-roll rebuilds one item, and its winner makes exactly one drop", function()
    local drop = openDrop(300)
    local NS, m, P = party(function(m)
        m.lootHistory["2900:1"] = drop
        m.lootEncounters = { { encounterID = 2900, encounterName = "Speaker Brokk", startTime = 90, duration = 0 } }
        m.activeLootRolls = { 11 }
        m.lootRolls[11] = { link = link(300), quality = 4 }
    end)
    m.addItem(link(300), ring(620))
    m.__fire("PLAYER_ENTERING_WORLD", false, true)
    local item = only(P)
    assertEqual(item.key, "2900:1"); assertEqual(item.rollID, 11, "your own roll is claimed again")
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("PLAYER_ENTERING_WORLD", false, false)
    assertEqual(#P.All(), 1, "not duplicated")
    brakkWins(drop)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1, "exactly one drop")
    assertEqual(drops[1].roll.winner.name, "Brakk")
    assertEqual(#P.All(), 0)
end)

-- ---------------------------------------------------------------------------------------------
-- No winner, the gate, the ticker, the stand-down
-- ---------------------------------------------------------------------------------------------

test("pending: all passed closes after 60 s with no feed record", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    local drop = openDrop(300)
    m.lootHistory["2900:1"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local item = only(P)
    local seen = listen(NS)
    drop.allPassed, drop.currentLeader = true, nil
    drop.rollInfos[1].state, drop.rollInfos[1].roll = 5, nil
    drop.rollInfos[2].state = 5
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(item.state, "allPassed")
    assertEqual(table.concat(seen, ","), item.id .. ":rolls")
    m.advance(59)
    assertEqual(#P.All(), 1, "still shown")
    m.advance(2)
    assertEqual(#P.All(), 0)
    assertEqual(table.concat(seen, ","), item.id .. ":rolls," .. item.id .. ":closed")
    assertEqual(#NS.LootFeed.Drops(), 0, "nothing goes to the feed")
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(#P.All(), 0, "it does not come back")
end)

test("pending: a drop below the quality gate is not pending", function()
    local NS, m, P = party()
    NS.addon.db.profile.feed.quality.fixed = 3   -- Rare: WoW Forever's default is Uncommon (RX-01)
    m.addItem(link(300), ring(590, 2))   -- an Uncommon side ring: under Rare, and no upgrade
    m.lootHistory["2900:1"] = openDrop(300)
    local seen = listen(NS)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(#P.All(), 0)
    assertEqual(#seen, 0)
    m.addItem(link(301), ring(620, 2))   -- an Uncommon upgrade: the override lets it through
    m.lootHistory["2900:2"] = openDrop(301)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(only(P).itemID, 301)
    assertEqual(#NS.LootFeed.Drops(), 0)
end)

-- RX-04 (rolls UX design §3.5, Review Focus 3): Rolling now admits a rolled lockbox as a Lockbox;
-- a rolled reagent is pending only with Everything else that is rolled on turned on, and its won
-- drop reaches the feed as an Item, its chat line first or not.
-- red under: Pending's gate not telling the filter the item is rolled on
local function lockbox() return { name = "Ornate Bronze Lockbox", quality = 2, ilvl = 20, equipLoc = "", classID = 15,
    subClassID = 0, bindType = 0, stats = {} } end
local function reagent() return { name = "Linen Cloth", quality = 2, ilvl = 5, equipLoc = "", classID = 7,
    subClassID = 5, bindType = 0, stats = {} } end

test("pending: a rolled lockbox is pending as a Lockbox; a reagent only with the catch-all on", function()
    local NS, m, P = party()
    assertTrue(NS.SchemaRuntime.Set("feed.quality.fixed", 2))
    m.addItem(link(400), lockbox())
    m.tooltips.hyperlink[link(400)] = { lines = { { type = 0, leftText = "Locked" } } }
    m.lootHistory["2900:1"] = openDrop(400)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local item = only(P)
    assertEqual(item.me.verdict, "lockbox"); assertNil(item.me.ilvlDelta)
    m.addItem(link(401), reagent())
    m.lootHistory["2900:2"] = openDrop(401)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(#P.All(), 1, "a reagent: Everything else is off by default")
    assertTrue(NS.SchemaRuntime.Set("feed.categories.other", true))
    m.addItem(link(402), reagent())
    local drop = openDrop(402)
    m.lootHistory["2900:3"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(#P.All(), 2, "the catch-all on: the reagent is pending")
    brakkWins(drop)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 3)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1, "the won reagent is a drop"); assertEqual(drops[1].me.verdict, "item")
end)

test("pending: a rolled reagent's chat line first is shown once its roll merges in", function()
    local NS, m = party()
    assertTrue(NS.SchemaRuntime.Set("feed.quality.fixed", 2))
    assertTrue(NS.SchemaRuntime.Set("feed.categories.other", true))
    m.addItem(link(402), reagent())
    local drop = openDrop(402)
    m.lootHistory["2900:1"] = drop
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(402) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    assertEqual(#NS.LootFeed.Drops(), 0, "a chat line alone: not rolled on as far as the feed knows")
    brakkWins(drop)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1, "merged and shown"); assertEqual(drops[1].me.verdict, "item")
end)

test("pending: the ticker stops when no roll is open", function()
    local _, m, P = party()
    m.addItem(link(300), ring(620))
    m.lootHistoryTime = 100
    m.lootHistory["2900:1"] = openDrop(300)
    assertEqual(tickers(m), 0, "no roll, no ticker")
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(tickers(m), 1, "one 1 s ticker while a roll is open")
    local item = only(P)
    m.advance(1)
    assertEqual(item.state, "open", "inside its duration")
    m.lootHistoryTime = 161
    m.advance(1)
    assertEqual(item.state, "expired", "the ticker closes a roll past startTime + duration")
    assertEqual(tickers(m), 0, "no open roll: the ticker stopped")
    m.advance(61)
    assertEqual(#P.All(), 0)
end)

test("pending: standing down unregisters every event and stops the ticker", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.lootEncounters = { { encounterID = 2900, encounterName = "Speaker Brokk" } }
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(tickers(m), 1)
    NS.addon:OnSlashCommand("disable")
    assertEqual(tickers(m), 0, "the ticker stopped")
    for _, e in ipairs({ "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY",
        "START_LOOT_ROLL", "CANCEL_LOOT_ROLL" }) do
        assertEqual(m.__fire(e, 2900, 1), 0, e .. " unregistered")
    end
    assertEqual(#m.__timers(), 0, "no live timer")
    NS.addon:OnSlashCommand("enable")
    assertEqual(#P.All(), 1, "the stand-up rebuilds the open roll")
    assertEqual(tickers(m), 1, "and its ticker")
end)

-- ---------------------------------------------------------------------------------------------
-- The M4 review's fixes
-- ---------------------------------------------------------------------------------------------

test("pending: a history clear during an item load never makes a second item", function()
    local _, m, P = party()
    m.addItem(link(300), ring(620, 4))
    m.items[link(300)].loadsNeeded = 1
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(#P.All(), 0, "still loading")
    m.__fire("LOOT_HISTORY_CLEAR_HISTORY")
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.advance(1)
    assertEqual(#P.All(), 1, "one item, not two")
end)

test("pending: a closed roll lets its popup go, so a later copy never claims it", function()
    local _, m, P = party()
    m.addItem(link(300), ring(620))
    local first = openDrop(300)
    m.lootHistory["2900:1"] = first
    m.lootRolls[11] = { link = link(300), quality = 4 }
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    assertEqual(only(P).rollID, 11)
    first.allPassed = true
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    m.advance(61)
    assertEqual(#P.All(), 0)
    m.lootHistory["2901:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2901)
    assertNil(only(P).rollID, "rollID 11 was released when its roll closed")
    assertNil(P.ForRoll(11))
end)

test("pending: a history clear detaches open items, so a reused key never resolves the wrong drop", function()
    local NS, m, P = party()
    m.addItem(link(300), ring(620)); m.addItem(link(301), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local old = only(P)
    m.__fire("LOOT_HISTORY_CLEAR_HISTORY")
    local reused = openDrop(301)   -- the key comes back for another drop, already won
    brakkWins(reused)
    m.lootHistory["2900:1"] = reused
    m.advance(1)
    assertEqual(old.state, "expired", "its own drop is gone")
    for _, rec in ipairs(NS.LootFeed.Drops()) do
        assertFalse(rec.pendingKey == old.id, "the old item never took the new drop")
    end
end)

test("pending: your verdict is judged again on a gear change", function()
    local NS, m, P = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local item = only(P)
    assertEqual(item.me.verdict, "upgrade")
    m.addItem(link(102), ring(640)); m.addItem(link(103), ring(640))
    m.inventory.player[11], m.inventory.player[12] = link(102), link(103)
    m.__fire("PLAYER_EQUIPMENT_CHANGED")
    m.advance(1)
    assertEqual(item.me.verdict, "downgrade")
    assertEqual(seen[#seen], item.id .. ":verdict")
end)

test("pending: a pending score is judged again on the score retry", function()
    local NS, m, P = party()
    local answer = "pending"
    NS.Scoring = { Scorer = function() return function() return answer end end }
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:1"] = openDrop(300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local item = only(P)
    assertTrue(NS.FeedRecords.HasReason(item.me, "scorePending"), "the scorer is not ready")
    local seen = listen(NS)
    answer = 12
    m.advance(NS.LootFeed.SCORE_RETRY)
    assertFalse(NS.FeedRecords.HasReason(item.me, "scorePending"), "re-scored")
    assertEqual(table.concat(seen, ","), item.id .. ":verdict")
    m.advance(NS.LootFeed.SCORE_RETRY * 10)
    assertEqual(#seen, 1, "a ready score retries no more")
    NS.Scoring = nil
end)
