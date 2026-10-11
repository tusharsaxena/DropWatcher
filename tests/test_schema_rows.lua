-- tests/test_schema_rows.lua — every setting of design spec §12.1 has a row, a default in
-- defaults/Profile.lua and a check the write seam runs (architecture-§5, savedvariables-§2).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local SITUATIONS = {
    "mythicPlus", "dungeon", "followerDungeon", "raidLFR", "raid", "delve", "scenario", "pvp",
    "openWorldGroup", "solo",
}
local COLUMNS = { "ilvl", "slot", "looter", "myEq", "theirEq", "me", "them", "trade", "actions" }

-- Spec §12.1's keys as stored paths. `debug` is the session-only console row, `minimap.shown` the
-- global closure row; `window.point`, `size`, `minimized` and `toast.point` are named state.
local function specPaths()
    local out = {
        "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole", "global.minimap.shown",
        "autoOpen",
        "feed.view", "feed.quality.mode", "feed.quality.fixed", "feed.quality.floor",
        "feed.quality.upgradeOverride", "feed.gearOnly", "feed.includeTokens", "feed.minIlvlMode",
        "feed.minIlvl", "feed.relativeIlvl", "feed.showOwn", "feed.clearOnBossKill", "feed.sort",
        "feed.content", "feed.usableOnly", "feed.upgradeOnly",
        "comparison.scorer", "comparison.weights", "comparison.sidegradeBand", "comparison.compareOwned",
        "comparison.heirloomProtect", "comparison.undesired",
        "trade.warnAt", "trade.likelyOnly",
        "messages.templates.ask", "messages.templates.offer", "messages.templates.announce",
        "messages.editFirst", "messages.oneAsk", "messages.announceChannel", "messages.autoAsk.enabled",
        "messages.autoAsk.delay", "messages.autoAsk.minGain",
        "window.compact", "window.rowHeight", "window.fontSize",
        "toast.enabled", "toast.minGain", "toast.duration", "toast.inCombat", "toast.sound",
        "global.history.maxGroups",
    }
    for _, key in ipairs(SITUATIONS) do
        for _, f in ipairs({ "track", "autoOpen", "quality" }) do out[#out + 1] = "situations." .. key .. "." .. f end
        out[#out + 1] = "trade.rules." .. key
    end
    for _, col in ipairs(COLUMNS) do out[#out + 1] = "window.columns." .. col end
    return out
end

local function profileDefault(NS, path)
    local node = NS.C.PROFILE
    for seg in path:gmatch("[^.]+") do
        if type(node) == "table" then node = node[seg] else node = nil end
    end
    return node
end

test("rows: every spec §12.1 setting has a row", function()
    local NS = T.newAddon()
    for _, path in ipairs(specPaths()) do
        assertTrue(NS.SchemaRuntime.FindRow(path) ~= nil, path)
    end
end)

test("rows: every hand-written row names its page, tab, label and a type the schema knows", function()
    local NS = T.newAddon()
    local types = { bool = true, number = true, string = true, map = true }
    for _, row in ipairs(NS.addon.Settings.Rows) do
        assertTrue(type(row.page) == "string" and type(row.group) == "string", row.path .. " page and tab")
        assertTrue(type(row.label) == "string" and type(row.tooltip) == "string", row.path .. " label and tooltip")
        assertTrue(types[row.type] == true, row.path .. " type")
        assertTrue(type(row.validate) == "function", row.path .. " is checked before it is stored")
    end
end)

test("rows: every default is defaults/Profile.lua's, and passes the row's own check", function()
    local NS = T.newAddon()
    for _, row in ipairs(NS.addon.Settings.Rows) do
        local want = row.path == "global.history.maxGroups" and NS.C.GLOBAL_DEFAULTS.history.maxGroups
            or profileDefault(NS, row.path)
        -- red under: a row whose `default` is a literal of its own that drifted from defaults/
        assertTrue(row.default == want, row.path .. " default is the defaults table's")
        assertTrue(row.validate(row.default), row.path .. " default passes its check")
    end
end)

test("rows: NS.Setting answers the default before the database, and the stored value after", function()
    local NS = T.newAddon()
    assertEqual(NS.Setting("feed.quality.fixed"), 3)
    assertEqual(NS.Setting("situations.raidLFR.autoOpen"), false)
    NS.addon:OnInitialize()
    assertTrue(NS.SchemaRuntime.Set("feed.quality.fixed", 4))
    assertEqual(NS.addon.db.profile.feed.quality.fixed, 4)
    assertEqual(NS.Setting("feed.quality.fixed"), 4)
end)

test("rows: a value outside a row's list or range is refused and stores nothing", function()
    local NS = T.bootAddon()
    local S, p = NS.SchemaRuntime, NS.addon.db.profile
    assertFalse(S.Set("feed.quality.mode", "bogus"))
    assertEqual(p.feed.quality.mode, "fixed")
    assertFalse(S.Set("messages.announceChannel", "SAY"), "never say or yell")
    assertFalse(S.Set("messages.autoAsk.delay", 2), "the delay is 3 to 30 seconds")
    assertFalse(S.Set("messages.templates.ask", "  "), "an empty template is refused")
    assertFalse(S.Set("trade.rules.raid", "bogus"))
    assertFalse(S.Set("window.columns.slot", "no"))
    assertTrue(S.Set("trade.rules.raid", "group"))
    assertEqual(p.trade.rules.raid, "group")
end)

test("rows: the per-spec maps take keyed values whole, and refuse a malformed one", function()
    local NS = T.bootAddon()
    local S = NS.SchemaRuntime
    -- Evaluate's prefs key is "<classID>:<subClassID>".
    assertTrue(S.Set("comparison.undesired", { [62] = { ["4:1"] = true, ["2:7"] = true } }))
    assertFalse(S.Set("comparison.undesired", { [62] = { ["4-1"] = true } }), "a key not <classID>:<subClassID>")
    assertFalse(S.Set("comparison.undesired", { mage = { ["4:1"] = true } }), "a specID that is not a number")
    assertTrue(S.Set("comparison.weights", { [62] = { INTELLECT = 1, HASTE = 0.8 } }))
    assertFalse(S.Set("comparison.weights", { [62] = { INTELLECT = "high" } }))
    local cfg = NS.LootFeed.Config()
    assertTrue(cfg.undesired[62]["4:1"] == true, "the feed reads the stored map")
    assertEqual(NS.addon.Settings.FormatValue(S.FindRow("comparison.undesired"), cfg.undesired,
        function() return "lib" end), "{1}", "the CLI renders a map as its entry count")
end)

test("rows: the feed, the situations and the messaging edge read the rows", function()
    local NS = T.bootAddon()
    local S = NS.SchemaRuntime
    S.Set("trade.rules.dungeon", "group")
    S.Set("feed.minIlvlMode", "absolute")
    S.Set("situations.delve.track", true)
    S.Set("situations.raid.quality", "dynamicSlot")
    S.Set("messages.oneAsk", false)
    S.Set("messages.announceChannel", "RAID")
    S.Set("trade.warnAt", 120)
    local cfg = NS.LootFeed.Config()
    assertEqual(cfg.rules.dungeon, "group")
    assertEqual(cfg.rules.pvp, "legacy", "an untouched situation keeps its default rule")
    assertEqual(cfg.minIlvlMode, "absolute")
    assertTrue(NS.Situations.IsTracking("delve"))
    assertEqual(NS.Situations.QualityOverride("raid"), "dynamicSlot")
    assertTrue(NS.Situations.QualityOverride("dungeon") == nil, "`global` means the feed's own mode")
    local a = NS.Asks.Settings()
    assertFalse(a.oneAsk)
    assertEqual(a.announceChannel, "RAID")
    assertEqual(a.templates.ask, NS.C.PROFILE.messages.templates.ask)
    assertEqual(NS.TradeTimer.WarnAt(), 120)
end)

test("rows: the filter bar seeds a fresh tab from the rows", function()
    local NS = T.bootAddon()
    NS.SchemaRuntime.Set("feed.view", "all")
    NS.SchemaRuntime.Set("trade.likelyOnly", true)
    NS.SchemaRuntime.Set("feed.usableOnly", true)
    NS.SchemaRuntime.Set("feed.upgradeOnly", true)
    local d = NS.WindowFilterBar.Defaults()
    assertEqual(d.view, "all")
    assertEqual(d.likelyOnly, true)
    assertEqual(d.usableOnly, true)
    assertEqual(d.upgradeOnly, true)
    assertEqual(d.content, "instance")
end)

test("rows: the Quality control and the compact preset write through the seam (handoff from M3)", function()
    local NS = T.enableAddon()
    local p = NS.addon.db.profile
    -- red under: write the profile path directly (a refused value would then be stored)
    assertTrue(NS.SetQualityMode("dynamicCharacter"))
    assertEqual(p.feed.quality.mode, "dynamicCharacter")
    assertFalse(NS.SetQualityMode("bogus"))
    NS.ShowWindow()
    local repaints = 0
    local real = NS.Window.Refresh
    NS.Window.Refresh = function(...) repaints = repaints + 1; return real(...) end
    NS.ToggleCompact()
    assertEqual(p.window.compact, true)
    assertTrue(repaints >= 1, "the row's reaction repaints the open window")
    NS.ToggleCompact()
    assertEqual(p.window.compact, false)
    NS.SchemaRuntime.Set("window.columns.slot", false)
    NS.Window.Refresh = real
    assertTrue(repaints >= 3)
end)

test("rows: the history cap is account-wide, and a profile reset leaves it", function()
    local NS = T.enableAddon()
    local S, path = NS.SchemaRuntime, "global.history.maxGroups"
    assertEqual(S.Get(path), 20)
    assertTrue(S.Set(path, 35))
    assertEqual(NS.addon.db.global.history.maxGroups, 35)
    assertTrue(NS.addon.db.profile.global == nil, "nothing lands in the profile")
    assertFalse(S.Set(path, 0))
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(S.Get(path), 35, "Reset all is a profile reset")
    S.ApplyDefault(S.FindRow(path))
    assertEqual(NS.addon.db.global.history.maxGroups, 20)
end)

test("rows: `/dw set` reaches a hand-written row", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("set feed.quality.floor 3")
    assertEqual(NS.addon.db.profile.feed.quality.floor, 3)
    NS.addon:OnSlashCommand("set situations.solo.track true")
    assertEqual(NS.addon.db.profile.situations.solo.track, true)
end)

test("rows: degraded, the hand-written rows still read, write and refuse", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertTrue(D.SchemaRuntime.Set("feed.quality.mode", "dynamicSlot"))
    assertEqual(D.addon.db.profile.feed.quality.mode, "dynamicSlot")
    assertFalse(D.SchemaRuntime.Set("feed.quality.mode", "bogus"))
    assertTrue(D.SchemaRuntime.Set("global.history.maxGroups", 10))
    assertEqual(D.addon.db.global.history.maxGroups, 10)
end)
