-- tests/test_disabled.lua — disabled means the addon is not running (slash-commands-§7).
--
-- Built on T.enableAddon() and the kit recorders (tests/_kit/mock_record.lua): `__registrations`,
-- `__timers()`, `__shownFrames`, `__svWrites` / `__resetSvWrites`, `__fire`. Nothing is injected
-- into NS.FEATURE_EVENTS or NS.STAND_*: the suite asserts on the addon's own rows.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The game events the addon owns today, pinned as literals (sorted).
local PINNED = {
    "ADDON_RESTRICTION_STATE_CHANGED", "BAG_UPDATE_DELAYED", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_START",
    "CHAT_MSG_LOOT", "EJ_LOOT_DATA_RECIEVED", "ENCOUNTER_END", "ENCOUNTER_LOOT_RECEIVED", "ENCOUNTER_START",
    "GROUP_ROSTER_UPDATE", "INSPECT_READY", "LOOT_CLOSED", "LOOT_HISTORY_UPDATE_DROP", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED",
    "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_SHOW", "TRADE_TARGET_ITEM_CHANGED",
    "TRANSMOG_COLLECTION_UPDATED", "UI_INFO_MESSAGE", "UNIT_INVENTORY_CHANGED", "ZONE_CHANGED_NEW_AREA",
}

