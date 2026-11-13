-- tests/test_pending_ml.lua — modules/PendingML.lua, the master-loot kind of the pending store
-- (Forever port design §6, plan DW-FP18): under master loot, an Epic (the threshold's quality) in
-- the loot window you opened is held as one `ml` item awaiting the master looter, keyed by its
-- source GUID and item ID so a re-opened corpse adds nothing; a receipt for that item inside
-- 600 s assigns it and the drop carries `askedML`; you as the master looter see nothing pending;
-- an item expires at 900 s; and group loot holds nothing from the loot window. Master loot is a
-- both-clients feature (design §11.2: on Retail it is Guild Master Loot), so every case runs on
-- both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local BRAKK, DOOM = "Player-1-0000000A", "Player-1-0000000D"
local BOSS = "Creature-0-1-2-3-2900-0000AAAA"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, quality)
    return { name = "Item", quality = quality or 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled addon in a raid in a raid instance under master loot, Doom Dock (raid3) the master
-- looter: the player wears two 600 rings.
local function raid()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "raid"
        m.instance = { name = "Nerub-ar Palace", difficultyID = 14 }
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(DOOM, "Doom", "Dock", "HUNTER") }, true)
    NS.Roster.Refresh("test")
    m.lootMethod = { 2, nil, 3 }
    return NS, m, NS.Pending
end

-- The boss corpse's loot window: one ring at the client's master-loot threshold (Epic on Forever,
-- Legendary on Retail; locked: the master looter's to give) and one a quality under it.
local TOP = T.forever and 4 or 5

local function corpse(m, epicID)
    m.addItem(link(epicID), ring(620, TOP))
    m.addItem(link(500), ring(620, TOP - 1))
    m.lootSlots = { { link = link(epicID), quality = TOP, locked = true, source = BOSS },
        { link = link(500), quality = TOP - 1, source = BOSS } }
end

local function mlItems(P)
    local out = {}
    for _, item in ipairs(P.All()) do
        if item.kind == "ml" then out[#out + 1] = item end
    end
    return out
end

test("ml pending: an Epic slot under master loot opens one ml item; re-opening the corpse does not duplicate it", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_READY", false)
    m.__fire("LOOT_OPENED", false, false)
    local items = mlItems(P)
    assertEqual(#items, 1, "the top slot only: the other is under the threshold")
    local item = items[1]
    assertEqual(item.state, "awaiting"); assertEqual(item.itemID, 300); assertEqual(item.link, link(300))
    assertEqual(item.key, BOSS .. ":300")
    assertEqual(item.me.verdict, "upgrade")
    assertEqual(item.ml.unit, "raid3")
    assertEqual(item.ml.name, T.forever and "Doom Dock" or "Doom", "the master looter, whole (Review Focus 4)")
    m.__fire("LOOT_CLOSED")
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 1, "re-opening the corpse adds nothing")
end)

test("ml pending: a receipt for that item assigns it and the drop carries askedML", function()
    local NS, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    local item = mlItems(P)[1]
    item.askedML = true   -- DW-FP19's ask; the store hands it on
    local seen = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.PENDING_CHANGED, function(_, id, cause)
        seen[#seen + 1] = tostring(id) .. ":" .. tostring(cause)
    end)
    m.advance(120)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(300) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    assertEqual(#mlItems(P), 0, "assigned: the item closed")
    assertEqual(table.concat(seen, ","), item.id .. ":closed")
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.looter.guid, BRAKK)
    assertTrue(rec.askedML, "the drop carries askedML"); assertEqual(rec.pendingKey, item.id)
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 0, "an assigned item does not come back from the corpse")
end)

test("ml pending: a receipt after 600 s, or for another item, assigns nothing", function()
    local NS, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    m.addItem(link(301), ring(620))
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(301) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    assertEqual(#mlItems(P), 1, "another item")
    m.advance(601)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(300) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    assertEqual(#mlItems(P), 1, "past 600 s")
    assertNil(NS.LootFeed.Drops()[2].pendingKey)
end)

test("ml pending: a cleared loot history keeps the ml item; re-opening the corpse still adds nothing", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    m.__fire("LOOT_HISTORY_CLEAR_HISTORY")
    m.__fire("LOOT_OPENED", false, false)
    local items = mlItems(P)
    assertEqual(#items, 1, "the history clear frees roll keys only")
    m.advance(901)
    assertEqual(items[1].state, "expired", "its expiry still runs")
end)

test("ml pending: you as master looter see no pending item", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.lootMethod = { 2, nil, 1 }   -- raid1: you
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 0)
    m.lootMethod = { 2, nil, 3 }
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 1)
    m.lootMethod = { 2, nil, 1 }
    m.__fire("PARTY_LOOT_METHOD_CHANGED")
    assertEqual(#mlItems(P), 0, "made master looter: nothing stays pending")
end)

test("ml pending: expires at 900 s", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    local item = mlItems(P)[1]
    m.advance(899)
    assertEqual(#mlItems(P), 1)
    m.advance(2)
    assertEqual(#mlItems(P), 0); assertEqual(item.state, "expired")
end)

test("ml pending: leaving the group or the instance expires it", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    m.instance = { name = "Dornogal", difficultyID = 0 }
    m.__context.inInstance, m.__context.instanceType = false, "none"
    m.__fire("PLAYER_ENTERING_WORLD", false, false)
    assertEqual(#mlItems(P), 0, "left the instance")
    m.instance = { name = "Nerub-ar Palace", difficultyID = 14 }
    m.__context.inInstance, m.__context.instanceType = true, "raid"
    m.__fire("PLAYER_ENTERING_WORLD", false, false)
    corpse(m, 301)
    m.lootSlots[1].source = "Creature-0-1-2-3-2901-0000BBBB"   -- the next boss
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 1)
    m.setGroup({})
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(#mlItems(P), 0, "left the group")
end)

test("ml pending: under group loot nothing is pending from the loot window", function()
    local _, m, P = raid()
    corpse(m, 300)
    m.lootMethod = { 3, nil, nil }
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 0)
    m.lootMethod = { 5, nil, nil }   -- personal loot (Retail)
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 0)
    m.lootMethod = nil
    m.__fire("LOOT_OPENED", false, false)
    assertEqual(#mlItems(P), 0, "no loot method read: nothing")
end)

test("ml pending: standing down drops the items and their timers", function()
    local NS, m, P = raid()
    corpse(m, 300)
    m.__fire("LOOT_OPENED", false, false)
    NS.addon:OnSlashCommand("disable")
    assertEqual(#P.All(), 0)
    for _, e in ipairs({ "LOOT_READY", "LOOT_OPENED", "PARTY_LOOT_METHOD_CHANGED" }) do
        assertEqual(m.__fire(e), 0, e .. " unregistered")
    end
    assertEqual(#m.__timers(), 0, "no live timer")
end)
