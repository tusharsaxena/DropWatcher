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
                situations = { solo = { track = false, quality = "loud" } },
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
    -- The loot rule rows are Retail's alone (Forever port design §4.4): on WoW Forever no row checks
    -- the stored rules, and TradeRules takes none of Retail's names as a rule there.
    if not T.forever then
        assertEqual(raid.trade.rules.raid, "group")
        assertTrue(raid.trade.rules.pvp == nil)
    end
    assertTrue(raid.messages.templates.ask == nil, "an empty template is dropped")
    assertEqual(raid.messages.templates.offer, "Mine: {item}")
    assertTrue(raid.messages.announceChannel == nil, "SAY is never a channel")
    assertEqual(raid.situations.solo.track, false)
    assertTrue(raid.situations.solo.quality == nil)
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

-- Feedback-5 spec §2 (DW-E2): Drops always lists your own drops; the retired switch's key goes.
test("database: step 6 retires feed.showOwn in every stored profile and keeps the rest", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 5 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { feed = { showOwn = true, clearOnBossKill = true } },
            Alt = { feed = { showOwn = false } },
        },
    }
    -- red under: no step 6 (the stored switch stays)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertNil(p.Default.feed.showOwn); assertNil(p.Alt.feed.showOwn)
    assertEqual(p.Default.feed.clearOnBossKill, true, "the other feed settings stay")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    NS.RetireShowOwn(nil); NS.RetireShowOwn({}); NS.RetireShowOwn({ feed = 3 })
end)

-- Feedback-6 spec §1 (DW-F1): My eq and Their eq merged into Me and Them; their toggles' keys go.
test("database: step 7 retires window.columns.myEq and theirEq in every stored profile and keeps the rest", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 6 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { window = { columns = { myEq = false, theirEq = true, me = false, slot = false } } },
            Alt = { window = { columns = { theirEq = false } } },
            Bare = { window = { mode = "compact" } },
        },
    }
    -- red under: no step 7 (the stored toggles stay)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertNil(p.Default.window.columns.myEq); assertNil(p.Default.window.columns.theirEq)
    assertNil(p.Alt.window.columns.theirEq)
    assertEqual(p.Default.window.columns.me, false, "the merged column's own toggle stays")
    assertEqual(p.Default.window.columns.slot, false, "the other toggles stay")
    assertEqual(p.Bare.window.mode, "compact")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.addon.db.profile.window.columns.myEq == nil, "no default brings it back")
    NS.RetireEqColumns(nil); NS.RetireEqColumns({}); NS.RetireEqColumns({ window = 3 })
    NS.RetireEqColumns({ window = { columns = 3 } })
    for _, key in ipairs({ "myEq", "theirEq" }) do
        assertNil(NS.SchemaRuntime.FindRow("window.columns." .. key), key .. ": no settings row toggles it")
    end
end)

-- IS-DW-07 (Item Search spec §4.8): the detail card's Sources chip is retired, and its switch's
-- stored key with it, in every profile.
test("database: step 15 retires window.itemSources in every stored profile and keeps the rest", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 14 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { window = { itemSources = false, mode = "compact" } },
            Alt = { window = { itemSources = true } },
            Bare = { feed = { sort = "oldest" } },
        },
    }
    -- red under: no step 15 (the stored switch stays)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertNil(p.Default.window.itemSources); assertNil(p.Alt.window.itemSources)
    assertEqual(p.Default.window.mode, "compact", "the rest of the window settings stay")
    assertEqual(p.Bare.feed.sort, "oldest")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 15)
    assertNil(NS.addon.db.profile.window.itemSources, "no default brings it back")
    assertNil(NS.SchemaRuntime.FindRow("window.itemSources"), "no settings row")
    NS.RetireItemSources(nil); NS.RetireItemSources({}); NS.RetireItemSources({ window = 3 })
end)

-- The Item Search split (DropWatcher#19, plan task D1): Item Search moved to its own addon, Ka0s
-- Item Search, and takes none of this data (no migration, R5), so step 19 deletes every stored
-- itemSearch table: each profile's settings, the account-wide prices and learned recipes, and each
-- character's key default mark.
test("database: step 19 deletes every stored itemSearch table and keeps the rest", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 18, itemSearch = { prices = { [1] = { [2] = { p = 5 } } },
            learnedRecipes = { [3] = true } }, minimap = { hide = true } },
        profileKeys = { ["Me - Realm"] = "Default" },
        char = { ["Me - Realm"] = { itemSearch = { keyDefaultedV = 2 }, role = { mode = "tank" } } },
        profiles = {
            Default = { itemSearch = { tooltip = { rows = 7 }, window = { pins = false } },
                window = { mode = "compact" } },
            Alt = { itemSearch = {} },
            Bare = { feed = { sort = "oldest" } },
        },
    }
    -- red under: no step 19 (the stored tables stay)
    NS.addon:OnInitialize()
    local sv = _G.DropWatcherDB
    assertNil(sv.global.itemSearch, "the account-wide prices and learned recipes go")
    assertNil(sv.char["Me - Realm"].itemSearch, "the character's key default mark goes")
    assertNil(sv.profiles.Default.itemSearch); assertNil(sv.profiles.Alt.itemSearch)
    assertEqual(sv.global.minimap.hide, true, "the rest of global stays")
    assertEqual(sv.char["Me - Realm"].role.mode, "tank", "the rest of the character's data stays")
    assertEqual(sv.profiles.Default.window.mode, "compact", "the rest of the profile stays")
    assertEqual(sv.profiles.Bare.feed.sort, "oldest")
    assertTrue(NS.SCHEMA_VERSION >= 19)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertNil(NS.addon.db.profile.itemSearch, "no default brings it back")
    assertNil(NS.SchemaRuntime.FindRow("itemSearch.tooltip.enabled"), "no settings row")
    NS.RetireItemSearchRows(nil); NS.RetireItemSearchRows({}); NS.RetireItemSearchRows({ global = 3, char = 3, profiles = 3 })
