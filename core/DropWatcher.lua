local addonName, NS = ...
-- core/DropWatcher.lua — AceAddon registration and lifecycle; the one place NS is promoted to an addon.
--
-- Every game event the addon reacts to is declared in NS.FEATURE_EVENTS, so OnEnable and the
-- stand-up register exactly the same list and the stand-down unregisters exactly that list
-- (slash-commands-§7). Feature modules append their rows, and their teardown and rebuild steps
-- (NS.STAND_DOWN / NS.STAND_UP), at file load. The host handlers the launcher, the Master controls
-- rows and the slash verbs share (test mode, lock, the window) live here, so each surface calls the
-- same function.

local DW = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
NS.addon = DW

-- Reclaim NS.Print from AceConsole's embed: core/CoreSetup.lua published the library printer on
-- NS.Util.print, and the two names must be the same function object (architecture-§2).
NS.Print = NS.Util.print

-- Every game event this addon owns, as { event, handlerMethodName } pairs. Two rows may name the
-- same event; registerFeatureEvents (below) fans it out to both handlers.
NS.FEATURE_EVENTS = NS.FEATURE_EVENTS or {}
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_DISABLED", "OnCombatStart" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED",  "OnCombatEnd" }

-- Teardown and rebuild steps feature modules contribute, run by the latch's two callbacks.
NS.STAND_DOWN = NS.STAND_DOWN or {}
NS.STAND_UP   = NS.STAND_UP or {}

