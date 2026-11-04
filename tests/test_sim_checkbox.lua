-- tests/test_sim_checkbox.lua — Master controls' Sim mode checkbox (R6-SIM, LibKa0s v1.85.0's
-- OptionsCompose minor 19, releasing.md's hosts-owe): the row is the composer's, driven by the
-- launcher's own pair (NS.IsSimMode / NS.ToggleSim, core/DropWatcher.lua), so the box, the
-- launcher's Sim mode entry and `/dw sim` are one act; the box follows the live state through the
-- sim's listener; Reset all settings stops a running sim and never starts one; nothing is stored.
-- Since R7-SIM (Ka0sAddonsCommonTasks docs/2026-11-04-SMOKE_ROUND7, call 2) the box reads "the
-- Simulation panel is shown or a sim runs": ticking opens the panel and the box stays ticked,
-- unticking stops a running sim and closes the panel, and the panel's OnShow / OnHide refresh it.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function simRow(NS)
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if row.path == "state.sim" then return row end
    end
end

test("sim checkbox: Master controls draws a session-only Sim mode row straight after Test mode", function()
    local NS = T.newAddon()
    -- red under: no isSimMode / toggleSim on settings/Panel.lua's MasterControls spec
    local row = simRow(NS)
    assertTrue(row ~= nil, "a state.sim row")
    assertEqual(row.label, "Sim mode")
    assertEqual(row.type, "bool")
    assertTrue(row.sessionOnly == true, "session-only: nothing stored")
    assertEqual(row.default, false)
    local rows, at, testAt = NS.addon.Settings.Schema, nil, nil
    for i, r in ipairs(rows) do
        if r.path == "state.sim" then at = i elseif r.path == "state.testMode" then testAt = i end
    end
    assertEqual(at, testAt + 1, "beside Test mode")
end)

test("sim checkbox: the launcher's pair is one NS pair the row reads", function()
    local NS = T.enableAddon()
    -- red under: the pair built inline in core/LauncherSetup.lua's descriptor
    assertEqual(type(NS.IsSimMode), "function")
    assertEqual(type(NS.ToggleSim), "function")
    local Sim = T.simBare(NS)
    assertFalse(NS.IsSimMode())
    assertEqual(NS.SchemaRuntime.Get("state.sim"), false)
    assertTrue(Sim:Start({ scenario = "test" }))
    assertTrue(NS.IsSimMode())
    assertEqual(NS.SchemaRuntime.Get("state.sim"), true, "the box reads the live sim")
    Sim:Stop()
    assertEqual(NS.SchemaRuntime.Get("state.sim"), false)
end)

test("sim checkbox: ticking it does what `/dw sim` does, the status and the sim panel", function()
    local NS = T.enableAddon()
    local Sim = T.simBare(NS)
    assertFalse(Sim:IsPanelShown())
    NS.SchemaRuntime.Set("state.sim", true)
    assertTrue(Sim:IsPanelShown(), "the bare verb's panel")
    assertFalse(Sim:IsActive(), "no scenario picked for the player")
    -- red under: isSimMode answering the running sim alone (R7-SIM: window shown or running)
    assertEqual(NS.SchemaRuntime.Get("state.sim"), true, "the open window keeps the box ticked")
    assertTrue(NS.addon.db.profile.state == nil or NS.addon.db.profile.state.sim == nil, "nothing stored")
end)

test("sim checkbox: unticking it stops a running sim; ticking a running sim changes nothing", function()
    local NS = T.enableAddon()
    local Sim = T.simBare(NS)
    assertTrue(Sim:Start({ scenario = "test" }))
    NS.SchemaRuntime.Set("state.sim", true)
    assertTrue(Sim:IsActive(), "a write of the value it holds is no toggle")
    NS.SchemaRuntime.Set("state.sim", false)
    assertFalse(Sim:IsActive(), "stopped")
end)

test("sim checkbox: Reset all settings stops a running sim and never starts one", function()
    local NS = T.enableAddon()
    local Sim = T.simBare(NS)
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertFalse(Sim:IsActive())
    assertFalse(Sim:IsPanelShown(), "an idle reset runs no verb")
    -- The reset brings up the first-run skin picker, whose preview is test mode (R6-PV), which a
    -- start refuses: take it down, as the player would, before starting.
    NS.HideSkinPicker()
    assertFalse(NS.State.testMode == true, "the picker's preview ended")
    assertTrue(Sim:Start({ scenario = "test" }))
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertFalse(Sim:IsActive(), "the reset walk wrote the row's default")
end)

