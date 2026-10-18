-- tests/test_schema_rows.lua — every setting of design spec §12.1 has a row, a default in
-- defaults/Profile.lua and a check the write seam runs (architecture-§5, savedvariables-§2).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local NO_LIBKA0S = T.loadAddon.libFiles

local SITUATIONS = {
    "mythicPlus", "dungeon", "followerDungeon", "raidLFR", "raid", "delve", "scenario", "pvp",
    "openWorldGroup", "solo",
}
-- `myEq` and `theirEq` were retired by schema step 7 (feedback-6 spec §1: merged into Me and Them).
local COLUMNS = { "ilvl", "slot", "looter", "me", "them", "trade", "tradeWindow", "actions" }

-- Spec §12.1's keys as stored paths. `debug` is the session-only console row, `minimap.shown` the
-- global closure row; `window.point`, `size`, `minimized` and `toast.point` are named state.
local function specPaths()
    local out = {
        "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole", "global.minimap.shown",
        "autoOpen",
        "feed.view.interesting", "feed.view.likely", "feed.view.usable", "feed.view.upgrade",
        "feed.quality.mode", "feed.quality.fixed", "feed.quality.floor",
        "feed.quality.upgradeOverride", "feed.gearOnly", "feed.includeTokens", "feed.minIlvlMode",
        "feed.minIlvl", "feed.relativeIlvl", "feed.clearOnBossKill", "feed.sort",
        "feed.content",
        "comparison.scorer", "comparison.weights", "comparison.sidegradeBand", "comparison.compareOwned",
        "comparison.heirloomProtect", "comparison.undesired",
        "trade.warnAt",
        "messages.templates.ask", "messages.templates.offer", "messages.templates.announce",
        "messages.editFirst", "messages.oneAsk", "messages.announceChannel", "messages.autoAsk.enabled",
        "messages.autoAsk.delay", "messages.autoAsk.minGain",
        "window.mode", "window.compactInRuns", "window.rowHeight", "window.fontSize",
        "toast.enabled", "toast.minGain", "toast.duration", "toast.inCombat", "toast.sound",
        "global.history.retentionDays",
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
    local types = { bool = true, number = true, string = true, map = true, color = true }
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
        local want = row.path == "global.history.retentionDays" and NS.C.GLOBAL_DEFAULTS.history.retentionDays
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
    local FB = NS.WindowFilterBar
    assertEqual(FB.ViewLabel(FB.Defaults().view), "View: All", "the default View is All (FB2-1)")
    NS.SchemaRuntime.Set("feed.view.likely", true)
    NS.SchemaRuntime.Set("feed.view.usable", true)
    NS.SchemaRuntime.Set("feed.view.upgrade", true)
    local d = FB.Defaults()
    assertTrue(d.view.likely and d.view.usable and d.view.upgrade, "each View row seeds its value")
    assertTrue(d.view.interesting == nil, "an off row is not in the set")
    assertEqual(FB.ViewLabel(d.view), "View: 3 selected")
    assertFalse(NS.SchemaRuntime.Set("feed.view.likely", "yes"), "a View row takes a boolean")
    assertTrue(NS.Setting("feed.usableOnly") == nil and NS.Setting("trade.likelyOnly") == nil,
        "the checkbox rows are retired")
    assertEqual(d.content, "session", "This session by default (feedback-13 spec §0)")
end)

test("rows: the Quality control and the window's layout write through the seam (handoff from M3)", function()
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
    NS.ToggleWindowMode()
    assertEqual(p.window.mode, "compact")
    assertTrue(repaints >= 1, "the row's reaction repaints the open window")
    NS.ToggleWindowMode()
    assertEqual(p.window.mode, "full")
    assertFalse(NS.SchemaRuntime.Set("window.mode", "tiny"), "a layout the row does not list is refused")
    assertEqual(NS.Setting("window.compact"), nil, "the compact preset's row is retired")
    NS.SchemaRuntime.Set("window.columns.slot", false)
    NS.Window.Refresh = real
    assertTrue(repaints >= 3)
end)

test("rows: Keep history for is account-wide, and a profile reset leaves it", function()
    local NS = T.enableAddon()
    local S, path = NS.SchemaRuntime, "global.history.retentionDays"
    assertEqual(S.Get(path), 30)
    assertTrue(S.Set(path, 90))
    assertEqual(NS.addon.db.global.history.retentionDays, 90)
    assertTrue(NS.addon.db.profile.global == nil, "nothing lands in the profile")
    assertTrue(S.Set(path, 0), "Never delete")
    assertFalse(S.Set(path, 45), "only the listed windows")
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(S.Get(path), 0, "Reset all is a profile reset")
    S.ApplyDefault(S.FindRow(path))
    assertEqual(NS.addon.db.global.history.retentionDays, 30)
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
    assertTrue(D.SchemaRuntime.Set("global.history.retentionDays", 14))
    assertEqual(D.addon.db.global.history.retentionDays, 14)
end)

