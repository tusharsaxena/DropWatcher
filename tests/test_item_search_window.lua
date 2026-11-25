-- tests/test_item_search_window.lua — the Item Search window (DropWatcher#17, Item Search spec §4.5;
-- Item Search feedback spec §5, ISF-DW-05 and ISF-DW-06): its pure search half
-- (modules/ItemSearchView.lua) and its frame edge (modules/ItemSearchWindow.lua,
-- modules/ItemSearchGrid.lua): the ways in (the main window's magnifier, `/dw search`), the
-- debounced search (an id without ForeverDB, a name through SearchItems), the frame (title, footer,
-- no lock, the resize and the saved size), the matches (their header, sort, selection, hover and
-- shift-click), the item header's shift-click, the tabs and their tables, the section headers'
-- marks and every tooltip, and the waypoint pins. The tabs' pure rows and columns are
-- tests/test_item_search_tabs.lua's. Every ForeverDB value is the kit fake's invented data
-- (tests/_kit/mock_foreverdb.lua); the Crafting rows read the shipped recipe table (Blizzard client
-- DB2 data). The map names and spots below are invented too.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is absent" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's absent case; the Forever cases cover WoW Forever" or nil

local LINEN = 2589   -- Linen Cloth: a First Aid and Tailoring reagent in the shipped table

-- The client's map names and waypoint API, invented: `waypoints` records each user waypoint.
local function installMap(mm, opts)
    opts = opts or {}
    mm.waypoints = {}
    mm.C_Map = {
        GetMapInfo = function(id) return ({ [IDS.mapA] = { name = "Fixture Vale" }, [IDS.mapB] = { name = "Fixture Hills" } })[id] end,
    }
    if opts.waypoint ~= false then
        mm.C_Map.CanSetUserWaypointOnMap = function() return true end
        mm.C_Map.SetUserWaypoint = function(p) mm.waypoints[#mm.waypoints + 1] = p end
        mm.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
    end
end

-- The addon enabled with the ForeverDB fake; `load` runs the 5 s login load (default on).
local function enabled(opts)
    opts = opts or {}
    local fake
    local NS, _, m = T.enableAddon{ mock = function(mm)
        fake = FDB.install(mm, { preset = opts.preset or "present" })
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        installMap(mm, opts)
        if opts.setup then opts.setup(mm) end
    end }
    if opts.load ~= false then
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
    end
    return NS, m, fake
end

-- ── the pure rows ───────────────────────────────────────────────────────────────────────────

test("item search view: the box's text is an id (all digits), a name (two letters or more), short or empty", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    assertEqual(V.Classify("  990101 ").kind, "id"); assertEqual(V.Classify("990101").id, 990101)
    assertEqual(V.Classify("bl").kind, "name"); assertEqual(V.Classify(" blade ").query, "blade")
    assertEqual(V.Classify("b").kind, "short")
    assertEqual(V.Classify("").kind, "none"); assertEqual(V.Classify(nil).kind, "none")
    -- red under: "0" read as an item id
    assertEqual(V.Classify("0").kind, "none")
end)

test("item search view: an id is looked up directly, without ForeverDB from the client's cache, else a bare row", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local client = function(id) return id == LINEN and { id = id, name = "Linen Cloth", quality = 1 } or nil end
    local rows, note = V.Matches(tostring(LINEN), { state = "missing", clientItem = client })
    -- red under: an id search that needs ForeverDB (spec §4.5: it works without it)
    assertEqual(#rows, 1); assertEqual(rows[1].id, LINEN); assertEqual(rows[1].name, "Linen Cloth"); assertNil(note)
    rows = V.Matches("123456", { state = "missing", clientItem = client })
    assertEqual(rows[1].id, 123456, "an item the client has not cached still has a row")
    assertNil(rows[1].name)
end)

test("item search view: a name searches ForeverDB only once it is loaded; before it says loading, without it the spec line", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local asked = 0
    local db = { SearchItems = function(q, limit)
        asked = asked + 1
        assertEqual(q, "blade"); assertEqual(limit, 50)
        return { { id = 1, name = "Bladed", quality = 3 }, { id = 2, name = "Blade" } }
    end }
    local rows, note = V.Matches("blade", { state = "loading", db = db, limit = 50 })
    -- red under: a name search that reads (so loads) ForeverDB before its load (spec §2)
    assertEqual(#rows, 0); assertEqual(note, "loading"); assertEqual(asked, 0)
    rows, note = V.Matches("blade", { state = "missing", db = db, limit = 50 })
    assertEqual(#rows, 0); assertEqual(note, "missing"); assertEqual(asked, 0)
    assertEqual(V.NoteText("missing"), "ForeverDB not installed: drop sources, quests and name search are unavailable")
    assertEqual(V.NoteText("loading"), "ForeverDB: loading…")
    rows, note = V.Matches("blade", { state = "loaded", db = db, limit = 50 })
    assertEqual(asked, 1); assertNil(note)
    assertEqual(rows[1].id, 1); assertEqual(rows[2].name, "Blade")
    db.SearchItems = function() return {} end
    assertEqual(select(2, V.Matches("zzz", { state = "loaded", db = db })), "none")
end)

test("item search view: a source's map is the one with the most spots (the lower id on a tie), its first spot the pin", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local s = V.SpotOf({ [20] = { { x = 0.1, y = 0.2 } }, [10] = { { x = 0.3, y = 0.4 }, { x = 0.5, y = 0.6 } } })
    assertEqual(s.map, 10); assertEqual(s.x, 0.3); assertEqual(s.y, 0.4)
    s = V.SpotOf({ [20] = { { x = 0.1, y = 0.2 } }, [10] = { { x = 0.3, y = 0.4 } } })
    assertEqual(s.map, 10, "a tie: the lower id")
    assertNil(V.SpotOf(nil)); assertNil(V.SpotOf({}))
end)

test("item search view: the item line names quality, class, subclass, level and id; the footer names ForeverDB's state", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local line = V.ItemLine({ id = 7, quality = 2, classID = 2, subclassID = 7, requiredLevel = 10 }, {
        qualityName = function(q) return q == 2 and "Uncommon" or nil end,
        classNames = function() return "Weapon", "One-Handed Swords" end })
    assertEqual(line, "Uncommon · Weapon · One-Handed Swords · Requires level 10 · id 7")
    assertEqual(V.ItemLine({ id = 7 }), "id 7")
    assertEqual(V.FooterText("loaded", "2099.01.01.1"), "ForeverDB 2099.01.01.1 · loaded")
    assertEqual(V.FooterText("loading", "2099.01.01.1"), "ForeverDB 2099.01.01.1 · loading…")
    assertEqual(V.FooterText("missing"), "ForeverDB · not installed")
    assertNil(V.Notice("loaded"))
    assertEqual(V.Notice("missing"), "ForeverDB not installed: drop sources, quests and name search are unavailable")
end)

test("item search view: the matches sort by Best match (SearchItems' order), Name or Item id", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local rows = { { id = 30, name = "beta" }, { id = 10 }, { id = 20, name = "Alpha" } }
    local function ids(list)
        local out = {}
        for i, r in ipairs(list) do out[i] = r.id end
        return table.concat(out, ",")
    end
    assertEqual(ids(V.SortMatches(rows, "best")), "30,10,20", "Best match keeps the database's order")
    -- red under: a case-sensitive sort ("Alpha" after "beta" only by byte) or an unnamed row first
    assertEqual(ids(V.SortMatches(rows, "name")), "20,30,10")
    assertEqual(ids(V.SortMatches(rows, "id")), "10,20,30")
    assertEqual(ids(rows), "30,10,20", "the input is never sorted in place")
    assertEqual(V.LevelText(33, 35), "33–35", "an en dash between the levels (feedback spec §5.4)")
end)

-- ── the window: Retail ──────────────────────────────────────────────────────────────────────

test("item search window: on Retail there is no window, no magnifier and no `search` verb", function()
    local NS = enabled()
    -- red under: a window or a header mark on Retail (spec §1: absent)
    assertFalse(NS.ItemSearchWindow.Open())
    assertNil(NS.ItemSearchWindow.Frame())
    NS.ShowWindow()
    assertNil(NS.Window.Frame().searchButton)
    for _, c in ipairs(NS.COMMANDS) do assertTrue(c[1] ~= "search", "no search verb") end
end, RETAIL_ONLY)

-- ── the window: ways in ─────────────────────────────────────────────────────────────────────

test("item search window: the main window's magnifier opens it, with the search box focused, and closes it", function()
    local NS, m = enabled()
    NS.ShowWindow()
    local b = NS.Window.Frame().searchButton
    assertTrue(b ~= nil, "the magnifier")
    -- red under: no tooltip on the mark (standalone-windows: every title-bar control has one)
    assertEqual(NS.Window.TooltipOf(b)[1], "Item Search")
    local focused = 0
    local real = NS.ItemSearchWindow.Open
    NS.ItemSearchWindow.Open = function(...)
        local ok = real(...)
        local box = NS.ItemSearchWindow.Frame().searchBox
        if rawget(box, "dwFocusSpy") == nil then
            box.dwFocusSpy = true
            box.SetFocus = function() focused = focused + 1 end
        end
        return ok
    end
    b:__fire("OnClick", "LeftButton")
    assertTrue(NS.ItemSearchWindow.IsShown())
    b:__fire("OnClick", "LeftButton")
    assertFalse(NS.ItemSearchWindow.IsShown(), "a second click closes it")
    b:__fire("OnClick", "LeftButton")
    assertEqual(focused, 1, "the box is focused on an empty open")
    assertTrue(m.UISpecialFrames[#m.UISpecialFrames] == "DropWatcherItemSearchFrame", "Escape closes it")
end, FOREVER_ONLY)

test("item search window: `/dw search <id>` shows the item, `/dw search <name>` lists the matches, bare opens it", function()
    local NS = enabled()
    local at
    for i, c in ipairs(NS.COMMANDS) do if c[1] == "search" then at = i end end
    assertTrue(at ~= nil, "the verb is in NS.COMMANDS (and the help)")
    NS.addon:OnSlashCommand("search " .. IDS.blade)
    assertTrue(NS.ItemSearchWindow.IsShown()); assertEqual(NS.ItemSearchWindow.ShownItem(), IDS.blade)
    NS.addon:OnSlashCommand("search blade")
    local list = NS.ItemSearchWindow.Matches()
    -- red under: a slash search that waits for the debounce, or one that skips SearchItems
    assertEqual(#list.rows, 3)
    assertEqual(list.rows[1].id, IDS.shard, "a prefix match first")
    NS.ItemSearchWindow.Close()
    NS.addon:OnSlashCommand("search")
    assertTrue(NS.ItemSearchWindow.IsShown())
end, FOREVER_ONLY)

-- ── the window: the search ──────────────────────────────────────────────────────────────────

test("item search window: the search runs 0.25 s after the last key, and Enter shows the first match", function()
    local NS, m = enabled()
    local W = NS.ItemSearchWindow
    W.Open()
    W.SetQuery("bla")
    m.advance(0.2)
    W.SetQuery("blade")
    m.advance(0.2)
    -- red under: no debounce (a search per key)
    assertEqual(#W.Matches().rows, 0, "still typing")
    m.advance(0.1)
    assertEqual(#W.Matches().rows, 3, "0.25 s after the last key")
    W.SetQuery("fixture blade")
    W.ShowFirst()
    assertEqual(W.ShownItem(), IDS.blade, "Enter: the first match at once")
end, FOREVER_ONLY)

test("item search window: without ForeverDB an id still shows the item, with Crafting and the spec §1 line", function()
    local NS, m = enabled({ preset = "missing" })
    local W = NS.ItemSearchWindow
    W.Open()
    W.SetQuery(tostring(LINEN))
    m.advance(0.25)
    assertEqual(W.Matches().rows[1].id, LINEN)
    W.SetQuery("linen")
    m.advance(0.25)
    assertEqual(W.Matches().note, "missing", "a name needs ForeverDB")
    assertTrue(W.ShowItem(LINEN))
    local f = W.Frame()
    -- red under: a notice-less pane without ForeverDB, or no Crafting from the shipped table
    assertEqual(f.notice:GetText(), "ForeverDB not installed: drop sources, quests and name search are unavailable")
    assertEqual(NS.ItemSearchWindow.ShownTab(), "crafting", "the one tab: Crafting")
    assertEqual(f.foot.left:GetText(), "ForeverDB · not installed")
end, FOREVER_ONLY)

test("item search window: ForeverDB installed but not loading: the matches note agrees with the notice", function()
    for _, preset in ipairs({ "loadfails", "reshaped" }) do
        local NS, m = enabled({ preset = preset })
        local W = NS.ItemSearchWindow
        W.Open()
        W.SetQuery("linen")
        m.advance(0.25)
        -- red under: an installed ForeverDB called "not installed" by the matches list
        assertEqual(W.Matches().note, "failed", preset)
        assertEqual(NS.ItemSearchView.NoteText(W.Matches().note),
            "ForeverDB did not load: drop sources, quests and name search are unavailable", preset)
        assertTrue(W.ShowItem(LINEN))
        assertEqual(W.Frame().notice:GetText(), NS.ItemSearchView.NoteText(W.Matches().note), preset)
    end
end, FOREVER_ONLY)

test("item search window: before the load a name search says loading and reads nothing", function()
    local NS, m, fake = enabled({ load = false })
    local W = NS.ItemSearchWindow
    W.Open()
    W.SetQuery("blade")
    m.advance(0.25)
    -- red under: a window search that loads ForeverDB (spec §2: the reads never load)
    assertEqual(W.Matches().note, "loading"); assertEqual(fake.loads, 0)
    assertEqual(W.Frame().foot.left:GetText(), "ForeverDB 2099.01.01.1 · loading…")
end, FOREVER_ONLY)

-- ── the window: the detail pane ─────────────────────────────────────────────────────────────

-- ── the window: the frame (feedback spec §5.1) ──────────────────────────────────────────────

test("item search window: the title says Drop Watcher, the footer ForeverDB alone, and there is no lock", function()
    local NS, m = enabled()
    m.bindKey("ALT-CTRL-D", "CLICK DropWatcherItemSearch:LeftButton")
    local W = NS.ItemSearchWindow
    W.Open()
    local f = W.Frame()
    -- red under: the bare "Item Search" title (W1)
    assertEqual(f.title:GetText(), "Drop Watcher · Item Search")
    assertEqual(f.foot.left:GetText(), "ForeverDB 2099.01.01.1 · loaded")
    -- red under: the key hint in the footer (W2)
    assertEqual(f.foot.right:GetText(), "")
    -- red under: the lock mark and its code (W13)
    assertNil(rawget(f, "lockButton")); assertNil(W.PaintLock); assertNil(W.LinkInChat); assertNil(W.Recent)
    local moved = 0
    f.StartMoving = function() moved = moved + 1 end
    NS.SetLocked(true)
    f.titleBar:__fire("OnDragStart")
    assertEqual(moved, 1, "always movable by its title bar, the main window's lock or not")
end, FOREVER_ONLY)

test("item search window: it opens at 980 x 600, resizes from the corner down to 760 x 440, and keeps its size", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.Open()
    local f = W.Frame()
    -- red under: a fixed window with no grip (W14)
    assertTrue(f.resizeGrip ~= nil, "a resize grip")
    assertTrue(f:IsResizable())
    local minW, minH = f:GetResizeBounds()
    assertEqual(minW, 760); assertEqual(minH, 440)
    assertEqual(f:GetWidth(), 980); assertEqual(f:GetHeight(), 600)
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 120, 640)
    f:SetSize(1200, 700)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    local g = NS.addon.db.profile.itemSearch.window
    assertEqual(g.size[1], 1200); assertEqual(g.size[2], 700)
    assertEqual(table.concat(g.point, ","), "TOPLEFT,BOTTOMLEFT,120,640", "the point is saved with the size")
    f:SetSize(500, 300)
    W.ApplySettings()
    assertEqual(f:GetWidth(), 1200, "the saved size comes back")
end, FOREVER_ONLY)

test("item search window: a wider window gives the tables' flex columns the room", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local narrow = f.grid.layout.source.w
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f:SetSize(1400, 700)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    -- red under: fixed columns that never use the room (W8)
    assertTrue(f.grid.layout.source.w > narrow, "the Source column grew")
    assertEqual(f.grid.layout.chance.w, 150, "a fixed column keeps its width")
end, FOREVER_ONLY)

test("item search window: every text takes the main window's table font and row height", function()
    local NS = enabled()
    NS.SchemaRuntime.Set("window.rowHeight", 24)
    local W = NS.ItemSearchWindow
    W.SlashSearch("blade")
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local row = W.TableRows()[1]
    -- red under: the window's own 20 px comfortable rows (W3)
    assertEqual(row:GetHeight(), 24)
    assertTrue(row.cells[1].text.dwTableText, "a cell is a table text (NS.WindowRows.ApplyRowFont)")
    assertEqual(W.MatchRows()[1]:GetHeight(), 24, "the matches too")
    assertTrue(W.MatchRows()[1].cells.name.text.dwTableText)
    -- red under: GameFontNormalLarge on the header's name (it is the detail card's item title)
    assertEqual(f.name.__template, "GameFontNormal")
end, FOREVER_ONLY)

test("item search window: recent searches are gone, and step 17 deletes what was saved", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    -- red under: the list (W4)
    assertNil(rawget(W.Frame(), "recentHost")); assertNil(NS.ItemSearchView.PushRecent)
    local sv = { global = { itemSearch = { recent = { 1, 2 } } }, profiles = {
        Default = { itemSearch = { window = { recent = false, density = "compact", fontSize = 14, columns = false, pins = false } } },
    } }
    NS.RetireItemSearchRows(sv)
    assertNil(sv.global.itemSearch, "the account-wide list")
    local w = sv.profiles.Default.itemSearch.window
    assertNil(w.recent); assertNil(w.density); assertNil(w.fontSize); assertNil(w.columns)
    assertFalse(w.pins, "a kept row keeps its value")
    NS.RetireItemSearchRows(sv)   -- idempotent
    assertTrue(NS.SCHEMA_VERSION >= 17)
end, FOREVER_ONLY)

-- ── the window: the matches (feedback spec §5.2) ────────────────────────────────────────────

test("item search window: the matches' header counts them and sorts them; Clear's label is centered", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.SlashSearch("blade")
    local f = W.Frame()
    -- red under: a bare "Matches" heading with no count (W10)
    assertEqual(f.matchHead.title:GetText(), "Matches"); assertEqual(f.matchHead.count:GetText(), "· 3")
    assertTrue(f.matchHead.marks.sort:IsShown())
    assertEqual(NS.Window.TooltipOf(f.matchHead.marks.sort)[1], "Sort the matches")
    W.SortMatches("id")
    assertEqual(W.MatchRows()[1].itemID, IDS.blade, "by id: the blade's is the lowest")
    W.SortMatches("name")
    assertEqual(W.MatchRows()[1].itemID, IDS.shard, "Bladed Fixture Shard first by name")
    -- red under: Clear's label nudged right of an empty mark slot (W6)
    local pt = f.clearButton.label.__points[1]
    assertEqual(pt[1], "CENTER"); assertEqual(pt[4], 0); assertFalse(f.clearButton.art:IsShown())
    assertEqual(NS.Window.TooltipOf(f.clearButton)[1], "Clear")
end, FOREVER_ONLY)

test("item search window: the selected match wears the selection look; hover is its tooltip; shift-click links it", function()
    local link = "|cff1eff00|Hitem:" .. IDS.blade .. "::|h[Fixture Blade]|h|r"
    local NS, m = enabled({ setup = function(mm)
        local real = mm.C_Item.GetItemInfo
        mm.C_Item.GetItemInfo = function(id)
            if id == IDS.blade then return "Fixture Blade", link, 2, 15, 10, "", "", 1, "", 9990001, 0, 2, 7 end
            return real(id)
        end
    end })
    local W = NS.ItemSearchWindow
    W.SlashSearch("blade")
    W.ShowItem(IDS.blade)
    local selected, others = nil, 0
    for _, row in ipairs(W.MatchRows()) do
        if row.itemID == IDS.blade then selected = row elseif not row.selected:IsShown() then others = others + 1 end
    end
    -- red under: no mark on the item the right pane shows (W5)
    assertTrue(selected ~= nil and selected.selected:IsShown() and selected.edge:IsShown())
    assertEqual(others, 2, "the other matches are not selected")
    selected:__fire("OnEnter")
    assertEqual(m.tooltipLinks[#m.tooltipLinks], link, "the item's game tooltip")
    m.shift = true
    selected:__fire("OnClick", "LeftButton")
    -- red under: a shift-click that opens the item instead of linking it (W7)
    assertEqual(m.chatLinks[#m.chatLinks], link)
    m.shift = false
end, FOREVER_ONLY)

test("item search window: the header's icon and name show the item's tooltip and shift-click link it", function()
    local link = "|cff1eff00|Hitem:" .. IDS.blade .. "::|h[Fixture Blade]|h|r"
    local NS, m = enabled({ setup = function(mm)
        local real = mm.C_Item.GetItemInfo
        mm.C_Item.GetItemInfo = function(id)
            if id == IDS.blade then return "Fixture Blade", link, 2, 15, 10, "", "", 1, "", 9990001, 0, 2, 7 end
            return real(id)
        end
    end })
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: the Link in chat button (W7)
    assertNil(rawget(f, "linkButton"))
    assertEqual(f.name:GetText(), "Fixture Blade")
    f.nameButton:__fire("OnEnter")
    assertEqual(m.tooltipLinks[#m.tooltipLinks], link)
    m.shift = true
    f.icon:__fire("OnClick", "LeftButton")
    f.nameButton:__fire("OnClick", "LeftButton")
    assertEqual(#m.chatLinks, 2); assertEqual(m.chatLinks[2], link)
    m.shift = false
    f.icon:__fire("OnClick", "LeftButton")
    assertEqual(#m.chatLinks, 2, "a plain click links nothing")
    W.ShowItem(IDS.pebble)
    -- red under: an empty tab strip for an item ForeverDB knows nothing about (spec §5.3)
    assertFalse(f.tabStrip:IsShown()); assertTrue(f.noFacts:IsShown())
    m.shift = true
    f.icon:__fire("OnClick", "LeftButton")
    assertTrue(m.prints[#m.prints]:find("That item is still loading", 1, true) ~= nil, "no client link yet")
    m.shift = false
end, FOREVER_ONLY)

-- ── the window: the tabs and tables (feedback spec §5.3 to §5.6) ────────────────────────────

local function tabLabels(f)
    local out = {}
    for _, key in ipairs({ "drops", "vendors", "quests", "crafting", "skinned" }) do
        if f.tabs[key]:IsShown() then out[#out + 1] = f.tabs[key].label:GetText() end
    end
    return table.concat(out, ",")
end

test("item search window: the blade has a tab per section with rows, its count in the label, and remembers the pick", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: a tab for a section with no rows, or the old stacked sections (W8)
    assertEqual(tabLabels(f), "Drops from 4,Sold by 2,Quests 1")
    assertEqual(W.ShownTab(), "drops", "the first tab")
    assertEqual(NS.Window.TooltipOf(f.tabs.drops)[1], "Drops from")
    f.tabs.quests:__fire("OnClick", "LeftButton")
    assertEqual(W.ShownTab(), "quests")
    assertEqual(W.TableRows()[1].cells[2].text:GetText(), "Fixture Errand", "the reward row, with its Role")
    W.ShowItem(IDS.leather)
    -- red under: the tab picked last forgotten for the next item that has it
    assertEqual(W.ShownTab(), "quests")
    assertEqual(NS.addon.db.profile.itemSearch.window.tab, "quests")
    W.ShowItem(IDS.blade)
    f.tabs.vendors:__fire("OnClick", "LeftButton")
    W.ShowItem(IDS.leather)
    assertEqual(W.ShownTab(), "quests", "an item without the picked tab shows its first")
end, FOREVER_ONLY)

test("item search window: the section header counts the rows, names the sort and shows Reset only off the default", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local h = W.Frame().section
    assertEqual(h.title:GetText(), "Drops from"); assertEqual(h.count:GetText(), "· 4 sources")
    assertEqual(h.note:GetText(), "sorted: Best for you")
    -- red under: a Reset with nothing to reset (spec §5.5)
    assertFalse(h.marks.reset:IsShown()); assertTrue(h.marks.filter:IsShown()); assertTrue(h.marks.sort:IsShown())
    assertFalse(h.marks.filter.dwBadge == true, "no filter narrows: no badge")
    for _, key in ipairs({ "filter", "sort" }) do
        assertTrue(#NS.Window.TooltipOf(h.marks[key]) >= 2, key .. " has a tooltip")
    end
    W.SetFilter("drops", "npc", false)
    assertEqual(h.count:GetText(), "· 2 of 4 sources", "the creatures went")
    assertTrue(h.marks.filter.dwBadge, "a narrowing filter fills the funnel")
    assertTrue(h.marks.reset:IsShown())
    assertEqual(NS.Window.TooltipOf(h.marks.reset)[1], "Reset")
    h.marks.reset:__fire("OnClick", "LeftButton")
    assertEqual(h.count:GetText(), "· 4 sources")
    assertFalse(h.marks.reset:IsShown())
end, FOREVER_ONLY)

test("item search window: a column's title sorts the table, and a second click flips it", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local g = W.Frame().grid
    local level
    for _, b in ipairs(g.labels) do if b.key == "level" then level = b end end
    assertTrue(level ~= nil, "the Level label")
    assertTrue(#NS.Window.TooltipOf(level) >= 2, "a column label has a tooltip")
    level:__fire("OnClick", "LeftButton")
    assertEqual(W.ViewState("drops").sort.col, "level"); assertFalse(W.ViewState("drops").sort.desc)
    assertEqual(W.TableRows()[1].cells[1].text:GetText(), "Fixture Kobold", "level 5 first")
    level:__fire("OnClick", "LeftButton")
    -- red under: a second click that does nothing
    assertTrue(W.ViewState("drops").sort.desc)
    assertEqual(W.TableRows()[1].cells[1].text:GetText(), "Fixture Gnoll", "level 10 first")
    assertTrue(level.arrow:IsShown(), "the arrow shows the sort")
    assertEqual(W.Frame().section.note:GetText(), "sorted: Level, high to low")
    -- round 3 spec §4.1, item 11: LootHistory's solid triangles, sort-down high to low, sort-up low to high
    assertTrue(level.arrow:GetTexture():find("sort-down", 1, true) ~= nil, "high to low: sort-down")
    assertEqual(level.arrow:GetAlpha(), 1, "the sort in force: full alpha")
    level:__fire("OnClick", "LeftButton")
    assertTrue(level.arrow:GetTexture():find("sort-up", 1, true) ~= nil, "low to high: sort-up")
end, FOREVER_ONLY)

test("item search window: a column title lights under the pointer and shows the triangle its click would give", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local g = W.Frame().grid
    local by = {}
    for _, b in ipairs(g.labels) do if b:IsShown() and b.key then by[b.key] = b end end
    local level, chance = by.level, by.chance
    assertTrue(level ~= nil and chance ~= nil, "the Level and Chance labels")
    local function same(fs, token)
        local r, gg, b = fs:GetTextColor()
        local er, eg, eb = NS.SkinColor(token)
        return math.abs(r - er) < 1e-6 and math.abs(gg - eg) < 1e-6 and math.abs(b - eb) < 1e-6
    end
    assertTrue(same(level.text, "list.header.text"), "at rest: the header's text")
    assertFalse(level.arrow:IsShown(), "at rest and not the sort: no triangle")
    level:__fire("OnEnter")
    -- red under: a header that does not look clickable (round 3 item 5)
    assertTrue(same(level.text, "text.link"), "hovered: the marks' hot tone")
    assertTrue(level.arrow:IsShown(), "hovered: the next sort's triangle")
    assertEqual(level.arrow:GetAlpha(), NS.ItemSearchGrid.ARROW_HINT_ALPHA, "faint")
    assertTrue(level.arrow:GetTexture():find("sort-up", 1, true) ~= nil, "Level's first click sorts low to high")
    local tip = NS.Window.TooltipOf(level)
    assertEqual(tip[#tip]:find("Click: sort by Level; click again to reverse", 1, true) ~= nil, true, "the hint names the column")
    level:__fire("OnLeave")
    assertTrue(same(level.text, "list.header.text")); assertFalse(level.arrow:IsShown(), "left: no triangle")
    chance:__fire("OnEnter")
    assertTrue(chance.arrow:GetTexture():find("sort-down", 1, true) ~= nil, "Chance's first click sorts high to low")
    chance:__fire("OnLeave")
    -- the untitled columns (the pin) get no label at all, and so no hover
    for _, b in ipairs(g.labels) do
        if b:IsShown() then assertTrue(b.key ~= nil, "every shown label sorts") end
    end
end, FOREVER_ONLY)

test("item search window: every row has a tooltip under the Ka0s rules, a stripe on every other one and the hover wash", function()
    local NS, m = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local rows = W.TableRows()
    assertEqual(#rows, 5, "the gnoll, the crate, the coffer, the kobold, then the World drop row")
    assertTrue(rows[5].dwTip.title == "World drop", "the World drop row stays last")
    for i, row in ipairs(rows) do
        assertTrue(row.tipRow, "the hover wash (NS.WindowRows)")
        assertEqual(row.stripe:IsShown(), i % 2 == 0, "row " .. i .. "'s stripe")
        local tip = row.dwTip
        if tip.item then
            row:__fire("OnEnter")
            assertTrue(m.tooltipLinks[#m.tooltipLinks]:find("item:" .. tip.item, 1, true) ~= nil, "a container: its game tooltip")
        else
            local lines = NS.Window.TooltipOf(row)
            -- red under: a row with no tooltip (W9)
            assertTrue(#lines >= 2, "row " .. i .. ": a title and its rows")
        end
    end
    local gnoll
    for _, row in ipairs(rows) do if row.dwTip.title == "Fixture Gnoll" then gnoll = row end end
    local lines = NS.Window.TooltipOf(gnoll)
    assertEqual(lines[1], "Fixture Gnoll")
    local text = table.concat(lines, "\n")
    assertTrue(text:find("Elite, level 10–12", 1, true) ~= nil, "the type and level")
    assertTrue(text:find("Fixture Vale (2 spots)", 1, true) ~= nil, "every zone with its spot count")
    assertTrue(text:find("Click the pin: set a waypoint", 1, true) ~= nil, "a dim hint line last")
end, FOREVER_ONLY)

test("item search window: Linen's Crafting tab: the glyphs, the My professions chip and the filtered count", function()
    local NS = enabled({ setup = function(mm)
        local lines = { { name = "First Aid", rank = 40, skillID = 129 } }
        mm.C_SkillInfo = { GetNumSkillLines = function() return #lines end, GetSkillLineInfo = function(i) return lines[i] end }
    end })
    local W = NS.ItemSearchWindow
    W.ShowItem(LINEN)
    local f = W.Frame()
    assertEqual(W.ShownTab(), "crafting")
    local label = f.tabs.crafting.label:GetText()
    -- red under: the whole count alone while only First Aid shows (spec §4)
    assertTrue(label:find("^Crafting %d+ ") ~= nil and label:find("/ %d+") ~= nil, label)
    assertTrue(f.section.chip:IsShown()); assertEqual(f.section.chip.label:GetText(), "My professions")
    for _, row in ipairs(W.TableRows()) do
        assertTrue(row.cells[3].text:GetText() == "First Aid", "only First Aid's recipes")
        assertTrue(row.cells[1].text:GetText() ~= "", "a glyph")
        -- round 3 spec §4.1: the tooltip's glyph at its explicit size, centered in its column
        assertTrue(row.cells[1].text:GetText():find(":14:14:", 1, true) ~= nil, "the glyph at GLYPH_SIZE, as in the tooltip")
        assertEqual(row.cells[1].text:GetJustifyH(), "CENTER", "the glyph column centered")
    end
    assertEqual(f.grid.layout.glyph.x, NS.ItemSearchTabs.INSET, "the first column inset off the table's edge")
    local shown = #W.TableRows()
    f.section.chip:__fire("OnClick", "LeftButton")
    assertEqual(f.section.chip.label:GetText(), "All professions")
    assertTrue(#W.TableRows() > shown, "every profession's recipes")
    assertEqual(NS.Window.TooltipOf(f.section.chip)[1], "All professions")
    assertFalse(NS.addon.db.profile.itemSearch.myProfessionsOnly == false, "the chip is not saved")
end, FOREVER_ONLY)

test("item search window: the Crafting tab's filter follows Only professions you know when the setting moves", function()
    local NS = enabled({ setup = function(mm)
        local lines = { { name = "First Aid", rank = 40, skillID = 129 } }
        mm.C_SkillInfo = { GetNumSkillLines = function() return #lines end, GetSkillLineInfo = function(i) return lines[i] end }
    end })
    local W, TABS = NS.ItemSearchWindow, NS.ItemSearchTabs
    W.ShowItem(LINEN)
    local f = W.Frame()
    assertEqual(f.section.chip.label:GetText(), "My professions")
    NS.SchemaRuntime.Set("itemSearch.myProfessionsOnly", false)
    -- red under: the tab keeping the filter it was made with, and Reset shown though nothing in the
    -- window was clicked (spec §4: the tab starts filtered by the setting)
    assertEqual(f.section.chip.label:GetText(), "All professions")
    assertTrue(TABS.IsDefault("crafting", W.ViewState("crafting"), { mine = false }), "still the default: no Reset")
    NS.SchemaRuntime.Set("itemSearch.myProfessionsOnly", true)
    assertEqual(f.section.chip.label:GetText(), "My professions")
end, FOREVER_ONLY)

test("item search window: a corner drag, a sort click or a tab pick re-lays the table without building it again", function()
    local NS = enabled()
    local W, ISC = NS.ItemSearchWindow, NS.ItemSearchCells
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local builds, real = 0, ISC.Build
    ISC.Build = function(...) builds = builds + 1; return real(...) end
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    for i = 1, 5 do f:SetSize(1000 + i * 20, 620) end
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    W.SortBy("drops", "level")
    W.SelectTab(W.ShownTab())
    -- red under: every resize tick (and every click) reading the facts and ranking every section again
    assertEqual(builds, 0, "the last build reused")
    assertTrue(#W.TableRows() > 0, "the rows still drawn")
    W.ShowItem(IDS.leather)
    assertEqual(builds, 1, "another item builds")
    ISC.Build = real
end, FOREVER_ONLY)

-- ── the window: pins ────────────────────────────────────────────────────────────────────────

-- Item Search feedback spec §6 (ISF-DW-07): TomTom or Drop Watcher's arrow, never the client's own
-- user waypoint. `m.waypoints` records every C_Map.SetUserWaypoint call, which must stay empty.
local function withTomTom(m)
    local added = {}
    m.TomTom = { AddWaypoint = function(_, map, x, y, opts) added[#added + 1] = { map, x, y, opts.title } end }
    return added
end

test("item search waypoints: who draws the way, by the setting and what is loaded (pure)", function()
    local NS = T.newAddon()
    local R = NS.ItemSearchWaypoint.Resolve
    -- red under: Automatic preferring the arrow over a loaded TomTom (the spec's W12 call)
    assertEqual(R("auto", true, true), "tomtom")
    assertEqual(R("auto", false, true), "arrow")
    assertEqual(R("arrow", true, true), "arrow", "the arrow even with TomTom loaded")
    assertEqual(R("tomtom", true, true), "tomtom")
    assertEqual(R("tomtom", false, true), "arrow", "TomTom not loaded: Drop Watcher's arrow instead")
    assertEqual(R("arrow", true, false), "tomtom", "no arrow library: TomTom")
    assertNil(R("auto", false, false), "neither: no pin")
    assertEqual(R("bogus", false, true), "arrow", "an unknown choice reads as Automatic")
end)

test("item search window: with TomTom loaded, Automatic sets TomTom's waypoint at the spot; never the client's", function()
    local NS, m = enabled()
    local added = withTomTom(m)
    assertEqual(NS.Setting("itemSearch.waypoints"), "auto", "the default (spec §6)")
    assertEqual(NS.ItemSearchWaypoint.Method(), "tomtom")
    -- red under: a pin that names no map, or the waypoint at the wrong spot
    assertEqual(NS.ItemSearchWindow.SetPin({ map = IDS.mapA, x = 0.1, y = 0.2 }, "Fixture Gnoll"), "tomtom")
    assertEqual(added[1][1], IDS.mapA); assertEqual(added[1][2], 0.1); assertEqual(added[1][3], 0.2)
    assertEqual(added[1][4], "Fixture Gnoll")
    assertEqual(#m.waypoints, 0, "C_Map.SetUserWaypoint is never called")
    local line = m.prints[#m.prints]
    assertTrue(line:find("Fixture Vale", 1, true) ~= nil and line:find("TomTom", 1, true) ~= nil,
        "one chat line names the zone and the arrow: " .. line)
end, FOREVER_ONLY)

test("item search window: without TomTom, Drop Watcher's arrow points at the spot; Drop Watcher's arrow wins over TomTom", function()
    local NS, m = enabled()
    local WP = NS.ItemSearchWaypoint
    assertTrue(WP.ArrowAvailable(), "LibKa0s-WaypointArrow-1.0 is vendored")
    assertEqual(WP.Method(), "arrow")
    assertEqual(NS.ItemSearchWindow.SetPin({ map = IDS.mapA, x = 0.5, y = 0.25 }, "Fixture Gnoll"), "arrow")
    local target = WP.Instance():Target()
    -- red under: the client's user waypoint (no arrow on Forever), or the arrow at the wrong spot
    assertEqual(#m.waypoints, 0, "C_Map.SetUserWaypoint is never called")
    assertEqual(target.mapID, IDS.mapA); assertEqual(target.x, 0.5); assertEqual(target.y, 0.25)
    assertEqual(target.label, "Fixture Gnoll")
    assertTrue(m.prints[#m.prints]:find("Drop Watcher's arrow", 1, true) ~= nil, "the chat line names the arrow")
    -- TomTom chosen while it is not loaded: the arrow still points
    assertTrue((NS.SchemaRuntime.Set("itemSearch.waypoints", "tomtom")))
    assertEqual(WP.Method(), "arrow", "TomTom not loaded: Drop Watcher's arrow")
    -- Drop Watcher's arrow chosen with TomTom loaded
    local added = withTomTom(m)
    assertTrue((NS.SchemaRuntime.Set("itemSearch.waypoints", "arrow")))
    assertEqual(NS.ItemSearchWindow.SetPin({ map = IDS.mapB, x = 0.3, y = 0.4 }, "Fixture Kobold"), "arrow")
    assertEqual(#added, 0, "TomTom is not called while Drop Watcher's arrow is picked")
    assertEqual(WP.Instance():Target().mapID, IDS.mapB, "the arrow retargets")
    -- a choice that hands the way to TomTom takes the arrow down
    assertTrue((NS.SchemaRuntime.Set("itemSearch.waypoints", "tomtom")))
    assertNil(WP.Instance():Target(), "the arrow's waypoint went with the choice")
    assertFalse((NS.SchemaRuntime.Set("itemSearch.waypoints", "client")), "the seam refuses an unknown choice")
end, FOREVER_ONLY)

test("item search window: a pin is a dim map pin, lit on its row's hover, and its tooltip names the arrow", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local gnoll
    for _, row in ipairs(W.TableRows()) do if row.dwTip.title == "Fixture Gnoll" then gnoll = row end end
    local pin = gnoll.pin
    assertTrue(pin:IsShown(), "a row with a spot has a pin")
    -- red under: the white arrow glyph (W11)
    assertEqual(pin.art:GetTexture(), NS.Icon("ph:map-pin"))
    local _, _, _, a = pin.art:GetVertexColor()
    assertEqual(a, NS.ItemSearchGrid.PIN_ALPHA, "dim at rest")
    gnoll:__fire("OnEnter")
    _, _, _, a = pin.art:GetVertexColor()
    assertEqual(a, 1, "lit while the pointer is on its row")
    gnoll:__fire("OnLeave")
    _, _, _, a = pin.art:GetVertexColor()
    assertEqual(a, NS.ItemSearchGrid.PIN_ALPHA, "dim again")
    local text = table.concat(NS.Window.TooltipOf(pin), "\n")
    assertTrue(text:find("Set a waypoint", 1, true) == 1, "its title")
    assertTrue(text:find("Fixture Vale", 1, true) ~= nil, "the place")
    assertTrue(text:find("Drop Watcher's arrow", 1, true) ~= nil, "the arrow it uses: " .. text)
    assertTrue(text:find("Click: set a waypoint", 1, true) ~= nil, "the hint")
end, FOREVER_ONLY)

test("item search window: a stand-down takes Drop Watcher's arrow down", function()
    local NS = enabled()
    local WP = NS.ItemSearchWaypoint
    NS.ItemSearchWindow.SetPin({ map = IDS.mapA, x = 0.5, y = 0.25 }, "Fixture Gnoll")
    local inst = WP.Instance()
    assertTrue(inst:Target() ~= nil)
    NS.addon:SlashEnabled(false)
    -- red under: an arrow left pointing while the addon is off
    assertNil(inst:Target(), "the stand-down cleared it")
    assertFalse(inst:IsShown())
end, FOREVER_ONLY)

test("item search settings: the arrow's rows are LibKa0s's, dimmed while TomTom draws the way", function()
    local NS, m = enabled()
    local R = NS.SchemaRuntime.FindRow
    local style = R("itemSearch.arrow.style")
    assertTrue(style ~= nil and style.group == "Waypoints", "the library's rows on the Waypoints tab")
    assertFalse(style.disabledIf(style), "no TomTom: the arrow is the one used")
    withTomTom(m)
    -- red under: the arrow's rows live while TomTom points every waypoint
    assertTrue(style.disabledIf(style), "Automatic with TomTom loaded: TomTom draws")
    assertTrue((NS.SchemaRuntime.Set("itemSearch.waypoints", "arrow")))
    assertFalse(style.disabledIf(style), "Drop Watcher's arrow picked")
    -- the library's own dimming is kept: the swatches while the skin's colors are drawn
    local far = R("itemSearch.arrow.farColor")
    assertTrue(far.disabledIf(far), "Use the skin's colors is on by default")
    assertTrue((NS.SchemaRuntime.Set("itemSearch.arrow.useSkinColors", false)))
    assertFalse(far.disabledIf(far))
    assertFalse((NS.SchemaRuntime.Set("itemSearch.arrow.scale", 5)), "the seam refuses a scale past 2")
    assertFalse((NS.SchemaRuntime.Set("itemSearch.arrow.style", "spiral")), "and an unknown style")
    assertTrue((NS.SchemaRuntime.Set("itemSearch.arrow.style", "flat")))
    assertEqual(NS.ItemSearchWaypoint.Instance():Get("style"), "flat", "a row's change reaches the arrow")
end, FOREVER_ONLY)

test("item search window: a stand-down closes it", function()
    local NS = enabled()
    NS.ItemSearchWindow.Open()
    NS.addon:SlashEnabled(false)
    -- red under: a window left open while the addon is off
    assertFalse(NS.ItemSearchWindow.IsShown())
end, FOREVER_ONLY)
