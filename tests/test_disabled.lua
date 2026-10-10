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
    "CHAT_MSG_LOOT", "ENCOUNTER_END", "ENCOUNTER_LOOT_RECEIVED", "ENCOUNTER_START",
    "GROUP_ROSTER_UPDATE", "INSPECT_READY", "LOOT_HISTORY_UPDATE_DROP", "PLAYER_DIFFICULTY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED",
    "TRANSMOG_COLLECTION_UPDATED", "UNIT_INVENTORY_CHANGED", "ZONE_CHANGED_NEW_AREA",
}

-- The bus messages the addon's receivers listen for (tracked, so the stand-down takes them down).
local PINNED_MESSAGES = { "Ka0s_DropWatcher_GearChanged", "Ka0s_DropWatcher_InspectDone" }

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

test("disabled 3: no SavedVariables write from a game event while disabled", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    m.__resetSvWrites()
    m.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED")
    m.__fireUnconditional(NS.addon, "PLAYER_REGEN_ENABLED")
    assertEqual(#m.__svWrites(), 0)
end)

test("disabled 4: every reserved verb keeps answering while disabled", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    for _, verb in ipairs({ "help", "version", "list", "get enabled", "diagnostics", "profile" }) do
        m.prints = {}
        NS.addon:OnSlashCommand(verb)
        local refused = false
        for _, line in ipairs(m.prints) do
            if line:find("is disabled", 1, true) and not line:find("slash commands", 1, true) then
                refused = verb ~= "help"
            end
        end
        assertFalse(refused, verb .. " was refused")
    end
end)

test("disabled 5: a feature verb answers with the one refusal line and does nothing", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    for _, verb in ipairs({ "show", "test", "lock" }) do
        m.prints = {}
        NS.addon:OnSlashCommand(verb)
        assertEqual(#m.prints, 1, verb)
        assertTrue(m.prints[1]:find("Ka0s Drop Watcher is disabled", 1, true) ~= nil, m.prints[1])
    end
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

test("disabled 8: the launcher's menu grays every entry but Enabled", function()
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
    m.ldbObjects.DropWatcher.OnClick(m.UIParent, "RightButton")
    assertTrue(boxes[1].enabled == nil, "Enabled stays live")
    for i = 2, #boxes do assertEqual(boxes[i].enabled, false, boxes[i].label) end
    boxes[3].click()
    assertFalse(NS.State.testMode, "a grayed entry writes nothing")
end)
