-- tests/test_sim_core.lua — the simulator's core (simulator spec §1, §2, §5): the answer seam every
-- NS.Compat member goes through (core/SimSeam.lua), its guarded members (nothing sent, no real
-- inspect, no real trade), the session (modules/Sim.lua): the refusals, test mode's exclusion, the
-- event delivery through the registered handlers, the simulated restrictions, the session-only
-- history log, the automatic stop, the stand-down, and a stop that cleans up everything it made.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

-- An enabled instance, solo and out of an instance; the player wears two 600 rings.
local function solo()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.INVTYPE_FINGER = "Finger"
    return NS, m, NS.Sim
end

-- Brakk in the client's group: the stand-in for the simulated roster the later items invent.
local function withBrakk(NS, m)
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
end

local function drop(NS, m, id, looter)
    m.addItem(link(id), ring(610))
    local dropID = NS.LootFeed.Add(link(id), looter)
    m.advance(0)
    return dropID
end

-- A drop the simulator invented: made while Fire delivers (Sim.IsDelivering), as its loot lines are.
local function simDrop(NS, m, id, looter)
    NS.Sim.delivering = true
    local ok, dropID = pcall(drop, NS, m, id, looter)
    NS.Sim.delivering = nil
    assert(ok, dropID)
    return dropID
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------------------------

test("sim seam: every Compat member that answers for the client is wrapped; the pure ones are not", function()
    local NS = T.newAddon()
    local keys = {}
    for _, key in ipairs(NS.Sim.SeamKeys()) do keys[key] = true end
    for _, key in ipairs({ "ChatSender", "NotifyInspect", "InitiateTrade", "InChatMessagingLockdown",
        "IsRestrictionActive", "TradeTimeRemaining", "InventoryItemLink", "GetItemInfo", "TradePartnerName" }) do
        assertTrue(keys[key], key .. " goes through the seam")
    end
    for _, key in ipairs({ "IsSecret", "CanAccess", "IsSafeKey", "FormatToPattern", "ReadTooltipLine" }) do
        assertNil(keys[key], key .. " is pure")
    end
end)

test("sim seam: a provider answers only while a simulation runs; Live reads the client again", function()
    local NS, m, Sim = solo()
    m.chatLockdown = false
    Sim.SetProvider("InventoryItemLink", function(live, unit, slot)
        if unit == "raid7" then return link(777) end
        return live(unit, slot)
    end)
    assertNil(NS.Compat.InventoryItemLink("raid7", 1), "no simulation: the client answers")
    assertTrue(Sim.Start({ scenario = "test" }))
    assertEqual(NS.Compat.InventoryItemLink("raid7", 1), link(777), "the provider answers")
    assertEqual(NS.Compat.InventoryItemLink("player", 11), link(100), "what it does not invent is the client's")
    assertNil(Sim.Live(function() return NS.Compat.InventoryItemLink("raid7", 1) end), "a live read skips it")
    Sim.Stop()
    assertNil(NS.Compat.InventoryItemLink("raid7", 1), "stopped: the client answers again")
    Sim.SetProvider("InventoryItemLink", nil)
end)

