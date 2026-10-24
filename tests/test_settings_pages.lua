-- tests/test_settings_pages.lua — the settings pages of design spec §12.2 (regrouped by
-- feedback-24): the page list and each page's strip, the rows each page draws, the dimmed rows, the
-- Drops › Situations' table, Drops › Quality's "in force now" readout, the Comparison page's per-spec
-- editors, the Messages page's template editors (live counters, token chips, preview, Reset
-- templates), Drops › Retention's Clear history beside Keep history for (feedback-15 spec §3), the
-- Window › Columns note, each page's Defaults button, and
-- the pure halves of the editors (settings/Editors.lua). Built headless under the kit's AceGUI
-- recorder: a page's body is drawn on its first OnShow, and a tab is reached by clicking the
-- strip's button.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The pages after the landing page, and each page's strip, in order. Stated here rather than read
-- from the rows, so a tab that moves is a named failure.
local PAGES = {
    { key = "general",    title = "General",    strip = { "Master controls", "Simulator", "Keybindings" } },
    -- item 020 folded the Situations page into Drops as its first tab (DRO-L01).
    { key = "feed",       title = "Drops",      strip = { "Situations", "Quality", "Items", "Retention" } },
    { key = "comparison", title = "Comparison", strip = { "Scoring", "Weights", "Unwanted types" } },
    { key = "messages",   title = "Messages",   strip = { "Sending", "Auto-ask", "Templates" } },
    { key = "window",     title = "Window",     strip = { "Layout", "Columns", "Starting view", "Icons" } },
    { key = "alerts",     title = "Alerts",     strip = { "Toast", "Upgrade glow" } },
}

local function gui(m) return m.__libs["AceGUI-3.0"] end

local function created(m, from)
    local out, list = {}, gui(m).__created
    for i = from + 1, #list do out[#out + 1] = list[i] end
    return out
end

-- Show a page and answer its ctx and the widgets its first render drew.
local function open(NS, m, key)
    local H = NS.addon.Settings.Helpers
    local ctx = H.__panelFor(key)
    assertTrue(ctx ~= nil, "page " .. key .. " was built")
    local before = #gui(m).__created
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    return ctx, created(m, before)
end

-- Click a tab and answer the widgets that render drew. BY POSITION, as the strip's buttons come
-- back in tab order, then checked against the tab the library says is active.
local function tab(m, ctx, label)
    local before = #gui(m).__created
    for _, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        if ctx.activeTab == label then return created(m, before) end
        before = #gui(m).__created
    end
    assertTrue(false, "no tab labeled " .. label)
end

local function find(list, wtype, label)
    for _, w in ipairs(list) do
        if w.type == wtype and (w.labelText == label or w.text == label) then return w end
    end
end

