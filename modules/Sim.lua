local _, NS = ...
-- modules/Sim.lua — the simulator's session (simulator spec §1, §2, §5), on LibKa0s-Sim-1.0: the
-- Sim:New descriptor that binds NS.SimSeam (core/SimSetup.lua) to one session, published as NS.Sim,
-- and the host half every simulated session needs: the refusals, the automatic stop, the
-- session-only history log, the simulated restrictions and the stop's cleanup steps.
--
-- THE PRINCIPLE (spec §1). The simulator invents the world's inputs at the edges and the real
-- engine computes everything else. It answers client calls through the seam (the providers on
-- NS.SimSeam, consulted by every NS.Compat member) and delivers game events through NS.Sim:Fire,
-- which calls the very handlers the event registration calls, in the same order, with the same
-- payload shapes (NS.DeliverEvent, core/DropWatcher.lua, which skips an event the client
-- rejected). It never sets a verdict, a trade estimate or an inspect state itself. Test mode's
-- placeholders (modules/TestMode.lua) are the opposite: the two are exclusive.
--
-- THE SESSION is the library's table (NS.Sim:Session(): sim = true, scenario, size, seed,
-- startedAt, events); the host fields go on it (the host bag, OWNER_SCOPE C.4):
--   { situation, guids = { [guid] = true }, restrictions = { [type value] = true }, lockdown,
--     log = { v, groups },               -- NS.SimHost.Begin's, set as the session starts
--     timeline,                          -- modules/SimScenario.lua's
--     pool, poolBuild,                   -- modules/SimPool.lua's (the item pool and its build)
--     members,                           -- modules/SimRoster.lua's (the invented group and its gear)
--     world, drive }                     -- modules/SimWorld.lua's and modules/SimEvents.lua's
--   Only the simulator's own modules write their fields; everything else reads them.
--
-- SAFETY (spec §5).
--   * Start refuses an unknown scenario and a second session (the library), then while stood
--     down, while test mode is on, in combat, inside an instance and in a real group, and says
--     which (NS.SimHost.Refusal, which the library runs inside NS.SimSeam:Live, so a simulated
--     answer never hides the real world).
--   * It stops by itself when the player joins a real group or enters an instance (the shared
--     GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA rows, which come first,
--     so it stops before any other handler reads the client), and when the addon stands down
--     (NS.Sim:Stop("standDown"), the first NS.STAND_DOWN step). Nothing about it is saved, so a
--     /reload or a logout ends it too.
--   * Nothing is sent: the seam's guarded ChatSender prints `[sim]` lines (core/SimSetup.lua).
--   * Saved history is never written: while it runs, modules/History.lua writes this session's
--     own log (NS.SimHost.HistoryLog), which the stop lets go.
--   * No real inspect and no real trade: the seam's guarded members never reach the client.
--   * Stop cleans everything, in this order (the library's two-phase stop): its timers; every
--     queued ask, canceled while the seam still guards the sender (OnStopGuarded), so nothing
--     queued can go out once it has ended; then, with the seam off (OnStop, in registration
--     order), the later modules' own steps (modules/SimEvents.lua's and modules/SimScenario.lua's,
--     registered at their load), the simulated restrictions lifted through the restriction
--     event, the waiting automatic asks of its drops and the drops themselves with their groups and
--     the encounter context (NS.LootFeed.RemoveWhere), the inspect entries of its members, the
--     roster, the log, the trade timer's entries (a fresh scan) and the situation (the classifier
--     re-reads the real one). The library runs every step under pcall, so one that raises never
--     skips the rest (nor the stand-down).
--   * Everything it invents carries `sim = true` (the session, the feed's drops, the history
--     entries), so a stray one is identifiable. Only what Fire delivers is invented (IsDelivering):
--     a real loot line or trade that arrives while a simulation runs stays real and is saved.
--
-- THE HOST CONTRACT (OWNER_SCOPE C.4). The members only DropWatcher's simulation has live on
-- NS.SimHost, never on NS.Sim: NS.Sim is the library instance, and nothing is written onto it.
-- Library absent: NS.Sim is the reference stub (LibKa0s tests/test_sim_stub.lua), which starts
-- nothing and says so.

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost
local L = NS.L

local TAG = "SIM"

--- The scenarios the descriptor names, filled in place by modules/SimScenario.lua at its load
--- (the library reads them when Start is called): { names = { ordered }, defs = { [name] = def } }.
NS.SimScenarioDefs = NS.SimScenarioDefs or { names = {}, defs = {} }

-- What the guarded answers did this session: { sends, handOvers }; core/SimSetup.lua's printSend
-- and handOver count into it, and Begin resets it.
Host.counts = Host.counts or { sends = 0, handOvers = 0 }

local function session()
    return NS.Sim:Session()
end

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

--- The session-only history log modules/History.lua writes while a simulation runs, else nil.
--- @return table|nil
function Host.HistoryLog()
    local s = session()
    return s and s.log or nil
end

--- Record a GUID the simulation invented (a member), so the stop forgets it everywhere.
--- @param guid string
function Host.MarkGUID(guid)
    local s = session()
    if s and s.guids and type(guid) == "string" then s.guids[guid] = true end
