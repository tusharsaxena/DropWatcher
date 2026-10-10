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

local function identity(out)
    local db = NS.addon and NS.addon.db
    local LC = NS.Lifecycle
    out:add(TAG, "schema stored=%s code=%s", db and db.global and db.global.schemaVersion,
        NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db and db.GetCurrentProfile and db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db and db.profile and db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", LC and LC.Holds and LC:Holds() or {})
end

local function settings(out)
    local S = NS.SchemaRuntime
    local Settings = NS.addon and NS.addon.Settings
    out:nonDefaults(Settings and Settings.Schema, function(row) return S.Get(row.path) end, nil, nil,
        { always = { "enabled" } })
end

-- The window's show decision and its inputs, so "why is the window not showing" is one read.
local function window(out)
    local W, State = NS.Window, NS.State
    local p = NS.addon and NS.addon.db and NS.addon.db.profile
    out:add(TAG, "window: built=%s shown=%s shouldShow=%s", W and W.Frame() ~= nil,
        W and read(W.IsShown), W and read(W.ShouldShow))
    out:add(TAG, "window: open=%s testMode=%s visibility=%s locked=%s", State.windowOpen,
        State.testMode, p and p.visibility, p and p.locked)
    local g = p and p.window or {}
    out:add(TAG, "window: point=%s size=%sx%s", type(g.point) == "table" and table.concat(g.point, ",")
        or "default", g.width or "default", g.height or "default")
end

local function registration(out)
    local names = {}
    for i, row in ipairs(NS.FEATURE_EVENTS or {}) do names[i] = row[1] end
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
        { "registration", registration },
        { "integrations", integrations },
    }
end