test("sim seam: the sender prints [sim] with the channel and the target, and sends nothing", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    -- red under: drop GUARDED.ChatSender (core/SimSeam.lua), and the client's sender is handed out
    NS.Compat.ChatSender()("Need it?", "WHISPER", nil, "Brakk-Testrealm")
    NS.Compat.ChatSender()("Free ring!", "RAID")
    assertEqual(#m.chatSent, 0, "nothing reached the client")
    assertEqual(printed(m, "[sim] WHISPER to Brakk-Testrealm: Need it?"), 1)
    assertEqual(printed(m, "[sim] RAID: Free ring!"), 1)
    assertEqual(Sim.Status().sends, 2)
    -- A provider never gets the client's sender: its fallback is the guarded one.
    Sim.SetProvider("ChatSender", function(fallback) return fallback() end)
    NS.Compat.ChatSender()("Again", "PARTY")
    assertEqual(#m.chatSent, 0)
    Sim.SetProvider("ChatSender", nil)
    Sim.Stop()
    NS.Compat.ChatSender()("Real", "PARTY")
    assertEqual(#m.chatSent, 1, "stopped, the client's sender is back")
end)

test("sim seam: an ask goes through the real messaging edge and is printed, never whispered", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    withBrakk(NS, m)
    local id = simDrop(NS, m, 300, "Brakk")
    local state = NS.Asks.Request("ask", "Brakk", id)
    assertEqual(state, "sent", "the edge ran its whole pipeline")
    assertEqual(#m.chatSent, 0)
    assertEqual(printed(m, "[sim] WHISPER to Brakk-Testrealm: Hi Brakk"), 1)
end)

test("sim seam: no real inspect and no real trade while a simulation runs", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    local C = NS.Compat
    assertTrue(C.NotifyInspect("party1")); assertTrue(C.ClearInspectPlayer())
    assertEqual(#m.inspect.notified, 0); assertEqual(m.inspect.cleared, 0)
    assertTrue(C.PickupBagItem(0, 1)); assertTrue(C.DropItemOnUnit("party1"))
    assertTrue(C.InitiateTrade("party2")); assertTrue(C.ClearCursor())
    assertEqual(#m.tradeCalls, 0, "nothing reached the client"); assertNil(m.cursor)
    assertEqual(printed(m, "[sim] Would hand the item to party1."), 1)
    assertEqual(printed(m, "[sim] Would open a trade with party2."), 1)
    Sim.Stop()
    C.NotifyInspect("party1")
    assertEqual(#m.inspect.notified, 1, "stopped, the client's inspect is back")
end)

-- ---------------------------------------------------------------------------------------------
-- Start: the refusals
-- ---------------------------------------------------------------------------------------------

local REFUSALS = {
    { "while stood down", function(NS) NS.addon:OnSlashCommand("disable") end, "is disabled" },
    { "while test mode is on", function(NS) NS.SetTestMode(true) end, "Turn test mode off" },
    { "in combat", function(_, m) m.inCombat = true end, "cannot start in combat" },
    { "inside an instance", function(_, m) m.__context.inInstance, m.__context.instanceType = true, "party" end,
      "cannot start inside an instance" },
    { "in a real group", function(NS, m) withBrakk(NS, m) end, "cannot start in a group" },
}

for _, case in ipairs(REFUSALS) do
    test("sim start: refused " .. case[1] .. ", and it says which", function()
        local NS, m, Sim = solo()
        case[2](NS, m)
        m.prints = {}
        local ok, why = Sim.Start({ scenario = "test" })
        assertFalse(ok); assertFalse(Sim.IsActive()); assertNil(NS.State.sim)
        assertTrue(why:find(case[3], 1, true) ~= nil, why)
        assertEqual(printed(m, case[3]), 1, "the line is printed")
    end)
end

test("sim start: a second start is refused; test mode is refused while one runs", function()
    local NS, m, Sim = solo()
    assertTrue(Sim.Start({ scenario = "key", situation = "mythicPlus" }))
    assertEqual(printed(m, "Simulation started (key)"), 1)
    assertTrue(Sim.IsActive()); assertTrue(NS.State.sim.sim, "the session carries sim = true")
    assertFalse((Sim.Start({ scenario = "raid" })), "one at a time")
    -- red under: drop the NS.Sim.active line from testModeRefusal (core/DropWatcher.lua)
    assertFalse(NS.SetTestMode(true)); assertFalse(NS.State.testMode)
    assertEqual(printed(m, "Test mode is not available while a simulation runs."), 1)
    assertEqual(Sim.Status().scenario, "key"); assertEqual(Sim.Status().situation, "mythicPlus")
end)

-- ---------------------------------------------------------------------------------------------
-- Events, timers and restrictions
-- ---------------------------------------------------------------------------------------------

test("sim fire: an event reaches the handlers its registration calls, with its payload", function()
    local NS, _, Sim = solo()
    assertEqual(Sim.Fire("ENCOUNTER_START", 2900, "Sim Boss", 16, 20), 0, "no simulation: nothing")
    Sim.Start({ scenario = "test" })
    local rows = 0
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if row[1] == "ENCOUNTER_START" then rows = rows + 1 end
    end
    assertEqual(Sim.Fire("ENCOUNTER_START", 2900, "Sim Boss", 16, 20), rows, "every declared handler")
    assertEqual(NS.LootFeed.Stats().encounter, "Sim Boss", "the feed's own handler took it")
    assertEqual(Sim.Status().events, 1)
end)

test("sim restrictions: Encounter and the lockdown are answered by the client seam and stop the sends", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    assertTrue(Sim.SetRestriction("Encounter", true))
    assertFalse(Sim.SetRestriction("Encounter", true), "already on")
    assertFalse(Sim.SetRestriction("NoSuchType", true))
    assertTrue(NS.Compat.IsRestrictionActive(m.Enum.AddOnRestrictionType.Encounter))
    assertEqual(NS.Restrictions.ActiveReason(), "encounter")
    assertFalse(NS.Restrictions.CanSendChat())
    assertTrue(Sim.SetRestriction("Encounter", false))
    assertNil(NS.Restrictions.ActiveReason())
    assertTrue(Sim.SetLockdown(true))
    assertTrue(NS.Compat.InChatMessagingLockdown()); assertEqual(NS.Restrictions.ActiveReason(), "chatLockdown")
    assertFalse(m.chatLockdown, "the client's own lockdown was never touched")
end)

test("sim timers: run while the simulation does, and never after its stop", function()
    local _, m, Sim = solo()
    assertNil(Sim.After(1, function() end), "no simulation: no timer")
    Sim.Start({ scenario = "test" })
    local ran = 0
    Sim.After(1, function() ran = ran + 1 end)
    Sim.After(5, function() ran = ran + 10 end)
    m.advance(2)
    assertEqual(ran, 1)
    Sim.Stop()
    m.advance(10)
    assertEqual(ran, 1, "the stop canceled the other")
end)

-- ---------------------------------------------------------------------------------------------
-- History: the session-only log
-- ---------------------------------------------------------------------------------------------

test("sim history: drops go to the session log, never to DropWatcherDB.global.history", function()
    local NS, m, Sim = solo()
    local real = drop(NS, m, 200, nil)
    assertEqual(#NS.History.Groups(), 1, "a real drop before the simulation is recorded")
    local stored = NS.addon.db.global.history
    local storedDrops = #stored.groups[1].drops
    Sim.Start({ scenario = "test" })
    assertEqual(#NS.History.Groups(), 0, "the History tab shows the simulation's log")
    local id = simDrop(NS, m, 300, nil)
    assertTrue(NS.LootFeed.Get(id).sim, "the feed's drop carries sim = true")
    assertNil(NS.LootFeed.Get(real).sim)
    local groups = NS.History.Groups()
    assertEqual(#groups, 1); assertEqual(#groups[1].drops, 1)
    assertTrue(groups[1].drops[1].sim, "the entry carries sim = true")
    -- red under: History's DropAdded writing H.Store() instead of H.Log() (modules/History.lua)
    assertEqual(#stored.groups, 1); assertEqual(#stored.groups[1].drops, storedDrops, "saved history untouched")
    assertTrue(NS.History.EntryOf(id) ~= nil)
    Sim.Stop()
    assertNil(NS.History.EntryOf(id), "the stop let the log go")
    assertEqual(#NS.History.Groups(), 1, "the tab reads the account's log again")
    assertEqual(NS.History.Groups()[1].drops[1].itemID, 200)
end)

test("sim history: a real drop while a simulation runs is real: saved, and it survives the stop", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    local stored = NS.addon.db.global.history
    -- red under: newRecord stamping `sim = NS.Sim.active` (modules/LootFeed.lua), or DropAdded
    -- writing H.Log() (modules/History.lua): the real drop goes to the session log and is lost
    local id = drop(NS, m, 300, nil)
    assertNil(NS.LootFeed.Get(id).sim, "a real loot line is not the simulation's")
    assertEqual(NS.LootFeed.Get(id).situation, "solo", "its situation is the real one")
    assertEqual(#stored.groups, 1, "it is saved")
    assertEqual(stored.groups[1].drops[1].itemID, 300)
    Sim.Stop()
    assertTrue(NS.LootFeed.Get(id) ~= nil, "the stop leaves it in the feed")
    assertEqual(#stored.groups, 1); assertTrue(NS.History.EntryOf(id) ~= nil, "and in the history")
end)

test("sim history: a real trade while a simulation runs settles against the saved history", function()
    local NS, m, Sim = solo()
    withBrakk(NS, m)
    local real = drop(NS, m, 200, "Brakk")
    m.setGroup({})
    NS.Roster.Refresh("test")
    assertTrue(Sim.Start({ scenario = "test" }))
    m.units.NPC = { name = "Brakk" }
    m.__fire("TRADE_SHOW")
    m.tradeItems.target, m.tradeItems.player = { link(200) }, {}
    m.__fire("TRADE_TARGET_ITEM_CHANGED", 1)
    m.__fire("TRADE_ACCEPT_UPDATE", 0, 1)
    m.__fire("TRADE_CLOSED")
    -- red under: settle() matching against H.Log(), the simulation's log (modules/History.lua)
    m.__fire("UI_INFO_MESSAGE", m.LE_GAME_ERR_TRADE_COMPLETE, m.ERR_TRADE_COMPLETE)
    assertEqual(NS.History.OutcomeOf(real), "received")
    Sim.Stop()
end)

-- ---------------------------------------------------------------------------------------------
-- Isolation: a handler or a stop step that raises
-- ---------------------------------------------------------------------------------------------

test("sim fire: a handler that raises never unwinds into the driver; the later handlers run", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    table.insert(NS.FEATURE_EVENTS, 1, { "ENCOUNTER_START", "OnSimTestBoom" })
    NS.addon.OnSimTestBoom = function() error("boom") end
    -- red under: deliver() calling the handlers without pcall (modules/Sim.lua)
    local ok, n = pcall(Sim.Fire, "ENCOUNTER_START", 2900, "Sim Boss", 16, 20)
    table.remove(NS.FEATURE_EVENTS, 1)
    NS.addon.OnSimTestBoom = nil
    assertTrue(ok, "the driver goes on"); assertTrue(n > 1)
    assertTrue(NS.LootFeed.Stats().encounter ~= nil, "the later handlers ran")
    assertFalse(Sim.IsDelivering(), "the delivery ended")
    Sim.Stop()
    assertEqual(#m.chatSent, 0)
end)

test("sim stop: a step that raises never skips the rest of the cleanup", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    Sim.MarkGUID(BRAKK)
    withBrakk(NS, m)
    local id = simDrop(NS, m, 301, "Brakk")
    local log = Sim.HistoryLog()
    m.setGroup({})
    NS.State.situation = "mythicPlus"
    local remove = NS.LootFeed.RemoveWhere
    NS.LootFeed.RemoveWhere = function() error("boom") end
    -- red under: cleanEngine running its steps without pcall (modules/Sim.lua)
    local ok = pcall(Sim.Stop)
    NS.LootFeed.RemoveWhere = remove
    assertTrue(ok, "the stop finished"); assertFalse(Sim.IsActive())
    assertNil(NS.Inspect.Get(BRAKK), "the inspect entries went")
    assertEqual(#log.groups, 0, "the log was let go"); assertNil(NS.History.EntryOf(id))
    assertEqual(NS.State.situation, "solo", "the situation was read again")
end)

-- ---------------------------------------------------------------------------------------------
-- Stop cleans everything
-- ---------------------------------------------------------------------------------------------

test("sim stop: its drops, groups, inspect entries, restrictions and lockdown go; real drops stay", function()
    local NS, m, Sim = solo()
    local real = drop(NS, m, 200, nil)
    Sim.Start({ scenario = "test" })
    Sim.MarkGUID(BRAKK)
    withBrakk(NS, m)
    Sim.Fire("ENCOUNTER_START", 2900, "Sim Boss", 16, 20)
    local mine, theirs = simDrop(NS, m, 300, nil), simDrop(NS, m, 301, "Brakk")
    assertTrue(NS.Inspect.Get(BRAKK) ~= nil, "the looter's inspect was asked for")
    Sim.SetRestriction("Encounter", true)
    Sim.SetLockdown(true)
    m.setGroup({})
    assertTrue(Sim.Stop())
    assertFalse(Sim.IsActive()); assertNil(NS.State.sim)
    assertNil(NS.LootFeed.Get(mine)); assertNil(NS.LootFeed.Get(theirs))
    assertTrue(NS.LootFeed.Get(real) ~= nil, "a real drop stays")
    assertEqual(#NS.LootFeed.Drops(), 1); assertEqual(#NS.LootFeed.Groups(), 1, "the simulation's group went")
    assertNil(NS.LootFeed.Stats().encounter, "the encounter context went")
    -- red under: drop the NS.Inspect.Forget loop from cleanEngine (modules/Sim.lua)
    assertNil(NS.Inspect.Get(BRAKK), "its member's inspect entry went")
    assertNil(NS.Restrictions.ActiveReason(), "its restriction and lockdown were lifted")
    assertFalse(NS.Sim.IsSimGUID(BRAKK))
    assertEqual(printed(m, "Simulation stopped."), 1)
    assertFalse(Sim.Stop(), "nothing left to stop")
end)

test("sim stop: a queued ask is canceled before the lift, so it never goes out", function()
    local NS, m, Sim = solo()
    local seen = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.ASK_STATE_CHANGED, function(_, _, state, _, _, reason)
        seen[#seen + 1] = state .. ":" .. tostring(reason)
    end)
    Sim.Start({ scenario = "test" })
    withBrakk(NS, m)
    local id = simDrop(NS, m, 300, "Brakk")
    Sim.SetRestriction("Encounter", true)
    assertEqual((NS.Asks.Request("ask", "Brakk", id)), "queued")
    -- red under: cancel the queued asks after cleanEngine (modules/Sim.lua Stop): the lifted
    -- restriction flushes the queue through the client's sender
    Sim.Stop()
    m.advance(5)
    assertEqual(#m.chatSent, 0, "nothing reached the client")
    assertEqual(printed(m, "[sim] WHISPER"), 0, "and nothing was even printed")
    assertEqual(NS.Asks.Stats().queued, 0)
    assertEqual(seen[#seen], "ready:simStop")
end)

test("sim stop: the situation is classified from the real client again", function()
    local NS, _, Sim = solo()
    Sim.Start({ scenario = "test" })
    NS.State.situation = "mythicPlus"   -- what a simulated situation would have left
    Sim.Stop()
    assertEqual(NS.State.situation, "solo")
end)

-- ---------------------------------------------------------------------------------------------
-- The automatic stop and the stand-down
-- ---------------------------------------------------------------------------------------------

test("sim auto-stop: joining a real group ends the simulation", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    m.__fire("PLAYER_ENTERING_WORLD")
    assertTrue(Sim.IsActive(), "nothing changed in the real world")
    withBrakk(NS, m)
    m.__fire("GROUP_ROSTER_UPDATE")
    assertFalse(Sim.IsActive())
    assertEqual(printed(m, "Simulation stopped: you joined a group."), 1)
end)

test("sim auto-stop: entering an instance ends the simulation", function()
    local _, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.__fire("ZONE_CHANGED_NEW_AREA")
    assertFalse(Sim.IsActive())
    assertEqual(printed(m, "Simulation stopped: you entered an instance."), 1)
end)

test("sim stand-down: disabling the addon stops the simulation and leaves no timer", function()
    local NS, m, Sim = solo()
    Sim.Start({ scenario = "test" })
    Sim.After(30, function() end)
    simDrop(NS, m, 300, nil)
    NS.addon:OnSlashCommand("disable")
    assertFalse(Sim.IsActive()); assertNil(NS.State.sim)
    assertEqual(printed(m, "Simulation stopped: the addon was disabled."), 1)
    assertEqual(#m.__timers(), 0, "no live timer")
    assertEqual(#NS.LootFeed.Drops(), 0, "its drop went with it")
    assertEqual(Sim.Fire("ENCOUNTER_START", 1, "x"), 0)
end)
