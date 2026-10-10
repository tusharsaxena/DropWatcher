local addonName, NS = ...
-- core/PerfSetup.lua — NS.Perf from LibKa0s-Perf-1.0 (performance-§1).
--
-- One instance, built at load from a descriptor. Hot paths bracket themselves with the gated form
-- (performance-§2):
--   local Perf = NS.Perf                          -- a load-time upvalue, never an NS lookup
--   local t0 = Perf.on and debugprofilestop()
--   ...
--   if t0 then Perf.Note("<bucket>", debugprofilestop() - t0) end
-- Suspend and resume take and release the latch's `perf` hold, so a suspended addon is inert through
-- the same stand-down the disabled state uses. The reserved `perf` verb is registered by the addon
-- (settings/Slash.lua) and answered by OnCommand. No `decorate` hook: the library draws the step
-- panel's close control from `addonName` itself.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

-- The buckets, in report order. Each one is bracketed by the module named beside it; the feature
-- items add theirs (design spec §13) together with the bracket that reaches them, so a declared
-- bucket is never left unreached.
local BUCKETS = {
    { key = "parse" },            -- modules/LootParser.lua Parse: one CHAT_MSG_LOOT line
    { key = "inspect.read" },     -- modules/Inspect.lua readSlots: one read of a unit's 17 slots
    { key = "window.refresh" },   -- modules/Window.lua Refresh: one window repaint pass
}

if not (lib and NS.Lifecycle) then
    -- Degrade, never error: the members the addon reaches, and nothing of the harness itself.
    local noop = function() end
    NS.Perf = {
        on = false, suspended = false, BUCKET_ORDER = {},
        Note = noop, Open = noop, Close = noop, Suspend = noop, Resume = noop,
        OnCommand = function()
            return { NS.L["%s, so the perf harness is unavailable."]:format(NS.LIBKA0S_MISSING) }
        end,
    }
    return
end

NS.Perf = lib:New({
    name      = addonName,           -- seeds the sampler and panel frame globals
    addonName = addonName,           -- the folder the panel's close mark is built from
    title     = NS.BRAND,            -- the library appends " — Perf Run"
    slash     = NS.SLASH,
    sv        = addonName .. "PerfDB",
    version   = NS.Version and NS.Version() or NS.version,
    lifecycle = NS.Lifecycle,        -- Suspend / Resume take and release the `perf` hold
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Perf", line) else NS.Print(line) end
    end,
    print   = function(line) NS.Print(line) end,
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then NS.DebugLog:Show() end
    end,
    buckets = BUCKETS,
})
