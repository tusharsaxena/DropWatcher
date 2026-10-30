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
    S.Set("situations.openWorldGroup.track", true)   -- off its default (untracked)
    S.Set("situations.raid.quality", "dynamicSlot")
    S.Set("messages.oneAsk", false)
    S.Set("messages.announceChannel", "RAID")
    S.Set("trade.warnAt", 120)
    local cfg = NS.LootFeed.Config()
    assertEqual(cfg.rules.dungeon, "group")
    assertEqual(cfg.rules.pvp, "legacy", "an untouched situation keeps its default rule")
    assertEqual(cfg.minIlvlMode, "absolute")
    assertTrue(NS.Situations.IsTracking("openWorldGroup"))
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
    NS.addon:OnSlashCommand("set situations.solo.track false")   -- off its default (tracked, DW-06)
    assertEqual(NS.addon.db.profile.situations.solo.track, false)
end)

test("rows: degraded, the hand-written rows still read, write and refuse", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertTrue(D.SchemaRuntime.Set("feed.quality.mode", "dynamicSlot"))
    assertEqual(D.addon.db.profile.feed.quality.mode, "dynamicSlot")
    assertFalse(D.SchemaRuntime.Set("feed.quality.mode", "bogus"))
    assertTrue(D.SchemaRuntime.Set("global.history.retentionDays", 14))
    assertEqual(D.addon.db.global.history.retentionDays, 14)
end)

