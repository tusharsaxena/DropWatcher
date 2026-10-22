-- tests/test_sim_panel.lua — the simulation step panel (sim feedback spec §1, §2; DW-91): the pure
-- composer (each row's name, command, state and tooltip; the run controls' state); the panel built
-- headless and its rows tracking the timeline; a click on a later row running every step in
-- between, in order; a typed `/dw sim step` moving the panel; Run all, Pause and Resume, Restart and
-- Stop; the scenario picker starting the chosen scenario; the opening verbs, the dock beside the
-- window, the remembered position and the stand-down (modules/SimPanel.lua).

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

local LEVEL = { [1] = 580, [2] = 590, [23] = 600, [8] = 610, [17] = 590, [14] = 600, [15] = 610, [16] = 620 }

-- Two dungeons dropping two rings at every dungeon difficulty, and a raid at every raid difficulty.
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

-- An enabled addon, solo and out of an instance; the player wears two 590 rings.
local function addon()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, 590), ring(590))
    m.addItem(link(101, 590), ring(590))
    m.inventory.player[11], m.inventory.player[12] = link(100, 590), link(101, 590)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    return NS, m
end

local function slash(NS, line) NS.addon:OnSlashCommand(line) end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function rows(NS) return NS.SimPanel.Frame().rows end

local function states(NS)
    local out = {}
    for i, row in ipairs(NS.SimPanel.Stats().rows) do out[i] = row.state end
    return table.concat(out, ",")
end

local function pos(NS) return NS.SimScenario.Status().pos end

-- ---------------------------------------------------------------------------------------------
-- Pure: the composer and the controls
-- ---------------------------------------------------------------------------------------------

