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
--- launcher entry and `/dw test`. Refused while stood down, in combat (which also ends it) and
--- while a simulation runs (modules/Sim.lua).
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
    if NS.Compat.InCombatLockdown() then return NS.L["Test mode is not available in combat."] end
    -- The simulator and test mode are exclusive (simulator spec §1): placeholders are not the engine.
    if NS.Sim.active then return NS.L["Test mode is not available while a simulation runs."] end
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
    -- The placeholder drops (modules/TestMode.lua): filled before the window shows them.
    if NS.TestMode then
        if on then NS.TestMode.Populate() else NS.TestMode.Clear() end
    end
    if NS.Window then NS.Window.OnTestModeChanged(on) end
    -- The toast is placed in test mode; turned off, a test drop's toast goes (modules/Toast.lua).
    if NS.Toast then NS.Toast.OnTestModeChanged(on) end
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

--- Inspect every other group member, one at a time (design spec §8): the window's Scan group
--- button, and `/dw scan` once it lands (DW-42). Refused while stood down.
--- @return number queued how many members were queued
function NS.ScanGroup()
    if NS.IsStoodDown() then
        NS.Print(NS.SlashCommands:DisabledLine())
        return 0
    end
    local n = NS.Inspect.Scan("scan")
    if n > 0 then
        NS.Print(NS.L["Inspecting %d group members, one at a time."]:format(n))
    else
        NS.Print(NS.L["Nothing to inspect: every member's gear is already read, or you are not in a group."])
    end
    return n
end

local function isQualityMode(mode)
    for _, m in ipairs(NS.Constants.QUALITY_MODES) do
        if m == mode then return true end
    end
    return false
end

--- Set the feed's minimum-quality mode (design spec §6.2): the filter bar's Quality control, and
--- the Feed page's row that shares the path, through the write seam. A new mode applies to the drops
--- that arrive after it; the row's reaction repaints the open window.
--- @param mode string one of NS.Constants.QUALITY_MODES
--- @return boolean changed
function NS.SetQualityMode(mode)
    if not isQualityMode(mode) then return false end
    local ok, err = NS.SchemaRuntime.Set("feed.quality.mode", mode)
    if ok == false then NS.Print(tostring(err)) end
    return ok ~= false
end

-- Why an ask was not sent, in words (modules/Asks.lua's refusal reasons, and the core's).
local ASK_REFUSAL = {
    notInGroup = NS.L["%s is not in your group."], self = NS.L["That is your own drop."],
    offline = NS.L["%s is offline."], noTarget = NS.L["The looter is not known."],
    alreadyAsked = NS.L["You already asked %s for it."],
    tooLong = NS.L["The message is longer than chat allows; shorten the ask template."],
    disabled = NS.L["The addon is disabled."], noDrop = NS.L["That drop is gone."],
}

--- The name an ask for `drop` is filed under (NS.Asks.Request's and StateOf's `target`): the
--- looter's name, else their GUID; nil for your own drop or a looter with neither.
--- @param drop table a feed record
--- @return string|nil
function NS.AskTargetOf(drop)
    local who = type(drop) == "table" and not drop.isMine and drop.looter
    if type(who) ~= "table" then return nil end
    return who.name or who.guid
end

-- Edit before sending (`messages.editFirst`, design spec §9.2): a fresh press opens the detail
-- card's Edit message box (modules/DetailCard.lua, read at call time) prefilled for this send, in
-- place of sending; the box's Send comes back here with `opts.text`, so it is not opened twice. A
-- press on a queued send still cancels it, and with the window closed (the box lives in it) the send
-- goes as it stands. True when the box opened.
local function editFirst(kind, target, dropID, opts)
    if opts ~= nil or NS.Setting("messages.editFirst") ~= true or not NS.IsWindowShown() then return false end
    if NS.Asks.StateOf(kind, target, dropID) == "queued" then return false end
    return NS.DetailCard.OpenEditor(dropID, kind, target) ~= nil
end

