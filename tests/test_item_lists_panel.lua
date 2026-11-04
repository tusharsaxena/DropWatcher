-- tests/test_item_lists_panel.lua — Drops › Item lists (issue #13, categories design spec §5.1;
-- settings/ListEditors.lua): the host tab after Items, its Always watch | Never watch secondary strip
-- and its healed `activeSubTab`, the LibKa0s IdList it draws for the list on screen (its entries,
-- candidates, onAdd and onRemove through NS.ItemLists, a refusal raised as its sentence, no repaint
-- of its own), and the Drops page's Defaults keeping both lists (plan #13, Q9). Built headless under
-- the kit's AceGUI recorder, as tests/test_settings_pages.lua builds the other pages.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local TAB = "Item lists"

-- Show the Drops page, then click its Item lists tab. Answers the page's ctx and every IdList spec
-- the renders drew, newest last (Helpers.IdList spied, then called through).
local function itemLists(NS)
    local H = NS.addon.Settings.Helpers
    local specs, idList = {}, H.IdList
    H.IdList = function(ctx, spec)
        specs[#specs + 1] = spec
        return idList(ctx, spec)
    end
    local ctx = H.__panelFor("feed")
    ctx.panel:Show()
    ctx.panel:__fire("OnShow")
    for _, b in ipairs(ctx.__tabLayout.buttons) do
        b:__fire("OnClick")
        if ctx.activeTab == TAB then break end
    end
    assertEqual(ctx.activeTab, TAB)
    return ctx, specs
end

local function ids(entries)
    local out = {}
    for i, e in ipairs(entries) do out[i] = e.id end
    return table.concat(out, ",")
end

test("item lists panel: the tab follows Items, with an Always watch | Never watch strip, Always watch first", function()
    local NS = T.enableAddon()
    local ctx, specs = itemLists(NS)
    assertEqual(#ctx.__subTabKids, 2)
    assertEqual(ctx.activeSubTab[TAB], "whitelist")
    assertEqual(specs[1].kind, "item"); assertEqual(specs[1].columns, 2); assertEqual(specs[1].removeStyle, "icon")
    assertTrue(specs[1].tooltip:find("shift-click", 1, true) ~= nil, "the box's tooltip names shift-clicking a link")
    assertTrue(specs[1].strings.nameHint ~= nil and specs[1].emptyText:find("(none)", 1, true) ~= nil)
    -- red under: the map rows declared before Items, or no host tab keyed by their group
    local order, buttons = {}, ctx.__tabLayout.buttons
    for i = 1, #buttons do
        buttons[i]:__fire("OnClick")
        order[i] = ctx.activeTab
    end
    assertEqual(table.concat(order, "|"), "Situations|Quality|Items|Item lists|Retention")
end)

test("item lists panel: a sub-tab click draws the other list, and a stale pointer heals to the first", function()
    local NS = T.enableAddon()
    NS.ItemLists.Add("blacklist", 400)
    local ctx, specs = itemLists(NS)
    ctx.__subTabKids[2]:__fire("OnClick")
    assertEqual(ctx.activeSubTab[TAB], "blacklist")
    assertEqual(ids(specs[#specs].entries()), "400", "Never watch's own entries")
    NS.addon.Settings.ListEditors.ItemListsTab(ctx)
    assertEqual(ctx.activeSubTab[TAB], "blacklist", "kept across a render")
    ctx.activeSubTab[TAB] = "otherlist"
    NS.addon.Settings.ListEditors.ItemListsTab(ctx)
    -- red under: the pointer trusted as it stands
    assertEqual(ctx.activeSubTab[TAB], "whitelist")
end)

test("item lists panel: the IdList's entries, candidates and writes go through NS.ItemLists", function()
    local NS, _, m = T.enableAddon()
    NS.ItemLists.Add("whitelist", 300)
    NS.ItemLists.Add("blacklist", 200)
    local _, specs = itemLists(NS)
    local spec = specs[#specs]
    assertEqual(ids(spec.entries()), "300")
    m.addItem("|cnIQ4:|Hitem:555::::::::90:::::|h[Ring]|h|r", { name = "Ring", quality = 4, ilvl = 600,
        equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, stats = {} })
    NS.LootFeed.Add("|cnIQ4:|Hitem:555::::::::90:::::|h[Ring]|h|r")
    -- both lists' IDs, then the live feed's items
    assertEqual(table.concat(spec.candidates(), ","), "300,200,555")
    local H, structural = NS.addon.Settings.Helpers, 0
    local refreshPanel, refreshAll = H.RefreshPanel, H.RefreshAllPanels
    H.RefreshPanel = function(...) structural = structural + 1; return refreshPanel(...) end
    H.RefreshAllPanels = function(...) structural = structural + 1; return refreshAll(...) end
    spec.onAdd(301)
    -- red under: the writer's seam write repainting the page under IdList (anti-pattern #39)
    assertEqual(structural, 0, "IdList asks for its own redraw once it is done")
    spec.onRemove(300)
    H.RefreshPanel, H.RefreshAllPanels = refreshPanel, refreshAll
    assertEqual(table.concat(NS.ItemLists.List("whitelist"), ","), "301")
end)

-- red under: onAdd swallowing the writer's refusal, so IdList clears the box and says nothing
test("item lists panel: a refused add is raised as its sentence, and nothing is written", function()
    local NS = T.enableAddon()
    NS.ItemLists.Add("blacklist", 200)
    local _, specs = itemLists(NS)
    local ok, err = pcall(specs[#specs].onAdd, 200)
    assertFalse(ok); assertEqual(err, "That item is on Never watch: remove it there first.")
    ok, err = pcall(specs[#specs].onRemove, 999)
    assertFalse(ok); assertEqual(err, "That item is not on Always watch.")
    assertEqual(#NS.ItemLists.List("whitelist"), 0)
end)

-- red under: the two map rows left out of resetExempt (the page's Defaults empties both lists)
test("item lists panel: the Drops page's Defaults keeps both lists and resets the rest", function()
    local NS = T.enableAddon()
    NS.ItemLists.Add("whitelist", 300)
    NS.ItemLists.Add("blacklist", 200)
    NS.SchemaRuntime.Set("feed.categories.mount", false)
    local ctx = itemLists(NS)
    ctx.panel.defaultsOnClick()
    assertEqual(NS.Setting("feed.categories.mount"), true, "the item kinds reset")
    assertEqual(table.concat(NS.ItemLists.List("whitelist"), ","), "300")
    assertEqual(table.concat(NS.ItemLists.List("blacklist"), ","), "200")
    assertTrue(ctx.panel.defaultsTooltip:find("The item lists are kept.", 1, true) ~= nil)
end)