-- The bus messages the addon's receivers listen for (tracked, so the stand-down takes them down),
-- one entry per receiver: a message two modules hear is listed twice (the window, DW-30, hears
-- DropAdded with the trade timer, InspectDone with the feed and RestrictionChanged with the asks;
-- DW-33 added its TradeTimerTick, beside the feed's, and TradeTimerExpiring for the tab of your drops;
-- DW-51's history hears DropAdded, DropUpdated and AskStateChanged, and its tab HistoryChanged;
-- DW-52's toast hears the same three as the history; DW-54's auto-ask hears those three,
-- HistoryChanged and, since the M6 review, RestrictionChanged; DW-83's window hears GearChanged,
-- beside the feed's, for the My eq column).
local PINNED_MESSAGES = { "Ka0s_DropWatcher_AskStateChanged", "Ka0s_DropWatcher_AskStateChanged",
    "Ka0s_DropWatcher_AskStateChanged", "Ka0s_DropWatcher_AskStateChanged",
    "Ka0s_DropWatcher_DropAdded", "Ka0s_DropWatcher_DropAdded", "Ka0s_DropWatcher_DropAdded",
    "Ka0s_DropWatcher_DropAdded", "Ka0s_DropWatcher_DropAdded",
    "Ka0s_DropWatcher_DropUpdated", "Ka0s_DropWatcher_DropUpdated", "Ka0s_DropWatcher_DropUpdated",
    "Ka0s_DropWatcher_DropUpdated",
    "Ka0s_DropWatcher_GearChanged", "Ka0s_DropWatcher_GearChanged",
    "Ka0s_DropWatcher_HistoryChanged", "Ka0s_DropWatcher_HistoryChanged",
    "Ka0s_DropWatcher_InspectDone", "Ka0s_DropWatcher_InspectDone",
    "Ka0s_DropWatcher_RestrictionChanged", "Ka0s_DropWatcher_RestrictionChanged",
    "Ka0s_DropWatcher_RestrictionChanged",
    "Ka0s_DropWatcher_SituationChanged", "Ka0s_DropWatcher_SituationChanged",
    "Ka0s_DropWatcher_TradeTimerExpiring",
    "Ka0s_DropWatcher_TradeTimerTick", "Ka0s_DropWatcher_TradeTimerTick" }

-- What is registered, every kind, or one kind ("event", "message").
local function registered(m, kind)
    local out = {}
    for _, r in ipairs(m.__registrations()) do
        if not kind or r.kind == kind then out[#out + 1] = r.event end
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- Each declared event once: two rows may share one (core/DropWatcher.lua fans it out).
local function declared(NS)
    local out, seen = {}, {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if not seen[row[1]] then
            seen[row[1]] = true
            out[#out + 1] = row[1]
        end
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- The two ways a player disables the addon: the slash verb, and the write seam the Master
-- controls checkbox and the launcher's Enabled entry use.
local DISABLES = {
    { "/dw disable", function(NS) NS.addon:OnSlashCommand("disable") end },
    { "the write seam", function(NS) NS.SchemaRuntime.Set("enabled", false) end },
}

test("disabled 1: enabled, the addon registers exactly the events it declares", function()
    local NS, _, m = T.enableAddon()
    assertEqual(registered(m, "event"), declared(NS))
    assertEqual(registered(m, "event"), table.concat(PINNED, ","))
    assertEqual(registered(m, "message"), table.concat(PINNED_MESSAGES, ","))
end)

for _, way in ipairs(DISABLES) do
    test("disabled 2: through " .. way[1] .. ", nothing is registered, scheduled or shown", function()
        local NS, _, m = T.enableAddon()
        NS.SetTestMode(true)
        assertTrue(NS.IsWindowShown())
        way[2](NS)
        assertTrue(NS.IsStoodDown())
        assertFalse(NS.addon.db.profile.enabled, "the stored setting is the source")
        -- red under: drop the UnregisterEvent loop in NS.StandDown (core/DropWatcher.lua)
        assertEqual(registered(m), "", "every feature event unregistered")
        for _, event in ipairs(PINNED) do assertEqual(m.__fire(event), 0, event) end
        assertEqual(#m.__timers(), 0, "no live timer")
        assertFalse(NS.IsWindowShown(), "the stand-down hid the window")
        assertFalse(NS.State.testMode, "and ended test mode")
        NS.ShowWindow()
        assertFalse(NS.IsWindowShown(), "the show decision refuses at the source")
    end)
end

-- Step 6: every event in R_on fired at the mock anyway, each one proven to have reached the
-- handler its registration named (kit 39's __fireUnconditional answers a count, 0 when nothing was
-- reached), and none of them writes, prints or shows.
test("disabled 3: every feature event, fired anyway while disabled, reaches its handler and writes, prints and shows nothing", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    m.__resetSvWrites()
    m.prints = {}
    local shownBefore = #m.__shownFrames()
    local names = NS.FeatureEventNames()
    local sorted = { unpack(names) }
    table.sort(sorted)
    assertEqual(table.concat(sorted, ","), table.concat(PINNED, ","), "R_on is the pinned set")
    -- red under: re-vendor kit 38 (its __fireUnconditional cannot reach OnCombatStart, so the count is 0)
    for _, event in ipairs(names) do
        assertTrue(m.__fireUnconditional(NS.addon, event) >= 1, event .. " reached no handler")
    end
    -- red under: add `NS.addon.db.profile.locked = true` to DW:OnCombatStart (core/DropWatcher.lua)
    assertEqual(#m.__svWrites(), 0, "no SavedVariables write")
    assertEqual(#m.prints, 0, "no chat output")
    assertEqual(#m.__shownFrames(), shownBefore, "no frame shown")
end)

-- Step 7. The live set is the library's reserved verbs plus `profile`, as settings/Slash.lua builds
-- it; every other verb in NS.COMMANDS is a feature verb.
local LIVE_ARGS = { get = "get enabled", set = "set scale 1.2", reset = "reset scale" }

local function liveSet(m)
    local live = { profile = true }
    for _, verb in ipairs(m.LibStub("LibKa0s-Slash-1.0").LIVE_VERBS) do live[verb] = true end
    return live
end

local function disabledWithOpener()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local opened = 0
    NS.addon.OpenSettings = function() opened = opened + 1 end
    return NS, m, function() return opened end
end

test("disabled 4: every reserved verb, and the bare command, keeps answering while disabled", function()
    local _, m0 = T.enableAddon()
    local verbs = { "" }
    for verb in pairs(liveSet(m0)) do verbs[#verbs + 1] = verb end
    table.sort(verbs)
    assertTrue(#verbs >= 15, "thirteen reserved verbs, profile and the bare command")
    for _, verb in ipairs(verbs) do
        local NS, m, opened = disabledWithOpener()
        m.prints = {}
        m.popupsShown = {}
        NS.addon:OnSlashCommand(LIVE_ARGS[verb] or verb)
        -- red under: drop `liveVerbs = liveVerbs` from the lib:New descriptor in settings/Slash.lua (profile is refused)
        local refusal = NS.SlashCommands:DisabledLine()
        if verb == "help" then
            -- help names the disabled state above its listing, and still lists every verb
            assertTrue(#m.prints > #NS.COMMANDS, "help lists the commands")
        else
            for _, line in ipairs(m.prints) do
                assertTrue(line:find(refusal, 1, true) == nil, "'" .. verb .. "' was refused")
            end
        end
        if verb == "" or verb == "config" then assertEqual(opened(), 1, "'" .. verb .. "' opens the panel") end
        if verb == "resetall" then assertEqual(#m.popupsShown, 1, "resetall shows its popup") end
    end
end)

test("disabled 5: every feature verb answers with the one refusal line and writes nothing", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local live, line, refused = liveSet(m), NS.SlashCommands:DisabledLine(), 0
    for _, entry in ipairs(NS.COMMANDS) do
        local verb = entry[1]
        if not live[verb] then
            m.prints = {}
            m.__resetSvWrites()
            NS.addon:OnSlashCommand(verb)
            -- red under: add the verb's name to `liveVerbs` in settings/Slash.lua
            assertEqual(#m.prints, 1, verb)
            assertTrue(m.prints[1]:find(line, 1, true) ~= nil, verb .. ": " .. m.prints[1])
            assertEqual(#m.__svWrites(), 0, verb .. " wrote SavedVariables")
            refused = refused + 1
        end
    end
    assertTrue(refused >= 16, "every feature verb was driven")
    assertFalse(NS.IsWindowShown())
    assertFalse(NS.State.testMode)
    assertFalse(NS.addon.db.profile.locked)
end)

test("disabled 6: the stand-up re-registers from current state and the window comes back", function()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    NS.addon:OnSlashCommand("disable")
    NS.SchemaRuntime.Set("scale", 1.5)    -- a setting changed while off
    NS.addon:OnSlashCommand("enable")
    assertFalse(NS.IsStoodDown())
    assertEqual(registered(m, "event"), table.concat(PINNED, ","))
    assertEqual(registered(m, "message"), table.concat(PINNED_MESSAGES, ","), "the bus receivers replayed")
    assertTrue(NS.IsWindowShown(), "the player's open window is back")
    assertEqual(NS.Window.Frame():GetScale(), 1.5)
end)

test("disabled 7: a disabled profile loads stood down, with nothing registered", function()
    local NS, _, m = T.bootAddon()
    NS.addon.db.profile.enabled = false
    NS.addon:OnEnable()
    assertTrue(NS.IsStoodDown())
    assertEqual(registered(m), "")
    assertTrue(m.ldbObjects.DropWatcher ~= nil, "setup stays up: the launcher is registered")
end)

test("disabled 8: the launcher's left-click opens settings and writes nothing; its menu grays every entry but Enabled", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local boxes = {}
    local root = {
        CreateTitle = function() end,
        CreateCheckbox = function(_, label, _, onClick)
            local box = { label = label, click = onClick }
            box.SetEnabled = function(self, v) self.enabled = v end
            boxes[#boxes + 1] = box
            return box
        end,
    }
    m.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    local opened = 0
    NS.addon.OpenSettings = function() opened = opened + 1 end
    m.__resetSvWrites()
    local shownBefore = #m.__shownFrames()
    -- red under: route the launcher's LeftButton through NS.ShowWindow (core/LauncherSetup.lua)
    m.ldbObjects.DropWatcher.OnClick(m.UIParent, "LeftButton")
    assertEqual(opened, 1, "left-click opens the settings panel")
    assertEqual(#m.__svWrites(), 0, "left-click writes nothing")
    assertEqual(#m.__shownFrames(), shownBefore, "left-click shows no frame of the addon's")
    m.ldbObjects.DropWatcher.OnClick(m.UIParent, "RightButton")
    assertEqual(#m.__svWrites(), 0, "opening the menu writes nothing")
    assertTrue(boxes[1].enabled == nil, "Enabled stays live")
    for i = 2, #boxes do assertEqual(boxes[i].enabled, false, boxes[i].label) end
    boxes[3].click()
    assertFalse(NS.State.testMode, "a grayed entry writes nothing")
end)

-- Every feature refusal a player can reach while stood down: the slash verbs that get past the
-- dispatcher's gate (it reads the stored `enabled`), and the window's host handlers.
local REFUSERS = {
    { "/dw scan", function(NS) NS.addon:OnSlashCommand("scan") end },
    { "/dw test", function(NS) NS.addon:OnSlashCommand("test") end },
    { "/dw sim start", function(NS) NS.addon:OnSlashCommand("sim start dungeon") end },
    { "Post my tradeables", function(NS) NS.PostTradeables() end },
    { "Retry inspect", function(NS) NS.RetryInspect(1) end },
    { "Ask", function(NS) NS.PressAsk(1) end },
    { "Offer", function(NS) NS.PressOffer(1, "Seta-Realm") end },
    { "Announce to group", function(NS) NS.PressAnnounce(1) end },
    { "Trade", function(NS) NS.TradeWithLooter(1) end },
}

local PERF_LINE = "Not available during a performance capture."

test("disabled 9: under the perf hold alone, each feature refusal names the capture, never 'is disabled'", function()
    local NS, _, m = T.enableAddon()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertTrue(NS.IsStoodDown())
    assertTrue(NS.addon.db.profile.enabled, "the stored setting is still on")
    -- red under: return NS.SlashCommands:DisabledLine() from NS.StoodDownRefusal unconditionally
    assertEqual(NS.StoodDownRefusal(), PERF_LINE)
    for _, r in ipairs(REFUSERS) do
        m.prints = {}
        r[2](NS)
        assertEqual(#m.prints, 1, r[1])
        assertTrue(m.prints[1]:find(PERF_LINE, 1, true) ~= nil, r[1] .. ": " .. tostring(m.prints[1]))
        assertTrue(m.prints[1]:find("is disabled", 1, true) == nil, r[1])
    end
    assertEqual(select(2, NS.PressAsk(1)), "perf", "the press names the hold it refused on")
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertFalse(NS.IsStoodDown())
    assertTrue(NS.StoodDownRefusal() == nil, "no refusal while standing up")
end)

test("disabled 10: while disabled, each feature refusal is the one refusal line, unwrapped", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local line = NS.SlashCommands:DisabledLine()
    assertEqual(NS.StoodDownRefusal(), line)
    for _, r in ipairs(REFUSERS) do
        m.prints = {}
        r[2](NS)
        assertEqual(#m.prints, 1, r[1])
        -- red under: drop the `if stoodDown` print branch in NS.PressAsk (core/DropWatcher.lua)
        assertTrue(m.prints[1]:find(line, 1, true) ~= nil, r[1] .. ": " .. tostring(m.prints[1]))
        assertTrue(m.prints[1]:find("Not ", 1, true) ~= 1 and m.prints[1]:find("No trade", 1, true) == nil, r[1])
    end
    assertEqual(select(2, NS.PressOffer(1, "Seta-Realm")), "disabled")
    assertTrue(NS.TradeHelper.ReasonText("stoodDown"):find(NS.BRAND, 1, true) ~= nil, "the tooltip names the addon")
end)

-- Step 10: the two-hold latch in both orders, through the kit's one form of it.
test("disabled 11: the latch holds in both orders, perf first and disabled first", function()
    local NS, _, m = T.enableAddon()
    -- red under: make NS.StandUp (core/DropWatcher.lua) run whenever the perf hold is released, ignoring the disabled hold
    local R_on = T.assertLatchHoldOrder({
        lifecycle  = NS.Lifecycle,
        perfHold   = NS.HOLD_PERF,
        setEnabled = function(on) NS.SchemaRuntime.Set("enabled", on) end,
        regSet     = m.__registrations,
        label      = NS.BRAND,
    })
    assertTrue(#R_on >= #PINNED + #PINNED_MESSAGES, "R_on holds the events and the bus receivers")
    assertFalse(NS.IsStoodDown(), "the helper leaves the addon enabled")
    assertEqual(registered(m, "event"), table.concat(PINNED, ","))
    assertEqual(registered(m, "message"), table.concat(PINNED_MESSAGES, ","))
end)

-- DW-04: the simulation panel is LibKa0s-Sim-1.0's. Its stand-down stop hides it while a session
-- runs; DropWatcher's own NS.STAND_DOWN step (modules/SimPanel.lua) hides an idle one, which has no
-- session to stop; and the library refuses to show it while stood down.
test("disabled 12: disabling hides the simulation panel, idle or running, and it stays shut", function()
    for _, d in ipairs(DISABLES) do
        local NS = T.enableAddon()
        -- red under: drop modules/SimPanel.lua's NS.STAND_DOWN step (an idle panel has no stop)
        assertTrue(NS.Sim:ShowPanel(), d[1])
        d[2](NS)
        assertFalse(NS.Sim:IsPanelShown(), d[1] .. ": an idle panel closes")
        NS.addon:OnSlashCommand("sim panel")
        assertFalse(NS.Sim:IsPanelShown(), d[1] .. ": `/dw sim panel` is refused")
        assertFalse(NS.Sim:ShowPanel(), d[1] .. ": the library refuses it while stood down")
    end
    local NS = T.enableAddon()
    NS.Sim:Start({ scenario = "key" })
    assertTrue(NS.Sim:IsActive())
    assertTrue(NS.Sim:ShowPanel())
    NS.addon:OnSlashCommand("disable")
    assertFalse(NS.Sim:IsActive(), "the simulation stopped")
    assertFalse(NS.Sim:IsPanelShown(), "and its panel closed")
end)
