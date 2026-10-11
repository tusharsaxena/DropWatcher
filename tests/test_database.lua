-- tests/test_database.lua — the defaults tree and the migration runner (savedvariables-§1).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

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
    assertEqual(g.schemaVersion, NS.SCHEMA_VERSION, "the next load retries it")
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
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: step 2 passes a fresh default profile through unchanged", function()
    local NS = T.bootAddon()
    local fresh = deepcopy(NS.addon.Settings.BuildDefaults().profile)
    assertEqual(NS.RepairStoredSettings(fresh), 0)
end)

-- Feedback-2 spec §1 (DW-A1): the View becomes a set, and the three checkboxes fold into it.
test("database: step 3 folds the View and the three checkboxes into the View set, per profile", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 2 },
        profiles = {
            -- The kit's AceDB fake turns a non-table under a table default into a table when it
            -- activates a profile (real AceDB keeps it), so the old strings sit on profiles that are
            -- not the active one, and the active one holds only the checkbox leaves.
            Default = { feed = { upgradeOnly = true }, trade = { likelyOnly = true } },
            Main = { feed = { view = "interesting", usableOnly = true }, trade = { likelyOnly = false, warnAt = 60 } },
            Raid = { feed = { view = "all", upgradeOnly = true }, trade = { likelyOnly = true } },
            Plain = { feed = { view = "all", content = "session" } },
            Empty = {},
        },
    }
    -- red under: no step 3 (the old string and the checkbox leaves stay)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    local d = p.Main
    assertTrue(d.feed.view.interesting and d.feed.view.usable, "a stored Interesting and Usable by me are kept")
    assertTrue(d.feed.view.likely == nil and d.feed.usableOnly == nil and d.trade.likelyOnly == nil)
    assertEqual(d.trade.warnAt, 60, "the rest of the profile is untouched")
    local r = p.Raid
    assertTrue(r.feed.view.upgrade and r.feed.view.likely and r.feed.view.interesting == nil,
        "All with two checkboxes on: those two")
    assertTrue(r.feed.upgradeOnly == nil and r.trade.likelyOnly == nil)
    assertTrue(p.Plain.feed.view == nil, "All with nothing on: the new default, All")
    assertEqual(p.Plain.feed.content, "session")
    assertTrue(p.Empty.feed == nil, "a profile that stored nothing gets nothing")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local FB = NS.WindowFilterBar
    assertEqual(FB.ViewLabel(FB.Defaults().view), "View: 2 selected", "the active profile seeds its set")
end)

test("database: step 3 passes a profile already in the new shape through unchanged", function()
    local NS = T.bootAddon()
    local fresh = deepcopy(NS.addon.Settings.BuildDefaults().profile)
    NS.MigrateViewSet(fresh)
    assertEqual(fresh.feed.view.interesting, false, "the default set stays")
    local chosen = { feed = { view = { likely = true } } }
    NS.MigrateViewSet(chosen)
    NS.MigrateViewSet(chosen)
    assertTrue(chosen.feed.view.likely)
    NS.MigrateViewSet(nil)
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
    assertEqual(NS.addon.db.global.history.retentionDays, 30)
    assertNil(NS.addon.db.global.history.maxGroups, "the group cap is retired")
end)

-- Feedback-2 spec §5 (DW-A5): the History is kept by days; the group cap goes, and nothing is pruned.
test("database: step 4 retires the History's group cap and prunes nothing", function()
    local NS = T.newAddon()
    local old = { at = 1, drops = { { at = 1, outcome = "seen" } } }
    _G.DropWatcherDB = {
        global = { schemaVersion = 3, history = { maxGroups = 35, v = 1, groups = { old } } },
    }
    -- red under: no step 4 (the stored cap stays)
    NS.addon:OnInitialize()
    local h = _G.DropWatcherDB.global.history
    assertNil(h.maxGroups)
    assertEqual(#h.groups, 1, "a group older than any window is still there")
    assertEqual(h.v, 1)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(NS.addon.db.global.history.retentionDays, 30, "the default window")
    NS.RetireHistoryCap(nil); NS.RetireHistoryCap({}); NS.RetireHistoryCap({ global = { history = 3 } })
end)
