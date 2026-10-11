-- tests/test_sim_scenario.lua — the simulator's scenarios, timeline and controls (simulator spec
-- §4, §6, §7): the pure verb parser and timeline; `/dw sim` through the real dispatcher (status,
-- usage, the refusals, refused while disabled); the SIM chip, the footer and the diagnostics
-- section; and the end-to-end scenarios: a `key` and a `raid` run headless through the mock,
-- asserting only what the real engine produced (modules/SimScenario.lua, settings/SimVerbs.lua).

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
-- dropping two rings at every raid difficulty.
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
    for _, d in ipairs({ 17, 14, 15, 16 }) do j.loot[201][d] = { add(201, d, 1), add(201, d, 2) } end
end

-- An enabled instance, solo; the player (a mage) wears two 590 rings and the journal is seeded.
local function addon()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, 590), ring(590))
    m.addItem(link(101, 590), ring(590))
    m.inventory.player[11], m.inventory.player[12] = link(100, 590), link(101, 590)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    return NS, m
end

local function slash(NS, line)
    NS.addon:OnSlashCommand(line)
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

local function savedHistory(NS)
    return #(NS.addon.db.global.history.groups or {})
end

-- Advance the clock until the timeline's next step is `kind` (a playing timeline).
local function playUntil(NS, m, kind)
    for _ = 1, 40 do
        local st = NS.SimScenario.Status()
        if st.next == kind then return end
        m.advance(1)
    end
    error("the timeline never reached " .. kind)
end

-- ---------------------------------------------------------------------------------------------
-- Pure: the verb parser and the timeline
-- ---------------------------------------------------------------------------------------------

test("sim verbs: Parse reads every verb and its arguments", function()
    local P = T.newAddon().SimVerbs.Parse
    assertEqual(P("").verb, "status")
    local c = P("start Raid 15")
    assertEqual(c.verb, "start"); assertEqual(c.scenario, "raid"); assertEqual(c.size, 15)
    assertNil(P("start key").size)
    assertEqual(P("start").verb, "usage")
    for _, v in ipairs({ "run", "step", "pull", "kill", "stop" }) do assertEqual(P(v).verb, v) end
    c = P("loot")
    assertEqual(c.verb, "loot"); assertNil(c.n); assertNil(c.who)
    c = P("loot 3 me")
    assertEqual(c.n, 3); assertEqual(c.who, "me")
    c = P("loot Brakk-Stormhold")
    assertNil(c.n); assertEqual(c.who, "Brakk-Stormhold")
    assertEqual(P("loot 0").verb, "usage")
    assertEqual(P("lockdown on").on, true); assertEqual(P("lockdown OFF").on, false)
    assertEqual(P("lockdown maybe").verb, "usage")
    assertEqual(P("trade 12").id, 12); assertEqual(P("trade x").verb, "usage")
    assertEqual(P("dance").verb, "usage")
end)

test("sim timeline: a boss is pull, lockdown, kill, loot, lockdown lifted; a key ends with its completion", function()
    local SC = T.newAddon().SimScenario
    local function kinds(def)
        local out = {}
        for i, step in ipairs(SC.Timeline(def)) do out[i] = step.kind end
        return table.concat(out, ",")
    end
    assertEqual(kinds({ bosses = 1 }), "pull,lockdownOn,kill,loot,lockdownOff")
    assertEqual(kinds({ bosses = 2, keystone = true }),
        "runStart,pull,kill,pull,kill,lockdownOn,runEnd,loot,lockdownOff")
    assertEqual(SC.Timeline({ bosses = 1, burst = 4 })[4].n, 4, "the burst size rides on the loot step")
    assertEqual(#SC.Timeline(nil), 0)
    for _, name in ipairs(SC.NAMES) do
        local def = SC.SCENARIOS[name]
        assertTrue(def ~= nil and #SC.Timeline(def) > 0, name)
    end
end)

-- ---------------------------------------------------------------------------------------------
-- `/dw sim` through the dispatcher
-- ---------------------------------------------------------------------------------------------

test("sim verbs: `/dw sim` prints the status and the usage; the verbs need a running simulation", function()
    local NS, m = addon()
    slash(NS, "sim")
    assertEqual(printed(m, "No simulation is running."), 1)
    assertTrue(printed(m, "sim start <key|dungeon|raid|lfr|delve|world> [size]") >= 1)
    for _, v in ipairs({ "run", "step", "pull", "kill", "loot", "lockdown on", "trade 1", "stop" }) do
        slash(NS, "sim " .. v)
    end
    assertEqual(printed(m, "No simulation is running: start one"), 8, "each verb says none runs")
    slash(NS, "sim start nowhere")
    assertEqual(printed(m, "Unknown scenario."), 1)
    assertFalse(NS.Sim.IsActive())
end)

test("sim verbs: refused while the addon is disabled, like every feature verb", function()
    local NS, m = addon()
    NS.SchemaRuntime.Set("enabled", false)
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim.IsActive())
    assertTrue(printed(m, "is disabled") >= 1)
end)

test("sim start: refused in combat and with test mode on, each with its line", function()
    local NS, m = addon()
    m.inCombat = true
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim.IsActive())
    assertEqual(printed(m, "A simulation cannot start in combat."), 1)
    m.inCombat = false
    NS.SetTestMode(true)
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim.IsActive())
    assertEqual(printed(m, "Turn test mode off before starting a simulation."), 1)
