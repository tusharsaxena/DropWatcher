-- tests/test_database.lua — the defaults tree and the migration runner (savedvariables-§1).

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target", function()
    local NS = T.newAddon()
    local defaults = NS.addon.Settings.BuildDefaults()
    -- red under: default schemaVersion to NS.SCHEMA_VERSION (AceDB would strip it at logout)
    assertEqual(defaults.global.schemaVersion, 0)
    NS.addon:OnInitialize()
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: the runner is idempotent, and a stored stamp at the target runs no step", function()
    local NS = T.bootAddon()
    local ran = 0
    local real = NS.MIGRATIONS[1]
    NS.MIGRATIONS[1] = function(db) ran = ran + 1; return real(db) end
    NS.addon:RunMigrations()
    NS.addon:RunMigrations()
    NS.MIGRATIONS[1] = real
    assertEqual(ran, 0)
end)

test("database: every step up to the target exists", function()
    local NS = T.newAddon()
    for v = 1, NS.SCHEMA_VERSION do assertTrue(type(NS.MIGRATIONS[v]) == "function", "step " .. v) end
end)

test("database: the profile defaults carry every Master controls value, and no debug flag", function()
    local NS = T.bootAddon()
    local p = NS.addon.db.profile
    assertEqual(p.enabled, true)
    assertEqual(p.visibility, "always")
    assertEqual(p.scale, 1)
    assertEqual(p.alpha, 1)
    assertEqual(p.locked, false)
    -- The debug flag is session-only (debug-logging-§5), and so is test mode.
    assertTrue(p.debug == nil and p.state == nil)
    assertEqual(NS.addon.db.global.minimap.hide, false)
end)