test("sim panel: a key's preview names every step, with its command, before a run", function()
    local NS = T.newAddon()
    local SP, SC = NS.SimPanel, NS.SimScenario
    local r = SP.Compose({ running = false, scenario = "key", steps = SC.Timeline(SC.SCENARIOS.key), pos = 0, now = 0 })
    local labels = {}
    for i, row in ipairs(r) do labels[i] = row.label end
    local B = NS.SimEvents.BOSSES
    assertEqual(table.concat(labels, "|"), table.concat({ "Start: Mythic+ key", "Key starts",
        "Pull: " .. B[1], "Kill: " .. B[1], "Pull: " .. B[2], "Kill: " .. B[2], "Pull: " .. B[3], "Kill: " .. B[3],
        "Combat and chat lockdown", "Key complete", "Loot: 2 drops", "Lockdown lifts", "Stop simulation" }, "|"))
    assertEqual(r[1].command, "/dw sim start key")
    assertEqual(r[2].command, "/dw sim step")
    assertEqual(r[#r].command, "/dw sim stop")
    assertEqual(r[1].state, "ready"); assertTrue(r[1].actionable)
    for i = 2, #r do
        assertEqual(r[i].state, "locked", "row " .. i)
        assertFalse(r[i].actionable, "row " .. i .. " is not clickable without a run")
    end
    assertEqual(T.tipPlainJoined({ r[11].tip[2], r[11].tip[3] }), "• Injects: 2 loot lines | • Through: the real loot handler (CHAT_MSG_LOOT)")
end)

test("sim panel: a running timeline's rows are done, current, next and ahead, with PerfPanel's states", function()
    local NS = T.newAddon()
    local SP = NS.SimPanel
    local steps = {
        { kind = "pull", ranAt = 10, detail = "Matron Seyla" }, { kind = "lockdownOn", ranAt = 13 },
        { kind = "kill", ranAt = 16, detail = "Matron Seyla" }, { kind = "loot", n = 3 }, { kind = "lockdownOff" },
    }
    local r = SP.Compose({ running = true, ready = true, scenario = "raid", size = 12, steps = steps, pos = 2,
        startedAt = 5, now = 25 })
    assertEqual(r[1].label, "Start: Raid"); assertEqual(r[1].command, "/dw sim start raid 12")
    local want = { "done", "done", "busy", "ready", "locked", "locked", "cancel" }
    for i, s in ipairs(want) do assertEqual(r[i].state, s, "row " .. i) end
    assertEqual(r[2].label, "Pull: Matron Seyla", "a played pull names its boss")
    assertEqual(r[4].label, "Kill: Matron Seyla")
    assertEqual(r[5].label, "Loot: 3 drops")
    assertFalse(r[2].actionable, "a completed step does nothing")
    assertEqual(T.tipPlain(r[2].tip[2]), "• Ran: 15s ago")
    assertEqual(T.tipPlain(r[1].tip[2]), "• Ran: 20s ago", "the start ran when the session started")
    assertTrue(r[4].actionable); assertFalse(r[4].ahead)
    assertTrue(r[6].actionable); assertTrue(r[6].ahead)
    assertEqual(T.tipPlain(r[6].tip[#r[6].tip]), "Click to run every step up to this one, in order.", "the closing hint")
    assertTrue(r[7].actionable, "Stop is clickable while a run lasts")
    -- A played loot step says what it dropped.
    steps[4].detail, steps[4].ranAt = "2 drops", 20
    assertEqual(SP.Compose({ running = true, ready = true, scenario = "raid", steps = steps, pos = 4, now = 25 })[5].label,
        "Loot: 2 drops")
end)

test("sim panel: before the pool is ready the start is current and nothing else is clickable", function()
    local NS = T.newAddon()
    local r = NS.SimPanel.Compose({ running = true, ready = false, scenario = "dungeon",
        steps = { { kind = "pull" }, { kind = "kill" } }, pos = 0, now = 0 })
    assertEqual(r[1].state, "busy")
    assertFalse(r[2].actionable); assertEqual(r[2].state, "locked")
    assertTrue(r[4].actionable)
end)

test("sim panel: the controls follow the timeline: Run all, Pause or Resume, Restart, Stop", function()
    local C = T.newAddon().SimPanel.Controls
    assertFalse(C(nil, false).running)
    local c = C({ ready = true, pos = 0, steps = 5, playing = false }, true)
    assertTrue(c.run); assertFalse(c.pause.enabled); assertEqual(c.pause.verb, "pause")
    assertTrue(c.restart); assertTrue(c.stop)
    c = C({ ready = true, pos = 2, steps = 5, playing = true }, true)
    assertFalse(c.run, "already playing"); assertTrue(c.pause.enabled)
    c = C({ ready = true, pos = 2, steps = 5, playing = false, paused = true }, true)
    assertEqual(c.pause.verb, "resume"); assertEqual(c.pause.label, "Resume"); assertTrue(c.pause.enabled)
    c = C({ ready = true, pos = 5, steps = 5 }, true)
    assertFalse(c.run, "nothing left to play")
    c = C({ ready = false, pos = 0, steps = 5 }, true)
    assertFalse(c.run, "the pool is not ready")
end)

test("sim panel: StartCommand carries a raid's size and leaves a random one out", function()
    local SP = T.newAddon().SimPanel
    assertEqual(SP.StartCommand("key"), "/dw sim start key")
    assertEqual(SP.StartCommand("raid", 0), "/dw sim start raid")
    assertEqual(SP.StartCommand("raid", 15), "/dw sim start raid 15")
end)

-- ---------------------------------------------------------------------------------------------
-- The panel: opening, building, docking
-- ---------------------------------------------------------------------------------------------

test("sim panel: `/dw sim` opens it, `/dw sim panel` toggles it, and it builds PerfPanel's three columns", function()
    local NS, m = addon()
    assertNil(NS.SimPanel.Frame(), "built on the first show")
    slash(NS, "sim")
    assertTrue(NS.SimPanel.IsShown())
    assertEqual(printed(m, "No simulation is running."), 1, "the bare verb still prints the status")
    local f = NS.SimPanel.Frame()
    assertEqual(f.title:GetText(), "Ka0s Drop Watcher - Simulation")
    assertTrue(f.closeButton ~= nil, "Core's close mark")
    local b = rows(NS)[1]
    assertEqual(b.__label, "Start: Mythic+ key"); assertEqual(b.__state, "ready")
    assertEqual(b.cmd:GetText(), "/dw sim start key")
    assertTrue(f.picker:IsShown(), "the picker shows while nothing runs")
    assertFalse(f.controls:IsShown())
    slash(NS, "sim panel")
    assertFalse(NS.SimPanel.IsShown())
    slash(NS, "sim panel")
    assertTrue(NS.SimPanel.IsShown())
    f.closeButton:__fire("OnClick")
    assertFalse(NS.SimPanel.IsShown(), "the close mark hides it")
end)

test("sim panel: `/dw sim start` opens it beside the window, its rows tracking the timeline", function()
    local NS = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.SimPanel.IsShown())
    local st = NS.SimPanel.Stats()
    assertEqual(st.dock, "right", "docked to the window's right edge, not over it")
    local pt = { NS.SimPanel.Frame():GetPoint(1) }
    assertEqual(pt[1], "TOPLEFT"); assertTrue(pt[2] == NS.Window.Frame()); assertEqual(pt[3], "TOPRIGHT")
    assertEqual(#st.rows, NS.SimScenario.Status().steps + 2)
    assertEqual(states(NS):sub(1, 18), "busy,ready,locked,")
    assertTrue(NS.SimPanel.Frame().controls:IsShown())
    assertFalse(NS.SimPanel.Frame().picker:IsShown())
end)

test("sim panel: opened before the window, it docks beside the window once a slow pool opens it", function()
    local NS, m = addon()
    for _, byDifficulty in pairs(m.journal.loot) do
        for _, list in pairs(byDifficulty) do
            for _, e in ipairs(list) do e.loadsNeeded = 1 end
        end
    end
    slash(NS, "sim start dungeon")
    assertTrue(NS.SimPanel.IsShown())
    assertFalse(NS.Window.IsShown(), "the pool is still loading: no window yet")
    assertEqual(NS.SimPanel.Stats().dock, "center")
    m.loadJournal()
    m.advance(NS.SimPool.SETTLE)
    assertTrue(NS.Window.IsShown(), "the ready pool opened the window")
    assertEqual(NS.SimPanel.Stats().dock, "right", "re-docked beside the window, not over it")
    local pt = { NS.SimPanel.Frame():GetPoint(1) }
    assertEqual(pt[1], "TOPLEFT"); assertTrue(pt[2] == NS.Window.Frame())
end)

test("sim panel: a dragged panel stays where it was put when the window opens later", function()
    local NS, m = addon()
    for _, byDifficulty in pairs(m.journal.loot) do
        for _, list in pairs(byDifficulty) do
            for _, e in ipairs(list) do e.loadsNeeded = 1 end
        end
    end
    NS.addon.db.profile.simPanel = { point = { "TOPLEFT", "TOPLEFT", 40, -60 } }
    slash(NS, "sim start dungeon")
    m.loadJournal()
    m.advance(NS.SimPool.SETTLE)
    assertTrue(NS.Window.IsShown())
    assertEqual(NS.SimPanel.Stats().dock, "saved")
end)

-- ---------------------------------------------------------------------------------------------
-- Clicking the rows
-- ---------------------------------------------------------------------------------------------

test("sim panel: clicking the next step runs it; clicking a later one runs every step in between", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    rows(NS)[2]:__fire("OnClick")
    assertEqual(pos(NS), 1)
    assertEqual(printed(m, "Simulation step 1 of 15: pull"), 1)
    rows(NS)[5]:__fire("OnClick")   -- timeline step 4, the loot
    assertEqual(pos(NS), 4, "steps 2, 3 and 4 ran, in order")
    for i, kind in ipairs({ "lockdownOn", "kill", "loot" }) do
        assertEqual(printed(m, ("Simulation step %d of 15: %s"):format(i + 1, kind)), 1, kind .. " ran once")
    end
    assertTrue(#NS.LootFeed.Drops("live") > 0, "the loot step reached the feed")
    local r = NS.SimPanel.Stats().rows
    assertEqual(r[2].state, "done"); assertEqual(r[5].state, "busy"); assertEqual(r[6].state, "ready")
    assertEqual(rows(NS)[2].__state, "done")
end)

test("sim panel: clicking a completed step does nothing, and its tooltip says when it ran", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    rows(NS)[2]:__fire("OnClick")
    m.advance(7)
    local before = #m.prints
    rows(NS)[2]:__fire("OnClick")
    rows(NS)[1]:__fire("OnClick")
    assertEqual(pos(NS), 1); assertEqual(#m.prints, before, "nothing ran, nothing printed")
    NS.SimPanel.Refresh()
    local tip = NS.Window.TooltipOf(rows(NS)[2])
    assertEqual(T.tipPlain(tip[2]), "• Ran: 7s ago")
end)

test("sim panel: a typed `/dw sim step` moves the panel too", function()
    local NS = addon()
    slash(NS, "sim start key")
    slash(NS, "sim step")
    slash(NS, "sim step")
    local r = NS.SimPanel.Stats().rows
    assertEqual(r[2].state, "done"); assertEqual(r[3].state, "busy"); assertEqual(r[4].state, "ready")
    assertEqual(rows(NS)[3].__state, "busy")
end)

-- ---------------------------------------------------------------------------------------------
-- The run controls
-- ---------------------------------------------------------------------------------------------

test("sim panel: Run all plays the timeline, highlighting each step; Pause holds it and Resume plays on", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    local ctl = NS.SimPanel.Frame().controls
    ctl.run:__fire("OnClick")
    assertEqual(pos(NS), 1, "one step at once")
    assertTrue(NS.SimScenario.Status().playing)
    assertFalse(ctl.run:IsEnabled(), "Run all is spent while playing")
    m.advance(NS.SimScenario.STEP_DELAY)
    assertEqual(pos(NS), 2)
    assertEqual(rows(NS)[3].__state, "busy", "the highlight follows the run")
    assertTrue(ctl.pause:IsEnabled(), "Pause stays live after an automatic step")
    assertFalse(ctl.run:IsEnabled(), "Run all stays spent after an automatic step")
    ctl.pause:__fire("OnClick")
    assertTrue(NS.SimScenario.Status().paused)
    assertEqual(ctl.pause.__label, "Resume")
    m.advance(NS.SimScenario.STEP_DELAY * 3)
    assertEqual(pos(NS), 2, "paused: nothing played")
    ctl.pause:__fire("OnClick")
    assertEqual(pos(NS), 3, "resumed: the next step at once")
    assertTrue(NS.SimScenario.Status().playing)
    assertEqual(ctl.pause.__label, "Pause")
    for _ = 1, 20 do m.advance(NS.SimScenario.STEP_DELAY) end
    assertEqual(pos(NS), 15, "played to the end")
    assertEqual(rows(NS)[17].__state, "cancel", "Stop is what is left")
end)

test("sim panel: Run all's tooltip names the current step delay (feedback-2 spec §8, FB2-8)", function()
    local NS = addon()
    slash(NS, "sim start dungeon")
    local run = NS.SimPanel.Frame().controls.run
    assertEqual(T.tipPlainJoined(NS.Window.TooltipOf(run)), "Run all | • Plays: every step left | • Every: 2 seconds | • Typed: /dw sim run")
    slash(NS, "set sim.stepDelay 3.5")
    assertEqual(T.tipPlain(NS.Window.TooltipOf(run)[3]), "• Every: 3.5 seconds")
end)

test("sim panel: the typed pause, resume and restart answer as the buttons do", function()
    local NS, m = addon()
    slash(NS, "sim pause")
    assertEqual(printed(m, "No simulation is running: start one"), 1)
    slash(NS, "sim start key")
    slash(NS, "sim pause")
    assertEqual(printed(m, "The timeline is not playing"), 1)
    slash(NS, "sim resume")
    assertEqual(printed(m, "The timeline is not paused."), 1)
    slash(NS, "sim run")
    slash(NS, "sim pause")
    assertTrue(NS.SimScenario.Status().paused)
    slash(NS, "sim resume")
    assertTrue(NS.SimScenario.Status().playing)
end)

test("sim panel: Restart stops the scenario and starts the same one again; Stop ends it", function()
    local NS = addon()
    slash(NS, "sim start raid 12")
    slash(NS, "sim step"); slash(NS, "sim step")
    local ctl = NS.SimPanel.Frame().controls
    ctl.restart:__fire("OnClick")
    assertTrue(NS.Sim:IsActive())
    local st = NS.SimScenario.Status()
    assertEqual(st.scenario, "raid"); assertEqual(st.pos, 0); assertEqual(st.size, 12)
    assertEqual(#NS.SimRoster.Get(), 12, "the same size again")
    assertEqual(NS.SimPanel.Stats().rows[1].state, "busy")
    ctl.stop:__fire("OnClick")
    assertFalse(NS.Sim:IsActive())
    assertTrue(NS.SimPanel.IsShown(), "the panel stays, with the picker")
    assertTrue(NS.SimPanel.Frame().picker:IsShown())
    assertEqual(NS.SimPanel.Stats().rows[1].state, "ready")
    assertEqual(NS.SimPanel.Choice().scenario, "raid", "the picker keeps the scenario that ran")
end)

test("sim panel: a typed `/dw sim stop` and an automatic stop repaint the panel", function()
    local NS, m = addon()
    slash(NS, "sim start key")
    slash(NS, "sim stop")
    assertEqual(NS.SimPanel.Stats().rows[1].state, "ready")
    slash(NS, "sim start key")
    m.setGroup({ { guid = "Player-1-0000BBBB", name = "Brakk", classFile = "WARRIOR", connected = true } })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertFalse(NS.Sim:IsActive())
    assertEqual(NS.SimPanel.Stats().rows[1].state, "ready")
end)

-- ---------------------------------------------------------------------------------------------
-- The scenario picker
-- ---------------------------------------------------------------------------------------------

test("sim panel: the picker starts the chosen scenario, with a raid's member count", function()
    local NS = addon()
    slash(NS, "sim panel")
    local f = NS.SimPanel.Frame()
    assertTrue(f.picker.scenario ~= nil, "the scenario dropdown")
    assertFalse(f.picker.size:IsShown(), "no member count for a key")
    f.picker.scenario.onSelect("raid")
    assertTrue(f.picker.size:IsShown(), "a raid takes a member count")
    f.picker.size.onSelect(15)
    assertEqual(rows(NS)[1].__command, "/dw sim start raid 15")
    f.picker.start:__fire("OnClick")
    assertTrue(NS.Sim:IsActive())
    assertEqual(NS.SimScenario.Status().scenario, "raid")
    assertEqual(#NS.SimRoster.Get(), 15)
    NS.SimPanel.Frame().controls.stop:__fire("OnClick")
    f.picker.scenario.onSelect("lfr")
    rows(NS)[1]:__fire("OnClick")   -- the Start row starts it too
    assertEqual(NS.SimScenario.Status().scenario, "lfr")
end)

test("sim panel: a dragged position is remembered, Reset position forgets it, stand-down hides it", function()
    local NS = addon()
    slash(NS, "sim panel")
    local f = NS.SimPanel.Frame()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "TOPLEFT", 40, -60)
    f:__fire("OnDragStop")
    assertEqual(NS.addon.db.profile.simPanel.point[3], 40)
    NS.SimPanel.Hide(); NS.SimPanel.Show()
    assertEqual(NS.SimPanel.Stats().dock, "saved")
    NS.Window.ResetPosition()
    assertNil(NS.addon.db.profile.simPanel.point)
    assertTrue(NS.SimPanel.Stats().dock ~= "saved")
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.SimPanel.IsShown(), "standing down closes it")
    NS.SimPanel.Show()
    assertFalse(NS.SimPanel.IsShown(), "and it does not open while stood down")
end)
