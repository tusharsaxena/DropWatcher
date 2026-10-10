-- tests/test_schema.lua — the one write seam, its reactions, and the resets (architecture-§5,
-- options-ui-§1/§12, launcher-§3).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

test("schema: every row validates against the defaults", function()
    local NS = T.bootAddon()
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)

test("schema: a stored row whose path has no default is counted, not passed vacuously", function()
    local NS = T.bootAddon()
    local rows = NS.addon.Settings.Schema
    rows[#rows + 1] = { path = "nope.noDefault", type = "bool", label = "No default" }
    local count = NS.addon.Settings.Helpers.ValidateSchema()
    rows[#rows] = nil
    assertTrue(count > 0, "the unresolved path is reported")
end)

test("schema: the Minimap button row's backing key resolves against the global defaults", function()
    local NS = T.bootAddon()
    local mm = NS.C.GLOBAL_DEFAULTS.minimap
    local saved = mm.hide
    mm.hide = nil
    local count = NS.addon.Settings.Helpers.ValidateSchema()
    mm.hide = saved
    assertEqual(count, 1)
end)

test("schema: the Master controls rows are the canonical set, in the canonical order", function()
    local NS = T.newAddon()
    local paths = {}
    for i, row in ipairs(NS.addon.Settings.Schema) do paths[i] = row.path end
    assertEqual(table.concat(paths, ","),
        "enabled,visibility,scale,alpha,locked,state.debugConsole,global.minimap.shown,state.testMode")
end)

test("schema: an unknown path is refused and stores nothing", function()
    local NS = T.bootAddon()
    local ok = NS.SchemaRuntime.Set("nope.never", 1)
    assertFalse(ok)
    assertTrue(NS.addon.db.profile.nope == nil)
end)

test("schema: the Minimap button row inverts onto LibDBIcon's own hide, with no shown key", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    assertEqual(NS.addon.db.global.minimap.hide, true)
    assertTrue(NS.addon.db.global.minimap.shown == nil, "no shown twin")
    assertFalse(m.minimapButtons.DropWatcher.shown, "LibDBIcon hid the button")
    assertEqual(NS.SchemaRuntime.Get("global.minimap.shown"), false)
end)

test("schema: neither reset touches the minimap button (launcher-§3)", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("global.minimap.shown", false)
    NS.SchemaRuntime.Set("scale", 1.5)
    -- red under: drop resetExempt from settings/Schema.lua and route reset all through ApplyDefault
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.global.minimap.hide, true, "Reset all settings left it hidden")
    assertEqual(NS.addon.db.profile.scale, 1, "and did reset the profile")
end)

test("schema: Reset all asks first, through the confirmation popup", function()
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("resetall")
    assertEqual(m.popupsShown[#m.popupsShown][1], "DROPWATCHER_RESET_ALL")
    assertTrue(m.StaticPopupDialogs.DROPWATCHER_RESET_ALL ~= nil or _G.StaticPopupDialogs.DROPWATCHER_RESET_ALL ~= nil)
end)

test("schema: a write to `scale` reaches the window through the row's reaction", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    NS.SchemaRuntime.Set("scale", 1.25)
    assertEqual(NS.Window.Frame():GetScale(), 1.25)
    NS.SchemaRuntime.Set("alpha", 0.5)
    assertEqual(NS.Window.Frame():GetAlpha(), 0.5)
end)

test("schema: degraded, `enabled` and `locked` are written through and still react", function()
    local D = T.enableAddon{ skip = NO_LIBKA0S }
    -- red under: drop `writeThrough` from settings/Schema.lua (the composed rows do not exist here)
    assertTrue(D.SchemaRuntime.Set("enabled", false))
    assertEqual(D.addon.db.profile.enabled, false)
    assertTrue(D.IsStoodDown(), "the reaction ran from announce")
    assertTrue(D.SchemaRuntime.Set("enabled", true))
    assertFalse(D.IsStoodDown())
    assertTrue(D.SchemaRuntime.Set("locked", true))
    assertEqual(D.addon.db.profile.locked, true)
end)

test("schema: degraded, a row-less path not in the list is still refused", function()
    local D = T.bootAddon{ skip = NO_LIBKA0S }
    assertFalse(D.SchemaRuntime.Set("scale", 2))
    assertEqual(D.addon.db.profile.scale, 1, "nothing stored")
end)
