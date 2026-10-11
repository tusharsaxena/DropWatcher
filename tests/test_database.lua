-- tests/test_database.lua — the defaults tree and the migration runner (savedvariables-§1).

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
end

test("database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target", function()
    local NS = T.newAddon()
    local defaults = NS.addon.Settings.BuildDefaults()
    -- red under: default schemaVersion to NS.SCHEMA_VERSION (AceDB would strip it at logout)
    assertEqual(defaults.global.schemaVersion, 0)
    NS.addon:OnInitialize()
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.addon.db.global.schemaVersion ~= defaults.global.schemaVersion,
        "the advanced stamp differs from its default, so the logout strip keeps it")
end)

test("database: the runner is idempotent, and a stored stamp at the target runs no step", function()
    local NS = T.bootAddon()
    local ran = 0
    local wrapped = {}
    for i, step in ipairs(NS.MIGRATIONS) do
        local real = step.run
        wrapped[i] = real
        step.run = function(...) ran = ran + 1; return real(...) end
    end
    NS.addon:RunMigrations()
    NS.addon:RunMigrations()
    for i, step in ipairs(NS.MIGRATIONS) do step.run = wrapped[i] end
    assertEqual(ran, 0)
end)

test("database: the steps rise one by one, and the target is the highest step", function()
    local NS = T.newAddon()
    for i, step in ipairs(NS.MIGRATIONS) do
        assertEqual(step.to, i, "step " .. i)
        assertTrue(type(step.run) == "function", "step " .. i .. " runs")
    end
    assertEqual(NS.SCHEMA_VERSION, NS.MIGRATIONS[#NS.MIGRATIONS].to)
end)

test("database: a step that raises leaves the stamp at the last completed step", function()
    local NS = T.bootAddon()
    local g = NS.addon.db.global
    g.schemaVersion = 1
    local step = NS.MIGRATIONS[2]
    local real = step.run
    step.run = function() error("boom") end
    -- red under: advance the stamp before running the step
    local ok = pcall(NS.addon.RunMigrations, NS.addon)
    step.run = real
    assertTrue(not ok, "the raise reaches the caller")
    assertEqual(g.schemaVersion, 1)
    NS.addon:RunMigrations()
    assertEqual(g.schemaVersion, 2, "the next load retries it")
end)

test("database: step 2 reaches a stored profile that is not the active one", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 1 },
        profiles = {
            Raid = {
                feed = { quality = { mode = "bogus", fixed = 4 } },
                window = { compact = "yes", columns = { slot = false, me = 1 } },
                trade = { rules = { raid = "group", pvp = "nope" } },
                messages = { templates = { ask = "", offer = "Mine: {item}" }, announceChannel = "SAY" },
                situations = { delve = { track = true, quality = "loud" } },
            },
        },
    }
    -- red under: run the step for the active profile only (db.profile, not sv.profiles)
    NS.addon:OnInitialize()
    local raid = _G.DropWatcherDB.profiles.Raid
    assertTrue(raid.feed.quality.mode == nil, "an unknown mode is dropped")
    assertEqual(raid.feed.quality.fixed, 4, "a valid value stays")
    assertTrue(raid.window.compact == nil and raid.window.columns.me == nil, "non-booleans are dropped")
    assertEqual(raid.window.columns.slot, false)
    assertEqual(raid.trade.rules.raid, "group")
    assertTrue(raid.trade.rules.pvp == nil)
    assertTrue(raid.messages.templates.ask == nil, "an empty template is dropped")
    assertEqual(raid.messages.templates.offer, "Mine: {item}")
    assertTrue(raid.messages.announceChannel == nil, "SAY is never a channel")
    assertEqual(raid.situations.delve.track, true)
    assertTrue(raid.situations.delve.quality == nil)
    assertEqual(NS.addon.db.global.schemaVersion, 2)
end)

test("database: step 2 passes a fresh default profile through unchanged", function()
    local NS = T.bootAddon()
    local fresh = deepcopy(NS.addon.Settings.BuildDefaults().profile)
    assertEqual(NS.RepairStoredSettings(fresh), 0)
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
    assertEqual(NS.addon.db.global.history.maxGroups, 20)
end)