-- ── Window › Upgrade glow (feedback-21) ─────────────────────────────────────────────────────

-- The knob table of the feedback-21 plan, shared with KickCD's glow slots: key, min, max, default.
local GLOW_KNOBS = {
    { "pixelLines", 1, 20, 8 }, { "pixelFrequency", 0.05, 2, 0.25 }, { "pixelLength", 0, 20, 0 },
    { "pixelThickness", 1, 6, 1 }, { "autocastParticles", 1, 12, 4 },
    { "autocastFrequency", 0.05, 2, 0.125 }, { "autocastScale", 0.5, 3, 1 },
    { "buttonFrequency", 0.05, 2, 0.25 }, { "procDuration", 0.25, 3, 1 },
    { "xOffset", -10, 10, 0 }, { "yOffset", -10, 10, 0 },
}

test("glow: both glows have every knob's row on Window › Upgrade glow, with the plan's defaults", function()
    local NS = T.newAddon()
    local S, TONE = NS.SchemaRuntime, NS.Constants.TONE
    for _, key in ipairs({ "main", "offSpec" }) do
        local base = "glow." .. key .. "."
        for _, k in ipairs(GLOW_KNOBS) do
            local row = S.FindRow(base .. k[1])
            assertTrue(row ~= nil, base .. k[1])
            assertEqual(row.page, "window"); assertEqual(row.group, "Upgrade glow")
            assertEqual(row.min, k[2], base .. k[1] .. " min"); assertEqual(row.max, k[3], base .. k[1] .. " max")
            assertEqual(row.default, k[4], base .. k[1] .. " default")
        end
        assertEqual(S.FindRow(base .. "pixelBorder").default, true)
        assertEqual(S.FindRow(base .. "procStartAnim").default, true)
        assertEqual(S.FindRow(base .. "enabled").default, true, key .. " is on by default")
        assertEqual(S.FindRow(base .. "color").type, "color")
        local cc = S.FindRow(base .. "useClassColor")
        assertTrue(cc ~= nil and cc.type == "bool", base .. "useClassColor")
        assertEqual(cc.default, false, key .. "'s Use class color is off by default (options-ui-§17)")
        assertEqual(cc.label, "Use class color")
        assertEqual(cc.classColorSource, "player", "the player's class, whoever looted the drop")
        assertEqual(S.FindRow(base .. "color").classColorSource, "player")
    end
    assertEqual(NS.Setting("glow.main.type"), "proc")
    assertEqual(NS.Setting("glow.offSpec.type"), "pixel")
    local main, off = NS.Setting("glow.main.color"), NS.Setting("glow.offSpec.color")
    assertTrue(main.r == TONE.good.r and main.g == TONE.good.g and main.b == TONE.good.b and main.a == 1,
        "main is the upgrade green, opaque")
    assertTrue(off.r == TONE.offspec.r and off.g == TONE.offspec.g and off.b == TONE.offspec.b and off.a == 1,
        "off-spec is the off-spec cyan, opaque")
end)

