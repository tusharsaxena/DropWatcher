-- tests/test_sim_events.lua — the simulator's event drivers and the world it answers (simulator
-- spec §2): loot lines written from the client's LOOT_ITEM* GlobalStrings and read by the real
-- parser and feed; the invented group answered through NS.Compat (the roster, the situation, the
-- announce channel); inspect replies through the broker's real queue after a seeded random delay;
-- boss pulls and kills with their combat edge and restriction, the ask queued meanwhile and
-- flushed after; a keystone run; your own drops' trade windows read by the trade timer; a
-- simulated completed trade settled by the history's own reader; and the stop that ends what the
-- drivers raised (modules/SimWorld.lua, modules/SimEvents.lua, core/CompatWorld.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function link(id, ilvl)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[Item %d]|h|r"):format(id, ilvl or 0, id)
end

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

-- Item levels per difficulty in the journal the cases seed.
local LEVEL = { [1] = 580, [2] = 590, [23] = 600, [8] = 610, [17] = 590, [14] = 600, [15] = 610, [16] = 620 }

-- Two dungeons of the newest tier, each dropping two rings at every dungeon difficulty, and a raid
-- dropping a ring at every raid difficulty.
local function seedJournal(m)
    local j = m.journal
    j.tiers = { { dungeons = { { id = 101, name = "Ashen Vault" }, { id = 102, name = "Tidewell" } },
        raids = { { id = 201, name = "The Spire" } } } }
    local function add(inst, d, n)
        local id = inst * 1000 + d * 10 + n
        local l = link(id, LEVEL[d])
        m.addItem(l, ring(LEVEL[d]))
        return { itemID = id, link = l, encounterID = 2000 + n }
    end
    for _, inst in ipairs({ 101, 102 }) do
        j.loot[inst] = {}
        for _, d in ipairs({ 1, 2, 23, 8 }) do j.loot[inst][d] = { add(inst, d, 1), add(inst, d, 2) } end
    end
    j.loot[201] = {}
    for _, d in ipairs({ 17, 14, 15, 16 }) do j.loot[201][d] = { add(201, d, 1) } end
end

-- An enabled instance, solo; the player (a mage) wears two 590 rings. `opts` = { situation, kind,
-- size, seed }. A simulation runs with its pool, its group and the group joined.
local function sim(opts)
    opts = opts or {}
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, 590), ring(590))
    m.addItem(link(101, 590), ring(590))
    m.inventory.player[11], m.inventory.player[12] = link(100, 590), link(101, 590)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    if opts.before then opts.before(NS, m) end
    local situation = opts.situation or "dungeon"
    assertTrue(NS.Sim.Start({ scenario = "test", situation = situation, seed = opts.seed or 11 }))
    NS.SimPool.Build({ situation = situation })
    local members = NS.SimRoster.Create({ kind = opts.kind or "party", size = opts.size, seed = opts.seed or 5 })
    NS.SimEvents.Join()
    m.advance(0)
    return NS, m, members
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function drops(NS)
    return NS.LootFeed.Drops("live")
end

