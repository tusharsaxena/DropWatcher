local _, NS = ...
-- modules/SimScenario.lua — the simulator's scenarios and their timeline (simulator spec §4): what
-- `/dw sim start <scenario> [size]` builds, and what `/dw sim run` and `/dw sim step` play.
--
-- A SCENARIO (SCENARIOS) names the situation it simulates, the kind of group (a party of four, or
-- a raid of 9 to 19 members besides you, sized by the verb's argument or at random), how many
-- bosses its timeline plays and how large each loot burst is. Start starts the session
-- (NS.Sim.Start, with its refusals), builds the pool (modules/SimPool.lua, which may wait for the
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
-- STEP_DELAY seconds, on the session's timers (NS.Sim.After), so the stop ends it. Nothing here
-- sets a verdict, a trade estimate or an inspect state: each step is an event driver, and the
-- engine computes the rest.
--
--   State.sim.timeline = { steps = { { kind, n } }, pos, playing (timer) | nil, ready, size, band }

NS.SimScenario = NS.SimScenario or {}
local SC = NS.SimScenario
local Sim = NS.Sim
local L = NS.L

local TAG = "SIM"

--- Seconds between two steps while the timeline plays.
SC.STEP_DELAY = 3

--- name -> { situation, kind, bosses, keystone, burst (loot lines per burst; nil: 1 to 3 at
--- random), band (the members' item-level offsets around the content's level; nil: the roster's
--- default) }.
SC.SCENARIOS = {
    key     = { situation = "mythicPlus",     kind = "party", bosses = 3, keystone = true, burst = 2 },
    dungeon = { situation = "dungeon",        kind = "party", bosses = 3, burst = 3 },
    raid    = { situation = "raid",           kind = "raid",  bosses = 2, burst = 5 },
    lfr     = { situation = "raidLFR",        kind = "raid",  bosses = 2, burst = 4 },
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
    local s = Sim.Session()
    return s and s.timeline
end

-- Each step kind's event driver. Answers whether it did something, and what, for the step's line.
local function lootDetail(n)
    if n == 1 then return L["1 drop"] end
    return L["%d drops"]:format(n)
end

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
    lockdownOn  = function() return Sim.SetLockdown(true) end,
    lockdownOff = function() return Sim.SetLockdown(false) end,
    loot        = function(step)
        local n = NS.SimEvents.Loot(step.n)
        return n > 0, lootDetail(n)
    end,
}

--- The chat line of a played step (sim feedback §0: every step gets one, typed or played):
--- `Simulation step 3 of 11: loot (2 drops).`
--- @param pos number
--- @param total number
--- @param kind string
--- @param detail string|nil
--- @return string
function SC.StepLine(pos, total, kind, detail)
    local what = kind
    if detail then what = L["%s (%s)"]:format(kind, detail) end
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
    local did, detail = PLAY[step.kind](step)
    NS.Debug(TAG, "timeline step %d/%d: %s%s", t.pos, #t.steps, step.kind, did and "" or " (nothing to do)")
    NS.Print(SC.StepLine(t.pos, #t.steps, step.kind, detail))
    return step
end

local tick

-- One step of a playing timeline, and the next one set for later while any is left.
tick = function(t)
    t.playing = nil
    if timeline() ~= t then return end
    SC.Step()
    if t.steps[t.pos + 1] then
        t.playing = Sim.After(SC.STEP_DELAY, function() tick(t) end)
    else
        NS.Debug(TAG, "timeline finished")
        NS.Print(L["The simulation's timeline has finished. /dw sim stop ends it."])
    end
end

--- Play the rest of the timeline, one step now and one every STEP_DELAY seconds. Answers true, or
--- false and why: `notRunning`, `building`, `done`, `playing`.
--- @return boolean, string|nil
function SC.Run()
    local t = timeline()
    if not t then return false, "notRunning" end
    if not t.ready then return false, "building" end
    if t.playing then return false, "playing" end
    if not t.steps[t.pos + 1] then return false, "done" end
    NS.Debug(TAG, "timeline plays from step %d", t.pos + 1)
    tick(t)
    return true
end

--- The timeline at a glance: { scenario, ready, pos, steps, playing, next }; nil when none runs.
--- @return table|nil
function SC.Status()
    local s = Sim.Session()
    local t = s and s.timeline
    if not t then return nil end
    local nxt = t.steps[t.pos + 1]
    return { scenario = s.scenario, ready = t.ready == true, pos = t.pos, steps = #t.steps,
        playing = t.playing ~= nil, next = nxt and nxt.kind }
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────

-- The pool is ready: the group is drawn and forms, and the window opens.
local function ready(s, def, t)
    if Sim.Session() ~= s then return end
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
end

--- Start scenario `name` (spec §4): the session (refused, with the line printed, per
--- NS.Sim.Refusal), its pool, then its group and the window. `size` sizes a raid's group;
--- `opts` = { seed, classFilter = `mine`|`any`, band = { low, high } (the members' item-level
--- offsets around the content's level; the scenario's, else modules/SimRoster.lua's default) }.
--- Answers true, or false and why: `unknown` (no such scenario), `refused`.
--- @param name string
--- @param size number|nil
--- @param opts table|nil
--- @return boolean, string|nil
function SC.Start(name, size, opts)
    local def = SC.SCENARIOS[name]
    if not def then return false, "unknown" end
    opts = type(opts) == "table" and opts or {}
    if not Sim.Start({ scenario = name, situation = def.situation, seed = opts.seed }) then
        return false, "refused"
    end
    local s = Sim.Session()
    s.seed = s.seed or math.floor(GetTime() * 1000)
    local t = { steps = SC.Timeline(def), pos = 0, size = tonumber(size), band = opts.band or def.band }
    s.timeline = t
    NS.SimPool.Build({ situation = def.situation, classFilter = opts.classFilter },
        function() ready(s, def, t) end)
    return true
end