test("glow: the main and off-spec rows alternate, so each knob reads across one line", function()
    local NS = T.newAddon()
    local rows = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("window")) do
        if row.group == "Upgrade glow" then rows[#rows + 1] = row end
    end
    assertEqual(#rows % 2, 0)
    local pairsSeen = 0
    for i = 1, #rows, 2 do
        local a, b = rows[i].path, rows[i + 1].path
        local g = a:match("^glow%.(%a+)%.color$")
        if g then
            -- options-ui-§17: a color's Use class color sits IMMEDIATELY to its right, on its line
            assertEqual(b, "glow." .. g .. ".useClassColor", a)
            assertTrue(rows[i].startsLine == true, a .. " starts its line")
            pairsSeen = pairsSeen + 1
        else
            assertEqual(a:gsub("^glow%.main%.", ""), b:gsub("^glow%.offSpec%.", ""), a)
            assertTrue(a:match("^glow%.main%.") ~= nil and b:match("^glow%.offSpec%.") ~= nil, a)
        end
    end
    assertEqual(pairsSeen, 2, "a color pair per glow, main first")
    assertTrue(rows[5].path == "glow.main.color" and rows[7].path == "glow.offSpec.color")
end)

test("glow: an out-of-range knob, an unknown style and a malformed color are refused", function()
    local NS = T.bootAddon()
    local S, p = NS.SchemaRuntime, NS.addon.db.profile
    assertFalse(S.Set("glow.main.pixelLines", 0), "1 to 20 lines")
    assertFalse(S.Set("glow.main.pixelLines", 21))
    assertFalse(S.Set("glow.offSpec.xOffset", 11), "-10 to 10")
    assertFalse(S.Set("glow.offSpec.procDuration", 0.1), "0.25 to 3 seconds")
    assertFalse(S.Set("glow.main.type", "sparkle"), "only LibCustomGlow's four styles")
    assertFalse(S.Set("glow.main.color", { r = 2, g = 0, b = 0 }), "a channel past 1")
    assertFalse(S.Set("glow.main.color", "green"), "a color is a table")
    assertFalse(S.Set("glow.main.enabled", "yes"))
    assertEqual(p.glow.main.pixelLines, 8, "nothing stored")
    assertTrue(S.Set("glow.main.type", "autocast"))
    assertTrue(S.Set("glow.offSpec.color", { r = 1, g = 0.5, b = 0, a = 0.5 }))
    assertEqual(p.glow.offSpec.color.g, 0.5)
    assertTrue(S.Set("glow.main.pixelLength", 0), "0 is automatic")
end)

test("glow: a knob is dimmed while its glow is in another style, the style while the glow is off, the color pair never", function()
    local NS = T.bootAddon()
    local S = NS.SchemaRuntime
    local function dim(path) return S.FindRow(path).disabledIf() == true end
    -- main is proc, off-spec pixel by default
    assertFalse(dim("glow.main.procDuration")); assertTrue(dim("glow.main.pixelLines"))
    assertFalse(dim("glow.offSpec.pixelLines")); assertTrue(dim("glow.offSpec.procDuration"))
    assertFalse(dim("glow.main.xOffset"), "the offsets serve proc")
    assertTrue(dim("glow.offSpec.buttonFrequency"))
    S.Set("glow.main.type", "button")
    assertTrue(dim("glow.main.xOffset"), "but not button")
    assertFalse(dim("glow.main.buttonFrequency"))
    assertFalse(dim("glow.main.type"))
    S.Set("glow.main.enabled", false)
    assertTrue(dim("glow.main.type") and dim("glow.main.buttonFrequency"), "off dims the style and every knob")
    -- anti-pattern #74: the swatch is read under either mode (its alpha), so neither half is dimmed
    for _, key in ipairs({ "main", "offSpec" }) do
        assertNil(S.FindRow("glow." .. key .. ".color").disabledIf, key .. " color")
        assertNil(S.FindRow("glow." .. key .. ".useClassColor").disabledIf, key .. " Use class color")
    end
    assertTrue(S.FindRow("glow.main.enabled").disabledIf == nil, "the switch itself is never dimmed")
    assertFalse(dim("glow.offSpec.pixelLines"), "the other glow is its own")
end)

test("glow: a glow row's write asks NS.Glow to repaint, and `/dw` reads a color and Automatic", function()
    local NS = T.enableAddon()
    local calls = 0
    NS.Glow = NS.Glow or {}
    local real = NS.Glow.Refresh
    NS.Glow.Refresh = function() calls = calls + 1 end
    assertTrue(NS.SchemaRuntime.Set("glow.main.pixelThickness", 3))
    assertTrue(NS.SchemaRuntime.Set("glow.offSpec.color", { r = 0, g = 1, b = 0, a = 1 }))
    assertTrue(NS.SchemaRuntime.Set("glow.main.useClassColor", true))
    assertFalse(NS.SchemaRuntime.Set("glow.main.useClassColor", "yes"), "a boolean")
    assertEqual(calls, 3)
    NS.Glow.Refresh = real
    local row = NS.SchemaRuntime.FindRow("glow.main.pixelLength")
    assertEqual(NS.addon.Settings.FormatValue(row, 0, function(_, v) return tostring(v) end), "0 (Automatic)")
    NS.addon:OnSlashCommand("set glow.offSpec.color 1 0 0 1")
    assertEqual(NS.addon.db.profile.glow.offSpec.color.r, 1)
end)

-- ── Window › Toast: Scale (feedback-21 G10) ─────────────────────────────────────────────────

test("toast scale: a 50-200 % slider by 5 on Window › Toast, after Play a sound, live only with the toast on", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    local row = S.FindRow("toast.scale")
    assertTrue(row ~= nil, "toast.scale has a row")
    assertEqual(row.page, "window"); assertEqual(row.group, "Toast"); assertEqual(row.label, "Scale")
    assertEqual(row.type, "number")
    assertEqual(row.min, 0.5); assertEqual(row.max, 2); assertEqual(row.step, 0.05)
    assertEqual(row.default, 1, "today's size"); assertEqual(NS.C.PROFILE.toast.scale, 1)
    assertTrue(row.isPercent == true, "drawn as a percentage, 50 % to 200 %")
    assertTrue(type(row.onChange) == "function", "applied live (NS.Toast.ApplyScale)")
    assertTrue(row.disabledIf(), "dimmed while the toast is off")
    assertTrue(S.Set("toast.enabled", true))
    assertFalse(row.disabledIf())
    assertFalse(S.Set("toast.scale", 0.25)); assertFalse(S.Set("toast.scale", 2.5))
    assertTrue(S.Set("toast.scale", 1.5)); assertEqual(NS.addon.db.profile.toast.scale, 1.5)
    local order = {}
    for _, r in ipairs(NS.addon.Settings.RowsForPage("window")) do
        if r.group == "Toast" then order[#order + 1] = r.path end
    end
    assertEqual(order[#order], "toast.scale", "the tab's last row")
    assertEqual(order[#order - 1], "toast.sound")
end)
