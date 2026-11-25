-- tests/test_item_search_settings.lua — Item Search's settings page (DropWatcher#17, Item Search
-- spec §4.7, mockup board 3), WoW Forever's alone: its rows (settings/ItemSearchRows.lua), their
-- defaults (defaults/Profile.lua) and reactions, the Item tooltip tab's section order drag list and
-- the page's Keybindings tab over the Item Search key alone (settings/ItemSearchPage.lua), the
-- window's gear opening the page, and on Retail no page, no row and no default (spec §1).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is absent" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's absent case; the Forever cases cover WoW Forever" or nil

-- The page's rows in declaration order: path, tab, subsection (spec §4.7's table, every row).
local ROWS = {
    { "itemSearch.tooltip.enabled",           "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.shiftOnly",         "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.header",            "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.hint",              "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.comparison",        "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.rows",              "Item tooltip", "Tooltip block" },
    { "itemSearch.myProfessionsOnly",         "Item tooltip", "Tooltip block" },
    { "itemSearch.tooltip.sections.drops",    "Item tooltip", "Sections" },
    { "itemSearch.tooltip.sections.vendors",  "Item tooltip", "Sections" },
    { "itemSearch.tooltip.sections.quests",   "Item tooltip", "Sections" },
    { "itemSearch.tooltip.sections.crafting", "Item tooltip", "Sections" },
    { "itemSearch.tooltip.sections.also",     "Item tooltip", "Sections" },
    { "itemSearch.tooltip.hideCompleted",     "Item tooltip", "Sections" },
    { "itemSearch.tooltip.order",             "Item tooltip", "Sections" },
    { "itemSearch.window.enabled",            "Item Search window", "Window" },
    { "itemSearch.window.barColor",           "Item Search window", "Bars" },
    { "itemSearch.window.barFromSkin",        "Item Search window", "Bars" },
    { "itemSearch.window.density",            "Item Search window", "Rows" },
    { "itemSearch.window.fontSize",           "Item Search window", "Rows" },
    { "itemSearch.window.columns",            "Item Search window", "Rows" },
    { "itemSearch.window.pins",               "Item Search window", "Rows" },
    { "itemSearch.window.recent",             "Item Search window", "Rows" },
}

local function profileDefault(NS, path)
    local node = NS.C.PROFILE
    for seg in path:gmatch("[^.]+") do
        if type(node) ~= "table" then return nil end
        node = node[seg]
    end
    return node
end

local function enabled(opts)
    opts = opts or {}
    local fake
    local NS, _, m = T.enableAddon{ mock = function(mm) fake = FDB.install(mm, { preset = opts.preset or "present" }) end }
    return NS, m, fake
end

-- Show the Item Search page; answer its ctx (its first tab, Item tooltip, is drawn). The panel is
-- marked as the window's tree, so the mock records the list's raw text (tests/wow_mock.lua).
local function openPage(NS)
    local ctx = NS.addon.Settings.Helpers.__panelFor("itemSearch")
    assertTrue(ctx ~= nil, "the Item Search page was built")
    ctx.panel.__dwTree = true
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx
end

local function labels(ctx)
    local out = {}
    for i, row in ipairs(ctx.dwSectionOrder.rows) do out[i] = row.label:GetText() end
    return table.concat(out, ",")
end

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