local function lastDrop(NS)
    local list = drops(NS)
    return list[#list]
end

local function otherRealm(members)
    for _, mem in ipairs(members) do
        if mem.realm ~= "Testrealm" then return mem end
    end
    return nil
end

local function sameRealm(members)
    for _, mem in ipairs(members) do
        if mem.realm == "Testrealm" then return mem end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- The loot lines (pure)
-- ---------------------------------------------------------------------------------------------

test("sim lines: every LOOT_ITEM* shape is written from its GlobalString and read back by the parser", function()
    local NS, _, m = T.newAddon()
    local E, LP = NS.SimEvents, NS.LootParser
    local l = link(4242, 600)
    for _, kind in ipairs({ "loot", "bonus", "pushed" }) do
        for _, qty in ipairs({ 1, 3 }) do
            local mine = E.WriteLine(m, kind, true, nil, l, qty)
            assertTrue(mine ~= nil, kind .. " self line")
            local loot = LP.Parse(mine)
            assertTrue(loot ~= nil and loot.isSelf, kind .. " self parsed: " .. mine)
            assertEqual(loot.kind, kind); assertEqual(loot.qty, qty); assertEqual(loot.link, l)
            local theirs = E.WriteLine(m, kind, false, "Brakk-Stormhold", l, qty)
            loot = LP.Parse(theirs)
            assertTrue(loot ~= nil and not loot.isSelf, kind .. " other parsed: " .. theirs)
            assertEqual(loot.looterName, "Brakk-Stormhold"); assertEqual(loot.kind, kind); assertEqual(loot.qty, qty)
        end
    end
    assertEqual(E.GlobalFor("bonus", true, true), "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE")
    assertEqual(E.GlobalFor("loot", false, false), "LOOT_ITEM")
end)

test("sim lines: a locale that reorders its arguments is written in its own order", function()
    local NS, _, m = T.newAddon()
    local E = NS.SimEvents
    assertEqual(E.Render("%2$s gets %1$s, 100%%", { "the ring", "Seta" }), "Seta gets the ring, 100%")
    m.LOOT_ITEM = "%2$s : butin pour %1$s."
    local text = E.WriteLine(m, "loot", false, "Seta", link(7, 600), 1)
    assertEqual(text, link(7, 600) .. " : butin pour Seta.")
    local loot = NS.LootParser.Parse(text)
    assertEqual(loot.looterName, "Seta", "the parser reads the locale's order back")
    m.LOOT_ITEM = nil
    assertNil(E.WriteLine(m, "loot", false, "Seta", link(7, 600), 1), "no GlobalString: no line")
end)

test("sim lines: a burst has one to three lines, your own when asked, and a looter from another realm", function()
    local NS = T.newAddon()
    local E, R = NS.SimEvents, NS.SimRoster
    local members = R.Members({ kind = "raid", size = 12, ownRealm = "Testrealm" }, R.Random(3))
    local pool = { { link = "a" }, { link = "b" } }
    for seed = 1, 30 do
        local plan = E.Plan(nil, members, pool, R.Random(seed), nil, "Testrealm")
        assertTrue(#plan >= 1 and #plan <= 3, "1 to 3 lines")
        local cross = false
        for _, line in ipairs(plan) do
            assertTrue(line.qty == 1 or line.qty == 2)
            assertTrue(line.kind == "loot" or line.kind == "bonus")
            if line.looter and line.looter.realm ~= "Testrealm" then cross = true end
        end
        if #plan >= 2 then assertTrue(cross, "a burst of two or more has a looter from another realm") end
    end
    for _, line in ipairs(E.Plan(4, members, pool, R.Random(2), "me", "Testrealm")) do
        assertNil(line.looter, "every line is yours")
    end
    assertEqual(#E.Plan(2, members, {}, R.Random(2)), 0, "an empty pool drops nothing")
    local brakk = members[1]
    assertEqual(E.ChatName(brakk, brakk.realm), brakk.name, "your realm: bare")
    assertEqual(E.ChatName(brakk, "Elsewhere"), brakk.fullName, "another realm: Name-Realm")
end)

-- ---------------------------------------------------------------------------------------------
-- The group and the world, through NS.Compat
-- ---------------------------------------------------------------------------------------------

test("sim world: the roster, the situation and the announce channel read the invented party", function()
    local NS, m, members = sim()
    assertEqual(NS.Roster.Count(), 5, "you and four members")
    for _, mem in ipairs(members) do
        local r = NS.Roster.Get(mem.guid)
        assertTrue(r ~= nil, "member in the roster")
        assertEqual(r.fullName, mem.fullName); assertEqual(r.classFile, mem.classFile); assertEqual(r.unit, mem.unit)
    end
    assertEqual(NS.Situations.Current(), "dungeon")
    assertEqual(NS.Asks.AnnounceChannel(), "PARTY")
    local name = NS.Compat.InstanceInfo()
    assertEqual(name, "Ashen Vault", "the instance the pool came from")
    local real = NS.Sim.Live(NS.Situations.ReadInputs)
    assertFalse(real.inGroup, "a live read sees the real world"); assertFalse(real.inInstance)
    assertEqual(#m.inspect.notified, 0)
end)

test("sim world: in a raid you are raid1 and the members raid2 onward; the channel is RAID", function()
    local NS, _, members = sim({ situation = "raid", kind = "raid", size = 12 })
    assertEqual(NS.Roster.Count(), 13)
    assertEqual(NS.Roster.Player().unit, "raid1")
    assertEqual(members[1].unit, "raid2")
    assertEqual(NS.Situations.Current(), "raid")
    assertEqual(NS.Asks.AnnounceChannel(), "RAID")
end)

test("sim world: the stop puts the real world back", function()
    local NS = sim()
    NS.Sim.Stop()
    assertEqual(NS.Roster.Count(), 1, "solo again")
    assertEqual(NS.Situations.Current(), "solo")
    assertNil(NS.Asks.AnnounceChannel())
end)

-- ---------------------------------------------------------------------------------------------
-- Loot through the real handler
-- ---------------------------------------------------------------------------------------------

test("sim loot: a member's line goes through the parser into the feed, under their GUID", function()
    local NS, m, members = sim({ kind = "raid", size = 12, situation = "raid" })
    local hits = NS.LootParser.Stats().hits
    local away = otherRealm(members)
    local home = sameRealm(members)
    assertEqual(NS.SimEvents.Loot(1, away.fullName), 1)
    m.advance(0)
    assertEqual(NS.LootParser.Stats().hits, hits + 1, "the parser read the line")
    local rec = lastDrop(NS)
    assertTrue(rec.sim, "a simulated drop")
    assertEqual(rec.looter.guid, away.guid, "a looter from another realm resolves")
    assertEqual(rec.situation, "raid")
    assertEqual(NS.SimEvents.Loot(1, home.name), 1)
    m.advance(0)
    assertEqual(lastDrop(NS).looter.guid, home.guid, "a bare name on your realm resolves")
    assertEqual(NS.SimEvents.Loot(1, "Nobody"), 0, "not in the group")
    assertEqual(#(NS.addon.db.global.history.groups or {}), 0, "saved history is never written")
end)

test("sim loot: n random lines, and nothing without a running simulation or a pool", function()
    local NS, m = sim()
    local before = #drops(NS)
    local sent = NS.SimEvents.Loot(3)
    assertEqual(sent, 3)
    m.advance(0)
    assertTrue(#drops(NS) >= before + 1, "the lines became drops (a multiple of one item merges no line)")
    NS.Sim.Stop()
    local n, why = NS.SimEvents.Loot(1)
    assertEqual(n, 0); assertEqual(why, "notRunning")
end)

-- ---------------------------------------------------------------------------------------------
-- Inspect replies through the broker
-- ---------------------------------------------------------------------------------------------

test("sim inspect: a looter is read through the broker's queue after the reply, never the fast path", function()
    local NS, m, members = sim()
    local brakk = members[1]
    NS.SimEvents.Loot(1, brakk.name)
    m.advance(0)
    local rec = lastDrop(NS)
    m.advance(0.1)
    local e = NS.Inspect.Get(brakk.guid)
    assertTrue(e ~= nil and e.status == "pending", "queued and in flight, not cached")
    assertEqual(#m.inspect.notified, 0, "no real inspect")
    m.advance(3)
    e = NS.Inspect.Get(brakk.guid)
    assertEqual(e.status, "fresh", "the reply was read")
    local worn = 0
    for slot, l in pairs(brakk.gear) do
        worn = worn + 1
        assertEqual(e.gear[slot].link, l)
    end
    assertTrue(worn > 0)
    m.advance(1)
    assertTrue(NS.LootFeed.Get(rec.id).them ~= nil, "the looter's verdict, from the kernel")
    assertTrue(NS.SimWorld.PROVIDERS ~= nil)
end)

test("sim inspect: a failing member times out; a member out of range waits and gives up", function()
    local NS, m, members = sim()
    local fail, far = members[1], members[2]
    NS.SimWorld.SetMember(fail.guid, { failing = true })
    NS.SimWorld.SetMember(far.guid, { far = true })
    NS.Inspect.Request(fail.guid, NS.Inspect.PRIORITY.looter)
    NS.Inspect.Request(far.guid, NS.Inspect.PRIORITY.looter)
    m.advance(40)
    assertEqual(NS.Inspect.Get(fail.guid).status, "failed")
    assertEqual(NS.Inspect.Get(far.guid).status, "outOfRange")
    assertFalse(NS.SimWorld.SetMember("Player-0-0", { far = true }), "not a member")
end)

test("sim inspect: the reply delay is the session's seeded random source", function()
    local function firstReply(seed)
        local NS, m, members = sim({ seed = seed })
        NS.Inspect.Request(members[1].guid, NS.Inspect.PRIORITY.looter)
        local t0 = m.GetTime()
        for _ = 1, 40 do
            m.advance(0.05)
            local e = NS.Inspect.Get(members[1].guid)
            if e and e.status == "fresh" then return m.GetTime() - t0 end
        end
        return nil
    end
    local a, b = firstReply(21), firstReply(21)
    assertTrue(a ~= nil, "answered")
    assertEqual(a, b, "the same seed replays the same delay")
end)

-- ---------------------------------------------------------------------------------------------
-- Encounters, combat and restrictions
-- ---------------------------------------------------------------------------------------------

test("sim encounter: a pull raises combat and the lockdown; the ask waits and goes out after the kill", function()
    local NS, m, members = sim()
    local E, brakk = NS.SimEvents, members[1]
    NS.SimEvents.Loot(1, brakk.name)
    m.advance(5)
    local rec = lastDrop(NS)
    local enc = E.Pull()
    assertEqual(enc.id, E.ENCOUNTER_BASE + 1); assertEqual(enc.name, E.BOSSES[1])
    assertEqual(select(2, E.Pull()), "engaged")
    assertTrue(E.Status().combat)
    assertTrue(NS.Restrictions.ActiveSet().encounter, "the Encounter restriction")
    assertTrue(NS.Restrictions.ActiveSet().combat, "the combat edge")
    local state = NS.Asks.Request("ask", brakk.name, rec.id)
    assertEqual(state, "queued", "held during the lockdown")
    assertEqual(printed(m, "[sim] WHISPER"), 0)
    E.Kill()
    m.advance(5)
    assertFalse(E.Status().combat)
    assertNil(NS.Restrictions.ActiveSet().encounter, "lifted")
    assertEqual(printed(m, "[sim] WHISPER to " .. brakk.fullName), 1, "flushed after the kill, printed")
    assertEqual(#m.chatSent, 0, "nothing reached the client")
    assertEqual(select(2, E.Kill()), "notEngaged")
end)

test("sim encounter: loot after a kill joins the boss's group, named by the pull", function()
    local NS, m, members = sim()
    local E = NS.SimEvents
    E.Pull({ name = "Warden Test" })
    E.Kill()
    E.Loot(1, members[2].name)
    m.advance(0)
    local rec = lastDrop(NS)
    assertEqual(rec.group.label, "Warden Test")
    assertEqual(E.Status().kills, 1)
    E.Pull(); E.Kill(false)
    assertEqual(E.Status().kills, 1, "a wipe is not a kill")
end)

test("sim encounter: a keystone run groups its loot and holds the ChallengeMode restriction", function()
    local NS, m, members = sim({ situation = "mythicPlus" })
    local E = NS.SimEvents
    assertEqual(NS.Situations.Current(), "mythicPlus")
    local run = E.RunStart()
    assertTrue(NS.Compat.ChallengeModeActive())
    assertTrue(NS.Restrictions.ActiveSet().challengeMode)
    assertEqual(select(2, E.RunStart()), "inRun")
    E.Loot(1, members[1].name)
    m.advance(0)
    assertEqual(lastDrop(NS).group.label, run.name, "the run's group, named for its dungeon")
    E.RunEnd()
    assertFalse(NS.Compat.ChallengeModeActive())
    assertNil(NS.Restrictions.ActiveSet().challengeMode)
    assertEqual(select(2, E.RunEnd()), "noRun")
end)

test("sim combat: the stop ends a combat edge it raised", function()
    local NS = sim()
    NS.SimEvents.Pull()
    assertTrue(NS.Restrictions.InCombat())
    NS.Sim.Stop()
    assertFalse(NS.Restrictions.InCombat(), "the edge ended with the simulation")
    assertNil(NS.Restrictions.ActiveSet().encounter)
end)

-- ---------------------------------------------------------------------------------------------
-- Your own drops: bags and trade windows
-- ---------------------------------------------------------------------------------------------

test("sim own drops: they land in your bags with a trade window the trade timer counts down", function()
    local NS, m = sim()
    local E, W = NS.SimEvents, NS.SimWorld
    assertEqual(E.Loot(2, "me"), 2)
    m.advance(3)
    local own = {}
    for _, rec in ipairs(drops(NS)) do
        if rec.isMine then own[#own + 1] = rec end
    end
    assertEqual(#own, 2, "both are yours")
    assertEqual(#W.BagItems(), 2)
    local soon = NS.TradeTimer.ForDrop(own[1].id)
    local later = NS.TradeTimer.ForDrop(own[2].id)
    assertTrue(soon ~= nil and later ~= nil, "the timer found both in the bags")
    local t = m.GetTime()
    assertTrue(math.abs(soon.expiresAt - t - (E.ENDING_SOON - 3)) < 1, "the first is ending soon")
    assertTrue(math.abs(later.expiresAt - t - (E.TRADE_WINDOW - 3)) < 1, "the next has the full window")
    m.advance(E.ENDING_SOON + 5)
    NS.TradeTimer.Scan("test")
    assertTrue(NS.TradeTimer.ForDrop(own[1].id).expired, "the window closed")
    assertFalse(NS.TradeTimer.ForDrop(own[2].id).expired)
    assertEqual(#m.chatSent, 0)
end)

test("sim own drops: read at their bag slot from their link, and their tooltip is their link's (DW-80)", function()
    local NS, m = sim()
    NS.SimEvents.Loot(1, "me")
    m.advance(3)
    local rec = lastDrop(NS)
    local e = NS.TradeTimer.ForDrop(rec.id)
    assertTrue(e ~= nil, "matched to its simulated bag item")
    assertEqual(rec.facts.ilvlSource, "current"); assertEqual(rec.facts.qualitySource, "location")
    assertEqual(rec.facts.ilvl, NS.ItemFacts.Get(rec.link).ilvl)
    local b = { link = rec.link, ownDropId = rec.id }
    assertEqual(NS.WindowGroup.SetItemTooltip(m.GameTooltip, b), "bag")
    assertEqual(m.tooltipSets[#m.tooltipSets], "link:" .. rec.link, "a simulated slot shows its link")
end)

test("sim own drops: the scenario sets the window and the ending-soon count", function()
    local NS, m = sim()
    local E = NS.SimEvents
    assertTrue(E.Configure({ window = 600, endingSoonCount = 0 }))
    E.Loot(1, "me")
    m.advance(3)
    local e = NS.TradeTimer.ForDrop(lastDrop(NS).id)
    assertTrue(math.abs(e.expiresAt - m.GetTime() - 597) < 1)
    NS.Sim.Stop()
    assertFalse(E.Configure({}), "no simulation")
    assertEqual(#NS.SimWorld.BagItems(), 0)
end)

-- ---------------------------------------------------------------------------------------------
-- A simulated completed trade
-- ---------------------------------------------------------------------------------------------

local function outcomeOf(NS, rec)
    return NS.History.OutcomeOf(rec.id)
end

test("sim trade: your drop traded away and another's received land in the session's history log", function()
    local NS, m, members = sim()
    local E = NS.SimEvents
    E.Configure({ endingSoonCount = 0 })
    E.Loot(1, "me")
    E.Loot(1, members[2].name)
    m.advance(3)
    local list = drops(NS)
    local mine, theirs
    for _, rec in ipairs(list) do
        if rec.isMine then mine = rec else theirs = rec end
    end
    assertTrue(E.Trade(mine.id))
    assertEqual(outcomeOf(NS, mine), "tradedAway")
    assertEqual(#NS.SimWorld.BagItems(), 0, "the item left your bags")
    assertTrue(E.Trade(theirs.id))
    assertEqual(outcomeOf(NS, theirs), "received")
    assertEqual(E.Status().trades, 2)
    assertEqual(#(NS.addon.db.global.history.groups or {}), 0, "saved history untouched")
    assertTrue(#NS.SimHost.HistoryLog().groups > 0, "the session's log holds them")
    assertEqual(#m.tradeCalls, 0, "no real trade")
end)

test("sim trade: refused for an unknown drop, a real one and an expired own drop", function()
    local realID
    local NS, m = sim({ before = function(NS0, m0)
        m0.addItem(link(555, 600), ring(600))
        realID = NS0.LootFeed.Add(link(555, 600), "Brakk")
        m0.advance(0)
    end })
    local E = NS.SimEvents
    assertEqual(select(2, E.Trade(999)), "noDrop")
    assertEqual(select(2, E.Trade(realID)), "notSim", "a drop the simulation did not make")
    E.Loot(1, "me")
    m.advance(3)
    local mine = lastDrop(NS)
    m.advance(E.ENDING_SOON + 1)
    assertEqual(select(2, E.Trade(mine.id)), "expired")
    assertEqual(outcomeOf(NS, mine) == "tradedAway", false)
end)

test("sim stop: your simulated bag items leave the gear snapshot and the trade timer", function()
    local NS, m = sim()
    NS.SimEvents.Loot(1, "me")
    m.advance(3)
    assertEqual(NS.TradeTimer.LiveCount(), 1)
    NS.Sim.Stop()
    m.advance(3)
    assertEqual(NS.TradeTimer.LiveCount(), 0)
    assertEqual(#NS.SimWorld.BagItems(), 0)
end)
