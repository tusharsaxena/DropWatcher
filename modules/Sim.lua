local _, NS = ...
-- modules/Sim.lua — the simulator's session (simulator spec §1, §2, §5): start and stop, the
-- refusals, the automatic stop, the session-only history log, the simulated restrictions and the
-- event delivery every simulated input goes through.
--
-- THE PRINCIPLE (spec §1). The simulator invents the world's inputs at the edges and the real
-- engine computes everything else. It answers client calls through the seam (NS.Sim.Answer,
-- core/SimSeam.lua, consulted by every NS.Compat member) and delivers game events through Fire,
-- which calls the very handlers the event registration calls, in the same order, with the same
-- payload shapes. It never sets a verdict, a trade estimate or an inspect state itself. Test mode's
-- placeholders (modules/TestMode.lua) are the opposite: the two are exclusive.
--
--   State.sim = { sim = true, scenario, situation, startedAt, seed, guids = { [guid] = true },
--                 timers = { [handle] = true }, restrictions = { [type value] = true },
--                 lockdown, log = { v, groups }, events,
--                 pool, poolBuild,   -- modules/SimPool.lua's (the item pool and its build)
--                 members,           -- modules/SimRoster.lua's (the invented group and its gear)
--                 world, drive }     -- modules/SimWorld.lua's and modules/SimEvents.lua's
--   Only the simulator's own modules write their fields; everything else reads them.
--
-- SAFETY (spec §5).
--   * Start refuses while stood down, while a simulation already runs, while test mode is on, in
--     combat, inside an instance and in a real group, and says which (Refusal). The real world is
--     read through NS.Sim.Live, so a simulated answer never hides it.
--   * It stops by itself when the player joins a real group or enters an instance (the shared
--     GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA rows, which come first,
--     so it stops before any other handler reads the client), and when the addon stands down.
--     Nothing about it is saved, so a /reload or a logout ends it too.
--   * Nothing is sent: the seam's guarded ChatSender prints `[sim]` lines (core/SimSeam.lua).
--   * Saved history is never written: while it runs, modules/History.lua writes this session's
--     own log (HistoryLog), which the stop lets go.
--   * No real inspect and no real trade: the seam's guarded members never reach the client.
--   * Stop cleans everything, in this order: its timers; every queued ask, canceled while the
--     seam still guards the sender, so nothing queued can go out once it has ended; then, with the
--     seam off, the later items' cleanup steps (AddCleanup), the simulated restrictions lifted
--     through the restriction event, the waiting automatic asks of its drops and the drops
--     themselves with their groups and the encounter context (NS.LootFeed.RemoveWhere), the inspect
--     entries of its members, the roster, the log, the trade timer's entries (a fresh scan) and the
--     situation (the classifier re-reads the real one).
--     Every step runs under pcall, so one that raises never skips the rest (nor the stand-down).
--   * Everything it invents carries `sim = true` (the session, the feed's drops, the history
--     entries), so a stray one is identifiable. Only what Fire delivers is invented (IsDelivering):
--     a real loot line or trade that arrives while a simulation runs stays real and is saved.

local Sim = NS.Sim
local State = NS.State
local L = NS.L

local TAG = "SIM"

local cleanups = {}

local STOP_TEXT = {
    stop      = "Simulation stopped.",
    group     = "Simulation stopped: you joined a group.",
    instance  = "Simulation stopped: you entered an instance.",
    standDown = "Simulation stopped: the addon was disabled.",
}

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

--- True while a simulation runs.
--- @return boolean
function Sim.IsActive()
    return Sim.active == true
end

--- The running simulation's session table, or nil. Read it; only the simulator's own modules
--- (SimPool, SimRoster) write their fields.
--- @return table|nil
function Sim.Session()
    return State.sim
end

--- The session-only history log modules/History.lua writes while a simulation runs, else nil.
--- @return table|nil
function Sim.HistoryLog()
    local s = State.sim
    return s and s.log or nil
end

