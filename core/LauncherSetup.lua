local addonName, NS = ...
-- core/LauncherSetup.lua — the launcher: one LibDataBroker object, registered twice (launcher).
--
-- LibKa0s-Launcher-1.0 builds the `launcher` object, registers the same object with LibDBIcon, owns
-- its single OnClick (left-click opens settings, right-click the options menu) and draws the status
-- tooltip. This file supplies the seams: the logo, the brand label, where LibDBIcon's `hide` lives
-- (db.global.minimap, shared with the Minimap button row), and one accessor-and-toggle pair per
-- menu entry -- Enabled, Locked, Test mode, Show window -- each calling the same handler its slash
-- verb or Master controls row calls (core/DropWatcher.lua, settings/Slash.lua).

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

-- The 128x128 uncompressed 32-bit logo; the same path as the TOC's ## IconTexture.
local ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga"):format(addonName, addonName:lower())

local function minimapStore()
    local db = NS.addon and NS.addon.db
    return db and db.global and db.global.minimap
end

-- ── the Show window key binding (launcher-§6) ───────────────────────────────────────────────
--
-- Bindings.xml (repo root, read by the client, never TOC-listed) declares one CLICK binding on the
-- button below, in the addon's own category (BINDING_HEADER_DROPWATCHER), with no header and no
-- default key. A plain, hidden, non-secure Button, registered AnyDown so one
-- key press is one click. Its OnClick asks NS.StoodDownRefusal first, because NS.ToggleWindow
-- relies on the dispatcher's gate for `/dw toggle`: stood down, the press prints the one line the
-- toggle verb would, chosen by hold (the disabled line, or the perf capture's). Otherwise it calls
-- NS.ToggleWindow, the handler the launcher's Show window entry and `/dw toggle` call. Built above
-- the library check, so a bound key works on a library-less install too.
--
-- THE NAME IS PERMANENT. The client stores a player's key against `CLICK <name>:LeftButton`, so
-- renaming DropWatcherToggleWindow silently unbinds every player's key.
local toggleButton = CreateFrame("Button", "DropWatcherToggleWindow", UIParent)
toggleButton:Hide()
toggleButton:RegisterForClicks("AnyDown")
toggleButton:SetScript("OnClick", function()
    local line = NS.StoodDownRefusal()
    if line then return NS.Print(line) end
    NS.ToggleWindow()
end)

-- The Keybindings page's labels. BINDING_HEADER_DROPWATCHER is the category every <Binding> in
-- Bindings.xml names, so it is this addon's own section title there: the brand, assigned at file
-- scope because the client reads it on ADDON_LOADED. The row is localized and carries no brand,
-- since the section already does (launcher-§6). Its global name holds a space and a colon, so it is
-- written with rawset rather than declared to luacheck.
BINDING_HEADER_DROPWATCHER = NS.BRAND
rawset(_G, "BINDING_NAME_CLICK DropWatcherToggleWindow:LeftButton", NS.L["Toggle drop feed"])

-- The one bindings table (launcher-§6), in Bindings.xml order, Show window first. General >
-- Keybindings (settings/Panel.lua, O.KeybindingsTab, options-ui-§20) draws a row per entry, and
-- tests/test_bindings.lua holds Bindings.xml to it (Kit.assertBindingsXml).
NS.BINDINGS = {
    { command = "CLICK DropWatcherToggleWindow:LeftButton", tooltip = NS.L["Shows or hides the drop feed."] },
}

if not lib then
    local missing = NS.L["%s, so there is no minimap button and no broker plugin."]:format(NS.LIBKA0S_MISSING)
    local said = false
    NS.Launcher = {
        Register = function()
            if not said then
                said = true
                if NS.Print then NS.Print(missing) end
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapStore()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = lib:New({
    name  = addonName,
    icon  = ICON,
    label = NS.BRAND,

    minimap = minimapStore,

    openSettings = function() NS.addon:OpenSettings() end,

    -- The stored `enabled` setting, the same accessor the Master controls row reads (launcher-§1),
    -- written through the same handler `/dw enable|disable` calls.
    isEnabled  = function() return NS.SchemaRuntime ~= nil and NS.SchemaRuntime.Get("enabled") ~= false end,
    setEnabled = function(on) NS.addon:SlashEnabled(on) end,

    isLocked       = function() return NS.SchemaRuntime ~= nil and NS.SchemaRuntime.Get("locked") == true end,
    toggleLock     = function() NS.ToggleLock() end,
    isTestMode     = function() return NS.State.testMode == true end,
    toggleTestMode = function() NS.ToggleTestMode() end,
    isWindowShown  = function() return NS.IsWindowShown() end,
    toggleWindow   = function() NS.ToggleWindow() end,

    print         = function(line) NS.Print(line) end,
    debug         = function(tag, message) NS.Debug(tag, message) end,
    debugAtEnable = function(tag, message) NS.DebugAtEnable(tag, "%s", message) end,

    version = function()
        local v = NS.Version()
        return v ~= "?" and v or nil
    end,
})