end

--- True when the running simulation invented this GUID.
--- @param guid any
--- @return boolean
function Host.IsSimGUID(guid)
    local s = session()
    return s ~= nil and s.guids ~= nil and guid ~= nil and s.guids[guid] == true
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

--- NS.Sim:Status() merged with the host half: { situation, members, sends, handOvers,
--- restrictions, lockdown, groups }; only `sends` and `handOvers` of it when none runs.
--- @return table
function Host.Status()
    local out, s, c = NS.Sim:Status(), session(), Host.counts
    out.sends, out.handOvers = c.sends, c.handOvers
    if not s then return out end
    out.situation, out.members = s.situation, count(s.guids)
    out.restrictions, out.lockdown = count(s.restrictions), s.lockdown
    out.groups = s.log and #s.log.groups or 0
    return out
end

-- The real world, read with the seam off: { inGroup, inInstance, inCombat }.
local function realWorld()
    return NS.SimSeam:Live(function()
        local i = NS.Situations.ReadInputs()
        return { inGroup = i.inGroup or i.inRaid, inInstance = i.inInstance,
            inCombat = NS.Restrictions.InCombat() }
    end)
end

--- Why a simulation may not start now, as the line to print, or nil when it may (spec §5). The
--- library has already refused an unknown scenario and a second session.
--- @return string|nil
function Host.Refusal()
    local stoodDown = NS.StoodDownRefusal()
    if stoodDown then return stoodDown end
    if NS.State.testMode then return L["Turn test mode off before starting a simulation."] end
    local w = realWorld()
    if w.inCombat then return L["A simulation cannot start in combat."] end
    if w.inInstance then return L["A simulation cannot start inside an instance."] end
    if w.inGroup then return L["A simulation cannot start in a group: leave it first."] end
    return nil
end

