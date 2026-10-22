local _, NS = ...
-- modules/SimScenario.lua — the simulator's scenarios and their timeline (simulator spec §4): what
-- `/dw sim start <scenario> [size]` builds, and what `/dw sim run` and `/dw sim step` play.
--
-- A SCENARIO (SCENARIOS) names the situation it simulates, the kind of group (a party of four, or
-- a raid of 9 to 19 members besides you, sized by the verb's argument or at random), how many
-- bosses its timeline plays and how large each loot burst is. Each row is also the scenario's
-- def on LibKa0s-Sim-1.0 (NS.SimScenarioDefs, filled in place at load): its pure `timeline` and,
-- for a raid, the `sizes` the picker offers. Start starts the session (NS.Sim:Start, with its
-- refusals), whose prepare (Prepare) builds the pool (modules/SimPool.lua, which may wait for the
-- journal), then draws the group (modules/SimRoster.lua), forms it (NS.SimEvents.Join) and opens
-- the window. Until the pool is ready the timeline waits (`building`).
--
-- THE TIMELINE (Timeline, pure) is a list of steps, each one event driver call: a boss is
--   pull -> lockdownOn -> kill -> loot -> lockdownOff
-- (the pull raises combat and the Encounter restriction; the chat lockdown outlasts the kill, as
-- the client's may, so an ask made during the loot burst waits and goes out when it lifts). A key
-- starts the run first, plays its bosses without loot, and ends with the completion:
--   runStart, (pull, kill) x bosses, lockdownOn, runEnd, loot, lockdownOff
-- The step machine is LibKa0s-Sim-1.0's (SimTimeline.lua): NS.Sim:Step plays the next step through
-- Play (the descriptor's `play`, each step one event driver) and prints its line; NS.Sim:Run plays
-- them all, one every StepDelay() seconds (the descriptor's `stepDelay`: the `sim.stepDelay`
-- setting, read as each next step is set, so a change takes effect from the next step), on the
-- session's timers, so the stop ends it; Pause, Resume and Restart are the library's too. Each
-- step's line names its detail (Play sets the step's `label`: `kill (Warden Ashvane)`). Nothing here
-- sets a verdict, a trade estimate or an inspect state: each step is an event driver, and the
-- engine computes the rest.
--
-- SC.Step, Run, Pause, Resume, Restart, Steps, Status and AddListener are one-line delegations to
-- NS.Sim (Status reshaped for the panel and the verbs) until the slash verbs and the step panel move
-- onto the library (DW-03, DW-04).

NS.SimScenario = NS.SimScenario or {}
local SC = NS.SimScenario
local Sim = NS.Sim
local L = NS.L

local TAG = "SIM"

--- Seconds between two steps while the timeline plays, by default (the `sim.stepDelay` setting's
--- default, defaults/Profile.lua), and the setting's range and step (feedback-2 spec §8).
SC.STEP_DELAY = NS.C.PROFILE.sim.stepDelay
SC.STEP_DELAY_MIN, SC.STEP_DELAY_MAX, SC.STEP_DELAY_STEP = 0.5, 10, 0.5

--- Whether `v` is a step delay the setting takes (pure): a number from 0.5 to 10, in steps of 0.5.
--- @param v any
--- @return boolean
function SC.ValidStepDelay(v)
    if type(v) ~= "number" or v ~= v or v < SC.STEP_DELAY_MIN or v > SC.STEP_DELAY_MAX then return false end
    local n = v / SC.STEP_DELAY_STEP
    return n == math.floor(n)
end

--- The seconds an automatic run waits between steps now: the setting, or the default when it is
--- not a value the setting takes.
--- @return number
function SC.StepDelay()
    local v = NS.Setting and NS.Setting("sim.stepDelay")
    if SC.ValidStepDelay(v) then return v end
    return SC.STEP_DELAY
end

--- A delay as the tooltip says it (pure): a whole number without its point, else one decimal.
--- @param v number
--- @return string
function SC.DelayText(v)
    if v == math.floor(v) then return ("%d"):format(v) end
    return ("%.1f"):format(v)
end

--- name -> { situation, kind, bosses, keystone, burst (loot lines per burst; nil: 1 to 3 at
--- random), band (the members' item-level offsets around the content's level; nil: the roster's
--- default), sizes (a raid's group sizes besides you, which the picker offers; the library adds 0,
--- random), timeline (SC.Timeline, set below) }.
SC.SCENARIOS = {
    key     = { situation = "mythicPlus",     kind = "party", bosses = 3, keystone = true, burst = 2 },
    dungeon = { situation = "dungeon",        kind = "party", bosses = 3, burst = 3 },
    raid    = { situation = "raid",           kind = "raid",  bosses = 2, burst = 5, sizes = { 9, 12, 15, 19 } },
    lfr     = { situation = "raidLFR",        kind = "raid",  bosses = 2, burst = 4, sizes = { 9, 12, 15, 19 } },
    delve   = { situation = "delve",          kind = "party", bosses = 1, burst = 3 },
    world   = { situation = "openWorldGroup", kind = "party", bosses = 1, burst = 3 },
}

--- The scenario names, in the order the usage line lists them.
SC.NAMES = { "key", "dungeon", "raid", "lfr", "delve", "world" }

-- ── the timeline (pure) ─────────────────────────────────────────────────────────────────────

local function add(steps, kind, n)
    steps[#steps + 1] = { kind = kind, n = n }
end

local function boss(steps, burst)
    add(steps, "pull"); add(steps, "lockdownOn"); add(steps, "kill")
    add(steps, "loot", burst); add(steps, "lockdownOff")
end

local function keystone(steps, def)
    add(steps, "runStart")
    for _ = 1, def.bosses do
        add(steps, "pull"); add(steps, "kill")
    end
    add(steps, "lockdownOn"); add(steps, "runEnd"); add(steps, "loot", def.burst); add(steps, "lockdownOff")
end

--- A scenario's timeline (pure): its steps, each { kind, n }, kind one of runStart, runEnd, pull,
--- kill, lockdownOn, lockdownOff, loot (n lines; nil for 1 to 3 at random).
--- @param def table a SCENARIOS row
--- @return table steps
function SC.Timeline(def)
    local steps = {}
    if type(def) ~= "table" then return steps end
    if def.keystone then
        keystone(steps, def)
    else
        for _ = 1, def.bosses or 1 do boss(steps, def.burst) end
    end
    return steps
end

-- ── the steps ───────────────────────────────────────────────────────────────────────────────

-- Each step kind's event driver. Answers whether it did something, and what, for the step's line.
-- Play (the descriptor's `play`) runs one.
local PLAY = {
    runStart    = function() return NS.SimEvents.RunStart() ~= nil end,
    runEnd      = function() return NS.SimEvents.RunEnd() ~= nil end,
    pull        = function()
        local enc = NS.SimEvents.Pull()
        return enc ~= nil, enc and enc.name
    end,
    kill        = function()
        local enc = NS.SimEvents.Kill()
        return enc ~= nil, enc and enc.name
    end,
    lockdownOn  = function() return NS.SimHost.SetLockdown(true) end,
    lockdownOff = function() return NS.SimHost.SetLockdown(false) end,
    -- Kept on the step: where its drops went (modules/SimReport.lua; feedback-3 spec §0), which the
    -- panel's row and tooltip read again on every repaint.
    loot        = function(step)
        local R = NS.SimReport
        local n, _, report = R.Loot(step.n)
        step.report = report
        return n > 0, R.Summarize(report, NS.LootFeed.Get, R.View()).text
    end,
}

--- A played step's name in its chat line (sim feedback §0: every step gets one, typed or played):
--- `kill (Warden Ashvane)`; a loot step says where its drops went (feedback-3 spec §0):
--- `loot: 3 drops (1 hidden)`. The library prints it as `Simulation step 3 of 11: <label>.`
--- @param kind string
--- @param detail string|nil
--- @return string
function SC.StepLabel(kind, detail)
    if not detail then return kind end
    return (kind == "loot" and L["%s: %s"] or L["%s (%s)"]):format(kind, detail)
end

--- Play one timeline step through its event driver (the descriptor's `play`, which the library
--- runs for NS.Sim:Step, every Run tick and the panel's click-ahead): answers its detail, and sets
--- the step's `label` for the line the library prints.
--- @param step table
--- @return string|nil detail
function SC.Play(step)
    local did, detail = PLAY[step.kind](step)
    local st = Sim:Status()
    NS.Debug(TAG, "timeline step %d/%d: %s%s", st.pos, st.total, step.kind, did and "" or " (nothing to do)")
    step.label = SC.StepLabel(step.kind, detail)
    return detail
end

-- ── the library's step machine ──────────────────────────────────────────────────────────────

SC.Step = function() return Sim:Step() end
SC.Run = function() return Sim:Run() end
SC.Pause = function() return Sim:Pause() end
SC.Resume = function() return Sim:Resume() end
SC.Restart = function() return Sim:Restart() end
SC.AddListener = function(fn) Sim:AddListener(fn) end

--- The running timeline's steps, each { kind, n, label, ranAt, detail, index } (the last four once
--- played), for the panel to read; nil when none runs. Read it; only the library and Play write it.
--- @return table|nil
function SC.Steps()
    if not Sim:IsActive() then return nil end
    return Sim:Steps()
end

--- The timeline at a glance, from NS.Sim:Status(): { scenario, ready, pos, steps, playing, paused,
--- next, size (nil: random, or a party) }; nil when none runs.
--- @return table|nil
function SC.Status()
    local st = Sim:Status()
    if not st.active then return nil end
    local nxt = Sim:Steps()[st.pos + 1]
    return { scenario = st.scenario, ready = st.ready == true, pos = st.pos, steps = st.total,
        playing = st.playing == true, paused = st.paused == true, next = nxt and nxt.kind,
        size = st.size ~= 0 and st.size or nil }
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────

-- The pool is ready: the group is drawn and forms, the window opens, and the session is ready. A
-- callback from an earlier session (a restart while its pool was building) does nothing (C.1).
local function poolReady(s, def, opts, ready)
    if Sim:Session() ~= s then return end
    local members = NS.SimRoster.Create({ kind = def.kind, size = opts.size, seed = s.seed, band = opts.band })
    NS.SimEvents.Join()
    local pool = NS.SimPool.Status()
    NS.Debug(TAG, "scenario %s ready: %d members, %d pool items (%s)", s.scenario, #members, pool.size,
        tostring(pool.source))
    NS.Print(L["Simulation ready: %d members, %d items. /dw sim run plays it, /dw sim step one event at a time."]
        :format(#members, pool.size))
    NS.ShowWindow()
    if NS.Window and NS.Window.IsShown() then NS.Window.Refresh() end
    ready()
end

--- Build a session's world (the descriptor's `prepare`, after NS.SimHost.Begin): its pool, then its
--- group and the window, and `ready()` once they stand. `opts` is the start's: { scenario, size (0:
--- random), seed, band, classFilter }.
--- @param s table the library's session
--- @param def table the scenario's SCENARIOS row
--- @param opts table
--- @param ready function
function SC.Prepare(s, def, opts, ready)
    local size = tonumber(opts.size)
    local plan = { size = size ~= 0 and size or nil, band = opts.band or def.band }
    -- The build's timers are the session's (NS.Sim:After, inside SimPool.Build), so the stop ends it.
    NS.SimPool.Build({ situation = s.situation, classFilter = opts.classFilter },
        function() poolReady(s, def, plan, ready) end)
end

--- Start scenario `name` (spec §4): the session (refused, with the line printed, by NS.Sim:Start:
--- an unknown scenario among them), its pool, then its group and the window (Prepare). `size`
--- sizes a raid's group; `opts` = { seed, classFilter = `mine`|`any`, band = { low, high } (the
--- members' item-level offsets around the content's level; the scenario's, else
--- modules/SimRoster.lua's default) }. Answers true, or false and `refused`.
--- @param name string
--- @param size number|nil
--- @param opts table|nil
--- @return boolean, string|nil
function SC.Start(name, size, opts)
    opts = type(opts) == "table" and opts or {}
    -- DropWatcher's own seed when the start names none: the client clock in milliseconds.
    local ok = Sim:Start({ scenario = name, size = size, seed = opts.seed or math.floor(GetTime() * 1000),
        band = opts.band, classFilter = opts.classFilter })
    if not ok then return false, "refused" end
    return true
end

-- ── the scenarios on LibKa0s-Sim-1.0 ────────────────────────────────────────────────────────

-- Each SCENARIOS row is its def: the library reads `timeline` and `sizes` (and `label`, absent
-- here, so its lines name the scenario).
do
    local defs = NS.SimScenarioDefs
    for i, name in ipairs(SC.NAMES) do
        local def = SC.SCENARIOS[name]
        def.timeline = SC.Timeline
        defs.names[i], defs.defs[name] = name, def
    end
end

-- The last simulator module to load: the stop's engine steps follow every module's own.
NS.SimHost.RegisterStopSteps()