end)

-- An account stored before Item Search's own steps (16 to 18) runs them over data step 17 now
-- deletes: nothing of it is left, and nothing raises.
test("database: steps 16 to 19 over a schema-15 account leave no itemSearch table", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 15, itemSearch = { recent = { "Linen Cloth" } } },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = { Default = { itemSearch = { tooltip = { dropsShown = 4, order = { "drops" } },
            window = { density = "compact" } } } },
    }
    NS.addon:OnInitialize()
    local sv = _G.DropWatcherDB
    assertNil(sv.global.itemSearch); assertNil(sv.profiles.Default.itemSearch)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

-- DW-04 (LibKa0s#54, OWNER_SCOPE C.11): the simulation panel's position is session-only, so the
-- window-state key the retired DropWatcher panel wrote (`profile.simPanel`) goes.
test("migrate 9: a stored simPanel point is retired, idempotently, and nothing else changes", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 8 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { simPanel = { point = { "TOPLEFT", "TOPLEFT", 40, -60 } }, feed = { content = "session" } },
            Alt = { window = { mode = "compact" } },
        },
    }
    -- red under: no step 9 (the stored point stays)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertNil(p.Default.simPanel, "the stored point goes")
    assertEqual(p.Default.feed.content, "session", "the rest of the profile stays")
    assertEqual(p.Alt.window.mode, "compact")
    assertNil(p.Alt.simPanel)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 9)
    local again = { simPanel = { point = {} }, sim = { stepDelay = 3 } }
    NS.RetireSimPanelPoint(again); NS.RetireSimPanelPoint(again)
    assertNil(again.simPanel); assertEqual(again.sim.stepDelay, 3)
    NS.RetireSimPanelPoint(nil); NS.RetireSimPanelPoint({}); NS.RetireSimPanelPoint(3)
    assertNil(NS.addon.db.profile.simPanel, "no default brings it back")
end)

-- R3-FRIZ: LibKa0s v1.85.0 deleted Ka0s Friz Quadrata TT (R3-L7); step 12 moves a stored pick of it to
-- Ka0s Ubuntu in every stored profile, at any depth. red under: no step 12, one that reaches only the
-- active profile or only the top level, or one that rewrites Blizzard's own "Friz Quadrata TT".
test("database: step 12 moves a stored Ka0s Friz Quadrata TT to Ka0s Ubuntu in every profile, Blizzard's Friz kept", function()
    local NS = T.newAddon()
    local FRIZ = "Ka0s Friz Quadrata TT"
    _G.DropWatcherDB = {
        global = { schemaVersion = 11 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { skin = { fullSkinReset = true, font = FRIZ }, window = { tableFont = FRIZ } },
            Alt = { skin = { fullSkinReset = true }, window = { tableFont = FRIZ } },
            Plain = { skin = { fullSkinReset = true }, window = { tableFont = "Friz Quadrata TT" } },
        },
    }
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.window.tableFont, "Ka0s Ubuntu", "the active profile's table font")
    assertEqual(p.Default.skin.font, "Ka0s Ubuntu", "the skin override")
    assertEqual(p.Alt.window.tableFont, "Ka0s Ubuntu", "another stored profile")
    assertEqual(p.Plain.window.tableFont, "Friz Quadrata TT", "Blizzard's own Friz stays")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(NS.RetireFonts(p.Alt), 0, "a second pass moves nothing")
end)

