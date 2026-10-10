local _, NS = ...
-- modules/Diagnostics.lua — the addon's sections of `/dw diagnostics` (debug-logging-§14).
--
-- Sections only: the markers, the identity header's library half, the per-section pcall, the cap
-- and the Add loop are LibKa0s-DebugLog-1.0's. Every section READS state and never acts: no hold,
-- no event, no timer, safe in combat and while stood down. `out:add` formats %s-only and runs every
-- argument through safeToString, so raw values are passed, never pre-built strings. The feature
-- items add their own sections (design spec §13) here.

NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

local function read(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, v = pcall(fn, ...)
    if not ok then return "unreadable" end
    return v
end

-- The report runs after OnInitialize, so the db exists; a section that raises costs one line
-- (the library pcalls each section).
local function identity(out)
    local db = NS.addon.db
    out:add(TAG, "schema stored=%s code=%s", db.global.schemaVersion, NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", NS.Lifecycle:Holds())
end

local function settings(out)
    local S = NS.SchemaRuntime
    local Settings = NS.addon and NS.addon.Settings
    out:nonDefaults(Settings and Settings.Schema, function(row) return S.Get(row.path) end, nil, nil,
        { always = { "enabled" } })
end

local function profile()
    local db = NS.addon and NS.addon.db
    return db and db.profile or {}
end

-- The window's show decision and its inputs, so "why is the window not showing" is one read.
local function window(out)
    local W, State, p = NS.Window, NS.State, profile()
    out:add(TAG, "window: built=%s shown=%s shouldShow=%s", W.Frame() ~= nil, read(W.IsShown),
        read(W.ShouldShow))
    out:add(TAG, "window: open=%s testMode=%s visibility=%s locked=%s", State.windowOpen,
        State.testMode, p.visibility, p.locked)
    local g = type(p.window) == "table" and p.window or {}
    local point = type(g.point) == "table" and g.point or { "default" }
    out:joined(TAG, "window: point", point)
    out:add(TAG, "window: size=%sx%s", g.width or "default", g.height or "default")
end

-- Where the addon thinks the player is, the inputs it read and that situation's settings
-- (design spec §6.1, §13). The inputs are read live: the classifier's edge only reads.
local function situation(out)
    local Sit = NS.Situations
    local i = Sit.ReadInputs()
    local key = Sit.Classify(i)
    local s = Sit.Settings(key)
    out:add(TAG, "situation: %s (last announced %s) track=%s autoOpen=%s quality=%s", key,
        NS.State.situation or "none", s.track, s.autoOpen, s.quality or "global")
    out:add(TAG, "situation inputs: inInstance=%s type=%s difficulty=%s challengeMode=%s",
        i.inInstance, i.instanceType, i.difficultyID or "none", i.isChallengeModeActive)
    out:add(TAG, "situation inputs: delve=%s follower=%s group=%s raid=%s pvp=%s", i.isDelve,
        i.isFollowerDungeon, i.inGroup, i.inRaid, i.isPvP)
end

-- What the restrictions allow now, every reason in effect (sorted, the Map type included) and
-- what was last announced (design spec §4, §13). Read live: the tracker only reads.
local function restrictions(out)
    local Rs = NS.Restrictions
    local snap = Rs.Snapshot()
    out:add(TAG, "restrictions: reason=%s canSendChat=%s canInspect=%s canTrade=%s",
        snap.reason or "none", snap.canSendChat, snap.canInspect, snap.canTrade)
    local active = {}
    for reason in pairs(Rs.ActiveSet()) do active[#active + 1] = reason end
    table.sort(active)
    out:joined(TAG, "restrictions: active", active)
    out:add(TAG, "restrictions: last announced %s", NS.State.restrictionSignature or "none")
end

-- The group as the roster last read it (design spec §4): stored state only, so the report never
-- triggers the roster's lazy read. One line per member.
local function roster(out)
    local r = NS.State.roster
    if not r then return out:add(TAG, "roster: not read yet") end
    out:add(TAG, "roster: %s members", #r.list)
    for _, m in ipairs(r.list) do
        out:add(TAG, "roster: %s unit=%s class=%s online=%s spec=%s player=%s", m.fullName or "?",
            m.unit, m.classFile or "?", m.online, m.specID or "unknown", m.isPlayer)
    end
end

local function registration(out)
    local names = NS.FeatureEventNames and NS.FeatureEventNames() or {}
    out:joined(TAG, "feature events (declared)", names)
    -- Stood down, the latch has unregistered them; the declared list is printed either way.
    out:add(TAG, "feature events registered=%s", not stoodDown())
    out:list(TAG, "rejected events", NS.rejectedEvents or {})
end

local function integrations(out)
    local Lc = NS.Launcher
    out:add(TAG, "launcher: registered=%s shown=%s", Lc and read(Lc.IsRegistered, Lc),
        Lc and read(Lc.IsShown, Lc))
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    out:add(TAG, "optional: Pawn=%s CanIMogIt=%s", loaded and read(loaded, "Pawn") or false,
        loaded and read(loaded, "CanIMogIt") or false)
end

--- The sections, in report order. Read at RUN time by core/DebugLogSetup.lua's descriptor.
--- @return table
function NS.Diagnostics.Sections()
    return {
        { "identity",     identity },
        { "settings",     settings },
        { "window",       window },
        { "situation",    situation },
        { "restrictions", restrictions },
        { "roster",       roster },
        { "registration", registration },
        { "integrations", integrations },
    }
end
