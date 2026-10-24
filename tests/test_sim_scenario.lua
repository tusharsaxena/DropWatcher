-- tests/test_sim_scenario.lua — the simulator's scenarios, timeline and controls (simulator spec
-- §4, §6, §7): the pure verb parser and timeline; `/dw sim` through the real dispatcher (status,
-- usage, the refusals, refused while disabled); the SIMULATION text, the footer and the diagnostics
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

test("sim verbs: DropWatcher's five host verbs on the descriptor, each parsing its arguments", function()
    local V = T.newAddon().SimVerbs
    local names = {}
    for verb in pairs(V.VERBS) do names[#names + 1] = verb end
    table.sort(names)
    -- red under: a generic verb (start, run, step, ...) kept in SimVerbs (the library owns them, C.7)
    assertEqual(table.concat(names, ","), "kill,lockdown,loot,pull,trade")
    local function P(line)
        local w = {}
        for x in line:gmatch("%S+") do w[#w + 1] = x end
        return V.VERBS[w[1]].parse(w)
    end
    assertTrue(P("pull") ~= nil); assertTrue(P("kill") ~= nil)
    local c = P("loot")
    assertNil(c.n); assertNil(c.who)
    c = P("loot 3 me")
    assertEqual(c.n, 3); assertEqual(c.who, "me")
    c = P("loot Brakk-Stormhold")
    assertNil(c.n); assertEqual(c.who, "Brakk-Stormhold")
    assertNil(P("loot 0")); assertNil(P("loot 1.5"))
    assertEqual(P("lockdown on").on, true); assertEqual(P("lockdown OFF").on, false)
    assertNil(P("lockdown maybe"))
    assertEqual(P("trade 12").id, 12); assertNil(P("trade x"))
    for _, spec in pairs(V.VERBS) do assertNil(spec.free, "every host verb needs the session") end
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

test("sim verbs: `/dw sim` through RunVerb prints the status and the usage and opens the panel", function()
    local NS, m = addon()
    slash(NS, "sim")
    -- The library's status and usage (LibKa0s-Sim-1.0 RunVerb), then DropWatcher's five verbs.
    assertEqual(printed(m, "Simulation: idle. Scenarios: key, dungeon, raid, lfr, delve, world."), 1)
    assertEqual(printed(m, "/dw sim start <scenario> [size]: start a simulation."), 1)
    for _, line in ipairs({ "/dw sim pull: ", "/dw sim kill: ", "/dw sim loot [n] [player|me]: ",
        "/dw sim lockdown on|off: ", "/dw sim trade <drop id>: " }) do
        assertEqual(printed(m, line), 1, line)
    end
    assertTrue(NS.Sim:IsPanelShown(), "the bare form opens the step panel")
    NS.Sim:HidePanel()
end)

test("sim verbs: every verb but the free ones needs a running simulation; an unknown word prints the usage", function()
    local NS, m = addon()
    for _, v in ipairs({ "run", "step", "pull", "kill", "loot", "lockdown on", "trade 1", "stop", "pause",
        "resume", "restart" }) do
        slash(NS, "sim " .. v)
    end
    -- DropWatcher's words for the library's notRunning (d.L NOT_RUNNING), host verbs included.
    assertEqual(printed(m, "No simulation is running: start one with /dw sim start <scenario>."), 11)
    local before = #m.prints
    slash(NS, "sim bogus")
    assertEqual(printed(m, "/dw sim start <scenario> [size]: start a simulation."), 1, "the usage")
    assertEqual(printed(m, "/dw sim trade <drop id>: "), 1, "with the host verbs")
    assertTrue(#m.prints - before >= 15)
    slash(NS, "sim start nowhere")
    -- The library's line since DW-02 (OWNER_SCOPE C.7; smoke SM-DW-5): it names the scenarios.
    assertEqual(printed(m, "Unknown scenario 'nowhere'. Scenarios: key, dungeon, raid, lfr, delve, world."), 1)
    assertFalse(NS.Sim:IsActive())
end)

test("sim verbs: each host verb runs through RunVerb with its line, and says why it did nothing", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.Sim:Status().ready)
    slash(NS, "sim kill")
    assertEqual(printed(m, "No simulated boss is engaged: /dw sim pull first."), 1)
    slash(NS, "sim pull")
    assertEqual(printed(m, "Simulated pull: Warden Ashvane."), 1)
    slash(NS, "sim pull")
    assertEqual(printed(m, "A simulated boss is already engaged: /dw sim kill first."), 1)
    slash(NS, "sim kill")
    assertEqual(printed(m, "Simulated kill: Warden Ashvane."), 1)
    slash(NS, "sim loot 1 Nobody-Elsewhere")
    assertEqual(printed(m, "No one by that name is in the simulated group."), 1)
    slash(NS, "sim loot 2")
    assertEqual(printed(m, "Simulated loot: 2 drops"), 1)
    slash(NS, "sim loot 0")
    assertEqual(printed(m, "/dw sim loot [n] [player|me]: "), 1, "a bad count prints the usage")
    slash(NS, "sim lockdown on")
    assertEqual(printed(m, "Simulated chat lockdown on."), 1)
    assertTrue(NS.Restrictions.ActiveSet().chatLockdown)
    slash(NS, "sim lockdown off")
    assertEqual(printed(m, "Simulated chat lockdown off."), 1)
    slash(NS, "sim trade 99999")
    assertEqual(printed(m, "No drop has that id."), 1)
end)

test("sim verbs: a refused start prints its one line and nothing more", function()
    local NS, m = addon()
    m.inCombat = true
    local before = #m.prints
    slash(NS, "sim start dungeon")
    -- red under: a WHY line for `refused` (the library keeps it silent)
    assertEqual(#m.prints - before, 1)
    assertEqual(printed(m, "A simulation cannot start in combat."), 1)
end)

test("sim verbs: `/dw sim run` while disabled prints the one refusal line", function()
    local NS, m = addon()
    NS.addon:OnSlashCommand("disable")
    local before = #m.prints
    slash(NS, "sim run")
    assertEqual(#m.prints - before, 1)
    assertTrue(m.prints[#m.prints]:find(NS.SlashCommands:DisabledLine(), 1, true) ~= nil)
end)

test("sim verbs: refused while the addon is disabled, like every feature verb", function()
    local NS, m = addon()
    NS.SchemaRuntime.Set("enabled", false)
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim:IsActive())
    assertTrue(printed(m, "is disabled") >= 1)
end)

test("sim start: refused in combat and with test mode on, each with its line", function()
    local NS, m = addon()
    m.inCombat = true
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim:IsActive())
    assertEqual(printed(m, "A simulation cannot start in combat."), 1)
    m.inCombat = false
    NS.SetTestMode(true)
    slash(NS, "sim start dungeon")
    assertFalse(NS.Sim:IsActive())
    assertEqual(printed(m, "Turn test mode off before starting a simulation."), 1)
end)

test("sim start: the scenario's pool, group and situation, and the window open", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.Sim:IsActive())
    local st = NS.SimScenario.Status()
    assertTrue(st.ready); assertEqual(st.pos, 0); assertEqual(st.steps, 15)
    assertEqual(NS.Roster.Count(), 5)
    assertEqual(NS.Situations.Current(), "dungeon")
    assertTrue(NS.Window.IsShown(), "the window opened")
    assertEqual(printed(m, "Simulation ready: 4 members"), 1)
    slash(NS, "sim start raid")
    assertEqual(printed(m, "A simulation is already running."), 1)
    slash(NS, "sim status")
    assertTrue(printed(m, "Simulation: dungeon, seed ") == 1 and printed(m, ", step 0 of 15, playing.") == 1,
        "the library's status line")
    assertEqual(printed(m, "Simulated Dungeon: 4 members, 0 sends printed."), 1, "then DropWatcher's")
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
    -- A typed start plays on its own (LibKa0s v1.76.0); paused, so this case steps by hand.
    slash(NS, "sim pause")
    slash(NS, "sim step")
    assertEqual(printed(m, "still setting up its items"), 1)
    shown = false
    m.advance(1)
    assertTrue(NS.SimScenario.Status().ready)
    slash(NS, "sim step")
    assertEqual(printed(m, "Simulation step 1 of 15: Pull: Warden Ashvane."), 1)
    assertTrue(NS.SimEvents.Status().encounter ~= nil)
    slash(NS, "sim step")
    assertTrue(NS.Restrictions.ActiveSet().chatLockdown, "the lockdown step")
    slash(NS, "sim pull")
    assertEqual(printed(m, "A simulated boss is already engaged"), 1)
    m.advance(10)
    assertEqual(NS.SimScenario.Status().pos, 2, "paused before the pool was ready: nothing played on its own")
end)

test("sim restart: a stale pool callback from the first session never readies the restarted one (C.1)", function()
    local NS, m = addon()
    local shown = true   -- the journal's frame is open: the restarted session's pool waits
    m.EncounterJournal = { IsShown = function() return shown end }
    local build, first = NS.SimPool.Build, nil
    NS.SimPool.Build = function(opts, done)
        if not first then first = done; return true end   -- the first session's pool: held back
        return build(opts, done)
    end
    assertTrue(NS.SimScenario.Start("dungeon", nil, { seed = 1 }))
    assertTrue(NS.Sim:Restart())
    NS.SimPool.Build = build
    first()   -- the first session's pool, arriving after the restart
    -- red under: poolReady without its session check (modules/SimScenario.lua)
    assertFalse(NS.Sim:Status().ready, "the restarted timeline is not ready early")
    assertEqual(#NS.SimRoster.Get(), 0, "no group drawn from the stale callback")
    assertEqual(printed(m, "Simulation ready:"), 0)
    shown = false
    m.advance(1)
    assertTrue(NS.Sim:Status().ready, "its own pool readies it")
    assertEqual(printed(m, "Simulation ready:"), 1)
end)

test("sim run: Run while the panel's click-ahead plays answers playing (C.2)", function()
    local NS, m = addon()
    assertTrue(NS.SimScenario.Start("world", nil, { seed = 1 }))
    m.advance(1)
    assertTrue(NS.Sim:Status().ready)
    local answers, play = {}, NS.SimScenario.Play
    NS.SimScenario.Play = function(step, s)
        local _, code = NS.Sim:Run()
        answers[#answers + 1] = tostring(code)
        return play(step, s)
    end
    -- The library's panel: its click on a row ahead is the click-ahead, which holds Run's slot.
    -- The kit's CreateFrame sets no global, so the panel's frame is caught as it is built.
    local create, panel = m.CreateFrame, nil
    m.CreateFrame = function(kind, name, ...)
        local f = create(kind, name, ...)
        if name == "DropWatcherSimPanel" then panel = f end
        return f
    end
    assertTrue(NS.Sim:ShowPanel())
    m.CreateFrame = create
    panel.__rowButtons[4]:__fire("OnClick")   -- timeline step 3
    NS.SimScenario.Play = play
    assertEqual(NS.Sim:Status().pos, 3, "the click-ahead played up to the row")
    assertEqual(table.concat(answers, ","), "playing,playing,playing")
    assertFalse(NS.Sim:Status().playing, "the slot is free again")
    NS.Sim:HidePanel()
end)

-- ── auto-play (LibKa0s v1.76.0, DW-01; OWNER_SCOPE A.1, C.1) ────────────────────────────────

test("sim run: a typed start plays on its own", function()
    local NS, m = addon()
    slash(NS, "sim start world")
    local st = NS.SimScenario.Status()
    -- red under: LibKa0s v1.75.2, where a typed start waited for `/dw sim run` or Run all
    assertTrue(st.playing, "playing from the start"); assertEqual(st.pos, 0)
    assertEqual(printed(m, ". It plays now: /dw sim pause holds it, /dw sim step plays one event at a time."), 1,
        "the ready line says it plays")
    m.advance(0)
    assertEqual(NS.SimScenario.Status().pos, 1, "the first step on the next frame")
    assertEqual(printed(m, "Simulation step 1 of 5: Pull: Warden Ashvane."), 1)
    local delay = NS.SimScenario.StepDelay()
    for pos = 2, 5 do
        m.advance(delay)
        assertEqual(NS.SimScenario.Status().pos, pos, "one step per step delay")
    end
    m.advance(delay * 5)
    st = NS.SimScenario.Status()
    assertEqual(st.pos, st.steps); assertFalse(st.playing)
    assertEqual(printed(m, "The simulation's timeline has finished."), 1)
end)

test("sim run: a typed start waits for the pool, then plays", function()
    local NS, m = addon()
    local shown = true   -- the journal's frame is open: the pool waits
    m.EncounterJournal = { IsShown = function() return shown end }
    slash(NS, "sim start dungeon")
    m.advance(1)
    assertFalse(NS.SimScenario.Status().ready)
    assertEqual(NS.SimScenario.Status().pos, 0, "nothing plays while the pool builds")
    assertEqual(printed(m, "Simulation step "), 0)
    shown = false
    m.advance(1)
    assertTrue(NS.SimScenario.Status().ready)
    -- red under: LibKa0s v1.75.2, where the ready pool waited for a verb
    assertTrue(NS.SimScenario.Status().pos >= 1, "the ready pool plays with no further verb")
    assertEqual(printed(m, "Simulation step 1 of 15: Pull: Warden Ashvane."), 1)
end)

test("sim step: a typed step while it plays pauses it and plays one step", function()
    local NS, m = addon()
    slash(NS, "sim start world")
    m.advance(0)
    assertEqual(NS.SimScenario.Status().pos, 1)
    slash(NS, "sim step")
    local st = NS.SimScenario.Status()
    assertEqual(st.pos, 2, "the next step at once")
    -- red under: LibKa0s v1.75.2, where a step beside a playing run left it playing
    assertFalse(st.playing); assertTrue(st.paused, "held")
    m.advance(10)
    assertEqual(NS.SimScenario.Status().pos, 2, "nothing more plays while held")
    slash(NS, "sim resume")
    m.advance(NS.SimScenario.StepDelay() * 5)
    st = NS.SimScenario.Status()
    assertEqual(st.pos, st.steps, "resume plays the rest")
    assertEqual(printed(m, "The simulation's timeline has finished."), 1)
end)

test("sim pause before the pool is ready: the ready pool plays nothing", function()
    local NS, m = addon()
    local shown = true
    m.EncounterJournal = { IsShown = function() return shown end }
    slash(NS, "sim start dungeon")
    slash(NS, "sim pause")
    shown = false
    m.advance(1)
    assertTrue(NS.SimScenario.Status().ready)
    m.advance(10)
    local st = NS.SimScenario.Status()
    assertEqual(st.pos, 0, "held before the pool readied: nothing played")
    assertFalse(st.playing)
    assertEqual(printed(m, "Simulation step "), 0)
end)

test("sim run: plays every step a few seconds apart, each with its line, then says it has finished", function()
    local NS, m = addon()
    slash(NS, "sim start world")
    -- The typed start already plays (LibKa0s v1.76.0): run, the resume synonym, has nothing to do.
    slash(NS, "sim run")
    assertEqual(printed(m, "The timeline is already playing."), 1)
    m.advance(NS.SimScenario.STEP_DELAY * 5)
    local st = NS.SimScenario.Status()
    assertEqual(st.pos, st.steps); assertFalse(st.playing)
    assertEqual(printed(m, "The simulation's timeline has finished."), 1)
    -- red under: the M7 run, which printed no step it played itself (sim feedback §0)
    -- Since DW-04 each line names the step as the panel does (its stepLabel).
    for _, line in ipairs({ "2 of 5: Combat and chat lockdown.", "3 of 5: Kill: Warden Ashvane.", "4 of 5: Loot: 3 drops",
        "5 of 5: Lockdown lifts." }) do
        assertEqual(printed(m, "Simulation step " .. line), 1, line)
    end
    assertEqual(NS.SimEvents.Status().kills, 1)
    slash(NS, "sim step")
    assertEqual(printed(m, "The simulation's timeline has finished."), 2)
end)

-- ── the step delay (feedback-2 spec §8, FB2-8) ──────────────────────────────────────────────

-- The owner's simulator feedback (2026-10-23) moved the default from two seconds to one.
test("sim step delay: one second by default, read from `sim.stepDelay`; a bad value falls back", function()
    local NS = addon()
    local SC = NS.SimScenario
    -- red under: defaults/Profile.lua's `sim.stepDelay = 2`, the default before the 2026-10-23 feedback
    assertEqual(SC.STEP_DELAY, 1)
    assertEqual(NS.C.PROFILE.sim.stepDelay, SC.STEP_DELAY, "the default is the profile's")
    assertEqual(SC.StepDelay(), 1)
    NS.addon.db.profile.sim.stepDelay = 4.5
    assertEqual(SC.StepDelay(), 4.5)
    NS.addon.db.profile.sim.stepDelay = 0.2
    assertEqual(SC.StepDelay(), 1, "out of range: the default")
    NS.addon.db.profile.sim.stepDelay = "fast"
    assertEqual(SC.StepDelay(), 1, "not a number: the default")
end)

test("sim step delay: an untouched setting runs the steps one second apart", function()
    local NS, m = addon()
    slash(NS, "sim start world")
    m.advance(0)
    assertEqual(NS.SimScenario.Status().pos, 1, "the typed start plays its first step on the next frame")
    m.advance(0.5)
    assertEqual(NS.SimScenario.Status().pos, 1, "half a second: not yet")
    -- red under: the two-second default, which leaves the run on step 1 here
    m.advance(0.5)
    assertEqual(NS.SimScenario.Status().pos, 2, "one second: the next step")
end)

test("sim step delay: ValidStepDelay takes 0.5 to 10 in steps of 0.5", function()
    local SC = T.newAddon().SimScenario
    for _, v in ipairs({ 0.5, 1, 2, 7.5, 10 }) do assertTrue(SC.ValidStepDelay(v), tostring(v)) end
    for _, v in ipairs({ 0, 0.4, 1.3, 10.5, 0 / 0, "2" }) do assertFalse(SC.ValidStepDelay(v), tostring(v)) end
end)

test("sim step delay: `/dw set sim.stepDelay` takes a half step, clamps to the range, refuses a quarter step", function()
    local NS = addon()
    slash(NS, "set sim.stepDelay 11")
    assertEqual(NS.addon.db.profile.sim.stepDelay, 10, "the slash parser clamps to the row's range")
    slash(NS, "set sim.stepDelay 1.5")
    assertEqual(NS.addon.db.profile.sim.stepDelay, 1.5)
    slash(NS, "set sim.stepDelay 1.2")
    assertEqual(NS.addon.db.profile.sim.stepDelay, 1.5, "not a half step")
    local row = NS.SchemaRuntime.FindRow("sim.stepDelay")
    -- red under: the pre-020 label and tooltip (DRO-L05: the unit in the label; DRO-L-new1: the verb)
    assertEqual(row.label, "Simulation step delay (seconds)")
    assertEqual(row.tooltip, "Paces /dw sim: how many seconds the simulator waits between steps as it "
        .. "plays. A change takes effect from the next step.", "no Run all in the tooltip")
    assertEqual(row.page, "general"); assertEqual(row.group, "Simulator")
    assertEqual(row.min, 0.5); assertEqual(row.max, 10); assertEqual(row.step, 0.5)
end)

test("sim step delay: a run waits the set delay, and a change takes effect from the next step", function()
    local NS, m = addon()
    slash(NS, "set sim.stepDelay 5")
    slash(NS, "sim start world")
    m.advance(0)
    assertEqual(NS.SimScenario.Status().pos, 1)
    m.advance(4.5)
    assertEqual(NS.SimScenario.Status().pos, 1, "five seconds, not the default one")
    slash(NS, "set sim.stepDelay 1")
    m.advance(0.5)
    assertEqual(NS.SimScenario.Status().pos, 2, "the step already set keeps its five seconds")
    m.advance(1)
    assertEqual(NS.SimScenario.Status().pos, 3, "the next step waits the new one second")
end)

test("sim stop: ends a playing timeline and its timers", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")   -- it plays on its own (LibKa0s v1.76.0)
    m.advance(0)
    slash(NS, "sim stop")
    assertFalse(NS.Sim:IsActive())
    assertNil(NS.SimScenario.Status())
    m.advance(60)
    assertEqual(NS.SimEvents.Status(), nil, "nothing played after the stop")
    assertEqual(#drops(NS), 0)
    assertNil(NS.Restrictions.ActiveSet().encounter)
end)

test("sim stand-down: disabling mid-run stops the timeline; nothing fires afterward", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")   -- it plays on its own (LibKa0s v1.76.0)
    m.advance(0)
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Sim:IsActive())
    assertEqual(printed(m, "Simulation stopped: the addon was disabled."), 1)
    local hits = NS.LootParser.Stats().hits
    m.advance(60)
    assertEqual(NS.LootParser.Stats().hits, hits, "no loot line after the stand-down")
end)

-- ---------------------------------------------------------------------------------------------
-- The chip, the footer and the diagnostics section
-- ---------------------------------------------------------------------------------------------

test("sim window: the sim strip (not the SIMULATION text) with the scenario tooltip, and the footer says Simulating", function()
    local NS = addon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertFalse(f.simText:IsShown())
    assertFalse(f.simBanner:IsShown())
    slash(NS, "sim start raid 10")
    NS.Window.Refresh()
    assertTrue(f.simBanner:IsShown(), "the cyan strip under the filter bar (DW-10)")
    assertFalse(f.simText:IsShown()); assertFalse(f.testText:IsShown())
    assertEqual(NS.Window.TooltipOf(f.simBanner)[1], "Simulation")
    assertEqual(f.simText.text:GetText(), "SIMULATION")
    local title, scenario = NS.WindowTitleBar.SimTip()
    assertEqual(title, "Simulation"); assertEqual(T.tipPlain(scenario), "• Scenario: raid (Raid)")
    local seg = NS.WindowFooter.Compose(NS.WindowFooter.Read()).situation
    assertEqual(seg.text, "Simulating: Raid · 10 members")
    slash(NS, "sim stop")
    assertFalse(f.simText:IsShown(), "gone with the simulation")
    assertFalse(f.simBanner:IsShown(), "the strip too")
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
    slash(NS, "sim step")   -- a typed step holds the run that the typed start armed
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
    -- The run's pace is pinned, not the default: the loot lines and the ask below take a second
    -- between the loot step and the lockdown lifting, which a one-second default (2026-10-23) would
    -- leave no room for.
    slash(NS, "set sim.stepDelay 2")
    slash(NS, "sim start key")
    assertEqual(NS.Situations.Current(), "mythicPlus")
    m.advance(0)   -- the typed start plays on its own (LibKa0s v1.76.0): its first step, the key's start
    assertTrue(NS.Compat.ChallengeModeActive(), "the run started")
    playUntil(NS, m, "lockdownOff")
    -- The completion's loot burst has landed, the chat lockdown still holds.
    assertTrue(NS.LootParser.Stats().hits > hits, "the written lines went through the parser")
    local member = NS.SimRoster.Get()[1]
    slash(NS, "sim loot 1 " .. member.name)
    slash(NS, "sim loot 1 me")
    m.advance(0.5)
    local theirs = firstWhere(drops(NS), function(r) return not r.isMine end)
    -- The newest of your drops: a trade settles the newest open drop of its item, and the burst may
    -- hold two of one item, depending on the session's seed (the client clock at the start).
    local mine = lastWhere(drops(NS), function(r) return r.isMine end)
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
    assertTrue(#NS.SimHost.HistoryLog().groups > 0)
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
    NS.Sim:Run()
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