--- Ask a drop's looter for it (design spec §9.2): the Drops row's Ask button and the detail
--- card's, through the messaging edge's Press, so a queued ask is canceled by a second click. A
--- refusal is said in chat; a send confirms itself (modules/Asks.lua). Refused while stood down.
--- With `messages.editFirst` on, a press without `opts` opens the Edit message box instead
--- (state `editing`).
--- @param dropID number
--- @param opts table|nil { text = the edited message } (the detail card's Edit message box)
--- @return string state, string|nil reason (as NS.Asks.Press, or `editing`)
function NS.PressAsk(dropID, opts)
    local L = NS.L
    local rec = NS.LootFeed.Get(dropID)
    local target = NS.AskTargetOf(rec)
    local state, reason
    if NS.IsStoodDown() then
        state, reason = "refused", "disabled"
    elseif not target then
        state, reason = "refused", rec and "self" or "noDrop"
    elseif editFirst("ask", target, dropID, opts) then
        state = "editing"
    else
        state, reason = NS.Asks.Press("ask", target, dropID, opts)
    end
    if state == "refused" then
        local why = ASK_REFUSAL[reason]
        why = why and why:format(target or "?") or tostring(reason)
        NS.Print(L["Not asked: %s"]:format(why))
    end
    return state, reason
end

-- The looter record of a drop that is not yours, or nil.
local function looterOf(dropID)
    local rec = NS.LootFeed.Get(dropID)
    local who = rec and not rec.isMine and rec.looter
    return type(who) == "table" and who or nil
end

--- Inspect a drop's looter again, ahead of the warm-up queue (design spec §8, §11.3): the detail
--- card's Retry inspect. Refused while stood down; says in chat when there is nobody to inspect.
--- @param dropID number
--- @return string|nil status NS.Inspect.Request's answer
function NS.RetryInspect(dropID)
    local L = NS.L
    if NS.IsStoodDown() then
        NS.Print(NS.SlashCommands:DisabledLine())
        return nil
    end
    local who = looterOf(dropID)
    local status = who and who.guid and NS.Inspect.Request(who.guid, NS.Inspect.PRIORITY.looter)
    if not status then
        NS.Print(L["Nobody to inspect for that drop."])
        return nil
    end
    NS.Debug("UI", "retry inspect: drop %s -> %s", tostring(dropID), status)
    return status
end

--- Open a trade with a drop's looter (design spec §11.3): the detail card's Trade button, through
--- the trade helper's Open and its guards. A refusal is said in chat.
--- @param dropID number
--- @return boolean ok, string|nil reason (as NS.TradeHelper.Open)
function NS.TradeWithLooter(dropID)
    local who = looterOf(dropID)
    local target = who and (who.guid or who.name)
    local ok, reason
    if not target then
        ok, reason = false, "noTarget"
    else
        ok, reason = NS.TradeHelper.Open(target)
    end
    if not ok then
        NS.Print(NS.L["No trade: %s"]:format(NS.TradeHelper.ReasonText(reason) or tostring(reason)))
    end
    return ok, reason
end

-- Why an offer or an announce was not sent, in words (modules/Asks.lua's refusal reasons).
local SEND_REFUSAL = {
    offer = { alreadyAsked = NS.L["You already offered it to %s."], self = NS.L["You cannot offer it to yourself."],
        noTarget = NS.L["That member is not known."] },
    announce = { alreadyAsked = NS.L["You already announced it."], noDrop = NS.L["That drop is gone."],
        noChannel = NS.L["You are not in a group, so there is no channel to post in."],
        noApi = NS.L["This client cannot send chat."] },
}

local function sendRefusal(kind, reason, who)
    local why = SEND_REFUSAL[kind][reason] or ASK_REFUSAL[reason]
    return why and why:format(who or "?") or tostring(reason)
end

-- One of your drops by id, or nil.
local function mineOf(dropID)
    local rec = dropID ~= nil and NS.LootFeed.Get(dropID) or nil
    return rec and rec.isMine and rec or nil
end

--- Offer one of your drops to a member (design spec §9.2, §11.4): the Offer panel's Offer button,
--- through the messaging edge's Press, so a queued offer is canceled by a second click. A refusal is
--- said in chat. Refused while stood down. With `messages.editFirst` on, a press without `opts`
--- opens the Edit message box instead (state `editing`).
--- @param dropID number
--- @param target string the member's "Name-Realm", name or GUID
--- @param opts table|nil { text = the edited message } (the Edit message box's Send)
--- @return string state, string|nil reason (as NS.Asks.Press, or `editing`)
function NS.PressOffer(dropID, target, opts)
    local state, reason
    if NS.IsStoodDown() then
        state, reason = "refused", "disabled"
    elseif not mineOf(dropID) then
        state, reason = "refused", "noDrop"
    elseif editFirst("offer", target, dropID, opts) then
        state = "editing"
    else
        state, reason = NS.Asks.Press("offer", target, dropID, opts)
    end
    if state == "refused" then
        NS.Print(NS.L["Not offered: %s"]:format(sendRefusal("offer", reason, target)))
    end
    return state, reason
end

--- Announce one of your drops to the group (design spec §9.2, §11.4): the Offer panel's Announce to
--- group, through the messaging edge's Press. A refusal is said in
--- chat. Refused while stood down. With `messages.editFirst` on, a press without `opts` opens the
--- Edit message box instead (state `editing`). Post my tradeables never does: its lines are cut to
--- fit the chat limit, so they are sent as they stand.
--- @param dropID number
--- @param opts table|nil { text = the edited message } (the Edit message box's Send)
--- @return string state, string|nil reason (as NS.Asks.Press, or `editing`)
function NS.PressAnnounce(dropID, opts)
    local state, reason
    if NS.IsStoodDown() then
        state, reason = "refused", "disabled"
    elseif not mineOf(dropID) then
        state, reason = "refused", "noDrop"
    elseif editFirst("announce", nil, dropID, opts) then
        state = "editing"
    else
        state, reason = NS.Asks.Press("announce", nil, dropID, opts)
    end
    if state == "refused" then
        NS.Print(NS.L["Not announced: %s"]:format(sendRefusal("announce", reason)))
    end
    return state, reason
end

--- Hand one of your drops to a member (design spec §11.4, AskFlow B4): the Offer panel's Trade
--- button, through the trade helper's Give and its guards. A refusal is said in chat.
--- @param dropID number
--- @param target string the member's "Name-Realm", name or GUID
--- @return boolean ok, string|nil reason (as NS.TradeHelper.Give)
function NS.GiveDrop(dropID, target)
    local ok, reason = NS.TradeHelper.Give(dropID, target)
    if not ok then
        NS.Print(NS.L["No trade: %s"]:format(NS.TradeHelper.ReasonText(reason) or tostring(reason)))
    end
    return ok, reason
end

local postSeq = 0   -- each Post my tradeables files its lines under a key of its own

--- Post my tradeables (design spec §11.4): one announce listing every drop of yours you can still
--- trade (in the feed on show), cut at the chat limit into several lines, each sent as an announce
--- through the messaging edge (queued under a restriction, printed in test mode).
--- @return number lines posted (sent or queued)
function NS.PostTradeables()
    local L = NS.L
    if NS.IsStoodDown() then
        NS.Print(NS.SlashCommands:DisabledLine())
        return 0
    end
    local links = {}
    local feed = NS.State.testMode == true and "test" or "live"
    for _, d in ipairs(NS.LootFeed.Drops(feed)) do
        if NS.WindowFilterBar.IsTradeableMine(d) then links[#links + 1] = d.link end
    end
    local lines = NS.MineCells.PostLines(links)
    if #lines == 0 then
        NS.Print(L["Nothing to post: none of your drops can be traded now."])
        return 0
    end
    postSeq = postSeq + 1
    local posted = 0
    for i, text in ipairs(lines) do
        local state, reason = NS.Asks.Request("announce", nil, ("post:%d:%d"):format(postSeq, i), { text = text })
        if state == "sent" or state == "queued" then
            posted = posted + 1
        else
            NS.Print(L["Not announced: %s"]:format(sendRefusal("announce", reason)))
        end
    end
    NS.Debug("UI", "post my tradeables: %d of %d lines", posted, #lines)
    return posted
end

--- Show the window in one layout, `full` or `compact` (compact spec §1): `window.mode` through the
--- write seam. The row's reaction (NS.WindowCompact.OnModeChanged) lets a run's compact override go,
--- since the player chose, and lays the window out. The title-bar toggle, the Window page's Layout
--- row, `/dw compact` and `/dw full` share it.
--- @param mode string
function NS.SetWindowMode(mode)
    NS.SchemaRuntime.Set("window.mode", mode)
end

--- Switch to the other layout from the one in force (the title-bar toggle, `/dw compact`).
function NS.ToggleWindowMode()
    NS.SetWindowMode(NS.WindowCompact.Mode() == "compact" and "full" or "compact")
end

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
-- (an incoming profile carries its own answer to `enabled`), auto-ask's and the toast's `enabled`
-- re-read (no row reaction runs on a switch) and the window's settings.
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
    if NS.AutoAsk then NS.AutoAsk.OnProfileReloaded() end
    if NS.Toast then NS.Toast.OnProfileReloaded() end
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
    -- The "Keep history for" confirmation's baseline: the stored window is the confirmed one.
    if NS.HistoryRetention then NS.HistoryRetention.Sync() end

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
