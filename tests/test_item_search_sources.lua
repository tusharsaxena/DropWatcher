-- tests/test_item_search_sources.lua — Item Search round 3's source work (spec §4.3, items 6 and 7,
-- RECON test-rows option A): a creature's rank as its color, the test-named sources left out, and
-- Gathered from (IS.GatherKind, core/GatherNodes.lua, its tab, its ranking, its tooltip section and
-- schema step 18). Every name and id here is invented, but the curated node names, which are the
-- game's own (core/GatherNodes.lua's header); no ForeverDB row is copied.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the node table is empty on Retail" or nil

local HERB = { name = "Peacebloom", classID = 7, subclassID = 9 }      -- the searched item, a herb
local ORE = { name = "Invented Ore", classID = 7, subclassID = 7 }
local VIAL = { name = "Invented Vial", classID = 12, subclassID = 0 }  -- a quest item

-- ── the test-name filter ────────────────────────────────────────────────────────────────────

test("item search sources: a test or dev name is caught, and a word that only contains \"test\" is not", function()
    local S = T.newAddon().ItemSearch
    for _, name in ipairs({ "TEST Invented Chest", "Invented test object", "Invented Test", "INVENTED (DND)",
        "Invented Wolf UNUSED", "[UNUSED] Invented Smith", "[PH] Invented Guard", "Test" }) do
        assertTrue(S.IsTestSource(name), name)
    end
    -- red under: a bare "test" substring match (Contest, Testament, Attest are real words)
    for _, name in ipairs({ "Contested Banner", "Invented Testament", "Attest", "Testing Totem", "Unused crate",
        "Invented Chest", "" }) do
        assertFalse(S.IsTestSource(name), name)
    end
    assertFalse(S.IsTestSource(nil)); assertFalse(S.IsTestSource(5))
end)

test("item search sources: a quest's giver skips a test-named one for the next", function()
    local NS = T.newAddon()
    local quest = { givers = { { kind = "npc", id = 1 }, { kind = "npc", id = 2 } } }
    local npc = { [1] = { name = "TEST Invented Giver" }, [2] = { name = "Invented Giver" } }
    local rows = NS.ItemSearchCells.Quests({ quests = { { id = 9, title = "Invented Errand", level = 5, state = "todo" } } },
        { level = 5 }, { quest = function() return quest end, npc = function(id) return npc[id] end })
    assertEqual(rows[1].cells.giver.text, "Invented Giver")
end)

-- A reader in LibKa0s-ForeverDB-1.0's shape over invented rows: two herb nodes under one name, a
-- vein, a School, a quest Pool, a chest, a test chest, a test creature, a test vendor and a
-- test-named skinned creature.
local function fakeDB(item)
    local objects = {
        [101] = "Peacebloom", [102] = "Peacebloom", [103] = "Copper Vein", [104] = "School of Invented Fish",
        [105] = "Invented Pool", [106] = "Invented Chest", [107] = "TEST Invented Chest",
    }
    local npcs = {
        [201] = { name = "Invented Elite", rank = 1, minLevel = 20 }, [202] = { name = "TEST Invented Wolf", rank = 0 },
        [203] = { name = "Invented Boss", rank = 3 }, [301] = { name = "Invented Vendor", faction = "A" },
        [302] = { name = "[UNUSED] Invented Vendor", faction = "A" },
    }
    return {
        ItemSources = function() return {
            creatures = { { id = 201, chance = 0.2 }, { id = 202, chance = 0.5 } },
            objects = { { id = 101, chance = 1 }, { id = 102, chance = 0.5 }, { id = 103, chance = 0.4 },
                { id = 104, chance = 0.85 }, { id = 105, chance = 0.1 }, { id = 106, chance = 0.3 }, { id = 107, chance = 0.3 } },
            vendors = { 301, 302 } } end,
        NPC = function(id) return npcs[id] end,
        Object = function(id) return objects[id] and { id = id, name = objects[id] } or nil end,
        Item = function() return item end,
        QuestsForItem = function() return {} end, RewardFrom = function() return {} end, StartsQuest = function() return nil end,
        SkinnedFrom = function() return { { id = 203, name = "Invented Boss", chance = 0.5 },
            { id = 202, name = "TEST Invented Wolf", chance = 0.5 } } end,
        VendorPriceAt = function() return nil, nil end,
    }
end