-- DW-CAT2 (issue #13, categories design spec §5.2): step 13 replaces Gear only and Include tier tokens
-- with the item kinds. red under: no step 13; one that reaches only the active profile; one that skips
-- cosmetics on gearOnly = false; one that applies includeTokens before the gearOnly sweep; or one that
-- leaves either retired key behind.
test("database: step 13 turns a stored gearOnly = false into every item kind, carries includeTokens, in every profile", function()
    local NS = T.newAddon()
    local KINDS = { "equipment", "tierToken", "mount", "pet", "toy", "recipe", "cosmetic" }
    _G.DropWatcherDB = {
        global = { schemaVersion = 12 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { feed = { gearOnly = false, minIlvl = 600 } },
            Both = { feed = { gearOnly = false, includeTokens = false } },
            Tokens = { feed = { includeTokens = false } },
            Fresh = { window = { mode = "compact" } },
        },
    }
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    for _, key in ipairs(KINDS) do
        assertEqual(p.Default.feed.categories[key], true, "every kind on: " .. key)
    end
    assertEqual(p.Default.feed.minIlvl, 600, "the other feed settings stay")
    assertEqual(p.Both.feed.categories.tierToken, false, "includeTokens = false beside gearOnly = false")
    assertEqual(p.Both.feed.categories.cosmetic, true)
    assertEqual(p.Tokens.feed.categories.tierToken, false, "includeTokens alone")
    assertNil(p.Tokens.feed.categories.equipment, "nothing else written: the default stands")
    assertNil(p.Fresh.feed, "a fresh profile untouched")
    for _, name in ipairs({ "Default", "Both", "Tokens" }) do
        assertNil(p[name].feed.gearOnly, name .. ": gearOnly goes")
        assertNil(p[name].feed.includeTokens, name .. ": includeTokens goes")
    end
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 13)
    assertEqual(NS.Setting("feed.categories.cosmetic"), true, "the active profile reads the migrated kinds")
    local again = { feed = { categories = { mount = false } } }
    NS.MigrateItemKinds(again); NS.MigrateItemKinds(again)
    assertEqual(again.feed.categories.mount, false, "idempotent: a stored kind is kept")
    local bare = { feed = { sort = "oldest" } }
    NS.MigrateItemKinds(bare)
    assertNil(bare.feed.categories, "no kinds table made from nothing")
    NS.MigrateItemKinds(nil); NS.MigrateItemKinds({}); NS.MigrateItemKinds({ feed = 3 })
    for _, key in ipairs({ "gearOnly", "includeTokens" }) do
        assertNil(NS.SchemaRuntime.FindRow("feed." .. key), key .. ": no settings row reads it")
    end
end)

-- SD-RV-DW (LibKa0s v1.108.0, OptionsCompose minor 20; skinning-§9, Every option default follows the
-- skin, the owner's R-2): the tables' Font color gains Use the skin's color, on by default. A stored
-- swatch other than the old default was a pick, which must keep drawing, so step 14 turns that
-- profile's companion off once. red under: no step 14; one that reaches only the active profile; one
-- that turns the companion off for a swatch at the default, a partial one AceDB left at the default,
-- or a profile with no swatch; or one that skips the active profile because AceDB copied the
-- companion's default into it.
test("database: step 14 keeps a picked table text color drawing, in every profile, and nothing else", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 13 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { skin = { fullSkinReset = true }, window = { tableFontColor = { r = 1, g = 0.5, b = 0, a = 1 } } },
            Alt = { skin = { fullSkinReset = true }, window = { tableFontColor = { r = 0.2 } } },
            Alpha = { skin = { fullSkinReset = true }, window = { tableFontColor = { a = 0.5 } } },
            AtDefault = { skin = { fullSkinReset = true }, window = { tableFontColor = { r = 0.92, g = 0.92, b = 0.92, a = 1 } } },
            Partial = { skin = { fullSkinReset = true }, window = { tableFontColor = {} } },
            Fresh = { skin = { fullSkinReset = true }, window = { mode = "compact" } },
        },
    }
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.window.tableFontColorFromSkin, false, "the active profile's pick")
    assertEqual(p.Alt.window.tableFontColorFromSkin, false, "another stored profile, one channel stored")
    assertEqual(p.Alpha.window.tableFontColorFromSkin, false, "an opacity of its own is a pick")
    assertNil(p.AtDefault.window.tableFontColorFromSkin, "a swatch at the default follows the skin")
    assertNil(p.Partial.window.tableFontColorFromSkin, "a swatch AceDB stripped to the default follows it")
    assertNil(p.Fresh.window.tableFontColorFromSkin, "a profile with no swatch is untouched")
    assertEqual(p.Default.window.tableFontColor.g, 0.5, "the pick itself is not written")
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 14)
    assertEqual(NS.Setting("window.tableFontColorFromSkin"), false, "the active profile reads it")
    local again = { window = { tableFontColor = { r = 1 } } }
    NS.KeepTableFontColorPick(again); NS.KeepTableFontColorPick(again)
    assertEqual(again.window.tableFontColorFromSkin, false, "idempotent")
    NS.addon:RunMigrations()
    NS.SchemaRuntime.Set("window.tableFontColorFromSkin", true)
    NS.addon:RunMigrations()
    assertEqual(NS.Setting("window.tableFontColorFromSkin"), true, "the stamp keeps a later on from being turned off")
    NS.KeepTableFontColorPick(nil); NS.KeepTableFontColorPick({}); NS.KeepTableFontColorPick({ window = 3 })
    NS.KeepTableFontColorPick({ window = { tableFontColor = "red" } })
end)