-- ── Alerts › Upgrade glow (feedback-21; Window's until feedback-24) ─────────────────────────

-- The knob table of the feedback-21 plan, shared with KickCD's glow slots: key, min, max, default.
-- pixelFrequency's 0.1 is DropWatcher's own default (feedback-21 H6); KickCD keeps the library's 0.25.
local GLOW_KNOBS = {
    { "pixelLines", 1, 20, 8 }, { "pixelFrequency", 0.05, 2, 0.1 }, { "pixelLength", 0, 20, 0 },
    { "pixelThickness", 1, 6, 1 }, { "autocastParticles", 1, 12, 4 },
    { "autocastFrequency", 0.05, 2, 0.125 }, { "autocastScale", 0.5, 3, 1 },
    { "buttonFrequency", 0.05, 2, 0.25 }, { "procDuration", 0.25, 3, 1 },
    { "xOffset", -10, 10, 0 }, { "yOffset", -10, 10, 0 },
}

test("glow: both glows have every knob's row on Alerts › Upgrade glow, with the plan's defaults", function()
    local NS = T.newAddon()
    local S, TONE = NS.SchemaRuntime, NS.Constants.TONE
    for _, key in ipairs({ "main", "offSpec" }) do
        local base = "glow." .. key .. "."
        for _, k in ipairs(GLOW_KNOBS) do
            local row = S.FindRow(base .. k[1])
            assertTrue(row ~= nil, base .. k[1])
            assertEqual(row.page, "alerts"); assertEqual(row.group, "Upgrade glow")
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
        assertEqual(cc.label, key == "main" and "Use class color (main spec)" or "Use class color (off-spec)")
        assertEqual(cc.classColorSource, "player", "the player's class, whoever looted the drop")
        assertEqual(S.FindRow(base .. "color").classColorSource, "player")
    end
    -- DW-03 (owner ruling D-18, image-39; was feedback-21 H6's two pixel borders and #FFF468): both
    -- Proc (flipbook), the main spec #19FF19 and the off-spec #3FC7EB, opaque.
    assertEqual(NS.Setting("glow.main.type"), "proc")
    assertEqual(NS.Setting("glow.offSpec.type"), "proc")
    local main, off = NS.Setting("glow.main.color"), NS.Setting("glow.offSpec.color")
    assertTrue(main.r == TONE.glowMain.r and main.g == TONE.glowMain.g and main.b == TONE.glowMain.b and main.a == 1,
        "main is its own token, opaque")
    assertTrue(off.r == TONE.glowOffSpec.r and off.g == TONE.glowOffSpec.g and off.b == TONE.glowOffSpec.b
        and off.a == 1, "off-spec is its own token, opaque")
    local function byte(v) return math.floor(v * 255 + 0.5) end
    local function hex(c) return string.format("%02X%02X%02X", byte(c.r), byte(c.g), byte(c.b)) end
    assertEqual(hex(TONE.glowMain), "19FF19"); assertEqual(hex(TONE.glowOffSpec), "3FC7EB")
    assertTrue(TONE.glowMain ~= TONE.good and TONE.glowOffSpec ~= TONE.offspec, "no longer the verdicts' tones")
end)

test("glow: the main and off-spec rows alternate, so each line reads main left, off-spec right", function()
    local NS = T.newAddon()
    local rows = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("alerts")) do
        if row.group == "Upgrade glow" then rows[#rows + 1] = row end
    end
    assertEqual(#rows % 2, 0)
    -- Every row, the colors and their companions too (feedback-21 H6): main left, off-spec right.
    for i = 1, #rows, 2 do
        local a, b = rows[i].path, rows[i + 1].path
        assertEqual(a:gsub("^glow%.main%.", ""), b:gsub("^glow%.offSpec%.", ""), a)
        assertTrue(a:match("^glow%.main%.") ~= nil and b:match("^glow%.offSpec%.") ~= nil, a)
    end
    -- The documented options-ui-§17 deviation (docs/ARCHITECTURE.md -> Documented deviations, the
    -- owner's choice): the swatches share a line and each Use class color sits BELOW its swatch,
    -- not immediately to its right. This test pins the deviation for these two pairs only.
    assertEqual(rows[5].path, "glow.main.color"); assertEqual(rows[6].path, "glow.offSpec.color")
    assertEqual(rows[7].path, "glow.main.useClassColor"); assertEqual(rows[8].path, "glow.offSpec.useClassColor")
    assertTrue(rows[5].startsLine == true and rows[7].startsLine == true, "each left-column row starts its line")
    assertNil(rows[6].startsLine); assertNil(rows[8].startsLine)
end)

-- feedback-24: Offset (three of the four styles) right after Effect, then each style's subsection
-- in the Style dropdown's own order, the default (Pixel border) first in both.
test("glow: the style subsections read in the Style dropdown's order, Offset first", function()
    local NS = T.newAddon()
    local heads, seen = {}, {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("alerts")) do
        if row.group == "Upgrade glow" and row.subgroup and not seen[row.subgroup] then
            seen[row.subgroup] = true
            heads[#heads + 1] = row.subgroup
        end
    end
    local styles = {}
    for i, v in ipairs(NS.SchemaRuntime.FindRow("glow.main.type").values) do styles[i] = v.text end
    assertEqual(table.concat(styles, "|"), "Pixel border|Auto cast sparkles|Button (rotating rays)|Proc (flipbook)")
    assertEqual(table.concat(heads, "|"), "Effect|Offset|" .. table.concat(styles, "|"))
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
    -- both proc by default (DW-03, D-18); the off-spec set to pixel and main to proc here
    assertTrue(S.Set("glow.offSpec.type", "pixel"))
    assertTrue(S.Set("glow.main.type", "proc"))
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

-- ── Alerts › Toast: Scale (feedback-21 G10; Window's until feedback-24) ─────────────────────

test("toast scale: a 50-200 % slider by 5 on Alerts › Toast, after Play a sound, live only with the toast on", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    local row = S.FindRow("toast.scale")
    assertTrue(row ~= nil, "toast.scale has a row")
    assertEqual(row.page, "alerts"); assertEqual(row.group, "Toast"); assertEqual(row.label, "Scale")
    assertEqual(row.type, "number")
    assertEqual(row.min, 0.5); assertEqual(row.max, 2); assertEqual(row.step, 0.05)
    assertEqual(row.default, 1, "today's size"); assertEqual(NS.C.PROFILE.toast.scale, 1)
    assertTrue(row.isPercent == true, "drawn as a percentage, 50 % to 200 %")
    assertTrue(type(row.onChange) == "function", "applied live (NS.Toast.ApplyScale)")
    assertFalse(row.disabledIf(), "live: the toast is on for a new profile")
    assertTrue(S.Set("toast.enabled", false))
    assertTrue(row.disabledIf(), "dimmed while the toast is off")
    assertTrue(S.Set("toast.enabled", true))
    assertFalse(row.disabledIf())
    assertFalse(S.Set("toast.scale", 0.25)); assertFalse(S.Set("toast.scale", 2.5))
    assertTrue(S.Set("toast.scale", 1.5)); assertEqual(NS.addon.db.profile.toast.scale, 1.5)
    local order = {}
    for _, r in ipairs(NS.addon.Settings.RowsForPage("alerts")) do
        if r.group == "Toast" then order[#order + 1] = r.path end
    end
    assertEqual(order[#order], "toast.scale", "the tab's last row")
    assertEqual(order[#order - 1], "toast.sound")
end)

-- ── Window › Icons (feedback-21 G11) ────────────────────────────────────────────────────────

-- The tab's rows in order: the Zoom row, then the composed Border block (options-ui-§16: Show
-- border leads, the mandated four in order, the skin companion after them (DW-03, the composer's
-- `fromSkin = "icon"`), then the quality extra).
local ICON_ROWS = {
    "icons.zoom", "icons.borderShow", "icons.borderStyle", "icons.borderSize", "icons.borderColor",
    "icons.useClassColorBorder", "icons.borderStyleFromSkin", "icons.borderQuality",
}

test("icons: Window › Icons is the Zoom row then the composed Border block, with the owner's defaults", function()
    local NS = T.newAddon()
    local S, I = NS.SchemaRuntime, NS.C.PROFILE.icons
    local order = {}
    for _, r in ipairs(NS.addon.Settings.RowsForPage("window")) do
        if r.group == "Icons" then order[#order + 1] = r.path end
    end
    assertEqual(table.concat(order, ","), table.concat(ICON_ROWS, ","))
    local zoom = S.FindRow("icons.zoom")
    assertEqual(zoom.subgroup, "Zoom"); assertEqual(zoom.label, "Icon zoom")
    assertEqual(zoom.min, 0); assertEqual(zoom.max, 0.25); assertEqual(zoom.step, 0.01)
    assertEqual(zoom.default, 0.1, "the baked-in edge trimmed (feedback-21 H6)")
    -- The composer's labels, word for word (options-ui-§16), under the Border subsection.
    local LABELS = { borderShow = "Show border", borderStyle = "Border style", borderSize = "Border thickness (px)",
        borderColor = "Border color", useClassColorBorder = "Use class color", borderQuality = "Color by item quality",
        borderStyleFromSkin = "Use the skin's border" }
    for leaf, label in pairs(LABELS) do
        local row = S.FindRow("icons." .. leaf)
        assertEqual(row.label, label, leaf); assertEqual(row.subgroup, "Border", leaf)
        assertEqual(row.page, "window", leaf)
        assertTrue(type(row.onChange) == "function", leaf .. " restyles the icons")
        assertTrue(type(row.validate) == "function", leaf .. " has a check")
        if leaf ~= "borderColor" then assertEqual(row.default, I[leaf], leaf .. " default from defaults/Profile.lua") end
    end
    assertTrue(type(zoom.onChange) == "function")
    assertEqual(S.FindRow("icons.borderStyle").dialogControl, "LSM30_Border")
    -- feedback-21 H6: a Solid black border, 2 pixels, neither class nor quality color.
    assertEqual(I.borderShow, true, "a border by default"); assertEqual(I.borderQuality, false)
    assertEqual(I.borderStyle, "Solid"); assertEqual(I.borderSize, 2)
    local bc = I.borderColor
    assertTrue(bc.r == 0 and bc.g == 0 and bc.b == 0 and bc.a == 1, "black, opaque")
    assertEqual(I.useClassColorBorder, false, "options-ui-§17: the companion is off by default")
    -- The color pair: player-scoped, the swatch starting its line, neither half ever dimmed.
    local swatch, cc = S.FindRow("icons.borderColor"), S.FindRow("icons.useClassColorBorder")
    assertEqual(swatch.classColorSource, "player"); assertEqual(cc.classColorSource, "player")
    assertTrue(swatch.startsLine == true, "the pair cannot split across two lines")
    assertNil(swatch.disabledIf, "anti-pattern #74"); assertNil(cc.disabledIf)
end)

test("icons: the border rows refuse what they cannot draw, and dim with Show border off", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    assertFalse(S.Set("icons.zoom", 0.3)); assertFalse(S.Set("icons.zoom", -0.01))
    assertTrue(S.Set("icons.zoom", 0.08)); assertEqual(NS.addon.db.profile.icons.zoom, 0.08)
    assertFalse(S.Set("icons.borderSize", 0)); assertFalse(S.Set("icons.borderSize", 17))
    assertFalse(S.Set("icons.borderShow", "yes")); assertFalse(S.Set("icons.borderStyle", ""))
    assertFalse(S.Set("icons.borderColor", { r = 2, g = 0, b = 0 }))
    -- The style and thickness rows are the skin's while the companion is on (DW-03): off here, so
    -- the dimming below is Show border's alone (tests/test_skin_hud.lua holds the companion's).
    assertTrue(S.Set("icons.borderStyleFromSkin", false))
    assertFalse(S.FindRow("icons.borderStyle").disabledIf(), "on by default (feedback-21 H6)")
    assertTrue(S.Set("icons.borderShow", false))
    for _, leaf in ipairs({ "borderStyle", "borderSize", "borderQuality" }) do
        assertTrue(S.FindRow("icons." .. leaf).disabledIf(), leaf .. " dimmed while Show border is off")
    end
    assertTrue(S.Set("icons.borderShow", true))
    assertFalse(S.FindRow("icons.borderStyle").disabledIf())
    assertTrue(S.Set("icons.borderSize", 4)); assertTrue(S.Set("icons.borderQuality", true))
    NS.addon:OnSlashCommand("set icons.borderColor 1 0 0 1")
    assertEqual(NS.addon.db.profile.icons.borderColor.r, 1)
end)

test("icons: without LibKa0s the tab keeps its Zoom row and the border reads its defaults", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertTrue(D.SchemaRuntime.Set("icons.zoom", 0.1))
    assertNil(D.SchemaRuntime.FindRow("icons.borderShow"), "the composer is hollow")
    assertEqual(D.Setting("icons.borderShow"), true, "the profile default: a border (feedback-21 H6)")
    assertEqual(D.Setting("icons.borderStyle"), "Solid")
end)

-- ── the settings-layout guard (DW-LY, item 020) ─────────────────────────────────────────────
--
-- Item 020 moves, regroups and relabels rows only: every stored path, its type and its default
-- stay exactly as they were. Pinned from the schema at b9d6651 (before the item's first edit), so
-- a key or default that drifts in a layout change fails here, in both directions.

local function serialize(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local PINNED_ROWS = {
    { "alpha", "number", "1" },
    { "autoOpen", "bool", "true" },
    { "comparison.compareOwned", "bool", "false" },
    { "comparison.heirloomProtect", "bool", "true" },
    { "comparison.scorer", "string", "\"auto\"" },
    { "comparison.sidegradeBand", "number", "0" },
    { "comparison.undesired", "map", "{}" },
    { "comparison.weights", "map", "{}" },
    { "enabled", "bool", "true" },
    { "feed.clearOnBossKill", "bool", "false" },
    { "feed.content", "string", "\"session\"" },
    { "feed.gearOnly", "bool", "true" },
    { "feed.includeTokens", "bool", "true" },
    { "feed.minIlvl", "number", "0" },
    { "feed.minIlvlMode", "string", "\"off\"" },
    { "feed.quality.fixed", "number", "3" },
    { "feed.quality.floor", "number", "2" },
    { "feed.quality.mode", "string", "\"fixed\"" },
    { "feed.quality.upgradeOverride", "bool", "true" },
    { "feed.relativeIlvl", "number", "10" },
    { "feed.sort", "string", "\"newest\"" },
    { "feed.view.interesting", "bool", "false" },
    { "feed.view.likely", "bool", "false" },
    { "feed.view.upgrade", "bool", "false" },
    { "feed.view.usable", "bool", "false" },
    { "global.history.retentionDays", "number", "30" },
    { "global.minimap.shown", "bool", "true" },
    { "glow.main.autocastFrequency", "number", "0.125" },
    { "glow.main.autocastParticles", "number", "4" },
    { "glow.main.autocastScale", "number", "1" },
    { "glow.main.buttonFrequency", "number", "0.25" },
    { "glow.main.color", "color", "{[\"a\"]=1,[\"b\"]=0.098039215686275,[\"g\"]=1,[\"r\"]=0.098039215686275}" },
    { "glow.main.enabled", "bool", "true" },
    { "glow.main.pixelBorder", "bool", "true" },
    { "glow.main.pixelFrequency", "number", "0.1" },
    { "glow.main.pixelLength", "number", "0" },
    { "glow.main.pixelLines", "number", "8" },
    { "glow.main.pixelThickness", "number", "1" },
    { "glow.main.procDuration", "number", "1" },
    { "glow.main.procStartAnim", "bool", "true" },
    -- DW-03 (owner ruling D-18): both glows default to Proc, the main spec to #19FF19.
    { "glow.main.type", "string", "\"proc\"" },
    { "glow.main.useClassColor", "bool", "false" },
    { "glow.main.xOffset", "number", "0" },
    { "glow.main.yOffset", "number", "0" },
    { "glow.offSpec.autocastFrequency", "number", "0.125" },
    { "glow.offSpec.autocastParticles", "number", "4" },
    { "glow.offSpec.autocastScale", "number", "1" },
    { "glow.offSpec.buttonFrequency", "number", "0.25" },
    { "glow.offSpec.color", "color", "{[\"a\"]=1,[\"b\"]=0.92156862745098,[\"g\"]=0.78039215686275,[\"r\"]=0.24705882352941}" },
    { "glow.offSpec.enabled", "bool", "true" },
    { "glow.offSpec.pixelBorder", "bool", "true" },
    { "glow.offSpec.pixelFrequency", "number", "0.1" },
    { "glow.offSpec.pixelLength", "number", "0" },
    { "glow.offSpec.pixelLines", "number", "8" },
    { "glow.offSpec.pixelThickness", "number", "1" },
    { "glow.offSpec.procDuration", "number", "1" },
    { "glow.offSpec.procStartAnim", "bool", "true" },
    { "glow.offSpec.type", "string", "\"proc\"" },
    { "glow.offSpec.useClassColor", "bool", "false" },
    { "glow.offSpec.xOffset", "number", "0" },
    { "glow.offSpec.yOffset", "number", "0" },
    { "icons.borderColor", "color", "{[\"a\"]=1,[\"b\"]=0,[\"g\"]=0,[\"r\"]=0}" },
    { "icons.borderQuality", "bool", "false" },
    { "icons.borderShow", "bool", "true" },
    { "icons.borderSize", "number", "2" },
    { "icons.borderStyle", "string", "\"Solid\"" },
    -- DW-03 adds the border's skin companion (the composer's `fromSkin = "icon"`): a new row, not a
    -- layout move, defaulting TRUE (the rollout's X3).
    { "icons.borderStyleFromSkin", "bool", "true" },
    { "icons.useClassColorBorder", "bool", "false" },
    { "icons.zoom", "number", "0.1" },
    { "locked", "bool", "false" },
    { "messages.announceChannel", "string", "\"auto\"" },
    { "messages.autoAsk.delay", "number", "10" },
    { "messages.autoAsk.enabled", "bool", "false" },
    { "messages.autoAsk.minGain", "number", "5" },
    { "messages.editFirst", "bool", "false" },
    { "messages.oneAsk", "bool", "true" },
    { "messages.templates.announce", "string", "\"{item} is up for grabs, whisper me.\"" },
    { "messages.templates.ask", "string", "\"Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!\"" },
    { "messages.templates.askOffSpec", "string", "\"Hi {player}, if you don't need {item}, could I have it for my off-spec? It'd be +{mygain} for me. No worries if not!\"" },
    { "messages.templates.offer", "string", "\"Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?\"" },
    { "messages.templates.transmog", "string", "\"Hi {player}, if you don't need {item}, could I have it for transmog? I haven't collected its look. No worries if not!\"" },
    { "messages.transmogAsk", "bool", "false" },
    { "scale", "number", "1" },
    { "sim.stepDelay", "number", "1" },
    -- The skinning rollout (DW-01) adds the seven skin.* keys, General's Skin tab: new rows, not a
    -- layout move, so they join the pin with their defaults (defaults/Profile.lua's skin table).
    { "skin.font", "string", "\"\"" },
    { "skin.ignoreFonts", "bool", "false" },
    { "skin.ignorePanel", "bool", "true" },
    -- LibKa0s v1.82.0 (DW-01 of the skin fonts run, ruling D-06): the Font outline, a new row.
    { "skin.outline", "string", "\"all\"" },
    { "skin.pickerSeen", "bool", "false" },
    { "skin.skin", "string", "\"ka0s\"" },
    { "skin.source", "string", "\"ka0s\"" },
    { "skin.texture", "string", "\"\"" },
    { "situations.delve.autoOpen", "bool", "true" },
    { "situations.delve.quality", "string", "\"global\"" },
    { "situations.delve.track", "bool", "true" },
    { "situations.dungeon.autoOpen", "bool", "true" },
    { "situations.dungeon.quality", "string", "\"global\"" },
    { "situations.dungeon.track", "bool", "true" },
    { "situations.followerDungeon.autoOpen", "bool", "true" },
    { "situations.followerDungeon.quality", "string", "\"global\"" },
    { "situations.followerDungeon.track", "bool", "true" },
    { "situations.mythicPlus.autoOpen", "bool", "true" },
    { "situations.mythicPlus.quality", "string", "\"global\"" },
    { "situations.mythicPlus.track", "bool", "true" },
    { "situations.openWorldGroup.autoOpen", "bool", "false" },
    { "situations.openWorldGroup.quality", "string", "\"global\"" },
    { "situations.openWorldGroup.track", "bool", "false" },
    { "situations.pvp.autoOpen", "bool", "false" },
    { "situations.pvp.quality", "string", "\"global\"" },
    { "situations.pvp.track", "bool", "false" },
    { "situations.raid.autoOpen", "bool", "true" },
    { "situations.raid.quality", "string", "\"global\"" },
    { "situations.raid.track", "bool", "true" },
    { "situations.raidLFR.autoOpen", "bool", "false" },
    { "situations.raidLFR.quality", "string", "\"global\"" },
    { "situations.raidLFR.track", "bool", "true" },
    { "situations.scenario.autoOpen", "bool", "true" },
    { "situations.scenario.quality", "string", "\"global\"" },
    { "situations.scenario.track", "bool", "true" },
    { "situations.solo.autoOpen", "bool", "true" },
    { "situations.solo.quality", "string", "\"global\"" },
    { "situations.solo.track", "bool", "true" },
    { "state.debugConsole", "bool", "false" },
    { "state.testMode", "bool", "nil" },
    { "toast.duration", "number", "8" },
    { "toast.enabled", "bool", "true" },   -- on for a new profile since 2026-10-25, no migration
    { "toast.inCombat", "bool", "false" },
    { "toast.minGain", "number", "10" },
    { "toast.scale", "number", "1" },
    { "toast.sound", "bool", "false" },
    { "trade.rules.delve", "string", "\"personal\"" },
    { "trade.rules.dungeon", "string", "\"personal\"" },
    { "trade.rules.followerDungeon", "string", "\"personal\"" },
    { "trade.rules.mythicPlus", "string", "\"personal\"" },
    { "trade.rules.openWorldGroup", "string", "\"personal\"" },
    { "trade.rules.pvp", "string", "\"legacy\"" },
    { "trade.rules.raid", "string", "\"personal\"" },
    { "trade.rules.raidLFR", "string", "\"personal\"" },
    { "trade.rules.scenario", "string", "\"personal\"" },
    { "trade.rules.solo", "string", "\"personal\"" },
    { "trade.warnAt", "number", "600" },
    { "visibility", "string", "\"always\"" },
    { "window.columns.actions", "bool", "true" },
    { "window.columns.armorType", "bool", "true" },
    { "window.columns.ilvl", "bool", "true" },
    { "window.columns.looter", "bool", "true" },
    { "window.columns.me", "bool", "true" },
    { "window.columns.slot", "bool", "true" },
    { "window.columns.them", "bool", "true" },
    { "window.columns.trade", "bool", "true" },
    { "window.columns.tradeWindow", "bool", "true" },
    { "window.compactInRuns", "bool", "true" },
    { "window.fontSize", "number", "0" },
    { "window.mode", "string", "\"full\"" },
    { "window.rowHeight", "number", "18" },
    -- DW-01 (the lead's ruling on D-07): the tables' font gained the rest of the font setting, new
    -- stored paths beside `window.fontSize`, whose path, type and default are unchanged.
    { "window.tableFont", "string", "\"Friz Quadrata TT\"" },
    { "window.tableFontClassColor", "bool", "false" },
    { "window.tableFontColor", "color", "{[\"a\"]=1,[\"b\"]=0.92,[\"g\"]=0.92,[\"r\"]=0.92}" },
    { "window.tableFontFlags", "string", "\"@skin\"" },
    { "window.tableFontFromSkin", "bool", "true" },
    { "window.tableFontShadow", "bool", "true" },
}

test("rows: the layout changes keep every stored path, its type and its default (DW-LY guard)", function()
    local NS = T.newAddon()
    local want = {}
    for _, p in ipairs(PINNED_ROWS) do want[p[1]] = p end
    local seen = 0
    for _, row in ipairs(NS.addon.Settings.Schema) do
        if row.path then
            local p = want[row.path]
            -- red under: a row renamed, added or retired by a layout change
            assertTrue(p ~= nil, "a stored path the layout must not add: " .. row.path)
            assertEqual(row.type, p[2], row.path .. ": type")
            -- red under: a default changed by a move
            assertEqual(serialize(row.default), p[3], row.path .. ": default")
            seen = seen + 1
        end
    end
    assertEqual(seen, #PINNED_ROWS, "every pinned path is still a row")
end)