--- Record a GUID the simulation invented (a member), so the stop forgets it everywhere.
--- @param guid string
function Sim.MarkGUID(guid)
    local s = State.sim
    if s and type(guid) == "string" then s.guids[guid] = true end
end

--- True when the running simulation invented this GUID.
--- @param guid any
--- @return boolean
function Sim.IsSimGUID(guid)
    local s = State.sim
    return s ~= nil and guid ~= nil and s.guids[guid] == true
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- The session at a glance: { active, scenario, situation, startedAt, members, sends, handOvers,
--- events, restrictions, lockdown, groups }; only `active`, `sends` and `handOvers` when none runs.
--- @return table
function Sim.Status()
    local s, c = State.sim, Sim.counts
    if not s then return { active = false, sends = c.sends, handOvers = c.handOvers } end
    return {
        active = true, scenario = s.scenario, situation = s.situation, startedAt = s.startedAt,
        members = count(s.guids), sends = c.sends, handOvers = c.handOvers, events = s.events,
        restrictions = count(s.restrictions), lockdown = s.lockdown, groups = #s.log.groups,
    }
end

-- The real world, read with the seam off: { inGroup, inInstance, inCombat }.
local function realWorld()
    return Sim.Live(function()
        local i = NS.Situations.ReadInputs()
        return { inGroup = i.inGroup or i.inRaid, inInstance = i.inInstance,
            inCombat = NS.Restrictions.InCombat() }
    end)
end

--- Why a simulation may not start now, as the line to print, or nil when it may (spec §5).
--- @return string|nil
function Sim.Refusal()
    local stoodDown = NS.StoodDownRefusal()
    if stoodDown then return stoodDown end
    if Sim.active then return L["A simulation is already running."] end
    if State.testMode then return L["Turn test mode off before starting a simulation."] end
    local w = realWorld()
    if w.inCombat then return L["A simulation cannot start in combat."] end
    if w.inInstance then return L["A simulation cannot start inside an instance."] end
    if w.inGroup then return L["A simulation cannot start in a group: leave it first."] end
    return nil
end

-- ── events and timers ───────────────────────────────────────────────────────────────────────

-- Every handler the registration of `event` calls, in row order, as the client would call them:
-- each one isolated, as the client's event dispatch isolates it, so a handler that raises never
-- unwinds into the driver that fired the event (its sequence and the timeline go on). The failure
-- is a SIM debug line.
local function deliver(event, ...)
    local DW, n = NS.addon, 0
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if row[1] == event then
            local ok, err = pcall(DW[row[2]], DW, event, ...)
            if not ok then
                NS.Debug(TAG, "handler %s for %s failed: %s", tostring(row[2]), tostring(event), NS.SafeToString(err))
            end
            n = n + 1
        end
    end
    return n
end

--- True only while Fire is delivering a simulated event: what its handlers make (a drop, a trade)
--- is the simulation's. A real event that arrives while a simulation runs is never delivered
--- through Fire, so what it makes stays real (spec §5: only what the simulator invented carries
--- `sim = true`).
--- @return boolean
function Sim.IsDelivering()
    return Sim.delivering == true
end

--- Deliver game event `event` with payload `...` to the handlers its registration calls (spec §2).
--- Answers how many ran: 0 while no simulation runs or while stood down (no event reaches a
--- stood-down addon).
--- @param event string
--- @return number
function Sim.Fire(event, ...)
    local s = State.sim
    if not (Sim.active and s) or NS.IsStoodDown() then return 0 end
    s.events = s.events + 1
    NS.Debug(TAG, "event %s", tostring(event))
    local outer = Sim.delivering
    Sim.delivering = true
    local n = deliver(event, ...)
    Sim.delivering = outer
    return n
end

--- Run `fn` after `delay` seconds while this simulation still runs; the stop cancels it. Nil when
--- none runs.
--- @param delay number
--- @param fn function
--- @return table|nil the timer
function Sim.After(delay, fn)
    local s = State.sim
    if not s then return nil end
    local t
    t = C_Timer.NewTimer(delay, function()
        s.timers[t] = nil
        if State.sim == s then fn() end
    end)
    s.timers[t] = true
    return t