local function findPrefix(list, wtype, prefix)
    for _, w in ipairs(list) do
        local l = w.labelText or w.text
        if w.type == wtype and type(l) == "string" and l:sub(1, #prefix) == prefix then return w end
    end
end

-- The strip's tabs in order, read as the active tab each button selects, then back to the first.
local function stripOf(ctx)
    local out, buttons = {}, ctx.__tabLayout.buttons
    out[1] = ctx.activeTab
    for i = 2, #buttons do
        buttons[i]:__fire("OnClick")
        out[i] = ctx.activeTab
    end
    ctx.__tabLayout.buttons[1]:__fire("OnClick")
    return out
end

-- The flow line holding a widget, among the widgets a render drew.
local function lineOf(list, w)
    for _, g in ipairs(list) do
        for _, c in ipairs(g.children or {}) do
            if c == w then return g end
        end
    end
end

-- ── the pages and their strips ──────────────────────────────────────────────────────────────

test("pages: General, Drops, Comparison, Messages, Window and Alerts are built, in that order", function()
    local NS = T.enableAddon()
    local built = {}
    for _, p in ipairs(NS.addon.Settings.Helpers.__pages()) do
        if p.key ~= "profiles" then built[#built + 1] = p.key end
    end
    local want = {}
    for i, p in ipairs(PAGES) do want[i] = p.key end
    assertEqual(table.concat(built, ","), table.concat(want, ","))
end)

test("pages: each page's strip is its own tabs, one per group, in declaration order", function()
    local NS, _, m = T.enableAddon()
    for _, p in ipairs(PAGES) do
        local ctx = open(NS, m, p.key)
        -- red under: rowsForPage answering the whole schema, which gave General fifteen tabs
        assertEqual(table.concat(stripOf(ctx), "|"), table.concat(p.strip, "|"), p.key)
    end
end)

test("pages: a page's rows are the rows whose page is its key", function()
    local NS = T.enableAddon()
    local S = NS.addon.Settings
    for _, p in ipairs(PAGES) do
        local rows = S.RowsForPage(p.key)
        assertTrue(#rows > 0, p.key .. " has rows")
        for _, row in ipairs(rows) do assertEqual(row.page, p.key, row.path) end
    end
end)

test("pages: every schema row with a page but the Profiles page's is drawn by one of these pages", function()
    local NS = T.enableAddon()
    local keys = {}
    for _, p in ipairs(PAGES) do keys[p.key] = true end
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(keys[row.page] == true, tostring(row.path) .. " is on a registered page")
    end
end)

-- ── Drops › Situations (General › When to show and Trade › Rules until feedback-24; its own page
-- until item 020) ────────────────────────────────────────────────────────────────────────────

-- Drops › Situations drawn with its table's frames recorded: a panel marked as the window's tree
-- has its children decorated by the mock (tests/wow_mock.lua), so the table's text and stripes
-- can be read back. The tab is the page's first, so its first render, and the mark goes on before
-- the show. Answers the ctx, the tab's widgets and the table.
local function whenToShow(NS, m)
    NS.addon.Settings.Helpers.__panelFor("feed").panel.__dwTree = true
    local ctx, drawn = open(NS, m, "feed")
    assertEqual(ctx.activeTab, "Situations", "the Drops page opens on its Situations tab")
    return ctx, drawn, ctx.dwSituations
end

-- The page rendered again, as a profile switch or a sub-strip click does; answers what it drew.
local function rerender(NS, m, ctx)
    local before = #gui(m).__created
    NS.addon.Settings.Helpers.RefreshPanel(ctx, true)
    return created(m, before)
end

test("situations: the global Auto-open row, then one table line per situation and no per-situation rows", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, t = whenToShow(NS, m)
    assertTrue(find(drawn, "CheckBox", "Auto-open the window") ~= nil, "the master auto-open first")
    for _, w in ipairs(drawn) do
        -- red under: the rows still drawn by the flow engine, a heading and three widgets apiece
        assertFalse(w.type == "Heading", "no per-situation heading: " .. tostring(w.labelText or w.text))
        assertFalse(w.labelText == "Track" or w.labelText == "Quality", "no per-situation row")
        assertFalse(w.labelText == "Mythic+", "no loot rule row of its own")
    end
    assertTrue(t ~= nil, "the table is drawn")
    local S = NS.Constants.SITUATIONS
    assertEqual(#t.rows, #S)
    for i, s in ipairs(S) do
        assertEqual(t.rows[i].label:GetText(), NS.WindowFooter.SituationLabel(s.key), s.key)
    end
end)

test("situations: five gold, left-aligned column headers, and a stripe on every second line", function()
    local NS, _, m = T.enableAddon()
    local _, _, t = whenToShow(NS, m)
    local names = {}
    for i, fs in ipairs(t.headers) do
        names[i] = fs:GetText()
        assertEqual(fs.__template, "GameFontNormalSmall")
        local r, g, b = fs:GetTextColor()
        assertTrue(r > 0.8 and g > 0.7 and b < 0.5, "gold")
    end
    assertEqual(table.concat(names, "|"), "Situation|Track|Auto-open|Quality|Loot rule")
    for i, r in ipairs(t.rows) do
        assertEqual(r.stripe:IsShown() == true, i % 2 == 0, "stripe on line " .. i)
        assertEqual(r.label.__template, "GameFontHighlightSmall")
    end
end)

test("situations: each cell paints its stored value, and a toggle writes its path", function()
    local NS, _, m = T.enableAddon()
    local _, _, t = whenToShow(NS, m)
    local delve = t.rows[6]   -- K.SITUATIONS order: delve is sixth, untracked by default
    assertEqual(delve.track.value, false)
    assertEqual(t.rows[1].track.value, true, "Mythic+ is tracked by default")
    assertEqual(t.rows[1].quality.value, "global")
    assertEqual(t.rows[1].quality.list.global, "Use global", "the row's own value list")
    delve.track:__fire("OnValueChanged", true)
    assertEqual(NS.addon.db.profile.situations.delve.track, true)
    t.rows[1].quality:__fire("OnValueChanged", "dynamicSlot")
    assertEqual(NS.addon.db.profile.situations.mythicPlus.quality, "dynamicSlot")
    t.rows[1].autoOpen:__fire("OnValueChanged", false)
    assertEqual(NS.addon.db.profile.situations.mythicPlus.autoOpen, false)
    assertEqual(t.rows[1].rule.value, "personal", "the loot rule (feedback-24)")
    assertEqual(t.rows[1].rule.list.legacy, "Legacy loot", "its own value list")
    t.rows[1].rule:__fire("OnValueChanged", "group")
    assertEqual(NS.addon.db.profile.trade.rules.mythicPlus, "group")
    NS.SchemaRuntime.Set("situations.raid.track", false)
    assertEqual(t.rows[5].track.value, false, "a write from elsewhere repaints it")
end)

test("situations: an untracked situation's Auto-open, Quality and Loot rule are dimmed, and so is every Auto-open with the master off", function()
    local NS, _, m = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    local _, _, t = whenToShow(NS, m)
    local mp, delve = t.rows[1], t.rows[6]
    assertFalse(mp.autoOpen.disabled == true, "mythicPlus auto-open live")
    assertFalse(mp.quality.disabled == true)
    assertFalse(delve.track.disabled == true, "Track is always live")
    assertTrue(delve.autoOpen.disabled == true, "delve (untracked) auto-open dimmed")
    assertTrue(delve.quality.disabled == true, "and its quality")
    assertTrue(delve.rule.disabled == true, "and its loot rule")
    assertFalse(mp.rule.disabled == true, "a tracked one's is live")
    assertEqual(select(1, delve.label:GetTextColor()), 0.5, "its label dims")
    Set("situations.delve.track", true)
    assertFalse(delve.autoOpen.disabled == true, "tracking it lights it")
    assertFalse(delve.quality.disabled == true)
    assertFalse(delve.rule.disabled == true)
    assertEqual(select(1, delve.label:GetTextColor()), 0.86)
    Set("autoOpen", false)
    -- red under: a disabled rule that reads the situation's track alone
    assertTrue(mp.autoOpen.disabled == true, "the master off dims every situation's")
    assertFalse(mp.quality.disabled == true, "but not its quality")
end)

test("situations: Defaults repaints the table", function()
    local NS, _, m = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    local _, _, t = whenToShow(NS, m)
    Set("situations.delve.track", true)
    Set("situations.mythicPlus.quality", "fixed")
    assertEqual(t.rows[6].track.value, true)
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(t.rows[6].track.value, false)
    assertEqual(t.rows[1].quality.value, "global")
    assertTrue(t.rows[6].autoOpen.disabled == true)
end)

test("situations: a profile switch repaints the table and re-hosts it", function()
    local NS, _, m = T.enableAddon()
    local ctx, _, t = whenToShow(NS, m)
    NS.SchemaRuntime.Set("situations.delve.track", true)
    assertEqual(t.rows[6].track.value, true)
    NS.addon.db:SetProfile("Other")
    -- red under: a full re-render that builds a second table, or re-hosts nothing after the park
    assertTrue(ctx.dwSituations == t, "the same table")
    assertEqual(t.rows[6].track.value, false, "the fresh profile's delve is untracked")
    assertTrue(t.rows[6].autoOpen.disabled == true, "and its auto-open dims again")
    assertTrue(t.host:IsShown() == true, "still on the page")
    assertTrue(t.host:GetParent() ~= ctx.panel, "re-hosted off the park")
end)

test("situations: the table is built once, parked before each render, and re-hosted on the new placeholder", function()
    local NS, _, m = T.enableAddon()
    local ctx, _, t = whenToShow(NS, m)
    local slot = t.rows[1]
    local first = t.host:GetParent()
    assertTrue(t.host:IsShown() == true)
    local parks, park = 0, NS.addon.Settings.PageEditors.ParkSituationTable
    NS.addon.Settings.PageEditors.ParkSituationTable = function(c) parks = parks + 1; return park(c) end
    local drawn = rerender(NS, m, ctx)
    NS.addon.Settings.PageEditors.ParkSituationTable = park
    -- red under: a render that does not park first, leaving the host on the released placeholder
    assertTrue(parks >= 1, "the render parks first")
    assertTrue(t.host:GetParent() ~= first, "off the placeholder the render handed back")
    assertTrue(ctx.dwSituations == t and t.rows[1] == slot, "the same slots")
    -- the render drew no second set of cells
    local checks = 0
    for _, w in ipairs(drawn) do if w.type == "CheckBox" and w.labelText == "" then checks = checks + 1 end end
    assertEqual(checks, 0)
    assertTrue(t.host:IsShown() == true)
    NS.SchemaRuntime.Set("situations.solo.track", true)
    assertEqual(t.rows[10].track.value, true, "repainted after the re-host")
end)

test("situations: releasing the placeholder outside the renderer parks the table (its OnRelease, options-ui-§19)", function()
    local NS, _, m = T.enableAddon()
    local ctx, drawn, t = whenToShow(NS, m)
    local holder
    for _, w in ipairs(drawn) do
        if w.type == "SimpleGroup" and w.frame == t.host:GetParent() then holder = w end
    end
    assertTrue(holder ~= nil, "the table sits on a SimpleGroup placeholder")
    gui(m):Release(holder)
    -- red under: an undo only the Situations page's renderer runs, so a release from any other path
    -- leaves the table riding the pooled frame
    assertEqual(t.host:GetParent(), ctx.panel, "parked on the panel")
    assertFalse(t.host:IsShown() == true, "and hidden")
    local again = rerender(NS, m, ctx)
    local fresh
    for _, w in ipairs(again) do
        if w.type == "SimpleGroup" and w.frame == t.host:GetParent() then fresh = w end
    end
    assertTrue(fresh ~= nil and fresh ~= holder, "re-hosted on the new placeholder")
    assertTrue(t.host:IsShown() == true, "and shown")
end)

test("situations: the per-situation rows are still schema rows, skipRender, with no subsection", function()
    local NS = T.enableAddon()
    for _, s in ipairs(NS.Constants.SITUATIONS) do
        local paths = { "trade.rules." .. s.key }
        for _, f in ipairs({ "track", "autoOpen", "quality" }) do paths[#paths + 1] = "situations." .. s.key .. "." .. f end
        for _, path in ipairs(paths) do
            local row = NS.SchemaRuntime.FindRow(path)
            assertTrue(row ~= nil, path)
            assertTrue(row.skipRender == true, path .. " is the table's")
            assertTrue(row.subgroup == nil, "no heading of its own")
            -- red under: the rows still stamped to the retired Situations page (DRO-L01)
            assertEqual(row.page, "feed", path)
            assertEqual(row.group, "Situations", path)
        end
    end
    assertFalse(NS.SchemaRuntime.FindRow("autoOpen").skipRender == true, "the global row is drawn")
end)

test("situations: the pure rows carry each situation's label, values and live cells", function()
    local NS = T.enableAddon()
    local E = NS.addon.Settings.Editors
    local Set = NS.SchemaRuntime.Set
    local function rows() return E.SituationRows(NS.SchemaRuntime.FindRow, NS.Setting, NS.WindowFooter.SituationLabel) end
    local list = rows()
    assertEqual(#list, #NS.Constants.SITUATIONS)
    assertEqual(list[1].key, "mythicPlus")
    assertEqual(list[1].label, "Mythic+")
    assertEqual(list[1].track.path, "situations.mythicPlus.track")
    assertEqual(list[1].quality.value, "global")
    assertEqual(list[1].rule.path, "trade.rules.mythicPlus")
    assertEqual(list[1].rule.value, "personal")
    assertTrue(list[1].active and list[1].autoOpen.enabled and list[1].quality.enabled and list[1].rule.enabled)
    -- track x global auto-open: Auto-open is live only with both on; Quality with the track on.
    local cases = { { true, true, true, true }, { true, false, false, true },
                    { false, true, false, false }, { false, false, false, false } }
    for _, c in ipairs(cases) do
        Set("situations.dungeon.track", c[1])
        Set("autoOpen", c[2])
        local d = rows()[2]
        local tag = tostring(c[1]) .. "/" .. tostring(c[2])
        assertEqual(d.active, c[1], tag)
        assertTrue(d.track.enabled, tag .. " track always live")
        assertEqual(d.autoOpen.enabled, c[3], tag .. " auto-open")
        assertEqual(d.quality.enabled, c[4], tag .. " quality")
        assertEqual(d.rule.enabled, c[4], tag .. " loot rule")
    end
end)

-- ── Drops › Quality ─────────────────────────────────────────────────────────────────────────

test("feed: the Quality tab closes with the threshold in force now, repainted on a write", function()
    local NS, _, m = T.enableAddon()
    local drawn = tab(m, open(NS, m, "feed"), "Quality")
    local readout = findPrefix(drawn, "Label", "In force now")
    assertTrue(readout ~= nil, "the readout is drawn")
    assertEqual(readout.text, "In force now: Quality: Rare+")
    NS.SchemaRuntime.Set("feed.quality.fixed", NS.Constants.QUALITY.EPIC)
    assertEqual(readout.text, "In force now: Quality: Epic+")
    NS.SchemaRuntime.Set("feed.quality.mode", "dynamicSlot")
    assertEqual(readout.text, "In force now: Quality: Match slot")
    -- red under: the pointer still sending the player to a Situations page (DRO-L02)
    assertTrue(find(drawn, "Label", "A situation can set a quality of its own: the Quality column on the Situations tab.") ~= nil,
        "the pointer to the Situations tab's Quality column (feedback-24, item 020)")
end)

-- feedback-24: the mode and Always show upgrades share line one, the mode's two dependents (never
-- live together) line two.
test("feed: the Quality tab pairs the mode with Always show upgrades, then Fixed minimum with Quality floor", function()
    local NS, _, m = T.enableAddon()
    local drawn = tab(m, open(NS, m, "feed"), "Quality")
    local mode, always = find(drawn, "Dropdown", "Minimum quality"), find(drawn, "CheckBox", "Always show upgrades for me")
    local fixed, floor = find(drawn, "Dropdown", "Fixed minimum"), find(drawn, "Dropdown", "Quality floor")
    assertTrue(lineOf(drawn, mode) ~= nil and lineOf(drawn, mode) == lineOf(drawn, always), "line one")
    assertTrue(lineOf(drawn, fixed) ~= nil and lineOf(drawn, fixed) == lineOf(drawn, floor), "line two")
end)

-- feedback-24: Items' Minimum item level alone on its line, its two values paired under it.
test("feed: Items draws Minimum item level alone, then Absolute minimum beside Levels under my average", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "feed")
    local drawn = tab(m, ctx, "Items")
    local mode = find(drawn, "Dropdown", "Minimum item level")
    local abs, rel = find(drawn, "Slider", "Absolute minimum"), find(drawn, "Slider", "Levels under my average")
    assertTrue(mode ~= nil and abs ~= nil and rel ~= nil, "all three drawn")
    assertEqual(#lineOf(drawn, mode).children, 1, "the mode alone")
    assertTrue(lineOf(drawn, abs) == lineOf(drawn, rel), "its values paired")
    -- red under: the pre-020 "Tier tokens", which did not read as a switch (DRO-L10)
    local gear, tokens = find(drawn, "CheckBox", "Gear only"), find(drawn, "CheckBox", "Include tier tokens")
    assertTrue(gear ~= nil and tokens ~= nil and lineOf(drawn, gear) == lineOf(drawn, tokens), "Gear only | Include tier tokens")
end)

test("feed: the fixed minimum is live in the fixed mode only, and the floor in the matching modes only", function()
    local NS, _, m = T.enableAddon()
    local drawn = tab(m, open(NS, m, "feed"), "Quality")
    local fixed, floor = find(drawn, "Dropdown", "Fixed minimum"), find(drawn, "Dropdown", "Quality floor")
    assertFalse(fixed.disabled == true)
    assertTrue(floor.disabled == true)
    NS.SchemaRuntime.Set("feed.quality.mode", "dynamicCharacter")
    assertTrue(fixed.disabled == true)
    assertFalse(floor.disabled == true)
end)

test("feed: the readout names the situation whose own quality setting is in force", function()
    local NS = T.enableAddon()
    local E = NS.addon.Settings.Editors
    assertEqual(E.ReadoutText("Quality: Rare+", nil), "In force now: Quality: Rare+")
    assertEqual(E.ReadoutText("Quality: Match slot", "Dungeon"),
        "In force now: Quality: Match slot (Dungeon's own setting)")
end)

-- ── Comparison › Weights and Preferences ────────────────────────────────────────────────────

test("comparison: Weights draws your class's specs as a sub-strip and one slider per stat", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    -- The mock player is a mage: Arcane, Fire and Frost, the first shown (250 is not a mage's).
    assertEqual(#ctx.__subTabKids, 3)
    assertEqual(ctx.activeSubTab["Weights"], 62)
    assertTrue(find(drawn, "Slider", "Intellect") ~= nil, "the spec's primary stat")
    assertTrue(find(drawn, "Slider", "Strength") == nil, "and not another's")
    assertTrue(find(drawn, "Slider", "Haste") ~= nil)
end)

test("comparison: a weight slider writes the whole map through the seam, for the spec on screen", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    find(drawn, "Slider", "Haste"):__fire("OnMouseUp", 1.5)
    local w = NS.Setting("comparison.weights")
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 1.5)
    -- Another spec, by its sub-tab: its own weights, the first spec's kept.
    local before = #gui(m).__created
    ctx.__subTabKids[2]:__fire("OnClick")
    assertEqual(ctx.activeSubTab["Weights"], 63)
    find(created(m, before), "Slider", "Haste"):__fire("OnMouseUp", 0.75)
    w = NS.Setting("comparison.weights")
    assertEqual(w[63].ITEM_MOD_HASTE_RATING_SHORT, 0.75)
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 1.5)
end)

test("comparison: the Pawn import box replaces the spec on screen's weights and says what came in", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Weights")
    local box = find(drawn, "EditBox", "Import a Pawn scale")
    assertTrue(box ~= nil, "the import box")
    NS.SchemaRuntime.Set("comparison.weights", { [63] = { ITEM_MOD_HASTE_RATING_SHORT = 2 } })
    local printed = #m.prints
    box:__fire("OnEnterPressed", '( Pawn: v1: "Mine": Intellect=1.2, HasteRating=0.7, Dps=4 )')
    local w = NS.Setting("comparison.weights")
    assertEqual(w[62].ITEM_MOD_INTELLECT_SHORT, 1.2)
    assertEqual(w[62].ITEM_MOD_HASTE_RATING_SHORT, 0.7)
    assertEqual(w[63].ITEM_MOD_HASTE_RATING_SHORT, 2, "another spec's weights are kept")
    local line = m.prints[printed + 1]
    assertTrue(line and line:find("Imported Mine into", 1, true) ~= nil and line:find("2 weights", 1, true) ~= nil, tostring(line))
    assertTrue(line:find("Not scored: Dps.", 1, true) ~= nil, line)
    -- A string that is not Pawn's writes nothing and says why.
    box:__fire("OnEnterPressed", "Intellect=9")
    assertEqual(NS.Setting("comparison.weights")[62].ITEM_MOD_INTELLECT_SHORT, 1.2)
    assertTrue(m.prints[#m.prints]:find("not a Pawn scale string", 1, true) ~= nil, m.prints[#m.prints])
end)

test("comparison: Unwanted types lists the class's weapon types and marks one unwanted per spec", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "comparison")
    local drawn = tab(m, ctx, "Unwanted types")
    local daggers = find(drawn, "CheckBox", "Daggers")
    assertTrue(daggers ~= nil, "a mage's daggers")
    assertTrue(find(drawn, "CheckBox", "Shields") == nil, "a mage carries no shield")
    daggers:__fire("OnValueChanged", true)
    local key = NS.Evaluate.SubClassKey(NS.Constants.ITEM_CLASS.WEAPON, NS.Constants.WEAPON_SUBCLASS.DAGGER)
    assertTrue(NS.Setting("comparison.undesired")[62][key] == true, "written for Arcane")
    -- red under: an edit made in place on the stored table, which skips the seam's check
    daggers:__fire("OnValueChanged", false)
    assertTrue(NS.Setting("comparison.undesired")[62] == nil, "the spec's last type cleared leaves no entry")
end)

-- ── Messages › Templates ────────────────────────────────────────────────────────────────────

local function templates(NS, m)
    local ctx = open(NS, m, "messages")
    local drawn = tab(m, ctx, "Templates")   -- the last tab since feedback-24
    local boxes = {}
    for _, kind in ipairs({ "ask", "offer", "announce" }) do
        local label = NS.addon.Settings.Editors.TEMPLATE_LABEL[kind]
        boxes[kind] = findPrefix(drawn, "EditBox", label)
        assertTrue(boxes[kind] ~= nil, kind .. " editor")
    end
    return ctx, drawn, boxes
end

test("messages: three editors whose labels count the template's bytes against 255", function()
    local NS, _, m = T.enableAddon()
    local _, _, boxes = templates(NS, m)
    local ask = NS.Setting("messages.templates.ask")
    assertEqual(boxes.ask.text, ask)
    assertTrue(boxes.ask.labelText:find(("%d / 255"):format(#ask), 1, true) ~= nil, boxes.ask.labelText)
    assertEqual(boxes.ask.maxLetters, 255)
end)

test("messages: typing repaints the counter and the preview live, and stores nothing until Enter", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    local body = findPrefix(drawn, "Label", "To ")
    assertTrue(body ~= nil, "the preview's text line")
    local stored = NS.Setting("messages.templates.offer")
    boxes.offer.text = "Want {item}?"
    boxes.offer:__fire("OnTextChanged", "Want {item}?")
    assertTrue(boxes.offer.labelText:find("12 / 255", 1, true) ~= nil, boxes.offer.labelText)
    assertTrue(findPrefix(drawn, "Label", "Preview: Offer") ~= nil, "the preview follows the box being edited")
    assertTrue(body.text:find("Want ", 1, true) ~= nil and body.text:find("{item}", 1, true) == nil, body.text)
    assertEqual(NS.Setting("messages.templates.offer"), stored)
    boxes.offer:__fire("OnEnterPressed", "Want {item}?")
    assertEqual(NS.Setting("messages.templates.offer"), "Want {item}?")
end)

-- Your worn helm, so a preview with no drop in the feed has a real item to name (test mode's
-- samples over your own gear, NS.TestMode.PreviewSpecs).
local function wearHelm(NS, m)
    local helm = m.addItem("|cnIQ4:|Hitem:6101::::::::90:::::|h[Worn Helm]|h|r",
        { name = "Worn Helm", quality = 4, ilvl = 300, equipLoc = "INVTYPE_HEAD", classID = 4, subClassID = 4, stats = {} })
    m.inventory.player[1] = helm
    NS.Gear.Refresh("test")
end

test("messages: the preview flags an unknown token and a text past the chat limit", function()
    local NS, _, m = T.enableAddon()
    wearHelm(NS, m)
    local _, drawn, boxes = templates(NS, m)
    local status
    for _, w in ipairs(drawn) do
        if w.type == "Label" and type(w.text) == "string" and w.text:find("^%d+ / 255") then status = w end
    end
    assertTrue(status ~= nil, "the status line")
    boxes.ask.text = "Hi {who}"
    boxes.ask:__fire("OnTextChanged", "Hi {who}")
    assertTrue(status.text:find("{who}", 1, true) ~= nil, status.text)
    local long = string.rep("x", 250) .. " {item}"
    boxes.ask.text = long
    boxes.ask:__fire("OnTextChanged", long)
    assertTrue(status.text:find("too long to send", 1, true) ~= nil, status.text)
end)

test("messages: an empty template is refused by the seam and the box shows the stored one again", function()
    local NS, _, m = T.enableAddon()
    local _, _, boxes = templates(NS, m)
    local ask = NS.Setting("messages.templates.ask")
    boxes.ask.text = ""
    boxes.ask:__fire("OnEnterPressed", "")
    assertEqual(NS.Setting("messages.templates.ask"), ask)
    assertEqual(boxes.ask.text, ask)
end)

test("messages: a token chip goes into the template last edited and is stored at once", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    local chip = find(drawn, "Button", "{mygain}")
    assertTrue(chip ~= nil, "the chips are drawn")
    local ask = NS.Setting("messages.templates.ask")
    chip:__fire("OnClick")
    assertEqual(NS.Setting("messages.templates.ask"), ask .. "{mygain}", "Ask until another is edited")
    boxes.announce:__fire("OnTextChanged", boxes.announce.text)
    find(drawn, "Button", "{item}"):__fire("OnClick")
    assertEqual(NS.Setting("messages.templates.announce"),
        NS.C.PROFILE.messages.templates.announce .. "{item}")
end)

test("messages: Reset templates puts the three back and repaints the boxes", function()
    local NS, _, m = T.enableAddon()
    local _, drawn, boxes = templates(NS, m)
    NS.SchemaRuntime.Set("messages.templates.ask", "Mine?")
    NS.SchemaRuntime.Set("messages.templates.offer", "Yours?")
    assertEqual(boxes.ask.text, "Mine?")
    find(drawn, "Button", "Reset templates"):__fire("OnClick")
    local D = NS.C.PROFILE.messages.templates
    assertEqual(NS.Setting("messages.templates.ask"), D.ask)
    assertEqual(NS.Setting("messages.templates.offer"), D.offer)
    assertEqual(boxes.ask.text, D.ask)
end)

-- ── Drops › Retention: Clear history (feedback-15 spec §3, DW-Q3; Window › Layout's until feedback-24)

test("feed: Retention draws Clear history beside Keep history for; it asks first and clears only on Yes", function()
    local NS, _, m = T.enableAddon()
    local ctx = open(NS, m, "feed")
    local drawn = tab(m, ctx, "Retention")
    local keep = find(drawn, "Dropdown", "Keep history for")
    local clear = find(drawn, "Button", "Clear history")
    -- red under: Keep history for after Clear on boss kill, which pairs with it and leaves no half
    -- for the button
    assertTrue(keep ~= nil and clear ~= nil, "both are drawn")
    assertTrue(lineOf(drawn, keep) ~= nil and lineOf(drawn, keep) == lineOf(drawn, clear), "on one line")
    -- red under: the pre-020 label, which did not say it clears the session's list (DRO-L11)
    assertTrue(find(drawn, "CheckBox", "Clear this session's drops on boss kill") ~= nil, "and the session's clear under them")
    local H = NS.History
    local hist = H.Store()
    hist.groups = { { key = "enc:1@1", label = "Boss A", kind = "encounter", at = 1, drops = {} } }
    clear:__fire("OnClick")
    assertEqual(m.popupsShown[#m.popupsShown][1], H.CLEAR_POPUP)
    assertEqual(#H.Store().groups, 1, "nothing cleared before the answer")
    m.StaticPopupDialogs[H.CLEAR_POPUP].OnAccept()
    assertEqual(#H.Store().groups, 0)
end)

test("feed: with test mode on, Clear history clears the samples and leaves the account's log", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()   -- the samples are drawn from the journal's gear (tests/test_test_mode.lua)
    local H = NS.History
    H.Store().groups = { { key = "enc:1@1", label = "Boss A", kind = "encounter", at = 1, drops = {} } }
    NS.SetTestMode(true)
    assertTrue(#H.Groups() > 0, "the samples are shown")
    local ctx = open(NS, m, "feed")
    find(tab(m, ctx, "Retention"), "Button", "Clear history"):__fire("OnClick")
    m.StaticPopupDialogs[H.CLEAR_POPUP].OnAccept()
    assertEqual(#H.Groups(), 0, "the samples cleared")
    NS.SetTestMode(false)
    assertEqual(#H.Store().groups, 1, "the account's log untouched")
end)

-- ── feedback-24: the switches alone, their knobs paired; the moved rows and their labels ────

test("pages: a switch is alone on its line and its knobs pair under it (Toast, Auto-ask)", function()
    local NS, _, m = T.enableAddon()
    local actx, drawn = open(NS, m, "alerts")
    assertEqual(actx.activeTab, "Toast")
    local show = find(drawn, "CheckBox", "Show a toast")
    assertEqual(#lineOf(drawn, show).children, 1, "Show a toast alone")
    local gain, dur = find(drawn, "Slider", "Least gain (item levels)"), find(drawn, "Slider", "Duration (seconds)")
    assertTrue(lineOf(drawn, gain) == lineOf(drawn, dur), "Least gain beside Duration")
    assertTrue(lineOf(drawn, find(drawn, "CheckBox", "Show in combat")) == lineOf(drawn, find(drawn, "CheckBox", "Play a sound")),
        "Show in combat beside Play a sound")
    local mctx = open(NS, m, "messages")
    drawn = tab(m, mctx, "Auto-ask")
    assertEqual(#lineOf(drawn, find(drawn, "CheckBox", "Ask automatically")).children, 1, "Ask automatically alone")
    assertTrue(lineOf(drawn, find(drawn, "Slider", "Delay (seconds)")) == lineOf(drawn, find(drawn, "Slider", "Least gain (item levels)")))
end)

test("pages: Messages opens on Sending, its per-send switches on one line, the transmog switch named apart from its template", function()
    local NS, _, m = T.enableAddon()
    local ctx, drawn = open(NS, m, "messages")
    assertEqual(ctx.activeTab, "Sending")
    -- red under: the pre-020 order, Offer transmog asks | Ask once, then Edit before sending | Announce
    -- channel (DRO-L08: the two per-send switches share a line)
    local once, edit = find(drawn, "CheckBox", "Ask once"), find(drawn, "CheckBox", "Edit before sending")
    local channel, transmog = find(drawn, "Dropdown", "Announce channel"), find(drawn, "CheckBox", "Offer transmog asks")
    assertTrue(once ~= nil and edit ~= nil and lineOf(drawn, once) == lineOf(drawn, edit), "Ask once | Edit before sending")
    assertTrue(channel ~= nil and transmog ~= nil and lineOf(drawn, channel) == lineOf(drawn, transmog),
        "Announce channel | Offer transmog asks")
    local order = {}
    for _, row in ipairs(NS.addon.Settings.RowsForPage("messages")) do
        if row.group == "Sending" then order[#order + 1] = row.path end
    end
    assertEqual(table.concat(order, ","), "messages.oneAsk,messages.editFirst,messages.announceChannel,messages.transmogAsk")
    assertTrue(find(drawn, "CheckBox", "Ask for transmog") == nil, "no checkbox shares the template's label")
end)

test("pages: Window's Columns note shows on Columns only; its Trade window mark and Starting view moved in", function()
    local NS, _, m = T.enableAddon()
    local ctx, drawn = open(NS, m, "window")
    assertEqual(ctx.activeTab, "Layout")
    assertTrue(find(drawn, "Dropdown", "Window layout") ~= nil, "the layout row, named apart from its tab")
    -- red under: the pre-020 Layout tab, one block with no subsections and the old run label
    -- (DRO-L06, DRO-L07): Mode holds the layout and its run override, Tables the two table knobs.
    local mode, inRuns = find(drawn, "Dropdown", "Window layout"), find(drawn, "CheckBox", "Compact view when it auto-opens in a run")
    local rowH, font = find(drawn, "Slider", "Row height"), find(drawn, "Slider", "Font size")
    assertTrue(inRuns ~= nil and lineOf(drawn, mode) == lineOf(drawn, inRuns), "Window layout | Compact view when it auto-opens in a run")
    assertTrue(rowH ~= nil and font ~= nil and lineOf(drawn, rowH) == lineOf(drawn, font), "Row height | Font size")
    assertEqual(NS.SchemaRuntime.FindRow("window.mode").subgroup, "Mode")
    assertEqual(NS.SchemaRuntime.FindRow("window.compactInRuns").subgroup, "Mode")
    assertEqual(NS.SchemaRuntime.FindRow("window.rowHeight").subgroup, "Tables")
    assertEqual(NS.SchemaRuntime.FindRow("window.fontSize").subgroup, "Tables")
    local heads = {}
    for _, w in ipairs(drawn) do if w.type == "Heading" then heads[#heads + 1] = w.labelText or w.text end end
    assertEqual(table.concat(heads, "|"), "Mode|Tables", "the two headings, in row order")
    assertTrue(findPrefix(drawn, "Label", "The full layout's Drops table") == nil, "no note on Layout")
    drawn = tab(m, ctx, "Columns")
    assertTrue(findPrefix(drawn, "Label", "The full layout's Drops table") ~= nil, "the note on Columns")
    assertTrue(find(drawn, "Slider", "Mark a trade window ending within (seconds)") ~= nil, "Trade › Timers' slider")
    drawn = tab(m, ctx, "Starting view")
    for _, label in ipairs({ "Interesting", "Likely tradeable", "Usable by me", "Upgrade for me" }) do
        assertTrue(find(drawn, "CheckBox", label) ~= nil, label)
    end
    -- red under: the pre-020 View tooltips, which never said what none ticked does (DRO-L15)
    for _, key in ipairs({ "interesting", "likely", "usable", "upgrade" }) do
        local tip = NS.SchemaRuntime.FindRow("feed.view." .. key).tooltip
        local tail = " With none ticked, a fresh tab lists every drop."
        assertEqual(tip:sub(-#tail), tail, key)
    end
    assertTrue(find(drawn, "Dropdown", "Content") ~= nil and find(drawn, "Dropdown", "Sort") ~= nil)
    assertEqual(NS.SchemaRuntime.FindRow("trade.warnAt").page, "window", "the path kept, the page moved")
    assertEqual(NS.SchemaRuntime.FindRow("feed.view.likely").page, "window")
end)

-- ── Defaults, page by page ──────────────────────────────────────────────────────────────────

test("pages: a page's Defaults resets that page's rows and no other page's", function()
    local NS, _, m = T.enableAddon()
    local Set = NS.SchemaRuntime.Set
    Set("feed.gearOnly", false)
    Set("trade.warnAt", 120)
    Set("situations.delve.track", true)
    Set("trade.rules.raid", "group")
    Set("autoOpen", false)
    Set("comparison.weights", { [62] = { ITEM_MOD_HASTE_RATING_SHORT = 2 } })
    local ctx = open(NS, m, "feed")
    ctx.panel.defaultsOnClick()
    assertEqual(NS.Setting("feed.gearOnly"), NS.C.PROFILE.feed.gearOnly)
    -- red under: the Situations rows left on a page of their own (item 020: Drops' Defaults owns them)
    assertEqual(NS.Setting("situations.delve.track"), NS.C.PROFILE.situations.delve.track, "the situations table reset")
    assertEqual(NS.Setting("trade.rules.raid"), NS.C.PROFILE.trade.rules.raid, "and its loot rules")
    assertEqual(NS.Setting("autoOpen"), NS.C.PROFILE.autoOpen, "and the global auto-open")
    assertEqual(NS.Setting("trade.warnAt"), 120, "Window's row untouched")
    local cctx = open(NS, m, "comparison")
    cctx.panel.defaultsOnClick()
    assertTrue(next(NS.Setting("comparison.weights")) == nil, "the weights map reset whole")
end)

test("pages: the Drops page's Defaults tooltip names the situations it now resets (DRO-L03)", function()
    local NS = T.enableAddon()
    local tip = NS.addon.Settings.Helpers.__panelFor("feed").panel.defaultsTooltip
    -- red under: the pre-020 tooltip, which left the situations out
    assertEqual(tip, "Reset the Drops page's settings (situations, quality, items and how long drops are kept) to their defaults.")
    assertTrue(NS.addon.Settings.Helpers.__panelFor("situations") == nil, "no Situations page")
end)

-- ── the editors' pure halves ────────────────────────────────────────────────────────────────

test("editors: a weight write is a fresh map; 0 removes the stat and an emptied spec", function()
    local E = T.newAddon().addon.Settings.Editors
    local stored = { [62] = { ITEM_MOD_HASTE_RATING_SHORT = 1 } }
    local out = E.WithWeight(stored, 62, "ITEM_MOD_CRIT_RATING_SHORT", 0.5)
    assertEqual(stored[62].ITEM_MOD_CRIT_RATING_SHORT, nil, "the stored map is not touched")
    assertEqual(out[62].ITEM_MOD_CRIT_RATING_SHORT, 0.5)
    assertEqual(E.Weight(out, 62, "ITEM_MOD_HASTE_RATING_SHORT"), 1)
    assertEqual(E.Weight(out, 63, "ITEM_MOD_HASTE_RATING_SHORT"), 0, "unset reads 0")
    out = E.WithWeight(E.WithWeight(out, 62, "ITEM_MOD_CRIT_RATING_SHORT", 0), 62, "ITEM_MOD_HASTE_RATING_SHORT", 0)
    assertTrue(out[62] == nil)
    assertTrue(E.WithWeight(nil, 70, "ITEM_MOD_STRENGTH_SHORT", 1)[70].ITEM_MOD_STRENGTH_SHORT == 1, "from no map")
end)

test("editors: a spec's stats are its primary stat, Stamina and the four secondaries", function()
    local NS = T.newAddon()
    local E = NS.addon.Settings.Editors
    local fury = E.StatsFor(72)
    assertEqual(fury[1], "ITEM_MOD_STRENGTH_SHORT")
    assertEqual(#fury, 6)
    local unknown = E.StatsFor(nil)
    assertEqual(#unknown, 8, "all three primaries for an unknown spec")
    assertEqual(E.StatLabel("ITEM_MOD_HASTE_RATING_SHORT", {}), "Haste")
    assertEqual(E.StatLabel("ITEM_MOD_HASTE_RATING_SHORT", { ITEM_MOD_HASTE_RATING_SHORT = "Tempo" }), "Tempo",
        "the client's own GlobalString first")
end)

test("editors: unwanted types are the class's weapons, then shields where a spec carries one", function()
    local NS = T.newAddon()
    local E, K = NS.addon.Settings.Editors, NS.Constants
    local keys = {}
    for _, c in ipairs(E.UndesiredChoices("PALADIN")) do keys[#keys + 1] = c.key end
    assertEqual(keys[#keys], NS.Evaluate.SubClassKey(K.ITEM_CLASS.ARMOR, K.ARMOR_SUBCLASS.SHIELD))
    local rogue = E.UndesiredChoices("ROGUE")
    assertEqual(#rogue, 5)
    for _, c in ipairs(rogue) do assertTrue(c.key:match("^" .. K.ITEM_CLASS.WEAPON .. ":") ~= nil, c.key) end
    assertEqual(#E.UndesiredChoices("NOPE"), 0)
end)

test("editors: an unwanted mark is a fresh map, and the last one cleared drops the spec", function()
    local E = T.newAddon().addon.Settings.Editors
    local stored = {}
    local out = E.WithUndesired(stored, 62, "2:15", true)
    assertTrue(next(stored) == nil, "the stored map is not touched")
    assertTrue(E.IsUndesired(out, 62, "2:15"))
    assertFalse(E.IsUndesired(out, 63, "2:15"))
    assertTrue(E.WithUndesired(out, 62, "2:15", false)[62] == nil)
end)

test("editors: the spec strip keeps the remembered spec, else yours, else the first", function()
    local NS = T.newAddon()
    local E = NS.addon.Settings.Editors
    local list = E.ClassSpecs("MAGE", function(id) return id == 63 and "Fire" or nil end)
    assertEqual(#list, 3)
    assertEqual(list[2].label, "Fire")
    assertEqual(list[1].label, "62", "an unnamed spec reads its id")
    assertEqual(E.PickSpec(list, 64, 63), 64)
    assertEqual(E.PickSpec(list, 250, 63), 63)
    assertEqual(E.PickSpec(list, nil, 250), 62)
    assertEqual(E.PickSpec({}, 62, 62), nil)
end)

test("editors: the counter label counts bytes and turns red past the limit", function()
    local E = T.newAddon().addon.Settings.Editors
    local label, over = E.CounterLabel("ask", "abc")
    assertTrue(label:find("3 / 255", 1, true) ~= nil and not over)
    label, over = E.CounterLabel("ask", string.rep("x", 256))
    assertTrue(over and label:find("|cffff4040256 / 255|r", 1, true) ~= nil, label)
end)

test("editors: the preview's drop is the newest that fits its template, an upgrade for you first", function()
    local E = T.newAddon().addon.Settings.Editors
    local me = { name = "Me", isSelf = true }
    local drops = {
        { looter = { name = "Old" }, me = { ilvlDelta = 9 } },
        { looter = { name = "New" }, me = { ilvlDelta = -3 } },
        { looter = me, candidates = {
            g1 = { name = "Bee", eval = { ilvlDelta = 4 } }, g2 = { name = "Ace", eval = { ilvlDelta = 4 } },
            g3 = { name = "Cee", eval = { ilvlDelta = -1 } } } },
    }
    local rec, who = E.PreviewSample("ask", drops)
    assertEqual(who.name, "Old", "an upgrade for you over a newer downgrade")
    assertTrue(rec == drops[1])
    local offerRec, offerTo = E.PreviewSample("offer", drops)
    assertTrue(offerRec == drops[3])
    assertEqual(offerTo.name, "Ace", "the candidate who gains most, ties by name")
    rec = E.PreviewSample("announce", drops)
    assertTrue(rec == drops[3])
    assertEqual(E.PreviewSample("ask", { drops[3] }), nil, "your own drop is no ask")
    local _, anyTo = E.PreviewSample("ask", { drops[2] })
    assertEqual(anyTo.name, "New", "with no upgrade, any drop of another's")
end)

test("editors: the preview's lines name who it goes to, the length and what is wrong", function()
    local E = T.newAddon().addon.Settings.Editors
    local lines = E.PreviewLines("ask", "Hi {player}, {item}? {bogus}", { player = "Seta", item = "[Crown]" }, "Seta")
    assertEqual(lines.header, "Preview: Ask, to Seta")
    assertEqual(lines.body, "To Seta: Hi Seta, [Crown]? {bogus}")
    assertTrue(lines.status:find("{bogus}", 1, true) ~= nil, lines.status)
    assertFalse(lines.tooLong)
    lines = E.PreviewLines("announce", string.rep("y", 300), {}, nil)
    assertEqual(lines.header, "Preview: Announce, to the group")
    assertTrue(lines.tooLong and lines.status:find("too long to send", 1, true) ~= nil)
end)

test("asks: TokenContext fills the tokens from a drop for who it goes to", function()
    local NS = T.newAddon()
    local rec = { link = "[Crown]", facts = { ilvl = 311, track = { name = "Hero" } },
        me = { ilvlDelta = 19 }, them = { ilvlDelta = -13 } }
    local ctx = NS.Asks.TokenContext("ask", rec, { name = "Seta" })
    assertEqual(ctx.player, "Seta")
    assertEqual(ctx.item, "[Crown]")
    assertEqual(ctx.ilvl, 311)
    assertEqual(ctx.track, "Hero")
    assertEqual(ctx.mygain, 19)
    assertEqual(ctx.gain, -13)
    assertEqual(NS.Asks.TokenContext("announce", nil, nil).player, nil, "no drop, no recipient")
end)
