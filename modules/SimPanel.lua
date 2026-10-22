local _, NS = ...
-- modules/SimPanel.lua — the simulation step panel's DropWatcher half: the presentation fields of
-- LibKa0s-Sim-1.0's panel (DW-04, LibKa0s#53 #54; contract proof 3/3). The panel itself (its rows,
-- states, colors, run controls, scenario picker, click-ahead, placement and stand-down refusal) is
-- the library's (libs/LibKa0s/SimPanel.lua); this file says what DropWatcher's steps are called and
-- what their tooltips say.
--
-- NS.SimPanel.FIELDS is the Sim:New descriptor's `panel` (modules/Sim.lua creates the table and
-- passes it; this file fills it in place at load, the way modules/SimScenario.lua fills the
-- scenario defs; the library reads each field when it draws, so nothing is captured early):
--   title      `Ka0s Drop Watcher - Simulation`
--   stepLabel  each step's name, with the boss a pull or a kill names (`Pull: Warden Ashvane`) and
--              where a played loot step's drops went (`Loot: 3 drops (1 hidden)`, modules/SimReport.lua);
--              the library prints the same name in its `Simulation step 3 of 11: ...` line
--   stepTip    what the step injects and, for a played loot step, each drop and where it went, as
--              { left, right } lines (the library adds when a played step ran)
--   startTip, stopTip   what Start and Stop do
--   anchorTo   the Drop Watcher window while it is shown (the panel docks beside it), else nil
--   check      the catalog's `confirm` tick, the done mark (declared on the CLAUDE.md icons line)
-- No `button` and no `tooltip` (the library's own button and GameTooltip, OWNER_SCOPE C.7) and no
-- `store`: the panel's position is session-only (C.11), so a simulation writes nothing to
-- SavedVariables (core/Database.lua's migration 9 retired the old `profile.simPanel` point).
--
-- The picker's scenario names are each def's `label` (modules/SimScenario.lua).

NS.SimPanel = NS.SimPanel or {}
local SP = NS.SimPanel
local L  = NS.L

SP.FIELDS = SP.FIELDS or {}
local F = SP.FIELDS

-- What each timeline step is called, and what it injects (its tooltip).
local KIND_LABEL = {
    runStart = L["Key starts"], runEnd = L["Key complete"],
    lockdownOn = L["Combat and chat lockdown"], lockdownOff = L["Lockdown lifts"],
}

-- Each step's tooltip lines, { left, right } pairs.
local THROUGH = { L["Through"], L["the real handlers"] }
local KIND_TIP = {
    runStart    = { { L["Injects"], L["CHALLENGE_MODE_START, the ChallengeMode restriction"] }, THROUGH },
    runEnd      = { { L["Injects"], L["CHALLENGE_MODE_COMPLETED"] }, { L["Lifts"], L["the ChallengeMode restriction"] }, THROUGH },
    pull        = { { L["Injects"], L["ENCOUNTER_START, the combat edge, the Encounter restriction"] }, THROUGH },
    kill        = { { L["Injects"], L["ENCOUNTER_END"] }, { L["Lifts"], L["combat and the Encounter restriction"] }, THROUGH },
    lockdownOn  = { { L["Injects"], L["the simulated chat lockdown"] }, { L["Asks"], L["wait until it lifts"] } },
    lockdownOff = { { L["Lifts"], L["the chat lockdown"] }, { L["Waiting asks"], L["go out (printed, never sent)"] } },
}

local START_TIP = { { L["Builds"], L["the item pool, from the Encounter Journal"] }, { L["Invents"], L["the group"] },
    { L["Opens"], L["the window"] } }
local STOP_TIP = { { L["Ends"], L["the simulation"] }, { L["Cleans up"], L["everything it made"] } }

local function lineCount(n)
    if n == 1 then return L["1 loot line"] end
    if n then return L["%d loot lines"]:format(n) end
    return L["1 to 3 loot lines"]
end

-- A played loot step reads its report again (modules/SimReport.lua; feedback-3 spec §0), so a drop
-- still loading when it ran is placed once it lands: `Loot: 3 drops (1 hidden)`. It reads the window's
-- view each time too (SimReport.View: test mode; feedback-3 spec §5).
local function lootLabel(step)
    local R = NS.SimReport
    if step.report then return L["Loot: %s"]:format(R.Summarize(step.report, NS.LootFeed.Get, R.View()).text) end
    if step.detail then return L["Loot: %s"]:format(step.detail) end
    if step.n == 1 then return L["Loot: 1 drop"] end
    if step.n then return L["Loot: %d drops"]:format(step.n) end
    return L["Loot: 1 to 3 drops"]
end

-- The boss step `index` of `steps` is about: the one it named once played, else the simulator's
-- next name in its rotation (modules/SimEvents.lua's BOSSES, by pull count); a kill names the pull's.
local function bossOf(steps, index)
    local pulls, current = 0, nil
    local list = NS.SimEvents and NS.SimEvents.BOSSES or {}
    for i = 1, index do
        local step = steps[i]
        if type(step) == "table" and step.kind == "pull" then
            pulls = pulls + 1
            current = step.detail or list[(pulls - 1) % math.max(#list, 1) + 1]
        elseif i == index and type(step) == "table" then
            current = step.detail or current
        end
    end
    return current
end

--- A timeline step's name (the descriptor's `panel.stepLabel`). `steps` is the timeline the step
--- sits in and `i` its index there, so a pull or a kill names its boss before it has played.
--- @param step table { kind, n, detail, report }
--- @param i number|nil
--- @param steps table|nil
--- @return string
function SP.StepLabel(step, i, steps)
    local boss = step.detail
    if type(steps) == "table" and type(i) == "number" then boss = bossOf(steps, i) end
    if step.kind == "pull" then return L["Pull: %s"]:format(boss or "?") end
    if step.kind == "kill" then return L["Kill: %s"]:format(boss or "?") end
    if step.kind == "loot" then return lootLabel(step) end
    return KIND_LABEL[step.kind] or step.kind
end

--- A timeline step's tooltip lines, { left, right } pairs (the descriptor's `panel.stepTip`): what
--- it injects; a played loot step names each drop, its looter and where it went.
--- @param step table
--- @return table lines
function SP.StepTip(step)
    if step.kind ~= "loot" then return KIND_TIP[step.kind] or {} end
    local lines = { { L["Injects"], lineCount(step.n) }, { L["Through"], L["the real loot handler (CHAT_MSG_LOOT)"] } }
    if step.report then
        local R = NS.SimReport
        for _, line in ipairs(R.TipLines(step.report, NS.LootFeed.Get, R.View())) do lines[#lines + 1] = line end
    end
    return lines
end

F.title = function() return L["%s - Simulation"]:format(NS.BRAND) end
F.stepLabel = SP.StepLabel
F.stepTip = SP.StepTip
F.startTip = START_TIP
F.stopTip = STOP_TIP
-- The window while it is shown, so the panel docks beside it and never beside a hidden frame.
F.anchorTo = function()
    local W = NS.Window
    if W and W.IsShown() then return W.Frame() end
    return nil
end
F.check = NS.Icon("confirm")

-- Standing down closes the panel even with no simulation to stop: the library hides it on a
-- stand-down stop and refuses to open it while stood down, but an idle panel has no stop.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    NS.Sim:HidePanel()
end
