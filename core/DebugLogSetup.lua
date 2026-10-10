local addonName, NS = ...
-- core/DebugLogSetup.lua — NS.DebugLog from a descriptor; publishes the bare NS.Debug seam.
--
-- The console window, the copy window, the formatters, the buffer, the gates and the diagnostics
-- report's frame are LibKa0s-DebugLog-1.0's (debug-logging). This file supplies the frame-name
-- prefix, the title, the monospace font (core/Constants.lua, which loads first), the addon FOLDER
-- name, where the session-only flag lives (core/State.lua), what the [Init] line says and where the
-- report's sections come from — plus the degradation stub.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
    -- Degrade, never error. The stub answers every member the addon calls; SetEnabled still flips
    -- the addon's own flag and still acknowledges. What is lost is the window, said once.
    local missing = NS.L["%s, so the debug console window is unavailable."]:format(NS.LIBKA0S_MISSING)
    local said = false
    local function sayOnce()
        if said then return end
        said = true
        if NS.Print then NS.Print(missing) end
    end

    NS.DebugLog = {
        buffer          = {},
        Add             = function() end,
        Debug           = function() end,
        DebugOnce       = function() end,
        DebugChanged    = function() end,
        DebugForget     = function() end,
        DebugAtEnable   = function() end,
        Clear           = function() end,
        Show            = function() sayOnce() end,
        Hide            = function() end,
        Toggle          = function() sayOnce() end,
        IsShown         = function() return false end,
        IsEnabled       = function() return (NS.State and NS.State.debug) and true or false end,
        RefreshHeader   = function() end,
        ShowCopy        = function() sayOnce() end,
        UpdateScrollBar = function() end,
        UpdateStatus    = function() end,
        BufferSize      = function() return 0 end,
        LastLine        = function() return nil end,
        FindLine        = function() return nil end,
        CopyText        = function() return "" end,
        MakeCloseButton = function() return nil end,
        Text            = function(_, key) return key end,
        BuildDiagnostics = function()
            return { lines = {}, dropped = 0, capped = false, capsHit = false }
        end,
        SetEnabled      = function(_, on)
            on = not not on
            if NS.State then NS.State.debug = on end
            if NS.Print then
                NS.Print(on and NS.L["debug logging |cff40ff40ON|r"] or NS.L["debug logging |cffff4040OFF|r"])
            end
            if on then sayOnce() end
        end,
        ConsoleCheckbox = function()
            return {
                label   = NS.L["Debug console"],
                tooltip = missing,
                get     = function() return false end,
                set     = function() sayOnce() end,
            }
        end,
        RunDiagnostics  = function()
            if NS.Print and NS.L then
                NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]
                    :format(NS.SLASH .. " diagnostics"))
            end
            return 0
        end,
        DebugVerb       = function() return false end,
    }
    NS.Debug         = NS.DebugLog.Debug
    NS.DebugOnce     = NS.DebugLog.DebugOnce
    NS.DebugChanged  = NS.DebugLog.DebugChanged
    NS.DebugAtEnable = NS.DebugLog.DebugAtEnable
    return
end

NS.DebugLog = lib:New({
    name      = addonName,          -- seeds the frame globals
    addonName = addonName,          -- the folder the shared marks' texture paths are built from
    title     = NS.BRAND,
    font      = NS.Constants.FONT_MONO,
    slash     = NS.SLASH,

    -- The flag stays the ADDON's, session-only and never in SavedVariables (debug-logging-§5).
    isEnabled  = function() return (NS.State and NS.State.debug) and true or false end,
    setEnabled = function(on) if NS.State then NS.State.debug = on end end,

    -- Call-time forwarders, never captured references.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    initSummary = function()
        local addon = NS.addon
        if addon and addon.InitSummary then return addon:InitSummary() end
    end,

    onVisibilityChanged = function()
        local H = NS.addon and NS.addon.Settings and NS.addon.Settings.Helpers
        if H and H.RefreshAll then H.RefreshAll() end
    end,

    -- The diagnostics dump (debug-logging-§14). Read at RUN time: modules/Diagnostics.lua loads
    -- later. diagnosticsEnablesLogging is left out, so a run turns logging on for the session.
    brandName   = NS.BRAND,
    diagnostics = function() return NS.Diagnostics and NS.Diagnostics.Sections() or {} end,

    L = {
        DIAG_WRITTEN = NS.L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."],
    },
})

-- The gated sink and the console's gates, published bare (DebugLog minor 18).
NS.Debug         = NS.DebugLog.Debug
NS.DebugOnce     = NS.DebugLog.DebugOnce
NS.DebugChanged  = NS.DebugLog.DebugChanged
NS.DebugAtEnable = NS.DebugLog.DebugAtEnable