--- The declared feature events, each once, in the order of their first row.
--- @return table names
function NS.FeatureEventNames()
    local names, seen = {}, {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if not seen[row[1]] then
            seen[row[1]] = true
            names[#names + 1] = row[1]
        end
    end
    return names
end

-- The handler method names declared for each event, in row order.
local function handlersByEvent()
    local by = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        by[row[1]] = by[row[1]] or {}
        local list = by[row[1]]
        list[#list + 1] = row[2]
    end
    return by
end

-- AceEvent keeps one handler per event per object, so an event two modules declare
-- (GROUP_ROSTER_UPDATE: the situation edge and the roster) is registered once, on this dispatcher,
-- which calls every declared handler in row order. Built at each registration.
local sharedHandlers = {}

function DW:OnSharedFeatureEvent(event, ...)
    for _, method in ipairs(sharedHandlers[event] or {}) do self[method](self, event, ...) end
end

local function registerFeatureEvents(self)
    local by = handlersByEvent()
    sharedHandlers = {}
    for _, event in ipairs(NS.FeatureEventNames()) do
        local list = by[event]
        local method = list[1]
        if #list > 1 then
            sharedHandlers[event] = list
            method = "OnSharedFeatureEvent"
        end
        NS.SafeRegisterEvent(self, event, method, NS.rejectedEvents)
    end
end

local function runAll(list)
    for _, fn in ipairs(list) do fn() end
end

local function storedEnabled(self)
    local p = self.db and self.db.profile
    return not (p and p.enabled == false)
end

-- ── stand-down and stand-up (slash-commands-§7) ─────────────────────────────────────────────

--- The latch's standDown: every feature event and every tracked bus registration actually
--- unregistered, test mode ended, and every module's teardown run. The chat command, the
--- dispatcher, the settings category, the launcher and AceDB's callbacks are setup and stay up.
function NS.StandDown()
    for _, event in ipairs(NS.FeatureEventNames()) do DW:UnregisterEvent(event) end
    NS.Bus:StandDown()
    NS.State.testMode = false
    runAll(NS.STAND_DOWN)
    if NS.Window then NS.Window.UpdateVisibility() end
end

--- The latch's standUp: rebuilt from CURRENT state, because settings may change while off.
function NS.StandUp()
    registerFeatureEvents(DW)
    NS.Bus:StandUp()
    runAll(NS.STAND_UP)
    if NS.Window then NS.Window.ApplySettings() end
end

-- ── the shared host handlers ────────────────────────────────────────────────────────────────

--- Turn test mode on or off (preview-mode). One handler for the Master controls checkbox, the
--- launcher entry and `/dw test`. Refused while stood down and while in combat, which also ends it.
--- @param on boolean
--- @return boolean changed
-- Repaint any open settings page, so a checkbox follows a change another surface made.
local function refreshPanels()
    local H = DW.Settings and DW.Settings.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
end

-- Why test mode may not turn on now, as the line to print, or nil when it may.
local function testModeRefusal()
    if NS.IsStoodDown() then return NS.SlashCommands:DisabledLine() end
    if InCombatLockdown() then return NS.L["Test mode is not available in combat."] end
    return nil
end

function NS.SetTestMode(on)
    on = on and true or false
    if on == NS.State.testMode then return false end
    local refusal = on and testModeRefusal()
    if refusal then
        NS.Print(refusal)
        return false
    end
    NS.State.testMode = on
    NS.Debug("State", "test mode %s", on and "on" or "off")
    if NS.Window then NS.Window.OnTestModeChanged(on) end
    refreshPanels()
    return true
end

function NS.ToggleTestMode()
    return NS.SetTestMode(not NS.State.testMode)
end

--- Lock or unlock the window through the write seam, the same write the Lock frame checkbox makes.
--- @param locked boolean
function NS.SetLocked(locked)
    local S = NS.SchemaRuntime
    if not S then return end
    local ok, err = S.Set("locked", locked and true or false)
    if ok == false then return NS.Print(tostring(err)) end
    NS.Print(locked and NS.L["window locked"] or NS.L["window unlocked"])
end

function NS.ToggleLock()
    local S = NS.SchemaRuntime
    NS.SetLocked(not (S and S.Get("locked") == true))
end

--- Show, hide or toggle the main window: the player's own choice for this session.
function NS.ShowWindow() if NS.Window then NS.Window.Open() end end
function NS.HideWindow() if NS.Window then NS.Window.Close() end end
function NS.ToggleWindow() if NS.Window then NS.Window.Toggle() end end
function NS.IsWindowShown() return NS.Window ~= nil and NS.Window.IsShown() end

-- Combat ends test mode (preview-mode), both combat edges re-run the window's show decision
-- (General visibility can depend on combat) and both hand the edge to the restriction tracker
-- (modules/Restrictions.lua, design spec §4), which loads below and is read at call time. Feature
-- events, so both are down while stood down.
function DW.OnCombatStart()
    NS.Debug("State", "combat started")
    if NS.Restrictions then NS.Restrictions.OnCombatEdge(true) end
    if NS.State.testMode then
        NS.SetTestMode(false)
        NS.Print(NS.L["Test mode ended: you entered combat."])
    end
    -- The edge itself decides (events-frames-taint-§2): the player's flag can lag it.
    if NS.Window then NS.Window.UpdateVisibility(true) end
end

function DW.OnCombatEnd()
    NS.Debug("State", "combat ended")
    if NS.Restrictions then NS.Restrictions.OnCombatEdge(false) end
    if NS.Window then NS.Window.UpdateVisibility(false) end
end

-- ── profiles ────────────────────────────────────────────────────────────────────────────────

-- The three profile events share one reaction: migrations, panel refresh, the latch re-read
-- (an incoming profile carries its own answer to `enabled`) and the window's settings.
local function reloadProfile(self)
    self:RunMigrations()
    local S = self.Settings
    local H = S and S.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
    if S and S.RefreshProfilesPage then S.RefreshProfilesPage() end
    if NS.Lifecycle then
        NS.Lifecycle:Set(NS.HOLD_DISABLED, not storedEnabled(self))
        NS.Lifecycle:Reevaluate()
    end
    if NS.Window then NS.Window.ApplySettings() end
end

-- Logged here, once (debug-logging-§10): a profile switch rewrites no row through the write seam.
function DW:OnProfileChanged(_, _, key)
    NS.Debug("Profile", "switched to '%s'", tostring(key or self.db:GetCurrentProfile()))
    reloadProfile(self)
end

function DW:OnProfileCopied(_, _, source)
    NS.Debug("Set", "copied profile '%s' \226\134\146 '%s'", source, self.db:GetCurrentProfile())
    reloadProfile(self)
end

function DW:OnProfileReset()
    local S = self.Settings
    local n = S and S.ConsumeResetCount and S.ConsumeResetCount()
    if n then
        NS.Debug("Set", "reset profile '%s' to defaults (%d rows)", self.db:GetCurrentProfile(), n)
    else
        NS.Debug("Set", "reset profile '%s' to defaults", self.db:GetCurrentProfile())
    end
    reloadProfile(self)
end

-- ── AceAddon lifecycle ──────────────────────────────────────────────────────────────────────

function DW:OnInitialize()
    -- settings/Schema.lua has loaded by ADDON_LOADED, so BuildDefaults exists.
    local S = self.Settings
    local defaults = S and S.BuildDefaults and S.BuildDefaults() or { profile = {} }
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    NS.db = self.db

    -- Before anything reads the profile (savedvariables-§1).
    self:RunMigrations()

    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnProfileChanged", function(...) self:OnProfileChanged(...) end)
        self.db.RegisterCallback(self, "OnProfileCopied",  function(...) self:OnProfileCopied(...) end)
        self.db.RegisterCallback(self, "OnProfileReset",   function(...) self:OnProfileReset(...) end)
    end

    self:RegisterChatCommand(NS.SLASH:sub(2), "OnSlashCommand")
    self:RegisterChatCommand(NS.SLASH_ALIAS:sub(2), "OnSlashCommand")
end

-- The optional integrations, said once when logging is turned on (debug-logging-§8).
local function logDependencies()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    local function state(name) return (loaded and loaded(name)) and "loaded" or "absent" end
    NS.DebugAtEnable("Init", "optional: Pawn %s, CanIMogIt %s", state("Pawn"), state("CanIMogIt"))
end

function DW:OnEnable()
    registerFeatureEvents(self)

    -- Eager category registration (options-ui-§1); bodies stay lazy.
    if self.Settings and self.Settings.Register then self.Settings.Register() end

    -- The launcher needs db.global.minimap, which exists from OnInitialize.
    if NS.Launcher then NS.Launcher:Register() end

    logDependencies()

    -- THE LATCH, taken from the stored path. Last, so everything above is up before it can be
    -- taken back down.
    if NS.Lifecycle then NS.Lifecycle:Set(NS.HOLD_DISABLED, not storedEnabled(self)) end
end

--- The [Init] session summary (debug-logging-§5): name, version, schema, profile, then state.
--- @return string
function DW:InitSummary()
    local db = self.db
    local schema  = db and db.global and db.global.schemaVersion
    local profile = (db and db.GetCurrentProfile and db:GetCurrentProfile()) or "?"
    local line = ("%s v%s, schema v%s, profile '%s' (enabled=%s)"):format(
        addonName, tostring(NS.Version()), tostring(schema), tostring(profile),
        tostring(storedEnabled(self)))
    if #NS.rejectedEvents > 0 then
        line = line .. ", rejected events: " .. table.concat(NS.rejectedEvents, ", ")
    end
    return line
end