end)

test("sim start: the scenario's pool, group and situation, and the window open", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.Sim.IsActive())
    local st = NS.SimScenario.Status()
    assertTrue(st.ready); assertEqual(st.pos, 0); assertEqual(st.steps, 15)
    assertEqual(NS.Roster.Count(), 5)
    assertEqual(NS.Situations.Current(), "dungeon")
    assertTrue(NS.Window.IsShown(), "the window opened")
    assertEqual(printed(m, "Simulation ready: 4 members"), 1)
    slash(NS, "sim start raid")
    assertEqual(printed(m, "A simulation is already running."), 1)
    slash(NS, "sim")
    assertEqual(printed(m, "Simulating dungeon (Dungeon): 4 members, step 0 of 15"), 1)
end)

test("sim start: a raid takes its size; a party is always four", function()
    local NS = addon()
    slash(NS, "sim start raid 15")
    assertEqual(#NS.SimRoster.Get(), 15)
    assertEqual(NS.Situations.Current(), "raid")
    slash(NS, "sim stop")
    slash(NS, "sim start delve 12")
    assertEqual(#NS.SimRoster.Get(), 4)
    assertEqual(NS.Situations.Current(), "delve")
end)

test("sim step: the timeline waits for the pool, then plays one step at a time", function()
    local NS, m = addon()
    local shown = true   -- the journal's frame is open: the pool waits
    m.EncounterJournal = { IsShown = function() return shown end }
    slash(NS, "sim start dungeon")
    slash(NS, "sim step")
    assertEqual(printed(m, "still setting up its items"), 1)
    shown = false
    m.advance(1)
    assertTrue(NS.SimScenario.Status().ready)
    slash(NS, "sim step")
    assertEqual(printed(m, "Simulation step 1 of 15: pull."), 1)
    assertTrue(NS.SimEvents.Status().encounter ~= nil)
    slash(NS, "sim step")
    assertTrue(NS.Restrictions.ActiveSet().chatLockdown, "the lockdown step")
    slash(NS, "sim pull")
    assertEqual(printed(m, "A simulated boss is already engaged"), 1)
end)

test("sim run: plays every step a few seconds apart, then says it has finished", function()
    local NS, m = addon()
    slash(NS, "sim start world")
    slash(NS, "sim run")
    assertEqual(NS.SimScenario.Status().pos, 1, "the first step at once")
    slash(NS, "sim run")
    assertEqual(printed(m, "The timeline is already playing."), 1)
    m.advance(NS.SimScenario.STEP_DELAY * 5)
    local st = NS.SimScenario.Status()
    assertEqual(st.pos, st.steps); assertFalse(st.playing)
    assertEqual(printed(m, "The simulation's timeline has finished."), 1)
    assertEqual(NS.SimEvents.Status().kills, 1)
    slash(NS, "sim step")
    assertEqual(printed(m, "The simulation's timeline has finished."), 2)
end)

test("sim stop: ends a playing timeline and its timers", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    slash(NS, "sim run")
    slash(NS, "sim stop")
    assertFalse(NS.Sim.IsActive())
    assertNil(NS.SimScenario.Status())
    m.advance(60)
    assertEqual(NS.SimEvents.Status(), nil, "nothing played after the stop")
    assertEqual(#drops(NS), 0)
    assertNil(NS.Restrictions.ActiveSet().encounter)
end)

test("sim stand-down: disabling mid-run stops the timeline; nothing fires afterward", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    slash(NS, "sim run")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Sim.IsActive())
    assertEqual(printed(m, "Simulation stopped: the addon was disabled."), 1)
    local hits = NS.LootParser.Stats().hits
    m.advance(60)
    assertEqual(NS.LootParser.Stats().hits, hits, "no loot line after the stand-down")
end)

-- ---------------------------------------------------------------------------------------------
-- The chip, the footer and the diagnostics section
-- ---------------------------------------------------------------------------------------------

test("sim window: the SIM chip with the scenario tooltip, and the footer says Simulating", function()
    local NS = addon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertFalse(f.simChip:IsShown())
    slash(NS, "sim start raid 10")
    NS.Window.Refresh()
    assertTrue(f.simChip:IsShown()); assertFalse(f.testChip:IsShown())
    local title, scenario = NS.WindowTitleBar.SimTip()
    assertEqual(title, "Simulation"); assertEqual(scenario, "Scenario: raid (Raid)")
    local seg = NS.WindowFooter.Compose(NS.WindowFooter.Read()).situation
    assertEqual(seg.text, "Simulating: Raid · 10 members")
    slash(NS, "sim stop")
    assertFalse(f.simChip:IsShown(), "gone with the simulation")
    seg = NS.WindowFooter.Compose(NS.WindowFooter.Read()).situation
    assertTrue(seg.text:find("Simulating", 1, true) == nil, "the real situation again")
end)

local function diagnostics(NS)
    local lines = {}
    local out = {
        add = function(_, _, fmt, ...)
            local args = { ... }
            for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
            lines[#lines + 1] = fmt:format(unpack(args))
        end,
    }
    for _, sec in ipairs(NS.Diagnostics.Sections()) do
        if sec[1] == "sim" then sec[2](out) end
    end
    return table.concat(lines, "\n")
end

test("sim diagnostics: the section reads the session, the pool, the timeline and the sends", function()
    local NS = addon()
    assertTrue(diagnostics(NS):find("sim: active=false sendsPrinted=0", 1, true) ~= nil)
    slash(NS, "sim start key")
    slash(NS, "sim step")
    local text = diagnostics(NS)
    assertTrue(text:find("sim: active=true scenario=key situation=mythicPlus members=4", 1, true) ~= nil, text)
    assertTrue(text:find("sim: pool size=", 1, true) ~= nil and text:find("source=journal", 1, true) ~= nil)
    assertTrue(text:find("sim: timeline step=1/11 next=pull ready=true playing=false", 1, true) ~= nil, text)
    assertTrue(text:find("sim: sendsPrinted=0", 1, true) ~= nil)
end)

test("sim debug: the SIM tag logs every injected event and every step", function()
    local NS = addon()
    NS.State.debug = true
    slash(NS, "sim start dungeon")
    slash(NS, "sim step")
    local log = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(log:find("[SIM] event ENCOUNTER_START", 1, true) ~= nil, "the injected event")
    assertTrue(log:find("[SIM] timeline step 1/15: pull", 1, true) ~= nil, "the step")
end)

-- ---------------------------------------------------------------------------------------------
-- End to end (spec §7): a key and a raid, through the real engine
-- ---------------------------------------------------------------------------------------------

local function firstWhere(list, fn)
    for _, rec in ipairs(list) do
        if fn(rec) then return rec end
    end
    return nil
end

local function lastWhere(list, fn)
    for i = #list, 1, -1 do
        if fn(list[i]) then return list[i] end
    end
    return nil
end

test("sim e2e key: parsed drops, both verdicts, the ask held in the lockdown and flushed, countdowns, a trade", function()
    local NS, m = addon()
    local hits = NS.LootParser.Stats().hits
    slash(NS, "sim start key")
    assertEqual(NS.Situations.Current(), "mythicPlus")
    slash(NS, "sim run")
    assertTrue(NS.Compat.ChallengeModeActive(), "the run started")
    playUntil(NS, m, "lockdownOff")
    -- The completion's loot burst has landed, the chat lockdown still holds.
    assertTrue(NS.LootParser.Stats().hits > hits, "the written lines went through the parser")
    local member = NS.SimRoster.Get()[1]
    slash(NS, "sim loot 1 " .. member.name)
    slash(NS, "sim loot 1 me")
    m.advance(0.5)
    local theirs = firstWhere(drops(NS), function(r) return not r.isMine end)
    local mine = firstWhere(drops(NS), function(r) return r.isMine end)
    assertTrue(theirs ~= nil and mine ~= nil)
    for _, rec in ipairs(drops(NS)) do assertTrue(rec.sim, "every drop is the simulation's") end
    assertEqual(NS.Asks.Request("ask", theirs.looter.fullName or member.fullName, theirs.id), "queued",
        "held in the lockdown")
    m.advance(0.5)
    assertTrue(NS.Restrictions.ActiveSet().chatLockdown)
    playUntil(NS, m, nil)
    m.advance(5)
    -- The kernel's verdicts: yours on every drop, the looter's after the simulated inspect.
    theirs = NS.LootFeed.Get(theirs.id)
    assertTrue(theirs.me ~= nil, "your verdict")
    assertTrue(theirs.them ~= nil, "the looter's verdict, after the simulated inspect")
    assertTrue(printed(m, "[sim] WHISPER to ") >= 1, "the queued ask flushed once the lockdown lifted")
    -- Your own drop's countdown, read by the trade timer from the simulated bag.
    local timer = NS.TradeTimer.ForDrop(mine.id)
    assertTrue(timer ~= nil and not timer.expired, "your drop counts down")
    -- A simulated trade lands in the session's log, never in saved history.
    slash(NS, "sim trade " .. mine.id)
    assertEqual(NS.History.OutcomeOf(mine.id), "tradedAway")
    assertTrue(#NS.Sim.HistoryLog().groups > 0)
    assertEqual(savedHistory(NS), 0, "DB.global.history untouched")
    assertEqual(#m.chatSent, 0, "the real chat sender was never called")
    assertEqual(#m.inspect.notified, 0, "no real inspect")
    assertEqual(#m.tradeCalls, 0, "no real trade")
    slash(NS, "sim stop")
    assertEqual(#drops(NS), 0)
    assertEqual(savedHistory(NS), 0)
end)

test("sim e2e raid: a large roster, auto-ask after its delay, a trade received, nothing sent or saved", function()
    local NS, m = addon()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    -- The members wear better rings than the heroic drops, so a drop is an upgrade for you and
    -- likely tradeable from them: the auto-ask's case.
    NS.SimScenario.Start("raid", 18, { band = { low = 25, high = 35 } })
    assertEqual(NS.Roster.Count(), 19, "you and eighteen members")
    assertEqual(NS.Asks.AnnounceChannel(), "RAID")
    NS.SimScenario.Run()
    playUntil(NS, m, "lockdownOff")
    assertTrue(#drops(NS) >= 5, "the first boss's burst")
    assertEqual(printed(m, "[sim] WHISPER"), 0, "nothing goes out in the lockdown")
    -- The second boss is pulled before the delay runs out: auto-ask holds through the encounter
    -- and asks once it is over.
    playUntil(NS, m, nil)
    m.advance(NS.AutoAsk.Config().delay + 2)
    local aa = NS.AutoAsk.Stats()
    assertTrue(aa.scheduled >= 1, "auto-ask scheduled")
    assertTrue(aa.sent >= 1, "auto-ask fired after its delay")
    assertTrue(printed(m, "[sim] WHISPER to ") >= 1, "printed, not sent")
    -- The newest such drop: a trade settles the newest open drop of its item from its partner.
    local rec = lastWhere(drops(NS), function(r) return not r.isMine and r.them ~= nil end)
    assertTrue(rec ~= nil, "a member's drop with the looter's verdict")
    slash(NS, "sim trade " .. rec.id)
    assertEqual(NS.History.OutcomeOf(rec.id), "received")
    assertEqual(NS.SimEvents.Status().kills, 2)
    assertEqual(savedHistory(NS), 0, "DB.global.history untouched")
    assertEqual(#m.chatSent, 0, "the real chat sender was never called")
    assertEqual(#m.tradeCalls, 0)
    slash(NS, "sim stop")
    assertEqual(NS.Roster.Count(), 1)
    assertEqual(NS.Situations.Current(), "solo")
end)
