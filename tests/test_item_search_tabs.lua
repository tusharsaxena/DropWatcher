-- tests/test_item_search_tabs.lua — the Item Search window's pure tabs and rows (Item Search feedback
-- spec §5.3 to §5.6, ISF-DW-06): modules/ItemSearchTabs.lua (the tab set and order, each tab's
-- columns, the layout, the sorts, the filters, Reset) and modules/ItemSearchCells.lua (each tab's
-- rows: their cells, sort values, flags and tooltips). Every fact below is invented; the leather's
-- quests are the kit fake's (tests/_kit/mock_foreverdb.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): Item Search's window is not built on Retail" or nil

local function keys(cols)
    local out = {}
    for i, c in ipairs(cols) do out[i] = c.key end
    return table.concat(out, ",")
end

local function texts(rows, key)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.cells[key] and (r.cells[key].text or r.cells[key].pct) or "" end
    return table.concat(out, ",")
end

local function tipRow(r, label)
    for _, row in ipairs(r.tip.rows or {}) do if row[1] == label then return row[2] end end
    return nil
end

-- Whether a row's tooltip carries `text` as one of its hints.
local function hint(r, text)
    for _, h in ipairs(r.tip.hints or {}) do if h == text then return true end end
    return false
end

-- ── the tabs ────────────────────────────────────────────────────────────────────────────────

test("item search tabs: one tab per section with rows, in spec order; Crafting counts my professions of all", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    local built = { skinned = { { best = 1 } }, drops = { { best = 1 }, { best = 2, world = true } }, vendors = {},
        quests = { { best = 1 } }, crafting = { { best = 1, mine = true }, { best = 2, mine = false }, { best = 3, mine = true } } }
    local tabs = TABS.Tabs(built, true)
    local out = {}
    for i, t in ipairs(tabs) do out[i] = ("%s=%d/%d"):format(t.key, t.count, t.total) end
    -- red under: an empty Sold by tab, the World drop row counted as a source, or Crafting's whole count
    assertEqual(table.concat(out, " "), "drops=1/1 quests=1/1 crafting=2/3 skinned=1/1")
    assertEqual(TABS.Tabs(built, false)[3].count, 3, "All professions: the whole count")
    assertEqual(TABS.Pick(tabs, "crafting"), "crafting")
    assertEqual(TABS.Pick(tabs, "vendors"), "drops", "a tab the item lacks: the first")
    assertNil(TABS.Pick({}, "drops"))
end)

test("item search tabs: each tab draws exactly the spec's columns, less the two with no client data", function()
    local NS = T.newAddon()
    local D = NS.ItemSearchTabs.DEF
    assertEqual(keys(D.drops.columns), "source,type,level,zone,chance,pin")
    -- Stock and Requires: ForeverDB's vendx is not in the reader's surface (spec §5.4 lets them go)
    assertEqual(keys(D.vendors.columns), "vendor,level,zone,faction,price,pin")
    assertEqual(keys(D.quests.columns), "mark,quest,role,level,min,status,giver,pin")
    assertEqual(keys(D.crafting.columns), "glyph,recipe,profession,uses,makes,skill,status")
    assertEqual(keys(D.skinned.columns), "creature,level,skill,zone,chance,pin")
    -- red under: a flex column turned fixed (no room for whole names, W8)
    for _, tab in ipairs({ "drops", "vendors", "quests", "crafting", "skinned" }) do
        local flex = 0
        for _, c in ipairs(D[tab].columns) do if c.flex then flex = flex + 1 end end
        -- Crafting's Status is the third (ISR3-DW-08: a not-known recipe's source, "Sold by <vendor> · <zone>")
        assertEqual(flex, tab == "crafting" and 3 or 2, tab .. ": its flex columns")
    end
end)