--- The host fields of a session that just started (the descriptor's prepare runs it first): the
--- situation it simulates (the start's `situation`, else the scenario's), its invented GUIDs, its
--- restrictions and lockdown and its session-only history log; the guarded answers' counts reset.
--- @param s table the library's session
--- @param def table the scenario's def
--- @param opts table the start's resolved options
function Host.Begin(s, def, opts)
    s.situation = opts.situation or def.situation
    s.guids, s.restrictions, s.lockdown, s.log = {}, {}, false, { v = 1, groups = {} }
    Host.counts = { sends = 0, handOvers = 0 }
    NS.Debug(TAG, "simulation started: %s (%s)", tostring(s.scenario), tostring(s.situation))
end

-- ── restrictions ────────────────────────────────────────────────────────────────────────────

--- Turn a simulated restriction (an Enum.AddOnRestrictionType member name: Encounter,
--- ChallengeMode, Combat, ...) on or off. The client answers it as active while it is on, and the
--- change is delivered as ADDON_RESTRICTION_STATE_CHANGED (type, active), the event's boolean
--- payload shape. Answers whether anything changed.
--- @param name string
--- @param on boolean
--- @return boolean
function Host.SetRestriction(name, on)
    local s = session()
    local rtype = s and s.restrictions and NS.Compat.RestrictionTypes()[name]
    if rtype == nil then return false end
    on = on and true or nil
    if s.restrictions[rtype] == on then return false end
    s.restrictions[rtype] = on
    NS.Sim:Fire("ADDON_RESTRICTION_STATE_CHANGED", rtype, on == true)
    return true
end

--- Turn the simulated chat-messaging lockdown on or off. The client has no event for it; the
--- restriction tracker reads it on its next refresh, which this asks for. Answers whether it moved.
--- @param on boolean
--- @return boolean
function Host.SetLockdown(on)
    local s = session()
    if not s or s.lockdown == (on == true) then return false end
    s.lockdown = on == true
    NS.Debug(TAG, "chat lockdown %s", s.lockdown and "on" or "off")
    NS.Restrictions.Refresh("simLockdown")
    return true
end

-- The seam's providers for the two restriction readers, keyed by their NS.Compat member names
-- (written as fields, so test_compat's seam-only scan never mistakes a key for a client call). The
-- restriction and chat-lockdown model is host code (OWNER_SCOPE C.9).
local PROVIDERS = {}

function PROVIDERS.IsRestrictionActive(live, rtype)
    local s = session()
    if s and s.restrictions and rtype ~= nil and s.restrictions[rtype] then return true end
    return live(rtype)
end

function PROVIDERS.InChatMessagingLockdown(live)
    local s = session()
    if s and s.lockdown then return true end
    return live()
end

for key, fn in pairs(PROVIDERS) do NS.SimSeam:SetProvider(key, fn) end

-- ── the session (LibKa0s-Sim-1.0) ───────────────────────────────────────────────────────────

-- The stop lines for the host's own reasons (the library's `stop` line is these words too).
local STOP_TEXT = {
    group     = L["Simulation stopped: you joined a group."],
    instance  = L["Simulation stopped: you entered an instance."],
    standDown = L["Simulation stopped: the addon was disabled."],
}

-- The library's lines in this addon's words, keyed by its STRINGS keys.
local LINES = {
    STARTED         = L["Simulation started (%s): nothing is sent, and your saved history is not touched."],
    STOPPED         = L["Simulation stopped."],
    ALREADY_RUNNING = L["A simulation is already running."],
}

-- The reference stub (LibKa0s tests/test_sim_stub.lua) for a load without the library.
local NEEDS_LINE = "The simulator needs LibKa0s-Sim-1.0."

local function newSimStub(say)
    local sim = {}
    local function no() return false end
    local function noop() end
    local function absent() return false, "absent" end
    sim.IsActive, sim.IsDelivering, sim.IsPanelShown = no, no, no
    function sim.Fire() return 0 end
    function sim.DeliverForCleanup() return 0 end
    function sim.After() return nil end
    function sim.Start() say(NEEDS_LINE); return false, NEEDS_LINE end
    sim.Stop = no
    sim.OnStop, sim.OnStopGuarded, sim.AddListener = noop, noop, noop
    function sim.Status() return { active = false } end
    function sim.Session() return nil end
    function sim.Steps() return {} end
    function sim.Step() return nil, "absent" end
    sim.Run, sim.Pause, sim.Resume, sim.Restart = absent, absent, absent, absent
    function sim.RunVerb() say(NEEDS_LINE); return false, "absent" end
    sim.ShowPanel, sim.TogglePanel = no, no
    sim.HidePanel, sim.RefreshPanel, sim.ResetPanelPosition = noop, noop, noop
    function sim.PanelRows() return {} end
    return sim
end

local Lib = LibStub and LibStub("LibKa0s-Sim-1.0", true)
if Lib then
    NS.Sim = Lib:New({
        name = "DropWatcher",
        seam = NS.SimSeam,
        slash = NS.SLASH .. " sim",
        deliver = function(...) return NS.DeliverEvent(...) end,
        isStoodDown = function() return NS.IsStoodDown() end,
        refusal = function() return Host.Refusal() end,
        scenarios = NS.SimScenarioDefs,
        prepare = function(s, def, opts, ready)
            Host.Begin(s, def, opts)
            return NS.SimScenario.Prepare(s, def, opts, ready)
        end,
        play = function(...) return NS.SimScenario.Play(...) end,
        stepDelay = function() return NS.SimScenario.StepDelay() end,
        stopText = STOP_TEXT,
        L = LINES,
        print = function(line) NS.Print(line) end,
        debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    })
else
    NS.Sim = newSimStub(function(line) NS.Print(line) end)
end

-- ── the stop ────────────────────────────────────────────────────────────────────────────────

-- While the seam still guards the sender: a queued ask must never go out after the stop.
NS.Sim:OnStopGuarded(function() NS.Asks.CancelQueued("simStop") end)

-- Every simulated restriction lifted through its event, then the lockdown read again.
local function liftRestrictions(s)
    for rtype in pairs(s.restrictions or {}) do
        NS.DeliverEvent("ADDON_RESTRICTION_STATE_CHANGED", rtype, false)
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
    for guid in pairs(s.guids or {}) do NS.Inspect.Forget(guid) end
end

local function refreshWindow(_, reason)
    if NS.Window and NS.Window.IsShown() then NS.Window.Refresh() end
    NS.Debug(TAG, "simulation stopped (%s): %d sends printed", tostring(reason), Host.counts.sends)
end

-- The stop's engine steps, in order, after the later modules' own (OnStop, registered at their
-- load). The library runs each under pcall, so one that raises never skips the rest.
local ENGINE_STEPS = {
    liftRestrictions,
    function() cleanFeed() end,
    forgetMembers,
    function() NS.Roster.Refresh("simStop") end,
    function(s) if s.log then NS.History.ReleaseLog(s.log) end end,
    function() NS.TradeTimer.Scan("simStop") end,
    function() NS.Situations.Refresh("simStop") end,
    refreshWindow,
}

--- Register the stop's engine steps on NS.Sim:OnStop. Called once, by the last simulator module
--- to load (modules/SimScenario.lua), so the steps modules/SimEvents.lua and
--- modules/SimScenario.lua register at their load run before them, in TOC order.
function Host.RegisterStopSteps()
    for _, fn in ipairs(ENGINE_STEPS) do NS.Sim:OnStop(fn) end
end

-- ── the automatic stop and the lifecycle ────────────────────────────────────────────────────

--- A world event: joining a real group or entering an instance ends the simulation (spec §5).
function Host.OnWorldEvent()
    if not NS.Sim:IsActive() then return end
    local w = realWorld()
    if w.inInstance then
        NS.Sim:Stop("instance")
    elseif w.inGroup then
        NS.Sim:Stop("group")
    end
end

-- Shared events (core/DropWatcher.lua's dispatcher): these rows come first in the TOC, so the
-- simulation is stopped before any other handler reads the client.
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSimWorldEvent" }
end

function NS.addon.OnSimWorldEvent()
    Host.OnWorldEvent()
end

-- The first stand-down step (H6): the stop cleans up while every module still holds its state.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    NS.Sim:Stop("standDown")
end
