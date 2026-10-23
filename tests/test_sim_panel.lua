-- tests/test_sim_panel.lua — the simulation step panel's DropWatcher content (DW-04, LibKa0s#53
-- #54): since contract proof 3/3 the panel is LibKa0s-Sim-1.0's (its rows, states, controls,
-- click-ahead, stale-click guard and placement order are pinned by the library's own suites), and
-- DropWatcher passes only the presentation fields (modules/SimPanel.lua's NS.SimPanel.FIELDS).
-- These cases read the panel through NS.Sim:PanelRows / ShowPanel / HidePanel / TogglePanel /
-- IsPanelShown and assert what is DropWatcher's: the step names (bosses, loot counts), the per-kind
-- tooltips, the Start and Stop tooltips, the scenarios' names and a raid's sizes, the done tick's
-- texture, the title, docking beside the Drop Watcher window, a position that is session-only and
-- the stand-down.

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

-- An enabled addon, solo and out of an instance; the player wears two 590 rings. The library's
-- panel frame (`DropWatcherSimPanel`) is caught as it is built: the kit's CreateFrame sets no global.
local function addon()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, 590), ring(590))
    m.addItem(link(101, 590), ring(590))
    m.inventory.player[11], m.inventory.player[12] = link(100, 590), link(101, 590)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    local create = m.CreateFrame
    m.CreateFrame = function(kind, name, ...)
        local f = create(kind, name, ...)
        if name == "DropWatcherSimPanel" then m.simPanel = f end
        return f
    end
    return NS, m
end

local function slash(NS, line) NS.addon:OnSlashCommand(line) end

local function labels(rows)
    local out = {}
    for i, row in ipairs(rows) do out[i] = row.label end
    return table.concat(out, "|")
end

-- Tooltip lines ({ left, right } pairs) as one string.
local function lines(list)
    local out = {}
    for i, line in ipairs(list) do out[i] = line[1] .. ": " .. tostring(line[2]) end
    return table.concat(out, " | ")
end

-- ---------------------------------------------------------------------------------------------
-- The fields: names and tooltips
-- ---------------------------------------------------------------------------------------------

