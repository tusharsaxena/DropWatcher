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
    assertEqual(table.concat(names, ","), "identity,settings,window,situation,restrictions,registration,integrations")
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
