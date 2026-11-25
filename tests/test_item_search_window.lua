-- tests/test_item_search_window.lua — the Item Search window (DropWatcher#17, Item Search spec §4.5,
-- mockup board 2): its pure rows (modules/ItemSearchView.lua) and its frame edge
-- (modules/ItemSearchWindow.lua): the ways in (the main window's magnifier, `/dw search`), the
-- debounced search (an id without ForeverDB, a name through SearchItems), the recent searches, the
-- detail pane's sections, the waypoint pins, Link in chat, the footer, the saved position and the
-- lock. Every ForeverDB value is the kit fake's invented data (tests/_kit/mock_foreverdb.lua); the
-- Crafting rows read the shipped recipe table (Blizzard client DB2 data). The map names and spots
-- below are invented too.

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

local function sectionKeys(NS, id)
    local ISW = NS.ItemSearchWindow
    local out = {}
    for _, s in ipairs(ISW.Sections(NS.ItemSearch.Get(id), {
        spots = NS.ForeverDB.Spots, mapName = NS.Compat.MapName, npc = NS.ForeverDB.NPC, quest = NS.ForeverDB.Quest,
        profession = NS.ItemSearchTip.ProfessionName })) do
        out[#out + 1] = s.key
    end
    return table.concat(out, ",")
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

test("item search view: the recent list puts the newest first, keeps each item once, and keeps ten", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local ids = {}
    for i = 1, 12 do ids = V.PushRecent(ids, i, 10) end
    assertEqual(#ids, 10); assertEqual(ids[1], 12); assertEqual(ids[10], 3)
    ids = V.PushRecent(ids, 5, 10)
    -- red under: a second entry for an item shown again
    assertEqual(ids[1], 5); assertEqual(#ids, 10)
    local seen = 0
    for _, v in ipairs(ids) do if v == 5 then seen = seen + 1 end end
    assertEqual(seen, 1)
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

test("item search view: DROPS FROM lists every source with a bar scaled to the top chance, then the World drop row", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local facts = { worldMinLevel = 8, drops = {
        { kind = "npc", id = 1, name = "A", named = true, minLevel = 10, maxLevel = 12, chance = 0.5 },
        { kind = "object", id = 2, name = "B", named = false, chance = 0.25 },
        { kind = "npc", id = 3, name = "C", named = true, minLevel = 5 },
        { kind = "npc", id = 4, name = "D", named = true, chance = 0.1 },
        { kind = "npc", id = 5, name = "E", named = true, chance = 0.05 },
    } }
    local spots = function(kind, id) if kind == "npc" and id == 1 then return { [7] = { { x = 0.5, y = 0.5 } } } end end
    local rows = V.DropRows(facts, { spots = spots, mapName = function(map) return map == 7 and "Vale" or nil end })
    -- red under: the tooltip's top 3 only (the window lists every source)
    assertEqual(#rows, 6, "five sources and the World drop row")
    assertEqual(rows[1].fraction, 1); assertEqual(rows[2].fraction, 0.5); assertEqual(rows[3].fraction, 0)
    assertEqual(rows[1].pct, "50%"); assertEqual(rows[3].pct, "rate unknown")
    assertEqual(rows[1].level, "10-12"); assertEqual(rows[3].level, "5"); assertNil(rows[2].level)
    assertEqual(rows[1].zone, "Vale"); assertEqual(rows[1].spot.map, 7)
    assertNil(rows[2].spot, "no spot: no pin")
    assertTrue(rows[6].world); assertEqual(rows[6].level, "level 8+")
end)

test("item search view: a known recipe's breakpoints against your rank; an unknown one learnable at its minimum", function()
    local NS = T.newAddon()
    local V = NS.ItemSearchView
    local function texts(parts)
        local out = {}
        for i, p in ipairs(parts) do out[i] = p.tone .. "=" .. p.text end
        return table.concat(out, " ")
    end
    assertEqual(texts(V.Breakpoints({ known = true, min = 1, yellow = 55, green = 75, gray = 95, rank = 60 })),
        "skillOrange=1 skillYellow=55 skillGreen=75 skillGray=95 plain=you 60")
    -- red under: breakpoints shown for a recipe you don't know
    assertEqual(texts(V.Breakpoints({ known = false, min = 40, yellow = 55, gray = 95 })), "muted=learnable at 40")
    assertEqual(texts(V.Breakpoints({ known = true })), "", "a learned recipe has no breakpoints")
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
    assertEqual(sectionKeys(NS, LINEN), "crafting")
    assertEqual(f.foot.left:GetText(), "ForeverDB · not installed")
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

-- ── the window: recent searches ─────────────────────────────────────────────────────────────

test("item search window: each item shown joins the account-wide recent searches, newest first, while remembered", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    W.ShowItem(IDS.leather)
    W.ShowItem(IDS.blade)
    local r = W.Recent()
    assertEqual(#r, 2); assertEqual(r[1], IDS.blade); assertEqual(r[2], IDS.leather)
    -- red under: the list stored per character or per profile (the lead: global)
    assertEqual(NS.addon.db.global.itemSearch.recent[1], IDS.blade)
    NS.addon.db.profile.itemSearch.window.recent = false
    W.ShowItem(IDS.cloak)
    assertEqual(#W.Recent(), 2, "not remembered while the switch is off")
    assertFalse(W.Frame().recentHost:IsShown(), "and not listed")
end, FOREVER_ONLY)

-- ── the window: the detail pane ─────────────────────────────────────────────────────────────

test("item search window: the blade's pane: DROPS FROM, SOLD BY and ALSO, the header and the footer", function()
    local NS, m = enabled()
    m.bindKey("CTRL-ALT-D", "CLICK DropWatcherItemSearch:LeftButton")
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: an empty section drawn, or one left out
    assertEqual(sectionKeys(NS, IDS.blade), "drops,vendors,also")
    assertEqual(f.name:GetText(), "Fixture Blade")
    assertTrue(f.line:GetText():find(("id %d"):format(IDS.blade), 1, true) ~= nil)
    assertFalse(f.notice:IsShown(), "no notice once ForeverDB is loaded")
    assertEqual(f.foot.left:GetText(), "ForeverDB 2099.01.01.1 · loaded")
    assertEqual(f.foot.right:GetText(), "CTRL-ALT-D: open in Item Search")
    local headings = {}
    for _, h in ipairs(f.headings) do if h:IsShown() then headings[#headings + 1] = h:GetText() end end
    assertEqual(table.concat(headings, ","), "DROPS FROM,SOLD BY,ALSO")
end, FOREVER_ONLY)

test("item search window: the leather's QUESTS rows carry the mark, title, zone and state", function()
    local NS, m = enabled()
    m.C_QuestLog = m.C_QuestLog or {}
    m.C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == IDS.errand end
    local V = NS.ItemSearchView
    local facts = NS.ItemSearch.Get(IDS.leather)
    local rows = V.QuestRows(facts, { quest = NS.ForeverDB.Quest, spots = NS.ForeverDB.Spots, mapName = NS.Compat.MapName })
    local errand
    for _, r in ipairs(rows) do if r.id == IDS.errand then errand = r end end
    assertTrue(errand ~= nil, "the errand needs the leather")
    assertEqual(errand.title, "Fixture Errand")
    assertEqual(errand.zone, "Fixture Vale", "its first giver's (the gnoll's) map")
    assertEqual(errand.stateText, "Completed")
    -- red under: completed quests hidden in the window (only the tooltip hides them by default)
    assertEqual(#V.QuestRows(facts, { hideCompleted = true }), #rows - 1)
end, FOREVER_ONLY)

-- ── the window: pins, Link in chat ──────────────────────────────────────────────────────────

test("item search window: a pin sets the client's user waypoint at the source's spot, else TomTom's; no spot, no pin", function()
    local NS, m = enabled()
    local W = NS.ItemSearchWindow
    assertEqual(NS.Compat.WaypointMethod(IDS.mapA), "client")
    -- red under: a pin that names no map, or the waypoint at the wrong spot
    assertEqual(W.SetPin({ map = IDS.mapA, x = 0.5, y = 0.25 }, "Fixture Gnoll"), "client")
    assertEqual(#m.waypoints, 1)
    assertEqual(m.waypoints[1].map, IDS.mapA); assertEqual(m.waypoints[1].x, 0.5); assertEqual(m.waypoints[1].y, 0.25)
    assertTrue(m.prints[#m.prints]:find("Fixture Vale", 1, true) ~= nil, "the line names the zone")
    local rows = NS.ItemSearchView.DropRows(NS.ItemSearch.Get(IDS.blade),
        { spots = NS.ForeverDB.Spots, mapName = NS.Compat.MapName })
    local byName = {}
    for _, r in ipairs(rows) do byName[r.name] = r end
    assertEqual(byName["Fixture Gnoll"].spot.map, IDS.mapA)
    assertEqual(byName["Fixture Gnoll"].zone, "Fixture Vale")
    assertNil(byName["Fixture Coffer"].spot, "a container has no spot: no pin")
end, FOREVER_ONLY)

test("item search window: without the client's waypoint, TomTom when installed; neither, no pin", function()
    local NS, m = enabled({ waypoint = false })
    assertNil(NS.Compat.WaypointMethod(IDS.mapA), "neither: the pin hides")
    local added = {}
    m.TomTom = { AddWaypoint = function(_, map, x, y, opts) added[#added + 1] = { map, x, y, opts.title } end }
    assertEqual(NS.Compat.WaypointMethod(IDS.mapA), "tomtom")
    assertEqual(NS.ItemSearchWindow.SetPin({ map = IDS.mapA, x = 0.1, y = 0.2 }, "Fixture Gnoll"), "tomtom")
    assertEqual(added[1][1], IDS.mapA); assertEqual(added[1][4], "Fixture Gnoll")
end, FOREVER_ONLY)

test("item search window: Link in chat puts the item's link in the chat box, or says it is still loading", function()
    local link = "|cff1eff00|Hitem:" .. IDS.blade .. "::|h[Fixture Blade]|h|r"
    local NS, m = enabled({ setup = function(mm)
        local real = mm.C_Item.GetItemInfo
        mm.C_Item.GetItemInfo = function(id)
            if id == IDS.blade then return "Fixture Blade", link, 2, 15, 10, "", "", 1, "", 9990001, 0, 2, 7 end
            return real(id)
        end
        mm.opened = {}
        mm.ChatFrame_OpenChat = function(text) mm.opened[#mm.opened + 1] = text end
    end })
    local W = NS.ItemSearchWindow
    W.ShowItem(IDS.blade)
    -- red under: a Link in chat that writes nothing with no chat box open
    assertTrue(W.LinkInChat())
    assertEqual(m.opened[1], link)
    W.ShowItem(IDS.pebble)
    assertFalse(W.LinkInChat(), "no client link yet")
    assertTrue(m.prints[#m.prints]:find("That item is still loading: try again in a moment.", 1, true) ~= nil)
end, FOREVER_ONLY)

-- ── the window: position and lock ───────────────────────────────────────────────────────────

test("item search window: a drag saves its point per profile, the next open puts it back, and the lock holds it", function()
    local NS = enabled()
    local W = NS.ItemSearchWindow
    W.Open()
    local f = W.Frame()
    local moved = 0
    f.StartMoving = function() moved = moved + 1 end
    f.titleBar:__fire("OnDragStart")
    assertEqual(moved, 1)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 100, 600)
    f.titleBar:__fire("OnDragStop")
    -- red under: no saved position (standalone-windows: MUST persist it)
    local pt = NS.addon.db.profile.itemSearch.window.point
    assertEqual(pt[1], "TOPLEFT"); assertEqual(pt[3], 100); assertEqual(pt[4], 600)
    W.ApplySettings()
    assertEqual(select(4, f:GetPoint(1)), 100)
    NS.SetLocked(true)
    f.titleBar:__fire("OnDragStart")
    assertEqual(moved, 1, "locked: no drag")
    assertEqual(f.lockButton.art:GetAlpha(), 1, "the lock mark at full strength")
end, FOREVER_ONLY)

test("item search window: a stand-down closes it", function()
    local NS = enabled()
    NS.ItemSearchWindow.Open()
    NS.addon:SlashEnabled(false)
    -- red under: a window left open while the addon is off
    assertFalse(NS.ItemSearchWindow.IsShown())
end, FOREVER_ONLY)
