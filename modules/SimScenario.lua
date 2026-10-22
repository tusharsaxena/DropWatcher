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
-- Step plays the next step and prints its line (StepLine); Run plays them all, one every
-- StepDelay() seconds (the `sim.stepDelay` setting, read as each next step is set, so a change takes
-- effect from the next step), on the session's timers (NS.Sim:After), so the stop ends it. Nothing here
-- sets a verdict, a trade estimate or an inspect state: each step is an event driver, and the
-- engine computes the rest.
--
--   NS.Sim:Session().timeline = { steps = { { kind, n, ranAt, detail, report } }, pos, playing (timer) | nil, paused,
--                          ready, size, band }
--
-- Pause, Resume and Restart are the panel's run controls (and `/dw sim pause|resume|restart`);
-- every move is told to the listeners (AddListener), which the panel repaints on.

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

-- ── the session's timeline ──────────────────────────────────────────────────────────────────

local function timeline()
    local s = Sim:Session()
    return s and s.timeline
end

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

--- Play one timeline step through its event driver (the descriptor's `play`): answers its detail.
--- @param step table
--- @return string|nil detail
function SC.Play(step)
    local did, detail = PLAY[step.kind](step)
    local t = timeline() or { pos = 0, steps = {} }
    NS.Debug(TAG, "timeline step %d/%d: %s%s", t.pos, #t.steps, step.kind, did and "" or " (nothing to do)")
    return detail
end

--- The chat line of a played step (sim feedback §0: every step gets one, typed or played):
--- `Simulation step 3 of 11: kill (Warden Ashvane).`; a loot step says where its drops went
--- (feedback-3 spec §0): `Simulation step 10 of 11: loot: 3 drops (1 hidden).`
--- @param pos number
--- @param total number
--- @param kind string
--- @param detail string|nil
--- @return string
function SC.StepLine(pos, total, kind, detail)
    local what = kind
    if detail then what = (kind == "loot" and L["%s: %s"] or L["%s (%s)"]):format(kind, detail) end
    return L["Simulation step %d of %d: %s."]:format(pos, total, what)
end

--- Play the timeline's next step and print its line. Answers the step, or nil and why:
--- `notRunning`, `building` (the pool is not ready yet), `done` (no step left).
--- @return table|nil step, string|nil why
function SC.Step()
    local t = timeline()
    if not t then return nil, "notRunning" end
    if not t.ready then return nil, "building" end
    local step = t.steps[t.pos + 1]
    if not step then return nil, "done" end
    t.pos = t.pos + 1
    local detail = SC.Play(step)
    -- Kept on the step for the panel (modules/SimPanel.lua): when it ran (time(), the session's
    -- clock), and what it did.
    step.ranAt, step.detail = time(), detail
    NS.Print(SC.StepLine(t.pos, #t.steps, step.kind, detail))
    SC.Notify()
    return step
end

local tick

-- One step of a playing timeline, and the next one set for later while any is left. The next timer
-- is set BEFORE the step runs, so the listeners the step notifies already see the timeline playing
-- (the panel keeps Pause live and Run all spent through an automatic run).
tick = function(t)
    t.playing = nil
    if timeline() ~= t then return end
    if t.steps[t.pos + 2] then
        t.playing = Sim:After(SC.StepDelay(), function() tick(t) end)
    end
    SC.Step()
    if not t.playing then
        NS.Debug(TAG, "timeline finished")
        NS.Print(L["The simulation's timeline has finished. /dw sim stop ends it."])
        SC.Notify()
    end
end

--- Play the rest of the timeline, one step now and one every StepDelay() seconds. Answers true, or
--- false and why: `notRunning`, `building`, `done`, `playing`.
--- @return boolean, string|nil
function SC.Run()
    local t = timeline()
    if not t then return false, "notRunning" end
    if not t.ready then return false, "building" end
    if t.playing then return false, "playing" end
    if not t.steps[t.pos + 1] then return false, "done" end
    NS.Debug(TAG, "timeline plays from step %d", t.pos + 1)
    t.paused = nil
    tick(t)
    SC.Notify()
    return true
end

--- Pause a playing timeline: its next step is not played until Resume (or Run, or a Step). Answers
--- true, or false and why: `notRunning`, `notPlaying`.
--- @return boolean, string|nil
function SC.Pause()
    local t = timeline()
    if not t then return false, "notRunning" end
    if not t.playing then return false, "notPlaying" end
    t.playing:Cancel()   -- the session's handle: canceled and forgotten
    t.playing, t.paused = nil, true
    NS.Debug(TAG, "timeline paused before step %d", t.pos + 1)
    SC.Notify()
    return true
end

--- Resume a paused timeline: it plays on from its next step, as Run does. Answers true, or false
--- and why: `notRunning`, `notPaused`, or Run's.
--- @return boolean, string|nil
function SC.Resume()
    local t = timeline()
    if not t then return false, "notRunning" end
    if not t.paused then return false, "notPaused" end
    return SC.Run()
end

--- The timeline at a glance: { scenario, ready, pos, steps, playing, next }; nil when none runs.
--- @return table|nil
function SC.Status()
    local s = Sim:Session()
    local t = s and s.timeline
    if not t then return nil end
    local nxt = t.steps[t.pos + 1]
    return { scenario = s.scenario, ready = t.ready == true, pos = t.pos, steps = #t.steps,
        playing = t.playing ~= nil, paused = t.paused == true, next = nxt and nxt.kind, size = t.size }
end

--- The running timeline's steps, each { kind, n, ranAt, detail } (ranAt and detail once played),
--- for the panel to read; nil when none runs. Read it; only this file writes it.
--- @return table|nil
function SC.Steps()
    local t = timeline()
    return t and t.steps
end

-- ── listeners ───────────────────────────────────────────────────────────────────────────────

local listeners = {}

--- Be told `fn()` whenever the timeline moves: a start, its pool ready, a step (typed, clicked or
--- played), a pause, a run, the end, and the stop (modules/SimPanel.lua repaints on it, so typing
--- and clicking stay in step). Listeners are never removed.
--- @param fn function
function SC.AddListener(fn)
    listeners[#listeners + 1] = fn
end

--- Tell every listener the timeline moved. Each runs under pcall, so one that raises never stops
--- the timeline.
function SC.Notify()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn)
        if not ok then NS.Debug(TAG, "timeline listener failed: %s", NS.SafeToString(err)) end
    end
end

-- The stop moves the timeline too (to nothing): every listener hears it, after the session is gone.
Sim:OnStop(function() SC.Notify() end)

-- ── start ───────────────────────────────────────────────────────────────────────────────────

-- The pool is ready: the group is drawn and forms, the window opens, and the session is ready. A
-- callback from an earlier session (a restart while its pool was building) does nothing.
local function poolReady(s, def, t, ready)
    if Sim:Session() ~= s then return end
    local members = NS.SimRoster.Create({ kind = def.kind, size = t.size, seed = s.seed, band = t.band })
    NS.SimEvents.Join()
    t.ready = true
    local pool = NS.SimPool.Status()
    NS.Debug(TAG, "scenario %s ready: %d members, %d pool items (%s)", s.scenario, #members, pool.size,
        tostring(pool.source))
    NS.Print(L["Simulation ready: %d members, %d items. /dw sim run plays it, /dw sim step one event at a time."]
        :format(#members, pool.size))
    NS.ShowWindow()
    if NS.Window and NS.Window.IsShown() then NS.Window.Refresh() end
    ready()
    SC.Notify()
end

--- Build a session's world (the descriptor's `prepare`, after NS.SimHost.Begin): its timeline, its
--- pool, then its group and the window, and `ready()` once they stand. `opts` is the start's:
--- { scenario, size (0: random), seed, band, classFilter }.
--- @param s table the library's session
--- @param def table the scenario's SCENARIOS row
--- @param opts table
--- @param ready function
function SC.Prepare(s, def, opts, ready)
    local size = tonumber(opts.size)
    if size == 0 then size = nil end
    local t = { steps = SC.Timeline(def), pos = 0, size = size, band = opts.band or def.band }
    s.timeline = t
    NS.SimPool.Build({ situation = s.situation, classFilter = opts.classFilter },
        function() poolReady(s, def, t, ready) end)
    SC.Notify()
end

--- Start scenario `name` (spec §4): the session (refused, with the line printed, by NS.Sim:Start),
--- its pool, then its group and the window (Prepare). `size` sizes a raid's group; `opts` = { seed,
--- classFilter = `mine`|`any`, band = { low, high } (the members' item-level offsets around the
--- content's level; the scenario's, else modules/SimRoster.lua's default) }. Answers true, or false
--- and why: `unknown` (no such scenario), `refused`.
--- @param name string
--- @param size number|nil
--- @param opts table|nil
--- @return boolean, string|nil
function SC.Start(name, size, opts)
    if not SC.SCENARIOS[name] then return false, "unknown" end
    opts = type(opts) == "table" and opts or {}
    -- DropWatcher's own seed when the start names none: the client clock in milliseconds.
    local ok = Sim:Start({ scenario = name, size = size, seed = opts.seed or math.floor(GetTime() * 1000),
        band = opts.band, classFilter = opts.classFilter })
    if not ok then return false, "refused" end
    return true
end

--- Stop the running scenario and start the same one again, at the same size, with a fresh seed.
--- Answers Start's answer, or false and `notRunning`.
--- @return boolean, string|nil
function SC.Restart()
    local s = Sim:Session()
    local t = s and s.timeline
    if not t then return false, "notRunning" end
    local name, size = s.scenario, t.size
    NS.Debug(TAG, "restarting %s", tostring(name))
    Sim:Stop("stop")
    return SC.Start(name, size)
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