test("sim checkbox: a sim started or stopped elsewhere refreshes the open page", function()
    local NS = T.enableAddon()
    local Sim = T.simBare(NS)
    local H = NS.addon.Settings.Helpers
    local was, n = H.RefreshScalars, 0
    H.RefreshScalars = function(...) n = n + 1; return was(...) end
    local ok, err = pcall(function()
        Sim:Start({ scenario = "test" })
        -- red under: no RefreshScalars from the sim's listener (modules/Sim.lua)
        assertTrue(n > 0, "the start refreshed the page")
        local after = n
        Sim:Stop()
        assertTrue(n > after, "the stop refreshed the page")
    end)
    H.RefreshScalars = was
    assert(ok, err)
end)

-- R7-SIM. The library's panel frame is a named global in the client (`DropWatcherSimPanel`); the
-- kit's CreateFrame sets no global, so these cases register it as the client would.
local function withPanelGlobal(m)
    local create = m.CreateFrame
    m.CreateFrame = function(kind, name, ...)
        local f = create(kind, name, ...)
        if name == "DropWatcherSimPanel" then m.DropWatcherSimPanel = f end
        return f
    end
end

local function simAddon()
    local NS, _, m = T.enableAddon()
    withPanelGlobal(m)
    return NS, T.simBare(NS), m
end

test("sim checkbox R7: the window open and idle reads ticked; closing it reads unticked", function()
    local NS, Sim, m = simAddon()
    NS.Sim:RunVerb("")
    assertTrue(Sim:IsPanelShown(), "`/dw sim` opened the window")
    assertFalse(Sim:IsActive())
    -- red under: isSimMode answering the running sim alone
    assertTrue(NS.IsSimMode(), "window shown, idle")
    assertEqual(NS.SchemaRuntime.Get("state.sim"), true)
    -- The window's own close button hides the frame directly, never through toggleSim.
    m.DropWatcherSimPanel:Hide()
    assertFalse(NS.IsSimMode(), "window closed, nothing running")
    assertEqual(NS.SchemaRuntime.Get("state.sim"), false)
end)

test("sim checkbox R7: a sim running with the window hidden reads ticked", function()
    local NS, Sim = simAddon()
    NS.Sim:RunVerb("")
    assertTrue(Sim:Start({ scenario = "test" }))
    Sim:HidePanel()
    assertFalse(Sim:IsPanelShown())
    assertTrue(NS.IsSimMode(), "running, window hidden")
    assertEqual(NS.SchemaRuntime.Get("state.sim"), true)
end)

test("sim checkbox R7: unticking a running sim stops it and closes the window", function()
    local NS, Sim = simAddon()
    NS.Sim:RunVerb("")
    assertTrue(Sim:Start({ scenario = "test" }))
    assertTrue(Sim:IsPanelShown())
    NS.SchemaRuntime.Set("state.sim", false)
    assertFalse(Sim:IsActive(), "stopped")
    -- red under: an untick that only stops the sim
    assertFalse(Sim:IsPanelShown(), "the window closed")
    assertEqual(NS.SchemaRuntime.Get("state.sim"), false)
end)

test("sim checkbox R7: unticking with the window open and idle closes it, and ticking reopens it", function()
    local NS, Sim = simAddon()
    NS.SchemaRuntime.Set("state.sim", true)
    assertTrue(Sim:IsPanelShown())
    NS.SchemaRuntime.Set("state.sim", false)
    -- red under: the old toggle, whose idle branch only re-ran the bare verb
    assertFalse(Sim:IsPanelShown(), "one untick closed the window")
    assertEqual(NS.SchemaRuntime.Get("state.sim"), false)
    NS.ToggleSim()
    assertTrue(Sim:IsPanelShown(), "the launcher's click opens it again")
    assertTrue(NS.IsSimMode())
end)

test("sim checkbox R7: the window's show and hide refresh the open page", function()
    local NS, _, m = simAddon()
    local H = NS.addon.Settings.Helpers
    local was, n = H.RefreshScalars, 0
    H.RefreshScalars = function(...) n = n + 1; return was(...) end
    local ok, err = pcall(function()
        NS.Sim:RunVerb("")
        -- red under: no refresh from the window's show (modules/Sim.lua's ShowPanel hook)
        assertTrue(n > 0, "the first show refreshed the page")
        local frame = m.DropWatcherSimPanel
        assertTrue(frame ~= nil, "the panel frame was built")
        -- The client runs OnHide / OnShow on every hide and show, the close button and Escape too.
        local before = n
        frame:Hide(); frame:__fire("OnHide")
        assertTrue(n > before, "the hide refreshed the page")
        before = n
        frame:Show(); frame:__fire("OnShow")
        assertTrue(n > before, "a later show refreshed the page")
    end)
    H.RefreshScalars = was
    assert(ok, err)
end)