end

--- Deliver `event` to its handlers with the simulation already ended: only for a stop's cleanup
--- step (AddCleanup), which undoes an edge the simulation raised (its combat, its bag items) once
--- the seam is off, so the handlers read the real client. Answers how many ran.
--- @param event string
--- @return number
function Sim.DeliverForCleanup(event, ...)
    if Sim.active or NS.IsStoodDown() then return 0 end
    NS.Debug(TAG, "cleanup event %s", tostring(event))
    return deliver(event, ...)
end

--- Add a step the stop runs, `fn(session)`, after the queued asks are canceled and the seam is off
--- (the later items' own state: the roster they invented, their pool). Called under pcall.
--- @param fn function
function Sim.AddCleanup(fn)
    cleanups[#cleanups + 1] = fn
end

-- ── restrictions ────────────────────────────────────────────────────────────────────────────

--- Turn a simulated restriction (an Enum.AddOnRestrictionType member name: Encounter,
--- ChallengeMode, Combat, ...) on or off. The client answers it as active while it is on, and the
--- change is delivered as ADDON_RESTRICTION_STATE_CHANGED (type, active), the event's boolean
--- payload shape. Answers whether anything changed.
--- @param name string
--- @param on boolean
--- @return boolean
function Sim.SetRestriction(name, on)
    local s = State.sim
    local rtype = s and NS.Compat.RestrictionTypes()[name]
    if rtype == nil then return false end
    on = on and true or nil
    if s.restrictions[rtype] == on then return false end
    s.restrictions[rtype] = on
    Sim.Fire("ADDON_RESTRICTION_STATE_CHANGED", rtype, on == true)
    return true
end

--- Turn the simulated chat-messaging lockdown on or off. The client has no event for it; the
--- restriction tracker reads it on its next refresh, which this asks for. Answers whether it moved.
--- @param on boolean
--- @return boolean
function Sim.SetLockdown(on)
    local s = State.sim
    if not s or s.lockdown == (on == true) then return false end
    s.lockdown = on == true
    NS.Debug(TAG, "chat lockdown %s", s.lockdown and "on" or "off")
    NS.Restrictions.Refresh("simLockdown")
    return true
end

-- The seam's providers for the two restriction readers, keyed by their NS.Compat member names
-- (written as fields, so test_compat's seam-only scan never mistakes a key for a client call).
local PROVIDERS = {}

function PROVIDERS.IsRestrictionActive(live, rtype)
    local s = State.sim
    if s and rtype ~= nil and s.restrictions[rtype] then return true end
    return live(rtype)
end

function PROVIDERS.InChatMessagingLockdown(live)
    local s = State.sim
    if s and s.lockdown then return true end
    return live()
end

for key, fn in pairs(PROVIDERS) do Sim.SetProvider(key, fn) end

-- ── start and stop ──────────────────────────────────────────────────────────────────────────

--- Start a simulation (spec §4, §5): refused, with the line printed, per Refusal. `opts` names the
--- scenario and the situation it simulates; the later items build the roster and the pool.
--- @param opts table|nil { scenario, situation, seed }
--- @return boolean started
--- @return string|nil refusal
function Sim.Start(opts)
    local refusal = Sim.Refusal()
    if refusal then
        NS.Print(refusal)
        return false, refusal
    end
    opts = type(opts) == "table" and opts or {}
    State.sim = {
        sim = true, scenario = opts.scenario or "custom", situation = opts.situation, startedAt = GetTime(),
        seed = tonumber(opts.seed),
        guids = {}, timers = {}, restrictions = {}, lockdown = false, log = { v = 1, groups = {} }, events = 0,
    }
    Sim.counts = { sends = 0, handOvers = 0 }
    Sim.active = true
    NS.Debug(TAG, "simulation started: %s (%s)", State.sim.scenario, tostring(opts.situation))
    NS.Print(L["Simulation started (%s): nothing is sent, and your saved history is not touched."]
        :format(State.sim.scenario))
    return true
end

local function cancelTimers(s)
    for t in pairs(s.timers) do t:Cancel() end
    s.timers = {}
end

local function runCleanups(s)
    for _, fn in ipairs(cleanups) do
        local ok, err = pcall(fn, s)
        if not ok then NS.Debug(TAG, "cleanup failed: %s", NS.SafeToString(err)) end
    end
end

-- Every simulated restriction lifted through its event, then the lockdown read again.
local function liftRestrictions(s)
    for rtype in pairs(s.restrictions) do
        deliver("ADDON_RESTRICTION_STATE_CHANGED", rtype, false)
    end
    NS.Restrictions.Refresh("simStop")
    if NS.AutoAsk then NS.AutoAsk.OnWorldChanged() end
end

local function isSim(rec) return rec.sim == true end

-- The simulation's drops: their waiting automatic asks, then the drops and their groups.
local function cleanFeed()
    local AA = NS.AutoAsk
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        if rec.sim and AA then AA.Cancel(rec.id, "simStop") end
    end
    NS.LootFeed.RemoveWhere(isSim, true)
end

local function forgetMembers(s)
    for guid in pairs(s.guids) do NS.Inspect.Forget(guid) end
end

local function refreshWindow()
    if NS.Window and NS.Window.IsShown() then NS.Window.Refresh() end
end

-- The stop's engine steps, in order. Each runs under pcall (step), so one that raises never skips
-- the rest, nor the stand-down steps after the stop.
local ENGINE_STEPS = {
    { "cleanups",     runCleanups },
    { "restrictions", liftRestrictions },
    { "feed",         function() cleanFeed() end },
    { "inspect",      forgetMembers },
    { "roster",       function() NS.Roster.Refresh("simStop") end },
    { "log",          function(s) NS.History.ReleaseLog(s.log) end },
    { "tradeTimer",   function() NS.TradeTimer.Scan("simStop") end },
    { "situation",    function() NS.Situations.Refresh("simStop") end },
    { "window",       refreshWindow },
}

local function cleanEngine(s)
    for _, step in ipairs(ENGINE_STEPS) do
        local ok, err = pcall(step[2], s)
        if not ok then NS.Debug(TAG, "stop step %s failed: %s", step[1], NS.SafeToString(err)) end
    end
end

--- End the running simulation and clean up everything it made (spec §5). `reason` is `stop` (the
--- player's), `group`, `instance` or `standDown`. Answers whether one was running.
--- @param reason string|nil
--- @return boolean
function Sim.Stop(reason)
    local s = State.sim
    if not (Sim.active and s) then return false end
    reason = STOP_TEXT[reason] and reason or "stop"
    cancelTimers(s)
    -- While the seam still guards the sender: a queued ask must never go out after the stop.
    local ok, err = pcall(NS.Asks.CancelQueued, "simStop")
    if not ok then NS.Debug(TAG, "stop step asks failed: %s", NS.SafeToString(err)) end
    Sim.active, State.sim, Sim.delivering = false, nil, nil
    cleanEngine(s)
    NS.Debug(TAG, "simulation stopped (%s): %d events, %d sends printed", reason, s.events, Sim.counts.sends)
    NS.Print(L[STOP_TEXT[reason]])
    return true
end

-- ── the automatic stop and the lifecycle ────────────────────────────────────────────────────

--- A world event: joining a real group or entering an instance ends the simulation (spec §5).
function Sim.OnWorldEvent()
    if not Sim.active then return end
    local w = realWorld()
    if w.inInstance then
        Sim.Stop("instance")
    elseif w.inGroup then
        Sim.Stop("group")
    end
end

-- Shared events (core/DropWatcher.lua's dispatcher): these rows come first in the TOC, so the
-- simulation is stopped before any other handler reads the client.
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSimWorldEvent" }
end

function NS.addon.OnSimWorldEvent()
    Sim.OnWorldEvent()
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    Sim.Stop("standDown")
end
