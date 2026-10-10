-- tests/test_slash.lua — the verb table and the host verbs (slash-commands-§1/§2/§3).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local RESERVED = { "help", "config", "enable", "disable", "version", "list", "get", "set", "reset",
    "resetall", "profile", "debug", "diagnostics", "perf" }

local function verbs(NS)
    local out = {}
    for _, entry in ipairs(NS.COMMANDS) do out[entry[1]] = entry end
    return out
end

test("slash: NS.COMMANDS is positional triples, every reserved verb present", function()
    local NS = T.newAddon()
    for _, entry in ipairs(NS.COMMANDS) do
        -- red under: write one entry as { name = ..., desc = ..., fn = ... }
        assertTrue(type(entry[1]) == "string" and type(entry[2]) == "string" and type(entry[3]) == "function",
            "positional triple: " .. tostring(entry[1]))
    end
    local v = verbs(NS)
    for _, name in ipairs(RESERVED) do assertTrue(v[name] ~= nil, "reserved verb " .. name) end
end)

test("slash: `diagnostics` has no alias of any kind (debug-logging-§14)", function()
    local NS = T.newAddon()
    local v = verbs(NS)
    assertTrue(v.diag == nil and v.dump == nil and v.dx == nil)
end)

test("slash: both chat commands are registered through AceConsole, and both dispatch", function()
    local _, _, m = T.bootAddon()
    local AC = m.LibStub("AceConsole-3.0")
    assertTrue(AC.commands.dw ~= nil and AC.commands.dropwatcher ~= nil, "dw and dropwatcher")
    m.prints = {}
    AC:__slash("dropwatcher", "version")
    assertTrue(m.prints[1]:find("0.1.0", 1, true) ~= nil, tostring(m.prints[1]))
end)

test("slash: the bare command opens the settings panel", function()
    local NS = T.enableAddon()
    local opened = 0
    local H = NS.addon.Settings.Helpers
    local real = H.OpenOptionsPanel
    H.OpenOptionsPanel = function() opened = opened + 1 end
    NS.addon:OnSlashCommand("")
    H.OpenOptionsPanel = real
    assertEqual(opened, 1)
end)

test("slash: lock and unlock write `locked` through the seam", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("lock")
    assertEqual(NS.addon.db.profile.locked, true)
    NS.addon:OnSlashCommand("unlock")
    assertEqual(NS.addon.db.profile.locked, false)
end)

test("slash: show, hide and toggle drive the window", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("show")
    assertTrue(NS.IsWindowShown())
    NS.addon:OnSlashCommand("hide")
    assertFalse(NS.IsWindowShown())
    NS.addon:OnSlashCommand("toggle")
    assertTrue(NS.IsWindowShown())
end)

test("slash: `test` toggles test mode through the shared handler", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("test")
    assertTrue(NS.State.testMode)
    assertTrue(NS.IsWindowShown(), "test mode shows the window")
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.State.testMode)
end)

test("slash: `perf` is the addon's verb and prints the harness's lines", function()
    local NS, _, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("perf")
    assertTrue(#m.prints > 0, "the library returned lines and the addon printed them")
end)

test("slash: `reset` with no path explains itself rather than resetting everything", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("scale", 1.5)
    m.prints = {}
    NS.addon:OnSlashCommand("reset")
    assertEqual(NS.addon.db.profile.scale, 1.5)
    assertTrue(m.prints[1]:find("takes a setting path", 1, true) ~= nil)
end)

test("slash: degraded, the host verbs still work and the CLI names the missing library", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    D.addon:OnSlashCommand("lock")
    assertEqual(D.addon.db.profile.locked, true)
    D.addon:OnSlashCommand("list")
    assertTrue(m.prints[#m.prints]:find("settings CLI is unavailable", 1, true) ~= nil)
    D.addon:OnSlashCommand("disable")
    m.prints = {}
    D.addon:OnSlashCommand("test")
    -- The degraded dispatcher refuses a feature verb while disabled, with the library's line.
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, tostring(m.prints[1]))
    assertFalse(D.State.testMode)
end)