test("sim panel: the descriptor carries DropWatcher's presentation fields and nothing else", function()
    local NS = T.newAddon()
    local F = NS.SimPanel.FIELDS
    local keys = {}
    for k in pairs(F) do keys[#keys + 1] = k end
    table.sort(keys)
    -- No button, no tooltip (OWNER_SCOPE C.7) and no store (C.11).
    assertEqual(table.concat(keys, ","), "anchorTo,check,startTip,stepLabel,stepTip,stopTip,title")
    assertEqual(F.title(), "Ka0s Drop Watcher - Simulation")
    assertEqual(F.check, NS.Icon("confirm"), "the done tick is the catalog's confirm icon")
    assertNil(F.anchorTo(), "no window shown: the panel floats")
end)

test("sim panel: a key's preview names every step with its boss, and every command, before a run", function()
    local NS = addon()
    local r = NS.Sim:PanelRows()
    local B = NS.SimEvents.BOSSES
    assertEqual(labels(r), table.concat({ "Start: Mythic+ key", "Key starts",
        "Pull: " .. B[1], "Kill: " .. B[1], "Pull: " .. B[2], "Kill: " .. B[2], "Pull: " .. B[3], "Kill: " .. B[3],
        "Combat and chat lockdown", "Key complete", "Loot: 2 drops", "Lockdown lifts", "Stop simulation" }, "|"))
    assertEqual(r[1].command, "/dw sim start key")
    assertEqual(r[2].command, "/dw sim step")
    assertEqual(r[#r].command, "/dw sim stop")
    assertEqual(lines(r[11].tip), "Injects: 2 loot lines | Through: the real loot handler (CHAT_MSG_LOOT)")
end)

test("sim panel: a step names the boss it played, and a loot step its count or its detail", function()
    local NS = T.newAddon()
    local SP = NS.SimPanel
    local steps = {
        { kind = "pull", detail = "Matron Seyla" }, { kind = "lockdownOn" }, { kind = "kill" },
        { kind = "loot", n = 3 }, { kind = "lockdownOff" }, { kind = "pull" }, { kind = "loot" }, { kind = "loot", n = 1 },
    }
    local out = {}
    for i, step in ipairs(steps) do out[i] = SP.StepLabel(step, i, steps) end
    assertEqual(table.concat(out, "|"), table.concat({ "Pull: Matron Seyla", "Combat and chat lockdown",
        "Kill: Matron Seyla", "Loot: 3 drops", "Lockdown lifts", "Pull: " .. NS.SimEvents.BOSSES[2],
        "Loot: 1 to 3 drops", "Loot: 1 drop" }, "|"))
    steps[4].detail = "2 drops"
    assertEqual(SP.StepLabel(steps[4], 4, steps), "Loot: 2 drops", "a played loot step says what it dropped")
    assertEqual(SP.StepLabel({ kind = "kill", detail = "Warden Ashvane" }), "Kill: Warden Ashvane", "no timeline: its detail")
end)

test("sim panel: every step kind's tooltip says what it injects; Start and Stop say what they do", function()
    local NS = addon()
    local SP = NS.SimPanel
    local want = {
        runStart = "Injects: CHALLENGE_MODE_START, the ChallengeMode restriction | Through: the real handlers",
        runEnd = "Injects: CHALLENGE_MODE_COMPLETED | Lifts: the ChallengeMode restriction | Through: the real handlers",
        pull = "Injects: ENCOUNTER_START, the combat edge, the Encounter restriction | Through: the real handlers",
        kill = "Injects: ENCOUNTER_END | Lifts: combat and the Encounter restriction | Through: the real handlers",
        lockdownOn = "Injects: the simulated chat lockdown | Asks: wait until it lifts",
        lockdownOff = "Lifts: the chat lockdown | Waiting asks: go out (printed, never sent)",
    }
    for kind, text in pairs(want) do assertEqual(lines(SP.StepTip({ kind = kind })), text, kind) end
    assertEqual(lines(SP.StepTip({ kind = "loot", n = 1 })), "Injects: 1 loot line | Through: the real loot handler (CHAT_MSG_LOOT)")
    local r = NS.Sim:PanelRows()
    assertEqual(lines(r[1].tip), "Builds: the item pool, from the Encounter Journal | Invents: the group | Opens: the window")
    assertEqual(lines(r[#r].tip), "Ends: the simulation | Cleans up: everything it made")
end)

test("sim panel: the scenarios carry their names, and the raids the sizes the picker offers", function()
    local NS = T.newAddon()
    local defs = NS.SimScenarioDefs.defs
    local names = {}
    for i, name in ipairs(NS.SimScenarioDefs.names) do names[i] = defs[name].label end
    assertEqual(table.concat(names, "|"), "Mythic+ key|Dungeon|Raid|Raid Finder|Delve|Open world")
    assertEqual(table.concat(defs.raid.sizes, ","), "9,12,15,19")
    assertEqual(table.concat(defs.lfr.sizes, ","), "9,12,15,19")
    assertNil(defs.key.sizes, "a party has no size")
end)

-- ---------------------------------------------------------------------------------------------
-- The panel: opening, the picker, the tick, docking
-- ---------------------------------------------------------------------------------------------

test("sim panel: `/dw sim` opens it with DropWatcher's title, `/dw sim panel` toggles it", function()
    local NS, m = addon()
    slash(NS, "sim")
    assertTrue(NS.Sim:IsPanelShown())
    assertEqual(m.simPanel.title:GetText(), "Ka0s Drop Watcher - Simulation")
    slash(NS, "sim panel")
    assertFalse(NS.Sim:IsPanelShown())
    slash(NS, "sim panel")
    assertTrue(NS.Sim:IsPanelShown())
    NS.Sim:HidePanel()
    assertFalse(NS.Sim:IsPanelShown())
end)

test("sim panel: picking Raid offers its sizes, and Start starts it at the chosen size", function()
    local NS, m = addon()
    assertTrue(NS.Sim:ShowPanel())
    local pk = m.simPanel.picker
    assertFalse(pk.size:IsShown(), "no member count for a key")
    pk.scenario.onSelect("raid")
    assertTrue(pk.size:IsShown(), "a raid takes a member count")
    pk.size.onSelect(15)
    local r = NS.Sim:PanelRows()
    assertEqual(r[1].label, "Start: Raid"); assertEqual(r[1].command, "/dw sim start raid 15")
    pk.start:__fire("OnClick")
    assertTrue(NS.Sim:IsActive())
    assertEqual(NS.SimScenario.Status().scenario, "raid")
    assertEqual(#NS.SimRoster.Get(), 15)
    slash(NS, "sim stop")
end)

test("sim panel: the controls are Pause, Restart and Stop", function()
    local NS, m = addon()
    assertTrue(NS.Sim:ShowPanel())
    m.simPanel.picker.scenario.onSelect("world")
    m.simPanel.picker.start:__fire("OnClick")
    assertTrue(NS.Sim:IsActive())
    local c = m.simPanel.controls
    -- red under: LibKa0s v1.75.2, whose footer carried Run all
    assertNil(c.run, "no Run all")
    assertEqual(c.pause.__label, "Pause"); assertTrue(c.pause:IsEnabled(), "the picker's Start plays at once")
    assertTrue(NS.SimScenario.Status().playing)
    assertTrue(c.restart ~= nil and c.stop ~= nil)
    m.advance(0)
    assertEqual(NS.SimScenario.Status().pos, 1, "it plays with nothing pressed")
    slash(NS, "sim stop")
end)

test("sim panel: a played step shows the catalog's confirm tick and names its boss", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.Sim:ShowPanel())
    slash(NS, "sim step"); slash(NS, "sim step")
    local b = m.simPanel.__rowButtons[2]
    assertEqual(b.__state, "done")
    assertEqual(b.check:GetTexture(), NS.Icon("confirm"))
    assertEqual(b.__label, "Pull: Warden Ashvane")
end)

test("sim panel: opened after `/dw sim start`, it docks beside the Drop Watcher window", function()
    local NS, m = addon()
    slash(NS, "sim start dungeon")
    assertTrue(NS.Window.IsShown())
    assertTrue(NS.Sim:ShowPanel())
    local pt = { m.simPanel:GetPoint(1) }
    assertEqual(pt[1], "TOPLEFT"); assertTrue(pt[2] == NS.Window.Frame()); assertEqual(pt[3], "TOPRIGHT")
    assertEqual(m.simPanel.__dock, "right")
end)

test("sim panel: opened before the window, it docks beside the window once a slow pool opens it", function()
    local NS, m = addon()
    for _, byDifficulty in pairs(m.journal.loot) do
        for _, list in pairs(byDifficulty) do
            for _, e in ipairs(list) do e.loadsNeeded = 1 end
        end
    end
    slash(NS, "sim start dungeon")
    slash(NS, "sim pause")   -- the typed start plays on its own (LibKa0s v1.76.0); this case is about docking
    assertTrue(NS.Sim:ShowPanel())
    assertFalse(NS.Window.IsShown(), "the pool is still loading: no window yet")
    assertEqual(m.simPanel.__dock, "float")
    m.loadJournal()
    m.advance(NS.SimPool.SETTLE)
    assertTrue(NS.Window.IsShown(), "the ready pool opened the window")
    assertEqual(m.simPanel.__dock, "right", "re-docked beside the window, not over it")
    local pt = { m.simPanel:GetPoint(1) }
    assertEqual(pt[1], "TOPLEFT"); assertTrue(pt[2] == NS.Window.Frame())
end)

-- ---------------------------------------------------------------------------------------------
-- The session-only position and the stand-down
-- ---------------------------------------------------------------------------------------------

test("sim panel: dragging writes nothing to the profile; Reset position redocks", function()
    local NS, m = addon()
    NS.ShowWindow()
    assertTrue(NS.Sim:ShowPanel())
    local f = m.simPanel
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "TOPLEFT", 40, -60)
    f:__fire("OnDragStop")
    assertEqual(f.__dock, "dragged")
    NS.Sim:HidePanel(); NS.Sim:ShowPanel()
    assertEqual(f.__dock, "dragged", "the dragged point holds for the session")
    assertNil(NS.addon.db.profile.simPanel, "nothing written to SavedVariables (OWNER_SCOPE C.11)")
    NS.Window.ResetPosition()
    assertEqual(f.__dock, "right", "Reset position forgets the point and docks it beside the window")
    assertNil(NS.addon.db.profile.simPanel)
end)

test("sim panel: standing down hides it, idle or running, and it does not open while stood down", function()
    local NS = addon()
    assertTrue(NS.Sim:ShowPanel())
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Sim:IsPanelShown(), "an idle panel closes too")
    assertFalse(NS.Sim:ShowPanel(), "refused while stood down")
    slash(NS, "sim panel")
    assertFalse(NS.Sim:IsPanelShown(), "the typed verb is refused as well")
    NS.SchemaRuntime.Set("enabled", true)
    slash(NS, "sim start key")
    assertTrue(NS.Sim:ShowPanel())
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.Sim:IsActive()); assertFalse(NS.Sim:IsPanelShown())
end)