test("item search settings: every spec §4.7 row is on the page, in order, with its default and WoW Forever's client", function()
    local NS = enabled()
    local rows = NS.addon.Settings.RowsForPage("itemSearch")
    -- red under: a row missing, moved to another tab, or declared for both clients
    assertEqual(#rows, #ROWS, "the page's rows")
    for i, want in ipairs(ROWS) do
        local row = rows[i]
        assertEqual(row.path, want[1], "row " .. i)
        assertEqual(row.group .. ">" .. row.subgroup, want[2] .. ">" .. want[3], want[1])
        assertEqual(table.concat(row.clients, ","), "forever", want[1])
        assertTrue(row.default ~= nil, want[1] .. " has a default")
        assertTrue(row.default == profileDefault(NS, want[1]), want[1] .. ": the default is defaults/Profile.lua's")
        assertTrue(type(row.label) == "string" and row.label ~= "" and type(row.tooltip) == "string", want[1])
    end
end, FOREVER_ONLY)

test("item search settings: the defaults are the spec's (on, off, on, on, off; 5 rows, my professions; comfortable, 13)", function()
    local NS = enabled()
    local S = NS.Setting
    assertTrue(S("itemSearch.tooltip.enabled")); assertFalse(S("itemSearch.tooltip.shiftOnly"))
    assertTrue(S("itemSearch.tooltip.header")); assertTrue(S("itemSearch.tooltip.hint"))
    assertFalse(S("itemSearch.tooltip.comparison"), "comparison tooltips off (the owner)")
    for key, on in pairs({ drops = true, vendors = true, quests = true, crafting = true, also = false }) do
        assertEqual(S("itemSearch.tooltip.sections." .. key), on, key)
    end
    assertEqual(S("itemSearch.tooltip.rows"), 5); assertTrue(S("itemSearch.tooltip.hideCompleted"))
    assertTrue(S("itemSearch.myProfessionsOnly"), "only the professions you know (feedback spec §4)")
    assertEqual(table.concat(S("itemSearch.tooltip.order"), ","), table.concat(NS.ItemSearchTip.ORDER, ","))
    assertTrue(S("itemSearch.window.barFromSkin")); assertEqual(S("itemSearch.window.density"), "comfortable")
    assertEqual(S("itemSearch.window.fontSize"), 13)
    for _, key in ipairs({ "columns", "pins", "recent", "enabled" }) do assertTrue(S("itemSearch.window." .. key), key) end
end, FOREVER_ONLY)

test("item search settings: the seam refuses an out-of-range count, a fractional size and a bad order", function()
    local NS = enabled()
    local Set = NS.SchemaRuntime.Set
    assertFalse((Set("itemSearch.tooltip.rows", 21)), "past 20")
    assertFalse((Set("itemSearch.tooltip.rows", 0)), "below 1")
    assertFalse((Set("itemSearch.tooltip.rows", 2.5)), "a whole number")
    assertTrue((Set("itemSearch.tooltip.rows", 20)), "20, the top")
    assertFalse((Set("itemSearch.window.fontSize", 17)), "past 16")
    assertFalse((Set("itemSearch.window.density", "airy")), "a density the window has not")
    -- red under: an order with an unknown section or one twice
    assertFalse((Set("itemSearch.tooltip.order", { "drops", "drops" })), "a section twice")
    assertFalse((Set("itemSearch.tooltip.order", { "drops", "loot" })), "an unknown section")
    assertFalse((Set("itemSearch.tooltip.order", {})), "no section")
    assertTrue((Set("itemSearch.tooltip.order", { "quests", "drops" })), "a partial order: the rest follow")
    assertEqual(table.concat(NS.ItemSearchTip.Options().order, ","), "quests,drops,vendors,crafting,also")
end, FOREVER_ONLY)

test("item search settings: a dimmed knob names what it needs; the block's switch dims its sub-rows", function()
    local NS = enabled()
    local R = NS.SchemaRuntime.FindRow
    assertFalse(R("itemSearch.tooltip.shiftOnly").disabledIf(), "on by default")
    NS.SchemaRuntime.Set("itemSearch.tooltip.enabled", false)
    for _, p in ipairs({ "shiftOnly", "header", "hint", "comparison", "sections.drops", "rows", "hideCompleted" }) do
        assertTrue(R("itemSearch.tooltip." .. p).disabledIf(), p .. " dims with the block off")
    end
    -- the profession filter also sets the window's default (feedback spec §4): never dimmed by the block
    assertTrue(R("itemSearch.myProfessionsOnly").disabledIf == nil or not R("itemSearch.myProfessionsOnly").disabledIf())
    NS.SchemaRuntime.Set("itemSearch.tooltip.enabled", true)
    assertTrue(R("itemSearch.tooltip.rows").tooltip:find("Needs Add Item Search to item tooltips.", 1, true) ~= nil)
    -- anti-pattern #74: a color and its companion are never dimmed
    assertNil(R("itemSearch.window.barColor").disabledIf); assertNil(R("itemSearch.window.barFromSkin").disabledIf)
end, FOREVER_ONLY)

test("item search settings: the switches reach the load, and the window's switch closes an open window", function()
    local NS, m, fake = enabled()
    NS.SchemaRuntime.Set("itemSearch.tooltip.enabled", false)
    NS.SchemaRuntime.Set("itemSearch.window.enabled", false)
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    -- red under: rows that write without the gate reading them (ForeverDB loaded with both off)
    assertEqual(fake.loads, 0, "both off: nothing loads ForeverDB")
    NS.SchemaRuntime.Set("itemSearch.tooltip.enabled", true)
    -- red under: no onChange calling IS.Refresh (the load waits for the next login)
    assertEqual(fake.loads, 1, "switched back on after the timer: it loads now")
    NS.SchemaRuntime.Set("itemSearch.window.enabled", true)
    assertTrue(NS.ItemSearchWindow.Open() ~= false)
    assertTrue(NS.ItemSearchWindow.IsShown(), "open")
    NS.SchemaRuntime.Set("itemSearch.window.enabled", false)
    assertFalse(NS.ItemSearchWindow.IsShown(), "its switch off closes it")
end, FOREVER_ONLY)

-- ── the page ────────────────────────────────────────────────────────────────────────────────

test("item search settings: the section order is a drag list in the stored order; a move writes it whole", function()
    local NS = enabled()
    local ISP = NS.addon.Settings.ItemSearchPage
    local ctx = openPage(NS)
    assertEqual(ctx.activeTab, "Item tooltip")
    -- red under: no afterGroup (no list), or a list in a fixed order
    assertEqual(labels(ctx), "Drops from,Sold by,Quests,Crafting,Reward from / starts quest")
    assertTrue(ctx.dwSectionList ~= nil, "a ReorderList controller for this render")
    assertTrue(ISP.Move(1, 3))
    assertEqual(table.concat(NS.Setting("itemSearch.tooltip.order"), ","), "vendors,quests,drops,crafting,also")
    assertEqual(table.concat(NS.ItemSearchTip.Options().order, ","), "vendors,quests,drops,crafting,also",
        "the tooltip writes the sections in the new order")
    NS.addon.Settings.Helpers.RefreshPanel(ctx, true)
    assertEqual(labels(ctx), "Sold by,Quests,Drops from,Crafting,Reward from / starts quest", "repainted")
    -- The page's Defaults puts the default order back.
    NS.addon.Settings.Helpers.RestoreDefaults("itemSearch", ctx)
    assertEqual(table.concat(NS.ItemSearchTip.Options().order, ","), table.concat(NS.ItemSearchTip.ORDER, ","))
end, FOREVER_ONLY)

test("item search settings: Moved is a pure splice, and an index outside the list changes nothing", function()
    local ISP = enabled().addon.Settings.ItemSearchPage
    local o = { "a", "b", "c", "d" }
    assertEqual(table.concat(ISP.Moved(o, 1, 4), ""), "bcda")
    assertEqual(table.concat(ISP.Moved(o, 4, 1), ""), "dabc")
    assertEqual(table.concat(ISP.Moved(o, 2, 9), ""), "acdb", "clamped to the end")
    assertEqual(table.concat(ISP.Moved(o, 7, 1), ""), "abcd")
    assertEqual(table.concat(o, ""), "abcd", "the input is not changed")
end, FOREVER_ONLY)

test("item search settings: a render parks the list first; its host never rides a released placeholder", function()
    local NS = enabled()
    local ISP = NS.addon.Settings.ItemSearchPage
    local ctx = openPage(NS)
    local host = ctx.dwSectionOrder.host
    assertTrue(host:IsShown())
    ISP.Park(ctx)
    -- red under: a Park that leaves the controller (its handles stay on the rows) or the host
    assertNil(ctx.dwSectionList, "the controller canceled")
    assertFalse(host:IsShown()); assertTrue(host:GetParent() == ctx.panel, "parked on the panel")
    NS.addon.Settings.Helpers.RefreshPanel(ctx, true)
    assertTrue(host:IsShown(), "re-hosted on the next render"); assertTrue(ctx.dwSectionList ~= nil)
    assertTrue(ctx.dwSectionOrder.host == host, "built once")
end, FOREVER_ONLY)

test("item search settings: the Keybindings tab shows and changes the Item Search key alone", function()
    local NS, m = enabled()
    local ctx = openPage(NS)
    local buttons = ctx.__tabLayout.buttons
    buttons[#buttons]:__fire("OnClick")
    assertEqual(ctx.activeTab, "Keybindings")
    local lib = m.LibStub("LibKa0s-Options-1.0")
    local rows = {}
    for row, owner in pairs(lib.__keybindLive) do
        if owner == ctx then rows[#rows + 1] = row end
    end
    -- red under: the tab over NS.BINDINGS whole (the window toggle is General > Keybindings')
    assertEqual(#rows, 1)
    assertEqual(rows[1].command, NS.Constants.ITEM_SEARCH.BINDING)
    assertEqual(rows[1].label.text, "Item Search")
    local saved = rawget(_G, "LibStub")
    rawset(_G, "LibStub", m.LibStub)
    local ok, line = pcall(T.keybindThroughTab, rows[1], 1, "F8")
    rawset(_G, "LibStub", saved)
    assertTrue(ok, tostring(line))
    assertEqual(line, m.KEY_BOUND)
    assertEqual(m.GetBindingKey(NS.Constants.ITEM_SEARCH.BINDING), "F8")
end, FOREVER_ONLY)

test("item search settings: the Item Search window's gear opens this page", function()
    local NS = enabled()
    local asked
    NS.addon.OpenSettings = function(_, key) asked = key end
    NS.ItemSearchWindow.Open()
    local gear = NS.ItemSearchWindow.Frame().settingsButton
    assertTrue(gear ~= nil, "the window carries the gear")
    gear:__fire("OnClick")
    assertEqual(asked, "itemSearch")
end, FOREVER_ONLY)

-- ── Retail: absent ──────────────────────────────────────────────────────────────────────────

test("item search settings: on Retail there is no page, no row and no default", function()
    local NS = T.enableAddon()
    assertNil(NS.C.PROFILE.itemSearch, "no default")
    assertEqual(#NS.addon.Settings.RowsForPage("itemSearch"), 0, "no row")
    for _, p in ipairs(NS.addon.Settings.Helpers.__pages()) do
        assertTrue(p.key ~= "itemSearch", "no page")
    end
    assertNil(NS.addon.Settings.ItemSearchPage)
end, RETAIL_ONLY)