test("item search tabs: fixed columns keep their width, the flex ones share the rest, a narrow table scales the fixed", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    local cols = TABS.DEF.drops.columns
    local wide, wider = TABS.Layout(cols, 700), TABS.Layout(cols, 1100)
    assertEqual(wide.type.w, 80); assertEqual(wide.chance.w, 150); assertEqual(wider.chance.w, 150)
    -- red under: one width for every window (W8: "use the space")
    assertTrue(wider.source.w > wide.source.w); assertEqual(wider.source.w, wider.zone.w)
    assertEqual(wide.level.x, wide.type.x + wide.type.w + TABS.GAP, "laid left to right, GAP apart")
    local last = wide.pin
    assertTrue(last.x + last.w <= 700, "nothing past the table's width")
    local narrow = TABS.Layout(TABS.DEF.crafting.columns, 520)
    assertTrue(narrow.recipe.w >= TABS.FLEX_MIN, "a flex column keeps its least width")
    assertTrue(narrow.skill.w < 130, "the fixed columns gave up room")
end)

test("item search tabs: the columns start TABS.INSET in and end TABS.INSET short; glyphs and marks are centered", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    -- round 3 spec §4.1, item 12: the window's own body margin
    assertEqual(TABS.INSET, 6); assertEqual(TABS.INSET, NS.Constants.WINDOW.INSET)
    for _, tab in ipairs(TABS.ORDER) do
        local cols = TABS.DEF[tab].columns
        local lay = TABS.Layout(cols, 900)
        -- red under: the first column flush with the table's edge (x = 0)
        assertEqual(lay[cols[1].key].x, TABS.INSET, tab .. ": the first column inset")
        local last = lay[cols[#cols].key]
        assertTrue(last.x + last.w <= 900 - TABS.INSET, tab .. ": the last column ends INSET short")
        local used = 0
        for _, c in ipairs(cols) do used = used + lay[c.key].w end
        used = used + TABS.GAP * (#cols - 1)
        assertTrue(used <= 900 - 2 * TABS.INSET and used > 900 - 2 * TABS.INSET - #cols, tab .. ": laid across width - 2 * INSET")
    end
    assertEqual(TABS.Column("crafting", "glyph").justify, "CENTER", "the glyph column centered")
    assertEqual(TABS.Column("quests", "mark").justify, "CENTER", "the mark column centered")
    assertEqual(TABS.Column("drops", "source").justify, nil, "a text column stays left")
end)

test("item search tabs: a column's click sorts by it, a second flips it; Best for you is the default", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    local st = TABS.DefaultState("drops")
    assertEqual(st.sort.col, "best")
    local s1 = TABS.NextSort("drops", st.sort, "level")
    assertEqual(s1.col, "level"); assertFalse(s1.desc)
    -- red under: a second click that keeps the order
    assertTrue(TABS.NextSort("drops", s1, "level").desc)
    assertTrue(TABS.NextSort("drops", s1, "chance").desc, "Chance starts high to low")
    assertEqual(TABS.NextSort("drops", s1, "best").col, "best")
    assertEqual(TABS.SortLabel("drops", st.sort), "Best for you")
    assertEqual(TABS.SortLabel("drops", s1), "Level, low to high")
    local choices = TABS.SortChoices("quests")
    assertEqual(choices[1].key, "best", "Best for you first in the Sort menu")
    assertEqual(#choices, 7, "and every sortable column (the mark and the pin are not)")
end)

test("item search tabs: the view sorts by a column with unknowns last, ties by the ranking, the World drop row last", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    local rows = {
        { best = 1, cells = {}, sort = { level = 30, source = "c" } },
        { best = 2, cells = {}, sort = { source = "a" } },
        { best = 3, cells = {}, sort = { level = 10, source = "b" } },
        { best = 4, cells = {}, sort = { level = 10, source = "d" } },
        { best = 5, world = true, cells = {}, sort = {} },
    }
    local function order(state)
        local out = {}
        for i, r in ipairs((TABS.View("drops", rows, state))) do out[i] = r.best end
        return table.concat(out, ",")
    end
    local st = TABS.DefaultState("drops")
    assertEqual(order(st), "1,2,3,4,5")
    st.sort = { col = "level", desc = false }
    -- red under: an unknown level first, or the World drop row sorted in with the sources
    assertEqual(order(st), "3,4,1,2,5")
    st.sort.desc = true
    assertEqual(order(st), "1,3,4,2,5", "flipped: the unknown still last, the tie still by the ranking")
end)

test("item search tabs: each tab's filters narrow its view; the funnel fills and Reset shows while one moved", function()
    local NS = T.newAddon()
    local TABS = NS.ItemSearchTabs
    local rows = {
        { best = 1, kind = "npc", here = true, band = true, cells = {}, sort = {} },
        { best = 2, kind = "npc", here = false, band = false, cells = {}, sort = {} },
        { best = 3, kind = "object", here = false, cells = {}, sort = {} },
        { best = 4, kind = "item", here = false, cells = {}, sort = {} },
    }
    local st = TABS.DefaultState("drops")
    assertFalse(TABS.Narrowed("drops", st)); assertTrue(TABS.IsDefault("drops", st))
    st.filters.npc = false
    local shown, hidden = TABS.View("drops", rows, st)
    assertEqual(#shown, 2); assertEqual(hidden, 2)
    -- red under: Creatures off read as "on" (a default-on toggle narrows when off)
    assertTrue(TABS.Narrowed("drops", st)); assertFalse(TABS.IsDefault("drops", st))
    st = TABS.DefaultState("drops")
    st.filters.zone = true
    assertEqual(#(TABS.View("drops", rows, st)), 1, "Only my zone")
    st = TABS.DefaultState("drops")
    st.filters.band = true
    assertEqual(#(TABS.View("drops", rows, st)), 3, "Only my level band keeps the rows with no level")
    local vendors = { { best = 1, other = true, cells = {}, sort = {} }, { best = 2, other = false, cells = {}, sort = {} } }
    st = TABS.DefaultState("vendors")
    st.filters.faction = true
    assertEqual(#(TABS.View("vendors", vendors, st)), 1, "Only my faction")
    local quests = { { best = 1, state = "done", cells = {}, sort = {} }, { best = 2, state = "log", cells = {}, sort = {} } }
    st = TABS.DefaultState("quests")
    st.filters.completed = true
    assertEqual(#(TABS.View("quests", quests, st)), 1, "Hide completed")
    local recipes = { { best = 1, mine = true, known = true, cells = {}, sort = {} },
        { best = 2, mine = false, known = false, cells = {}, sort = {} }, { best = 3, mine = true, known = false, cells = {}, sort = {} } }
    st = TABS.DefaultState("crafting", { mine = true })
    assertTrue(st.filters.mine, "My professions is the setting's default (spec §4)")
    assertTrue(TABS.IsDefault("crafting", st, { mine = true }))
    assertTrue(TABS.Narrowed("crafting", st), "the funnel is filled while My professions narrows (mockup)")
    assertEqual(#(TABS.View("crafting", recipes, st)), 2)
    st.filters.known = true
    assertEqual(#(TABS.View("crafting", recipes, st)), 1, "Only known")
    assertFalse(TABS.DefaultState("crafting", { mine = false }).filters.mine)
    assertEqual(TABS.CountText("crafting", 1, 3), "1 of 3 recipes")
    assertEqual(TABS.CountText("drops", 1, 1), "1 source")
end)

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

test("item search cells: a level's difficulty color against yours, the game's quest colors", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    assertEqual(C.LevelTone(40, 35), "red"); assertEqual(C.LevelTone(38, 35), "skillOrange")
    assertEqual(C.LevelTone(33, 35), "skillYellow"); assertEqual(C.LevelTone(30, 35), "skillGreen")
    -- red under: every lower level green (a level-35 player's gray starts at 27)
    assertEqual(C.GrayLevel(35), 27); assertEqual(C.LevelTone(27, 35), "skillGray")
    assertEqual(C.LevelTone(nil, 35), "plain")
    assertEqual(C.GrayLevel(4), 0, "no gray for a new character")
end)

test("item search cells: DROPS FROM's rows: the type from its rank, the colored level, the zone, the container's tooltip", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { worldMinLevel = 8, drops = {
        { kind = "npc", id = 1, name = "Raptor", named = true, minLevel = 35, maxLevel = 36, rank = 0, chance = 0.016 },
        { kind = "npc", id = 2, name = "Skarr", named = true, minLevel = 58, maxLevel = 58, rank = 2, chance = 0.006 },
        { kind = "item", id = 3, name = "Trunk", named = true, chance = 0.4 },
        { kind = "object", id = 4, ids = { 4, 5, 6 }, name = "Chest", named = true, chance = 0.1 },
        { kind = "npc", id = 7, name = "Creature 7", named = false },
    } }
    local spots = function(kind, id)
        if kind == "npc" and id == 1 then return { [10] = { { x = 0.1, y = 0.1 } }, [11] = { { x = 0.2, y = 0.2 } } } end
        return nil
    end
    local rows = C.Drops(facts, { level = 35, mapID = 10, spots = spots }, { spots = spots,
        mapName = function(map) return ({ [10] = "Vale", [11] = "Hills" })[map] end,
        item = function(id) return id == 3 and { name = "Trunk", quality = 2 } or nil end })
    local by = {}
    for _, r in ipairs(rows) do by[r.cells.source.text] = r end
    -- red under: "Object 4"-style types, or a Rare Elite read as Creature
    assertEqual(by.Raptor.cells.type.text, "Creature"); assertEqual(by.Skarr.cells.type.text, "Rare Elite")
    assertEqual(by.Trunk.cells.type.text, "Container"); assertEqual(by.Chest.cells.type.text, "Object ×3")
    assertEqual(by.Raptor.cells.level.text, "35–36"); assertEqual(by.Raptor.cells.level.tone, "skillYellow")
    assertEqual(by.Skarr.cells.level.tone, "red"); assertEqual(by.Trunk.cells.level.text, "–")
    -- red under: the zone with the most spots when one is in yours (spec §5.4: yours first)
    assertEqual(by.Raptor.cells.zone.text, "Vale +1 zone"); assertEqual(by.Raptor.spot.map, 10)
    assertTrue(by.Raptor.here); assertTrue(by.Raptor.band); assertFalse(by.Skarr.band)
    -- round 4 (R4-DW-01): the Type cell in its type's own tone, the Source cell plain for every kind
    assertEqual(by.Raptor.cells.source.tone, "plain", "a normal creature's name plain")
    assertEqual(by.Raptor.cells.type.tone, "typeCreature", "Creature in white")
    assertEqual(by.Skarr.cells.source.tone, "plain", "a rare elite's name plain")
    assertEqual(by.Skarr.cells.type.tone, "typeRareElite", "its Type in the rare elite tone")
    assertEqual(by.Chest.cells.source.tone, "plain", "an object's name plain")
    assertEqual(by.Chest.cells.type.tone, "typeObject")
    assertEqual(by.Trunk.cells.source.tone, "plain", "a container's name plain")
    assertEqual(by.Trunk.cells.source.quality, nil, "no longer in its quality color")
    assertEqual(by.Trunk.cells.type.tone, "typeContainer"); assertEqual(by.Trunk.cells.type.quality, nil)
    assertEqual(by["Creature 7"].cells.type.tone, "typeCreature", "an unnamed creature is still a Creature")
    assertEqual(rows[#rows].cells.type.tone, "muted", "the World drop's dash stays muted")
    assertEqual(by.Trunk.tip.item, 3, "a container's row shows its game tooltip")
    assertEqual(by["Creature 7"].cells.source.tone, "muted")
    assertEqual(by.Raptor.best, 1, "in your zone: first")
    assertTrue(rows[#rows].world, "the World drop row last")
    assertEqual(rows[#rows].cells.level.text, "level 8+")
    assertEqual(tipRow(by.Raptor, "Type"), "Creature, level 35–36")
    assertEqual(tipRow(by.Raptor, "Chance"), "1.6%")
end)

test("item search cells: SOLD BY's rows: the faction (Horde only for the other side), each row's own price", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { vendors = {
        { id = 1, name = "Darahir", minLevel = 35, maxLevel = 35, faction = "A", subname = "Potions" },
        { id = 2, name = "Glyx", minLevel = 45, maxLevel = 45, faction = "AH", price = 1200, priceOrigin = "vp" },
        { id = 3, name = "Bro'kin", minLevel = 49, faction = "H" },
    } }
    local rows = C.Vendors(facts, { faction = "A" }, { coin = function(c) return c .. "c" end })
    local by = {}
    for _, r in ipairs(rows) do by[r.cells.vendor.text] = r end
    assertEqual(by.Darahir.cells.faction.text, "Alliance"); assertEqual(by.Glyx.cells.faction.text, "Both")
    -- red under: a vendor of the other side listed as one you can buy from; round 3 spec §4.4: it
    -- names the side that can (was "can't buy")
    assertEqual(by["Bro'kin"].cells.faction.text, "Horde only"); assertEqual(by["Bro'kin"].cells.faction.tone, "red")
    assertTrue(hint(by["Bro'kin"], "Only Horde characters can buy here: ForeverDB marks this vendor Horde. Only my faction hides these rows."))
    assertTrue(by["Bro'kin"].other); assertEqual(rows[#rows].cells.vendor.text, "Bro'kin", "the other side last")
    assertEqual(by.Glyx.cells.price.text, "1200c"); assertEqual(by.Darahir.cells.price.text, "–")
    assertTrue(hint(by.Glyx, "Recorded by ForeverDB"))
    assertTrue(hint(by.Darahir, "No price recorded yet: open this vendor and Drop Watcher remembers it"))
    assertEqual(tipRow(by.Darahir, "Title"), "Potions", "the subname on hover")
    assertEqual(tipRow(by.Darahir, "Zone"), "No known spawn", "no spot anywhere (round 3 spec §4.4)")
    local A = C.Vendors(facts, { faction = "H" }, {})
    assertEqual(A[#A].cells.faction.text, "Alliance only", "the other way round")
end)

test("item search cells: QUESTS' rows join the objectives, the rewards and the one it starts, with a Role", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local quest = { [1] = { title = "Errand", level = 12, minLevel = 8, givers = { { kind = "npc", id = 50 } } },
        [2] = { title = "Hunt", level = 44, minLevel = 40 }, [3] = { title = "Summons", level = 15, minLevel = 12 } }
    local facts = { quests = { { id = 1, title = "Errand", level = 12, minLevel = 8, state = "log" } },
        rewardFrom = { { id = 2, title = "Hunt", level = 44 } }, startsQuest = { id = 3, title = "Summons", level = 15 } }
    local rows = C.Quests(facts, { level = 20, questState = function(id) return id == 3 and "done" or "todo" end },
        { quest = function(id) return quest[id] end, npc = function() return { name = "Gnoll" } end,
          spots = function() return { [9] = { { x = 0.5, y = 0.5 } } } end, mapName = function() return "Vale" end })
    -- red under: a tab of its own for Rewards from (spec §5.3: rows with a Role)
    assertEqual(texts(rows, "role"), "Needs it,Rewards it,Starts it")
    assertEqual(texts(rows, "status"), "In your log,Requires level 40,Completed")
    assertEqual(rows[1].cells.mark.mark, "log"); assertEqual(rows[2].cells.mark.mark, "high")
    assertEqual(rows[1].cells.giver.text, "Gnoll · Vale"); assertEqual(rows[1].spot.map, 9)
    -- round 3 item 13: complete but not turned in, its own status, sorted before the log
    facts.quests[1].state = "ready"
    rows = C.Quests(facts, { level = 20, questState = function(id) return id == 3 and "done" or "todo" end },
        { quest = function(id) return quest[id] end })
    assertEqual(rows[1].cells.status.text, "Ready to turn in"); assertEqual(rows[1].cells.status.tone, "good")
    assertEqual(rows[1].cells.mark.mark, "ready")
    assertTrue(rows[1].sort.status < C.Quests({ quests = { { id = 1, state = "log" } } }, { level = 20 }, {})[1].sort.status,
        "ready sorts before in your log")
    assertEqual(C.QuestStatus("ready", 50, 20), "ready", "kept whatever the level")
    assertEqual(rows[2].cells.min.text, "40", "the minimum level from the quest row")
    assertEqual(rows[1].cells.quest.tone, "skillGray", "a level-12 quest is gray for a level-20 player (gray from 13)")
    assertEqual(rows[2].cells.quest.tone, "red", "a level-44 quest is red")
end)

test("item search cells: a Rewards it row with no level in the facts ranks by its quest row's level", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local quest = { [21] = { title = "Zeta", level = 30, minLevel = 1 }, [22] = { title = "Alpha", level = 60, minLevel = 1 },
        [23] = { title = "Mid", level = 45, minLevel = 1 } }
    local facts = { quests = {}, rewardFrom = { { id = 22 }, { id = 21 }, { id = 23 } } }
    local rows = C.Quests(facts, { level = 70, questState = function() return "todo" end },
        { quest = function(id) return quest[id] end })
    -- red under: the level and title filled after the ranking (every row level-less then: a tie on a
    -- nil name, the facts' order kept)
    assertEqual(texts(rows, "quest"), "Zeta,Mid,Alpha")
    assertEqual(texts(rows, "level"), "30,45,60")
end)

test("item search cells: the leather's quests from the fake carry their giver and their zone", function()
    local fake
    local NS, _, m = T.enableAddon{ mock = function(mm) fake = FDB.install(mm, { preset = "present" }) end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    assertTrue(fake ~= nil)
    local rows = NS.ItemSearchCells.Quests(NS.ItemSearch.Get(IDS.leather), {},
        { quest = NS.ForeverDB.Quest, npc = NS.ForeverDB.NPC, object = NS.ForeverDB.Object, spots = NS.ForeverDB.Spots,
          mapName = NS.Compat.MapName })
    local errand
    for _, r in ipairs(rows) do if r.id == IDS.errand then errand = r end end
    assertTrue(errand ~= nil, "the errand needs the leather")
    assertEqual(errand.cells.quest.text, "Fixture Errand")
    assertTrue(errand.cells.giver.text:find("Fixture Gnoll", 1, true) == 1, "its first giver, the gnoll")
end, FOREVER_ONLY)

test("item search cells: CRAFTING's rows: the breakpoints, the uses, what it makes and the status", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { crafting = {
        { spell = 1, name = "Gloves", skillLine = 165, count = 6, made = 90, min = 1, yellow = 150, green = 160, gray = 170,
          known = true, rank = 155, color = "yellow" },
        { spell = 2, name = "Belt", skillLine = 165, count = 5, min = 165, yellow = 175, green = 185, gray = 195,
          known = false, rank = 155 },
        { spell = 3, name = "Bracer", skillLine = 164, count = 4, min = 1, yellow = 100, green = 110, gray = 120, known = false },
    } }
    local rows = C.Crafting(facts, { ranks = { [165] = 155 } }, {
        profession = function(line) return ({ [165] = "Leatherworking", [164] = "Blacksmithing" })[line] end,
        item = function(id) return id == 90 and { name = "Barbaric Gloves", quality = 2 } or nil end })
    assertEqual(texts(rows, "recipe"), "Gloves,Belt,Bracer", "known first, a profession you lack last")
    -- red under: the placeholder minimum of 1 drawn as an orange breakpoint (IS-REV)
    local parts = {}
    for i, p in ipairs(rows[1].cells.skill.parts) do parts[i] = p.tone .. "=" .. p.text end
    assertEqual(table.concat(parts, " "), "skillYellow=150 skillGreen=160 skillGray=170")
    assertEqual(rows[2].cells.skill.parts[1].text, "165", "a real minimum is the orange one")
    assertEqual(texts(rows, "uses"), "×6,×5,×4")
    assertEqual(rows[1].cells.makes.text, "Barbaric Gloves"); assertEqual(rows[1].makesID, 90)
    -- red under: "Learn at 1", or a recipe of a profession you lack read as merely not known
    assertEqual(texts(rows, "status"), "Known,Learn at 165,No Blacksmithing")
    assertTrue(rows[2].mine); assertFalse(rows[3].mine)
    assertEqual(rows[1].cells.recipe.tone, "plain"); assertEqual(rows[2].cells.recipe.tone, "muted")
    assertEqual(tipRow(rows[1], "Your rank"), "155 · Yellow: likely to skill up")
end)

-- ISR3-DW-08: a not-known recipe's source. Invented recipe items: 501 sold by a vendor (and dropped),
-- 502 a quest's reward, 503 dropped by eight creatures, 504 a world drop, 505 ForeverDB knows no
-- source of, 506 the context has no facts for.
local function recipeSourceFacts()
    local mobs = {}
    for i = 1, 8 do mobs[i] = { kind = "npc", id = 600 + i, name = ("Mob %d"):format(i), chance = 1 - i / 10 } end
    return {
        [501] = { fdb = "loaded", vendors = { { id = 1, name = "Quartermaster" } },
            drops = { { kind = "npc", id = 2, name = "Raider", chance = 0.1 } } },
        [502] = { fdb = "loaded", rewardFrom = { { id = 7, level = 10 } } },
        [503] = { fdb = "loaded", drops = mobs },
        [504] = { fdb = "loaded", worldMinLevel = 20 },
        [505] = { fdb = "loaded" },
    }
end

local function recipeSourceCtx()
    local F = recipeSourceFacts()
    return {
        facts = function(id) return F[id] end,
        quest = function(id) return id == 7 and { title = "Fixture Errand" } or nil end,
        item = function(id) return id == 505 and { name = "Recipe: Fixture Stew" } or nil end,
        spots = function(kind, id) return kind == "npc" and id == 1 and { [10] = { { x = 0.5, y = 0.5 } } } or nil end,
        mapName = function(map) return map == 10 and "Fixture Vale" or nil end,
        profession = function(line) return ({ [185] = "Cooking", [164] = "Blacksmithing" })[line] end,
    }
end

-- A live crafting row; `taughtBy` as the model sets it: `taught` its first, the list only for several.
local function craftRowOf(spell, taughtBy, extra)
    local r = { spell = spell, name = "Recipe " .. spell, skillLine = 185, count = 1, min = 1, yellow = 50, green = 60,
        gray = 70, known = false, rank = 100, taught = taughtBy and taughtBy[1],
        taughtBy = taughtBy and #taughtBy > 1 and taughtBy or nil }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

test("item search cells: a not-known recipe's Status says where it is learned: a trainer, a vendor, a quest, a drop (ISR3-DW-08)", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { crafting = {
        craftRowOf(1, nil), craftRowOf(2, { 501 }), craftRowOf(3, { 502 }), craftRowOf(4, { 503 }),
        craftRowOf(5, { 504 }), craftRowOf(6, { 505 }), craftRowOf(7, { 506 }),
    } }
    local rows = C.Crafting(facts, { ranks = { [185] = 100 } }, recipeSourceCtx())
    local by = {}
    for _, r in ipairs(rows) do by[r.spell] = r end
    -- red under: every not-known row still reading "Not known" (the owner's screenshot)
    assertEqual(by[1].cells.status.text, "Trainer"); assertEqual(by[1].cells.status.tone, "muted")
    assertNil(by[1].itemID, "a trainer's recipe has no recipe item to open")
    assertEqual(tipRow(by[1], "Learn"), "from a profession trainer")
    -- red under: a drop shown before the vendor that sells it (the kinds' order: vendor, quest, drop)
    assertEqual(by[2].cells.status.text, "Sold by Quartermaster · Fixture Vale"); assertEqual(by[2].cells.status.tone, "plain")
    assertEqual(by[2].itemID, 501, "the row's click opens the recipe item")
    assertEqual(tipRow(by[2], "Recipe item"), "Item 501")
    assertEqual(tipRow(by[2], "Sold by"), "Quartermaster · Fixture Vale")
    assertEqual(tipRow(by[2], "Drops from"), "Raider", "the other kinds listed too")
    assertTrue(hint(by[2], "Click: search the recipe item") and hint(by[2], "Shift-click: link the recipe item"))
    assertEqual(by[3].cells.status.text, "Quest reward: Fixture Errand", "the quest titled from ForeverDB's row")
    assertEqual(by[4].cells.status.text, "Drops from Mob 1", "the best drop: the highest chance")
    assertEqual(by[5].cells.status.text, "World drop")
    assertEqual(by[6].cells.status.text, "Recipe: Fixture Stew", "no source known: the recipe item's name")
    assertEqual(by[6].cells.status.tone, "muted"); assertEqual(tipRow(by[6], "Sources"), "none known")
    assertEqual(by[7].cells.status.text, "Item 506"); assertEqual(tipRow(by[7], "Sources"), "ForeverDB is not loaded")
end)

test("item search cells: a recipe source's tooltip caps each kind, and of several recipe items the best source wins", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { crafting = { craftRowOf(4, { 503 }), craftRowOf(8, { 505, 502 }) } }
    local rows = C.Crafting(facts, { ranks = { [185] = 100 } }, recipeSourceCtx())
    local by = {}
    for _, r in ipairs(rows) do by[r.spell] = r end
    local drops = {}
    for _, row in ipairs(by[4].tip.rows) do if row[1] == "Drops from" then drops[#drops + 1] = row[2] end end
    -- red under: an uncapped list of every creature (a world-drop recipe has scores of them)
    assertEqual(#drops, C.SOURCE_ROWS + 1)
    assertEqual(drops[#drops], ("and %d more"):format(8 - C.SOURCE_ROWS))
    -- red under: the first (lowest id) recipe item kept though it has no known source
    assertEqual(by[8].itemID, 502); assertEqual(by[8].cells.status.text, "Quest reward: Fixture Errand")
    assertEqual(tipRow(by[8], "Other recipe items"), "1")
end)

test("item search cells: Known, Learn at N and No <profession> keep their Status; the last two still open the recipe item", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { crafting = {
        craftRowOf(1, { 501 }, { known = true }),
        craftRowOf(2, { 501 }, { min = 165 }),
        craftRowOf(3, { 502 }, { skillLine = 164, rank = nil }),
        craftRowOf(4, nil, { learned = true }),
    } }
    local rows = C.Crafting(facts, { ranks = { [185] = 100 } }, recipeSourceCtx())
    local by = {}
    for _, r in ipairs(rows) do by[r.spell] = r end
    assertEqual(by[1].cells.status.text, "Known"); assertNil(by[1].itemID, "a known recipe opens nothing")
    assertNil(tipRow(by[1], "Recipe item"))
    -- red under: "Learn at 165" replaced by the source, or the source dropped from its tooltip
    assertEqual(by[2].cells.status.text, "Learn at 165"); assertEqual(by[2].itemID, 501)
    assertEqual(tipRow(by[2], "Sold by"), "Quartermaster · Fixture Vale")
    assertEqual(by[3].cells.status.text, "No Blacksmithing"); assertEqual(by[3].itemID, 502)
    -- red under: a profession you lack reading its recipe item's sources (a cold Rune Thread build reads ~300)
    assertEqual(tipRow(by[3], "Recipe item"), "Item 502"); assertNil(tipRow(by[3], "Quest reward"))
    assertEqual(by[4].cells.status.text, "Not known", "a recipe the profession window learned has no table source")
end)

test("item search cells: SKINNED FROM's Skill: level x 5 above 20, (level - 10) x 10 from 11, red above your rank", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    assertEqual(C.SkinSkill(38), 190); assertEqual(C.SkinSkill(15), 50); assertEqual(C.SkinSkill(8), 1)
    assertNil(C.SkinSkill(nil))
    local rows = C.Skinned({ skinnedFrom = {
        { id = 1, name = "Thunderer", minLevel = 37, maxLevel = 38, chance = 1 },
        { id = 2, name = "Fleshstalker", minLevel = 45, maxLevel = 46, chance = 0.93 },
    } }, { level = 40, ranks = { [C.SKINNING] = 221 } }, {})
    local by = {}
    for _, r in ipairs(rows) do by[r.cells.creature.text] = r end
    assertEqual(by.Thunderer.cells.skill.text, "190"); assertEqual(by.Thunderer.cells.skill.tone, "plain")
    -- red under: a creature you cannot skin yet drawn like one you can
    assertEqual(by.Fleshstalker.cells.skill.text, "230"); assertEqual(by.Fleshstalker.cells.skill.tone, "red")
    assertEqual(tipRow(by.Fleshstalker, "Skinning"), "230 (you 221)")
end)
