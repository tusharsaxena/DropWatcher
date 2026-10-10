-- tests/test_diagnostics.lua — the addon's own sections of the diagnostics report
-- (debug-logging-§14). The contract around them (both forms, append, the run turning logging on,
-- the markers, no alias) is the kit's test_diagnostics_contract.lua, run against this dispatcher.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

test("diagnostics: the sections are the addon's, in report order", function()
    local NS = T.newAddon()
    local names = {}
    for i, s in ipairs(NS.Diagnostics.Sections()) do names[i] = s[1] end
    assertEqual(table.concat(names, ","), "identity,settings,window,situation,restrictions,roster,gear,registration,integrations")
end)

test("diagnostics: the report names the schema, the profile, the holds and the window decision", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local text = report(NS)
    assertTrue(text:find("schema stored=1 code=1", 1, true) ~= nil, "identity")
    assertTrue(text:find("profile=", 1, true) ~= nil)
    assertTrue(text:find("window: built=true shown=true shouldShow=true", 1, true) ~= nil, "window")
    assertTrue(text:find("PLAYER_REGEN_DISABLED", 1, true) ~= nil, "registration")
end)

test("diagnostics: the situation section names the key, its settings and the inputs", function()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    local text = report(NS)
    assertTrue(text:find("situation: dungeon (last announced dungeon) track=true autoOpen=true quality=global", 1, true) ~= nil, text)
    assertTrue(text:find("situation inputs: inInstance=true type=party difficulty=2 challengeMode=false", 1, true) ~= nil)
end)

test("diagnostics: it runs while stood down and says so, without acting", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local text = report(NS)
    assertTrue(text:find("stoodDown=true", 1, true) ~= nil)
    assertTrue(text:find("holds disabled", 1, true) ~= nil, text)
    assertTrue(NS.IsStoodDown(), "the report changed nothing")
end)

test("diagnostics: a non-default setting is listed, and `enabled` always is", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("scale", 1.5)
    local text = report(NS)
    assertTrue(text:find("scale", 1, true) ~= nil and text:find("1.5", 1, true) ~= nil)
    assertTrue(text:find("enabled", 1, true) ~= nil)
end)

test("diagnostics: the restrictions section names the answers, the reasons and the last announced", function()
    local NS, _, m = T.enableAddon()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    m.restrictionStates[RT.Map] = RS.Active
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", RT.Encounter, RS.Active)
    local text = report(NS)
    assertTrue(text:find("restrictions: reason=encounter canSendChat=false canInspect=true canTrade=true", 1, true) ~= nil, text)
    assertTrue(text:find("restrictions: active", 1, true) ~= nil)
    assertTrue(text:find("encounter, map", 1, true) ~= nil or text:find("encounter,map", 1, true) ~= nil, text)
    assertTrue(text:find("restrictions: last announced encounter|false|true|true", 1, true) ~= nil, text)
end)

test("diagnostics: the roster section lists the stored members without reading the client", function()
    local NS, _, m = T.enableAddon()
    NS.State.roster = nil
    assertTrue(report(NS):find("roster: not read yet", 1, true) ~= nil)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", classFile = "WARRIOR", connected = false } })
    m.__fire("GROUP_ROSTER_UPDATE")
    local text = report(NS)
    assertTrue(text:find("roster: 2 members", 1, true) ~= nil, text)
    assertTrue(text:find("roster: Brakk-Testrealm unit=party1 class=WARRIOR online=false spec=unknown player=false", 1, true) ~= nil, text)
end)

test("diagnostics: the gear section lists the stored slots without reading the client", function()
    local NS, _, m = T.enableAddon()
    NS.State.gear = nil
    assertTrue(report(NS):find("gear: not read yet", 1, true) ~= nil)
    local HEAD = "|cnIQ4:|Hitem:3001::::::::90:::::|h[Hood]|h|r"
    local RING = "|cnIQ4:|Hitem:3002::::::::90:::::|h[Band]|h|r"
    m.addItem(HEAD, { name = "Hood", quality = 4, ilvl = 610, equipLoc = "INVTYPE_HEAD", classID = 4,
        subClassID = 1, stats = {} })
    m.addItem(RING, { name = "Band", quality = 3, ilvl = 620, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, stats = {} })
    m.inventory.player[1] = HEAD
    m.bags[0] = { size = 1, [1] = RING }
    NS.Gear.Refresh("test")
    local text = report(NS)
    assertTrue(text:find("gear: class=MAGE spec=250 dualWield=false", 1, true) ~= nil, text)
    assertTrue(text:find("gear: HEAD ilvl=610 quality=4", 1, true) ~= nil, text)
    assertTrue(text:find("gear: NECK empty", 1, true) ~= nil, text)
    assertTrue(text:find("gear: FINGER1 empty owned=620", 1, true) ~= nil, text)
end)