local function names(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.name end
    return table.concat(out, ",")
end

test("item search sources: a test-named creature, object, vendor and skinned creature are left out and counted", function()
    local S = T.newAddon().ItemSearch
    local f = S.Static(900001, { fdb = "loaded", db = fakeDB(ORE) })
    -- red under: no filter (TWO-SOLUTION TEST and its kind in the drops, the owner's item 6 screenshot)
    assertTrue(names(f.drops):find("TEST", 1, true) == nil, names(f.drops))
    assertEqual(names(f.vendors), "Invented Vendor")
    assertEqual(names(f.skinnedFrom), "Invented Boss")
    assertEqual(f.testSources, 4, "the creature, the chest, the vendor, the skinned creature")
    assertEqual(f.skinnedFrom[1].rank, 3, "a skinned creature carries its rank")
end)

test("item search sources: the test-named count reaches the debug log once per item", function()
    local NS = T.enableAddon{ mock = function(mm) FDB.install(mm, { preset = "present" }) end }
    local logged = {}
    local debug = NS.Debug
    NS.Debug = function(cat, fmt, ...) logged[#logged + 1] = fmt:format(...); return debug(cat, fmt, ...) end
    local IS = NS.ItemSearch
    local static = { id = 900001, item = { name = "Invented" }, testSources = 2, fishingHerbs = 1, unnamedObjects = 0,
        quests = {}, crafting = {} }
    IS.Static = function() return static end
    IS.Get(900001); IS.Get(900001)
    local named, fish = 0, 0
    for _, line in ipairs(logged) do
        if line:find("test-named", 1, true) then named = named + 1 end
        if line:find("fishing node", 1, true) then fish = fish + 1 end
    end
    NS.Debug = debug
    if not IS.Enabled() then return end
    -- red under: a line per hover (the cache keeps the item, so the second Get logs nothing)
    assertEqual(named, 1); assertEqual(fish, 1)
end)

-- ── what gathering an object is ─────────────────────────────────────────────────────────────

test("item search sources: GatherKind files fishing, then mining, then herbalism, else a drop", function()
    local S = T.newAddon().ItemSearch
    assertEqual(S.GatherKind("School of Invented Fish", ORE), "fishing")
    for _, name in ipairs({ "Floating Wreckage", "Floating Debris", "Oil Spill", "Patch of Elemental Water" }) do
        assertEqual(S.GatherKind(name, ORE), "fishing", name)
    end
    -- red under: a bare Pool rule (a quest pool yields quest vials)
    assertEqual(S.GatherKind("Invented Pool", ORE), "fishing", "a pool yielding a non-quest item")
    assertNil(S.GatherKind("Invented Pool", VIAL), "a pool yielding a quest item")
    assertEqual(S.GatherKind("Invented Vein", ORE), "mining"); assertEqual(S.GatherKind("Rich Invented Deposit", ORE), "mining")
    assertEqual(S.GatherKind("Small Obsidian Chunk", ORE), "mining")
    -- the herb rule: the item's own name, class 7 subclass 9
    assertEqual(S.GatherKind("Invented Bloom", { name = "Invented Bloom", classID = 7, subclassID = 9 }), "herbalism")
    assertNil(S.GatherKind("Invented Bloom", { name = "Invented Bloom", classID = 7, subclassID = 7 }), "not a herb")
    assertNil(S.GatherKind("Invented Chest", HERB)); assertNil(S.GatherKind(nil, HERB)); assertNil(S.GatherKind("", HERB))
    -- fishing first: a School that yields a herb is still fishing (ForeverDB's data quirk)
    assertEqual(S.GatherKind("School of Invented Fish", HERB), "fishing")
end)

test("item search sources: the curated nodes name a herb and a vein with their skill; fishing has none", function()
    local NS = T.newAddon()
    local S = NS.ItemSearch
    assertEqual(S.GatherKind("Silverleaf", ORE), "herbalism", "a table herb, whatever the item")
    assertEqual(S.GatherSkill("Peacebloom", "herbalism"), 1); assertEqual(S.GatherSkill("Mageroyal", "herbalism"), 50)
    assertEqual(S.GatherSkill("Copper Vein", "mining"), 1); assertEqual(S.GatherSkill("Mithril Deposit", "mining"), 175)
    assertEqual(S.GatherSkill("Ooze Covered Mithril Deposit", "mining"), 175, "an Ooze Covered vein at its base's value")
    assertNil(S.GatherSkill("Invented Vein", "mining"), "a vein the table lacks")
    assertNil(S.GatherSkill("Peacebloom", "fishing")); assertNil(S.GatherSkill("Peacebloom", "mining"), "the wrong profession")
    local herbs, veins = 0, 0
    for _, node in pairs(NS.GatherNodes) do
        if node.prof == "herbalism" then herbs = herbs + 1 elseif node.prof == "mining" then veins = veins + 1 end
    end
    -- red under: a table entry the build has no object for (the 9 absent Ooze Covered names)
    assertEqual(herbs, 28); assertEqual(veins, 21)
end, FOREVER_ONLY)

test("item search sources: the gathering nodes leave the drops, one row per name, each with its profession and skill", function()
    local S = T.newAddon().ItemSearch
    local f = S.Static(2447, { fdb = "loaded", db = fakeDB(HERB) })
    -- red under: nodes still in Drops from (the owner's item 7)
    assertEqual(names(f.drops), "Invented Chest,Invented Elite")
    assertEqual(names(f.gathered), "Peacebloom,School of Invented Fish,Copper Vein,Invented Pool")
    local by = {}
    for _, g in ipairs(f.gathered) do by[g.name] = g end
    assertEqual(by.Peacebloom.gather, "herbalism"); assertEqual(by.Peacebloom.skill, T.forever and 1 or nil)
    assertEqual(#by.Peacebloom.ids, 2, "merged per name"); assertEqual(by.Peacebloom.chance, 1, "the higher chance")
    assertEqual(by["Copper Vein"].gather, "mining"); assertEqual(by["School of Invented Fish"].gather, "fishing")
    assertNil(by["School of Invented Fish"].skill, "no fishing skill on this client")
    assertEqual(f.fishingHerbs, 2, "the School and the Pool yield this herb")
    assertEqual(#S.Static(2447, { fdb = "missing" }).gathered, 0, "no ForeverDB: no nodes")
end)

-- ── the ranking ─────────────────────────────────────────────────────────────────────────────

test("item search sources: Gathered from ranks a profession you have at your skill, then above it, then one you lack", function()
    local S = T.newAddon().ItemSearch
    local rows = {
        { id = 1, name = "A Lacked", gather = "mining", skill = 1, chance = 1 },
        { id = 2, name = "B High", gather = "herbalism", skill = 200, chance = 1 },
        { id = 3, name = "C Low", gather = "herbalism", skill = 1, chance = 0.5 },
        { id = 4, name = "D Unknown", gather = "herbalism", chance = 0.9 },
        { id = 5, name = "E Here", gather = "herbalism", skill = 1, chance = 0.1 },
        { id = 6, name = "F Rateless", gather = "herbalism", skill = 1 },
    }
    local spots = function(_, id) if id == 5 then return { [10] = { { x = 0.5, y = 0.5 } } } end end
    local me = { ranks = { [182] = 100 }, mapID = 10, spots = spots }
    -- red under: chance before zone, an unknown skill read as too high, or a lacked profession first
    assertEqual(names(S.Rank.gathered(rows, me)), "E Here,D Unknown,C Low,F Rateless,B High,A Lacked")
    -- before the skills are read, every row is the first tier
    assertEqual(names(S.Rank.gathered(rows, { mapID = 10, spots = spots })), "E Here,A Lacked,B High,D Unknown,C Low,F Rateless")
    assertEqual(#S.Ranked({ gathered = rows }, me).gathered, 6)
end)

-- ── the tab ─────────────────────────────────────────────────────────────────────────────────

local function keys(cols)
    local out = {}
    for i, c in ipairs(cols) do out[i] = c.key end
    return table.concat(out, ",")
end

test("item search sources: the Gathered from tab sits after Drops from with its columns and filters", function()
    local TABS = T.newAddon().ItemSearchTabs
    assertEqual(table.concat(TABS.ORDER, ","), "drops,gathered,vendors,quests,crafting,skinned")
    local def = TABS.DEF.gathered
    assertEqual(def.title, "Gathered from"); assertEqual(def.one .. "/" .. def.many, "node/nodes")
    assertEqual(keys(def.columns), "node,profession,skill,zone,chance,pin")
    assertEqual(TABS.Column("gathered", "profession").w, 90); assertEqual(TABS.Column("gathered", "skill").w, 64)
    local f = {}
    for i, flt in ipairs(def.filters) do f[i] = flt.key end
    assertEqual(table.concat(f, ","), "herbalism,mining,fishing,mine,zone")
    local rows = { { best = 1, gather = "herbalism", mine = true, here = false, sort = {} },
        { best = 2, gather = "mining", mine = false, here = true, sort = {} },
        { best = 3, gather = "fishing", mine = true, here = true, sort = {} } }
    local st = TABS.DefaultState("gathered")
    assertEqual(#TABS.View("gathered", rows, st), 3, "every row by default")
    st.filters.mining = false
    local shown = TABS.View("gathered", rows, st)
    assertEqual(#shown, 2, "Mining off")
    st.filters.mine, st.filters.zone = true, true
    shown = TABS.View("gathered", rows, st)
    assertEqual(#shown, 1); assertEqual(shown[1].gather, "fishing", "my professions, in my zone")
    assertTrue(TABS.Narrowed("gathered", st))
end)

test("item search sources: Gathered from's rows: the node, its profession, its skill against yours, zone and chance", function()
    local NS = T.newAddon()
    local C = NS.ItemSearchCells
    local facts = { gathered = {
        { kind = "object", id = 1, ids = { 1, 2, 3 }, name = "Peacebloom", gather = "herbalism", skill = 1, chance = 1 },
        { kind = "object", id = 4, name = "Invented Deposit", gather = "mining", skill = 230, chance = 0.4 },
        { kind = "object", id = 5, name = "Invented Vein", gather = "mining", chance = 0.3 },
        { kind = "object", id = 6, name = "School of Invented Fish", gather = "fishing", chance = 0.85 },
    } }
    local spots = function(_, id) if id == 2 then return { [10] = { { x = 0.4, y = 0.6 } } } end end
    local rows = C.Gathered(facts, { ranks = { [182] = 50, [186] = 100 }, mapID = 10, spots = spots },
        { spots = spots, mapName = function() return "Vale" end })
    local by = {}
    for _, r in ipairs(rows) do by[r.cells.node.text] = r end
    assertEqual(by.Peacebloom.cells.profession.text, "Herbalism"); assertEqual(by.Peacebloom.cells.skill.text, "1")
    assertEqual(by.Peacebloom.cells.skill.tone, "plain")
    -- red under: a node above your rank not in red
    assertEqual(by["Invented Deposit"].cells.skill.text, "230"); assertEqual(by["Invented Deposit"].cells.skill.tone, "red")
    assertEqual(by["Invented Vein"].cells.skill.text, "?", "a node the table lacks")
    assertEqual(by["School of Invented Fish"].cells.skill.text, "–"); assertEqual(by["School of Invented Fish"].cells.skill.tone, "muted")
    assertFalse(by["School of Invented Fish"].mine, "no Fishing rank")
    assertTrue(by.Peacebloom.here, "a merged node's spots are the union of its parts")
    assertEqual(by.Peacebloom.cells.zone.text, "Vale")
    local merged
    for _, row in ipairs(by.Peacebloom.tip.rows) do if row[1] == "Merged" then merged = row[2] end end
    assertEqual(merged, "3 kinds of Peacebloom")
    assertEqual(rows[1].cells.node.text, "Peacebloom", "best for you first")
    assertEqual(#C.Build({ gathered = facts.gathered }, {}, {}).gathered, 4)
end)

-- ── the rank colors (item 6) ────────────────────────────────────────────────────────────────

test("item search sources: a creature's color is its rank's, the same in the cells and the tooltip", function()
    local NS = T.newAddon()
    local S, C = NS.ItemSearch, NS.ItemSearchCells
    assertEqual(S.RankTone(0), "plain"); assertEqual(S.RankTone(nil), "plain"); assertEqual(S.RankTone(1), "rankElite")
    assertEqual(S.RankTone(4), "rankRare"); assertEqual(S.RankTone(2), "rankRareElite"); assertEqual(S.RankTone(3), "rankBoss")
    local T0 = NS.Constants.TONE
    assertEqual(T0.rankElite.r .. "," .. T0.rankElite.g .. "," .. T0.rankElite.b, "1,0.82,0", "#FFD100")
    assertEqual(T0.rankBoss.b, 1); assertEqual(T0.rankRare.b, 0.86); assertEqual(T0.rankRareElite.r, 0.62)
    local rows = C.Skinned({ skinnedFrom = { { id = 1, name = "Invented Boss", rank = 3, chance = 0.5 } } }, {}, {})
    assertEqual(rows[1].cells.creature.tone, "rankBoss", "Skinned from's Creature cell too")
end)

-- ── the tooltip ─────────────────────────────────────────────────────────────────────────────

local function enabled()
    local tdp
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        tdp = TDP.install(mm)
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
    end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m, tdp
end

test("item search sources: the tooltip's Gathered from section, after Drops from, capped by Rows per section", function()
    local NS = T.newAddon()
    local IST = NS.ItemSearchTip
    assertEqual(table.concat(IST.ORDER, ","), "drops,gathered,vendors,quests,crafting,skinned,also")
    assertTrue(IST.SECTIONS.gathered)
    local facts = { drops = {}, vendors = {}, quests = {}, crafting = {}, skinnedFrom = {}, rewardFrom = {}, gathered = {
        { kind = "object", id = 1, name = "Peacebloom", gather = "herbalism", skill = 1, chance = 1 },
        { kind = "object", id = 2, name = "School of Invented Fish", gather = "fishing", chance = 0.85 },
    } }
    local o = { order = IST.ORDER, sections = IST.SECTIONS, rows = 1, header = false }
    local lines = IST.Lines(facts, o, nil, { ranks = { [182] = 75 } })
    local text = {}
    for i, l in ipairs(lines) do text[i] = l.text .. (l.right and (" | " .. l.right) or "") end
    assertEqual(text[2], "Gathered from")
    assertTrue(text[3]:find("^  Peacebloom | Herbalism ") ~= nil, text[3])
    assertTrue(text[3]:find("· 100%", 1, true) ~= nil, "the chance on the right")
    assertEqual(text[4], "  and 1 more", "capped at one row")
    o.rows = 2
    lines = IST.Lines(facts, o, nil, { ranks = {} })
    assertEqual(lines[4].right, "Fishing · 85%", "fishing: no skill")
    o.sections = { gathered = false }
    assertEqual(#IST.Lines(facts, o, nil, {}), 0, "the section switched off")
end)

test("item search sources: the tooltip draws a creature's name in its rank's color", function()
    local NS = T.newAddon()
    local IST = NS.ItemSearchTip
    local facts = { vendors = {}, quests = {}, crafting = {}, rewardFrom = {}, gathered = {},
        drops = { { kind = "npc", id = 1, name = "Invented Elite", named = true, rank = 1, chance = 0.5 },
            { kind = "object", id = 2, name = "Invented Chest", named = true, chance = 0.4 } },
        skinnedFrom = { { id = 3, name = "Invented Rare", rank = 4, chance = 0.5 } } }
    local lines = IST.Lines(facts, { order = IST.ORDER, sections = IST.SECTIONS, rows = 5, header = false }, nil, {})
    local tone = {}
    for _, l in ipairs(lines) do tone[l.text] = l.tone end
    assertEqual(tone["  Invented Elite"], "rankElite"); assertEqual(tone["  Invented Chest"], "plain")
    assertEqual(tone["  Invented Rare"], "rankRare")
end)

test("item search sources: on WoW Forever a hovered herb's Gathered from section comes from the kit fake", function()
    local _, _, tdp = enabled()
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    -- the kit's objects are a crate and a coffer: no gathering node, so no section
    for _, line in ipairs(tdp.texts(tip)) do assertTrue(line ~= "Gathered from", "no nodes for the blade") end
end, FOREVER_ONLY)

-- ── schema step 18 ──────────────────────────────────────────────────────────────────────────

test("item search sources: step 18 puts Gathered from after Drops from in a stored order, once", function()
    local NS = T.newAddon()
    local p = { itemSearch = { tooltip = { order = { "quests", "drops", "vendors" } } } }
    NS.MigrateGatheredSection(p)
    assertEqual(table.concat(p.itemSearch.tooltip.order, ","), "quests,drops,gathered,vendors")
    NS.MigrateGatheredSection(p)
    assertEqual(table.concat(p.itemSearch.tooltip.order, ","), "quests,drops,gathered,vendors", "idempotent")
    local q = { itemSearch = { tooltip = { order = { "vendors", "quests" } } } }
    NS.MigrateGatheredSection(q)
    assertEqual(table.concat(q.itemSearch.tooltip.order, ","), "vendors,quests,gathered", "no drops: at the end")
    local r = { itemSearch = { tooltip = { rows = 3 } } }
    NS.MigrateGatheredSection(r)
    assertNil(r.itemSearch.tooltip.order, "no stored order: the default is read")
    NS.MigrateGatheredSection(nil); NS.MigrateGatheredSection({}); NS.MigrateGatheredSection({ itemSearch = 1 })
    assertEqual(NS.MIGRATIONS[18].to, 18)
end)
