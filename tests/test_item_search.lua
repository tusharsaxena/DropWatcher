-- tests/test_item_search.lua — Item Search's model, ForeverDB's delayed load and the
-- profession-window learner (DropWatcher#17, Item Search spec §1, §2, §4.2 B, §4.3). Every
-- ForeverDB value here is the kit fake's invented data (tests/_kit/mock_foreverdb.lua) or invented
-- below; the shipped recipe table is Blizzard client DB2 data (core/RecipeReagentsForever.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases cover WoW Forever" or nil

local function IS() return T.newAddon().ItemSearch end

-- ── the pure model ──────────────────────────────────────────────────────────────────────────

test("item search: the skill-up color is orange, yellow, green, gray at the classic breakpoints", function()
    local S = IS()
    assertEqual(S.Green(55, 95), 75, "floor((yellow + gray) / 2)")
    assertEqual(S.Green(30, 61), 45)
    local seen = {}
    for _, rank in ipairs({ 1, 54, 55, 74, 75, 94, 95, 300 }) do seen[#seen + 1] = S.SkillColor(rank, 55, 95) end
    -- red under: a green from yellow + 10, or a gray only past the gray rank
    assertEqual(table.concat(seen, ","), "orange,orange,yellow,yellow,green,green,gray,gray")
    assertNil(S.SkillColor(nil, 55, 95), "no rank: the player lacks the profession")
    assertNil(S.SkillColor(100, 0, 0), "no breakpoints in the table")
    assertNil(S.SkillColor(100, nil, nil), "a learned recipe has none")
end)

test("item search: a race or class mask lets in its bits, and nil or 0 means any", function()
    local S = IS()
    -- 5 = bits 1 and 3
    assertTrue(S.MaskAllows(5, 1)); assertFalse(S.MaskAllows(5, 2)); assertTrue(S.MaskAllows(5, 3))
    assertFalse(S.MaskAllows(5, 4))
    assertTrue(S.MaskAllows(nil, 2)); assertTrue(S.MaskAllows(0, 2)); assertTrue(S.MaskAllows(5, nil))
    assertTrue(S.MaskAllows(2 ^ 10, 11), "a high bit")
end)

test("item search: SF-DW-01's percent and source merge moved here, and the retired chip's module is gone", function()
    local NS = T.newAddon()
    local S = NS.ItemSearch
    assertEqual(S.Percent(0.25), "25%"); assertEqual(S.Percent(0.05), "5.0%"); assertNil(S.Percent(0))
    assertEqual(S.Percent(0.0002), "<0.1%")
    -- red under: modules/ItemSources.lua still loaded (the Sources chip is retired, spec §4.8)
    assertNil(NS.ItemSources, "no Sources chip module")
    local merged = S.MergeSources({ creatures = { { id = 5, chance = 0.25 }, { id = 6 } },
        objects = { { id = 7, chance = 1 } }, items = { { id = 9, chance = 0.25 } } })
    local ids = {}
    for i, s in ipairs(merged) do ids[i] = s.kind .. ":" .. s.id end
    -- red under: an unknown rate sorted before a known one, or a tie broken against creature first
    assertEqual(table.concat(ids, ","), "object:7,npc:5,item:9,npc:6")
    assertEqual(#S.MergeSources(nil), 0); assertEqual(#S.MergeSources("reshaped"), 0)
end)

-- An invented recipe table in the shipped shape: two recipes use reagent 900001.
local function recipes()
    return {
        recipes = {
            [800001] = { skillLine = 171, min = 1, yellow = 55, gray = 95, made = 900101, name = "Invented Draught",
                reagents = { [900001] = 2, [900002] = 1 } },
            [800002] = { skillLine = 129, min = 1, yellow = 30, gray = 60, made = 900102, name = "Invented Wrap",
                reagents = { [900001] = 1 } },
        },
        byReagent = { [900001] = { 800001, 800002 }, [900002] = { 800001 } },
    }
end

test("item search: crafting rows are the table's recipes in its order, then the learned ones it lacks", function()
    local S = IS()
    local learned = {
        [800003] = { skillLine = 197, name = "Invented Cloak", made = 900103, reagents = { [900001] = 4 } },
        [800001] = { skillLine = 171, name = "Stale copy", reagents = { [900001] = 9 } },   -- the table has it
        [800004] = { skillLine = 197, name = "Unrelated", reagents = { [900009] = 1 } },
    }
    local rows = S.CraftingRows(900001, recipes(), learned)
    local got = {}
    for i, r in ipairs(rows) do got[i] = ("%d:%s:%s"):format(r.spell, r.name, tostring(r.count)) end
    -- red under: a learned entry the table covers shown twice, or one for another reagent shown
    assertEqual(table.concat(got, ","), "800001:Invented Draught:2,800002:Invented Wrap:1,800003:Invented Cloak:4")
    assertEqual(rows[1].yellow .. "/" .. rows[1].green .. "/" .. rows[1].gray, "55/75/95")
    assertEqual(rows[1].made, 900101); assertFalse(rows[1].learned); assertTrue(rows[3].learned)
    assertNil(rows[3].yellow, "a learned recipe has no breakpoints")
    assertEqual(#S.CraftingRows(900001, nil, nil), 0, "no table (Retail) and nothing learned")
end)

-- A reader in LibKa0s-ForeverDB-1.0's shape over invented answers, counting every call.
local function fakeDB()
    local db = { calls = 0 }
    local answers = {
        ItemSources = { creatures = { { id = 11, chance = 0.25 }, { id = 12 } }, objects = { { id = 13, chance = 1 } },
            items = { { id = 14, chance = 0.05 } }, vendors = { 15, 16 }, worldMinLevel = 8 },
        QuestsForItem = { { id = 21, title = "Q Any", level = 5 }, { id = 22, title = "Q Race 2", level = 6, races = 2 },
            { id = 23, title = "Q Class 1", level = 7, classes = 1, preQuests = { 21 } } },
        RewardFrom = { { id = 24, title = "Q Reward", level = 9 } },
        StartsQuest = { id = 25, title = "Q Start", level = 10 },
        SkinnedFrom = { { id = 11, name = "Invented Beast", chance = 0.5 }, { id = 17 } },
    }
    local npcs = { [11] = { name = "Invented Beast", minLevel = 10, maxLevel = 12 }, [15] = { name = "Invented Vendor" } }
    local objects = { [13] = { id = 13, name = "Invented Chest" } }
    local items = { [900001] = { id = 900001, name = "Invented Herb", quality = 1, icon = 7 }, [14] = { name = "Invented Box" } }
    local function count(fn) return function(...) db.calls = db.calls + 1; return fn(...) end end
    for name, answer in pairs(answers) do db[name] = count(function() return answer end) end
    db.NPC = count(function(id) return npcs[id] end)
    db.Item = count(function(id) return items[id] end)
    db.Object = count(function(id) return objects[id] end)
    db.VendorPrice = count(function() return 1200, 16 end)
    return db
end

local function staticCtx(db, over)
    local ctx = { fdb = "loaded", db = db, recipes = recipes(), race = 1, class = 2,
        clientItem = function(id) return { id = id, name = "Client Herb", link = "item:" .. id, quality = 2 } end }
    for k, v in pairs(over or {}) do ctx[k] = v end
    return ctx
end

test("item search: the static facts read ForeverDB's drops, vendors, quests and also-rows when loaded", function()
    local S = IS()
    local f = S.Static(900001, staticCtx(fakeDB()))
    local drops = {}
    for i, d in ipairs(f.drops) do drops[i] = ("%s=%s"):format(d.name, tostring(d.chance)) end
    assertEqual(table.concat(drops, ","), "Invented Chest=1,Invented Beast=0.25,Invented Box=0.05,Creature 12=nil")
    assertEqual(f.drops[2].minLevel .. "-" .. f.drops[2].maxLevel, "10-12", "a creature's level range")
    assertTrue(f.drops[2].named); assertTrue(f.drops[1].named, "an object named through Object(id)")
    assertEqual(f.worldMinLevel, 8)
    assertEqual(f.vendors[1].name .. "," .. f.vendors[2].name, "Invented Vendor,Creature 16")
    assertEqual(f.vendorPrice.price .. "@" .. f.vendorPrice.npc, "1200@16")
    local quests = {}
    for i, q in ipairs(f.quests) do quests[i] = q.title end
    -- red under: the race-2 quest kept for a race-1 player, or the class-1 quest dropped for class 2
    assertEqual(table.concat(quests, ","), "Q Any")
    assertEqual(f.rewardFrom[1].title, "Q Reward"); assertEqual(f.startsQuest.title, "Q Start")
    assertEqual(f.skinnedFrom[1].name .. "," .. f.skinnedFrom[2].name, "Invented Beast,Creature 17")
    -- ForeverDB's item row first, the client's fills what it lacks
    assertEqual(f.item.name, "Invented Herb"); assertEqual(f.item.link, "item:900001"); assertEqual(f.item.quality, 1)
    assertEqual(#f.crafting, 2); assertEqual(f.fdb, "loaded")
end)

test("item search: before the load (or without ForeverDB) the reader is never asked; crafting still answers", function()
    local S = IS()
    for _, state in ipairs({ "loading", "missing", "failed", "off" }) do
        local db = fakeDB()
        local f = S.Static(900001, staticCtx(db, { fdb = state }))
        -- red under: a read that asks ForeverDB before Item Search loaded it (spec §2)
        assertEqual(db.calls, 0, state .. ": no ForeverDB read")
        assertEqual(#f.drops + #f.vendors + #f.quests + #f.rewardFrom + #f.skinnedFrom, 0, state)
        assertNil(f.startsQuest); assertEqual(f.fdb, state)
        assertEqual(#f.crafting, 2, state .. ": the shipped table needs no ForeverDB")
        assertEqual(f.item.name, "Client Herb", state .. ": the client's cached item")
    end
    assertNil(S.Static(nil, {})); assertNil(S.Static(0, {})); assertNil(S.Facts("x", {}))
end)

test("item search: the live half adds quest states, known marks, ranks, colors and the drops past the shown", function()
    local S = IS()
    local static = S.Static(900001, staticCtx(fakeDB(), { race = 2, class = 1 }))
    assertEqual(#static.quests, 3, "race 2, class 1: every quest")
    local states = { [21] = "done", [22] = "log" }
    local f = S.Live(static, {
        questState = function(id) return states[id] or "todo" end,
        knows = function(spell) return spell == 800002 end,
        ranks = { [171] = 80 },
        dropsShown = 1,
    })
    local q = {}
    for i, row in ipairs(f.quests) do q[i] = row.id .. "=" .. row.state end
    assertEqual(table.concat(q, ","), "21=done,22=log,23=todo")
    assertEqual(f.quests[3].preQuests[1], 21)
    assertEqual(f.crafting[1].color, "green", "Alchemy 80 against 55/75/95"); assertEqual(f.crafting[1].rank, 80)
    assertFalse(f.crafting[1].known); assertTrue(f.crafting[2].known)
    assertNil(f.crafting[2].color, "no First Aid rank"); assertNil(f.crafting[2].rank)
    assertEqual(f.dropMore, 3, "four sources, one shown")
    assertEqual(S.Live(static, {}).dropMore, 1, "three shown by default")
    -- red under: the live half writing into the cached static facts
    assertNil(static.quests[1].state); assertNil(static.crafting[1].color); assertNil(static.dropMore)
end)

-- ── the profession window's learner (pure) ──────────────────────────────────────────────────

test("item search: the learner keeps only recipes the table lacks, and counts what it changed", function()
    local S = IS()
    local shipped = recipes().recipes
    local learned = {}
    local rows = {
        { spell = 800001, skillLine = 171, reagents = { [900001] = 2 }, name = "In the table" },
        { spell = 800005, skillLine = 197, reagents = { [900001] = 3 }, made = 900105, name = "Invented Robe" },
        { spell = "x", reagents = {} }, { spell = 800006 },
    }
    -- red under: a recipe the shipped table carries written to the account-wide store
    assertEqual(S.Learn.Merge(learned, rows, shipped, "1.60.1.1"), 1)
    assertNil(learned[800001]); assertNil(learned[800006], "no reagents, no entry")
    local e = learned[800005]
    assertEqual(("%d|%d|%d|%s|%s"):format(e.skillLine, e.reagents[900001], e.made, e.name, e.build), "197|3|900105|Invented Robe|1.60.1.1")
    rows[2].reagents[900001] = 7
    assertEqual(e.reagents[900001], 3, "the stored reagents are a copy")
    assertEqual(S.Learn.Merge(learned, { { spell = 800005, skillLine = 197, reagents = { [900001] = 3 }, made = 900105,
        name = "Invented Robe" } }, shipped, "1.60.1.1"), 0, "the same entry again changes nothing")
    assertEqual(S.Learn.Merge(learned, rows, shipped, "1.60.1.1"), 1, "a changed count rewrites it")
    assertEqual(S.Learn.Merge(learned, nil, shipped, "b"), 0); assertEqual(S.Learn.Merge(nil, rows, shipped, "b"), 0)
end)

test("item search: an entry the shipped table now covers is dropped from the learned store", function()
    local S = IS()
    local learned = { [800001] = { reagents = {} }, [800009] = { reagents = {} } }
    assertEqual(S.PruneLearned(learned, recipes().recipes), 1)
    assertNil(learned[800001]); assertTrue(learned[800009] ~= nil)
    assertEqual(S.PruneLearned(learned, nil), 0)
end)

-- ── the client reads (core/CompatSearch.lua) ────────────────────────────────────────────────

local function compat()
    local NS, _, m = T.newAddon()
    m.issecretvalue = function(v) return T.isSecret(v) end
    return NS.Compat, m
end

test("compat search: a quest's log and completion reads, nil for no API or a secret", function()
    local Compat, m = compat()
    m.C_QuestLog = {
        GetLogIndexForQuestID = function(id) if id == 1 then return 4 end if id == 3 then return T.secret(1) end end,
        IsQuestFlaggedCompleted = function(id) return id == 2 end,
    }
    assertTrue(Compat.QuestInLog(1)); assertFalse(Compat.QuestInLog(2)); assertNil(Compat.QuestInLog(3), "secret")
    assertTrue(Compat.QuestDone(2)); assertFalse(Compat.QuestDone(1))
    m.C_QuestLog.GetLogIndexForQuestID = nil
    m.C_QuestLog.IsOnQuest = function(id) return id == 2 end
    assertTrue(Compat.QuestInLog(2), "IsOnQuest's rung")
    m.C_QuestLog = nil
    assertNil(Compat.QuestInLog(1)); assertNil(Compat.QuestDone(1)); assertNil(Compat.QuestInLog(nil))
end)

test("compat search: the skill-line ranks answer a child line under its parent, else the professions", function()
    local Compat, m = compat()
    local lines = {
        { name = "Professions", isHeader = true },
        { name = "Leatherworking", rank = 120, skillID = 2945, parentSkillLineID = 165 },
        { name = "First Aid", rank = 75, skillID = 129 },
        T.secret({}),
    }
    m.C_SkillInfo = { GetNumSkillLines = function() return #lines end, GetSkillLineInfo = function(i) return lines[i] end }
    local r = Compat.SkillLineRanks()
    -- red under: the shipped table's vanilla id 165 missing Forever's child line's rank
    assertEqual(r[165], 120); assertEqual(r[2945], 120); assertEqual(r[129], 75)
    m.C_SkillInfo = nil
    m.GetProfessions = function() return 3, nil, nil, nil, 5 end
    m.GetProfessionInfo = function(i)
        if i == 3 then return "Alchemy", 1, 60, 75, 0, 0, 171 end
        return "Cooking", 1, 10, 75, 0, 0, 185
    end
    r = Compat.SkillLineRanks()
    assertEqual(r[171], 60); assertEqual(r[185], 10)
    m.GetProfessions, m.GetProfessionInfo = nil, nil
    assertNil(Compat.SkillLineRanks(), "no API")
end)

test("compat search: a known spell reads IsPlayerSpell, then C_SpellBook, then IsSpellKnown", function()
    local Compat, m = compat()
    m.IsPlayerSpell, m.IsSpellKnown = nil, nil
    m.C_SpellBook = nil
    assertNil(Compat.SpellKnown(5), "no reader")
    m.IsSpellKnown = function(id) return id == 5 end
    assertTrue(Compat.SpellKnown(5)); assertFalse(Compat.SpellKnown(6))
    m.IsPlayerSpell = function(id) return id == 6 end
    assertTrue(Compat.SpellKnown(6)); assertTrue(Compat.SpellKnown(5), "a later rung still says yes")
    m.IsPlayerSpell = function() return T.secret(true) end
    assertNil(Compat.SpellKnown(7), "a secret answer")
    assertNil(Compat.SpellKnown(nil))
end)

test("compat search: a cached item by id, the build, and the player's race and class ids", function()
    local Compat, m = compat()
    m.C_Item.GetItemInfo = function(id)
        if id == 900001 then return "Invented Herb", "item:900001", 1, 5, 0, "", "", 20, "", 7, 0, 7, 9 end
    end
    local it = Compat.ItemInfoByID(900001)
    assertEqual(("%s|%s|%d|%d|%d|%d|%d"):format(it.name, it.link, it.quality, it.itemLevel, it.icon, it.classID, it.subclassID),
        "Invented Herb|item:900001|1|5|7|7|9")
    assertNil(Compat.ItemInfoByID(900002), "not cached"); assertNil(Compat.ItemInfoByID(0))
    m.GetBuildInfo = function() return "1.60.1", "70938", "Nov 1 2026", 16001 end
    assertEqual(Compat.ClientBuild(), "1.60.1.70938")
    m.GetBuildInfo = nil
    assertNil(Compat.ClientBuild())
    m.UnitRace = function() return "Invented", "Invented", 3 end
    m.UnitClass = function() return "Invented", "INVENTED", 8 end
    local race, class = Compat.PlayerRaceClassIDs()
    assertEqual(race .. "/" .. class, "3/8")
    m.UnitRace, m.UnitClass = nil, nil
    race, class = Compat.PlayerRaceClassIDs()
    assertNil(race); assertNil(class)
end)

-- C_TradeSkillUI over invented recipes: 990901 makes 990950 from two reagents, 990902 has only a
-- modifying slot, 990903 is the shipped Linen Bandage.
local function tradeSkillUI(m)
    m.Enum = m.Enum or {}
    m.Enum.CraftingReagentType = { Modifying = 0, Basic = 1 }
    local schematics = {
        [990901] = { outputItemID = 990950, reagentSlotSchematics = {
            { reagentType = 1, quantityRequired = 2, reagents = { { itemID = 2589 } } },
            { reagentType = 1, quantityRequired = 1, reagents = { { itemID = 990960 } } } } },
        [990902] = { reagentSlotSchematics = { { reagentType = 0, quantityRequired = 1, reagents = { { itemID = 990961 } } } } },
        [3275] = { outputItemID = 1251, reagentSlotSchematics = {
            { reagentType = 1, quantityRequired = 1, reagents = { { itemID = 2589 } } } } },
    }
    m.C_TradeSkillUI = {
        ids = { 990901, 990902, 3275 },
        GetAllRecipeIDs = function() return m.C_TradeSkillUI.ids end,
        GetRecipeSchematic = function(id) return schematics[id] end,
        GetRecipeInfo = function(id) return { name = "Invented Recipe " .. id } end,
        GetTradeSkillLineForRecipe = function(id) if id == 990901 then return 2950, "Child", 129 end return 129 end,
    }
end

test("compat search: the profession window's recipes and their basic reagents", function()
    local Compat, m = compat()
    assertNil(Compat.TradeSkillRecipes(), "no C_TradeSkillUI")
    tradeSkillUI(m)
    local rows = Compat.TradeSkillRecipes()
    assertEqual(#rows, 2, "the modifying-only recipe is left out")
    local r = rows[1]
    assertEqual(("%d|%s|%d|%d|%d|%d"):format(r.spell, r.name, r.skillLine, r.made, r.reagents[2589], r.reagents[990960]),
        "990901|Invented Recipe 990901|129|990950|2|1")
    m.C_TradeSkillUI.ids = {}
    assertEqual(#Compat.TradeSkillRecipes(), 0, "no window open")
end)

-- ── on WoW Forever: the load ────────────────────────────────────────────────────────────────

-- The addon enabled with the kit's ForeverDB fake (`opts`); answers NS, the mock, the fake.
local function enabled(opts)
    local fake
    local NS, _, m = T.enableAddon{ mock = function(mm) fake = FDB.install(mm, opts or { preset = "present" }) end }
    return NS, m, fake
end

test("item search: ForeverDB loads 5 s after the first PLAYER_ENTERING_WORLD, once, and never at login", function()
    local NS, m, fake = enabled()
    local S = NS.ItemSearch
    -- red under: a load at file load or at PLAYER_LOGIN
    assertEqual(fake.loads, 0); assertEqual(S.State(), "loading")
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertTrue((S.LoadPending()), "the timer is armed")
    m.advance(4.9)
    assertEqual(fake.loads, 0, "not before the delay")
    m.advance(0.2)
    assertEqual(fake.loads, 1); assertEqual(S.State(), "loaded")
    m.fireEvent("PLAYER_ENTERING_WORLD", false, false)
    m.advance(10)
    assertEqual(fake.loads, 1, "a zone change arms nothing")
end, FOREVER_ONLY)

test("item search: a load due in combat waits for PLAYER_REGEN_ENABLED", function()
    local NS, m, fake = enabled()
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.inCombat = true
    m.advance(5)
    -- red under: ForeverDB's 12 MB load in combat
    assertEqual(fake.loads, 0); assertEqual(NS.ItemSearch.State(), "loading")
    assertTrue(select(2, NS.ItemSearch.LoadPending()), "it waits for the combat's end")
    m.inCombat = false
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(fake.loads, 1); assertEqual(NS.ItemSearch.State(), "loaded")
end, FOREVER_ONLY)

test("item search: a read before the load never loads, and shows no ForeverDB facts", function()
    local NS, m, fake = enabled()
    local f = NS.ItemSearch.Get(IDS.blade)
    assertEqual(fake.loads, 0, "IS.Get never loads (spec §2)")
    assertEqual(f.fdb, "loading"); assertEqual(#f.drops, 0)
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    f = NS.ItemSearch.Get(IDS.blade)
    assertEqual(f.fdb, "loaded"); assertTrue(#f.drops > 0, "the cache was emptied when the state moved")
end, FOREVER_ONLY)

test("item search: switched off entirely, nothing loads; switched back on, it loads", function()
    local NS, m, fake = enabled()
    local p = NS.addon.db.profile.itemSearch
    p.tooltip.enabled, p.window.enabled = false, false
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(10)
    -- red under: a load for a player who turned Item Search off
    assertEqual(fake.loads, 0); assertEqual(NS.ItemSearch.State(), "off")
    p.window.enabled = true
    assertEqual(NS.ItemSearch.State(), "loading", "the window alone wants it")
    NS.ItemSearch.Refresh()
    assertEqual(fake.loads, 1); assertEqual(NS.ItemSearch.State(), "loaded")
end, FOREVER_ONLY)

test("item search: without ForeverDB the state says so, nothing loads, and crafting still answers", function()
    for _, case in ipairs({ { preset = "missing", before = "missing", after = "failed", loads = 0 },
        { preset = "loadfails", before = "loading", after = "failed", loads = 1 },
        { preset = "reshaped", before = "loading", after = "failed", loads = 1 } }) do
        local NS, m, fake = enabled({ preset = case.preset })
        assertEqual(NS.ItemSearch.State(), case.before, case.preset)
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
        assertEqual(fake.loads, case.loads, case.preset); assertEqual(NS.ItemSearch.State(), case.after, case.preset)
        -- Linen Cloth (2589) is a First Aid reagent in the shipped table
        local f = NS.ItemSearch.Get(2589)
        assertEqual(#f.drops, 0, case.preset); assertTrue(#f.crafting > 0, case.preset .. ": crafting from the table")
    end
end, FOREVER_ONLY)

test("item search: a stand-down takes the timer back and the stand-up arms it again", function()
    local NS, m, fake = enabled()
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    NS.SchemaRuntime.Set("enabled", false)
    m.advance(10)
    assertEqual(fake.loads, 0, "stood down: no load")
    NS.SchemaRuntime.Set("enabled", true)
    m.advance(5)
    assertEqual(fake.loads, 1)
end, FOREVER_ONLY)

-- ── on WoW Forever: the facts against the kit fake ──────────────────────────────────────────

local function loaded(setup)
    local NS, m, fake = enabled()
    if setup then setup(m) end
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m, fake
end

test("item search: the facts read the fake: drops, vendors, the lowest price, the quest it rewards", function()
    local NS = loaded()
    local f = NS.ItemSearch.Get(IDS.blade)
    local drops = {}
    for i, d in ipairs(f.drops) do drops[i] = d.name .. "=" .. tostring(d.chance) end
    assertEqual(table.concat(drops, ","), "Fixture Crate=1,Fixture Gnoll=0.25,Fixture Coffer=0.05,Fixture Kobold=nil")
    assertEqual(f.drops[2].minLevel .. "-" .. f.drops[2].maxLevel, "10-12")
    assertEqual(f.dropMore, 1); assertEqual(f.worldMinLevel, 8)
    assertEqual(f.vendors[1].name .. "," .. f.vendors[2].name, "Fixture Vendor,Fixture Trainer")
    assertEqual(f.vendorPrice.price, 1200); assertEqual(f.vendorPrice.npc, IDS.trainer)
    assertEqual(f.rewardFrom[1].title, "Fixture Errand"); assertEqual(f.item.name, "Fixture Blade")
    assertEqual(NS.ItemSearch.Get(IDS.letter).startsQuest.title, "Fixture Summons")
end, FOREVER_ONLY)

test("item search: the quests are filtered by the player's race and class, each with its live state", function()
    local states = {}
    local NS, m = loaded(function(mm)
        mm.UnitRace = function() return "R", "R", 1 end
        mm.UnitClass = function() return "C", "C", 4 end   -- class 4: the hunt's mask 9 (bits 1 and 4) lets it in
        mm.C_QuestLog = {
            GetLogIndexForQuestID = function(id) if states[id] == "log" then return 2 end end,
            IsQuestFlaggedCompleted = function(id) return states[id] == "done" end,
        }
    end)
    local f = NS.ItemSearch.Get(IDS.leather)
    local q = {}
    for i, row in ipairs(f.quests) do q[i] = row.title .. "=" .. row.state end
    assertEqual(table.concat(q, ","), "Fixture Errand=todo,Fixture Hunt=todo")
    states[IDS.errand], states[IDS.hunt] = "done", "log"
    f = NS.ItemSearch.Get(IDS.leather)
    q = {}
    for i, row in ipairs(f.quests) do q[i] = row.title .. "=" .. row.state end
    -- red under: the quest state cached with the item's facts (spec §4.3: read live)
    assertEqual(table.concat(q, ","), "Fixture Errand=done,Fixture Hunt=log")
    m.UnitRace = function() return "R", "R", 2 end
    NS.ItemSearch.Invalidate()
    q = {}
    for i, row in ipairs(NS.ItemSearch.Get(IDS.leather).quests) do q[i] = row.title end
    -- the errand's race mask 5 (bits 1 and 3) leaves race 2 out
    assertEqual(table.concat(q, ","), "Fixture Hunt")
    local skins = {}
    for i, s in ipairs(f.skinnedFrom) do skins[i] = s.name .. "=" .. tostring(s.chance) end
    assertEqual(table.concat(skins, ","), "Fixture Kobold=0.75,Fixture Gnoll=0.25")
end, FOREVER_ONLY)

test("item search: an item's facts are kept for the session; a repeat read asks ForeverDB nothing", function()
    local NS = loaded()
    NS.ItemSearch.Get(IDS.blade)
    local lib, calls = NS.ForeverDB, 0
    local orig = lib.ItemSources
    lib.ItemSources = function(...) calls = calls + 1; return orig(...) end
    NS.ItemSearch.Get(IDS.blade); NS.ItemSearch.Get(IDS.blade)
    lib.ItemSources = orig
    -- red under: every hover reading the database again
    assertEqual(calls, 0)
end, FOREVER_ONLY)

test("item search: crafting from the shipped table, known through IsPlayerSpell, colored by the rank", function()
    local NS = loaded(function(mm)
        mm.C_SkillInfo = { GetNumSkillLines = function() return 1 end,
            GetSkillLineInfo = function() return { name = "First Aid", rank = 45, skillID = 129 } end }
        mm.IsPlayerSpell = function(id) return id == 3275 end
    end)
    local f = NS.ItemSearch.Get(2589)
    local bandage
    for _, r in ipairs(f.crafting) do if r.spell == 3275 then bandage = r end end
    -- Linen Bandage: First Aid, yellow 30, gray 60 in the shipped table, so green from 45
    assertEqual(bandage.skillLine, 129); assertEqual(bandage.color, "green"); assertEqual(bandage.rank, 45)
    assertTrue(bandage.known)
end, FOREVER_ONLY)

-- ── on WoW Forever: the learner ─────────────────────────────────────────────────────────────

test("item search: the profession window teaches a recipe the table lacks, out of combat, after the burst", function()
    local NS, m = loaded(function(mm)
        tradeSkillUI(mm)
        mm.GetBuildInfo = function() return "1.60.1", "70938" end
    end)
    local S = NS.ItemSearch
    local before = #S.Get(2589).crafting
    m.fireEvent("TRADE_SKILL_SHOW"); m.fireEvent("TRADE_SKILL_LIST_UPDATE")
    assertTrue((S.Learn.Pending()), "one read queued for the burst")
    m.advance(1)
    local store = NS.addon.db.global.itemSearch.learnedRecipes
    assertEqual(store[990901].build, "1.60.1.70938"); assertEqual(store[990901].reagents[2589], 2)
    -- red under: the shipped Linen Bandage written to the account-wide store
    assertNil(store[3275])
    local f = S.Get(2589)
    assertEqual(#f.crafting, before + 1, "the cache was emptied")
    assertTrue(f.crafting[#f.crafting].learned); assertEqual(f.crafting[#f.crafting].spell, 990901)
end, FOREVER_ONLY)

test("item search: a profession read in combat waits for its end; switched off, nothing is read", function()
    local NS, m = loaded(tradeSkillUI)
    local S = NS.ItemSearch
    m.inCombat = true
    m.fireEvent("TRADE_SKILL_SHOW")
    m.advance(1)
    assertNil(NS.addon.db.global.itemSearch and NS.addon.db.global.itemSearch.learnedRecipes[990901])
    assertTrue(select(2, S.Learn.Pending()))
    m.inCombat = false
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(NS.addon.db.global.itemSearch.learnedRecipes[990901] ~= nil)
    local p = NS.addon.db.profile.itemSearch
    p.tooltip.enabled, p.window.enabled = false, false
    NS.addon.db.global.itemSearch.learnedRecipes[990901] = nil
    m.fireEvent("TRADE_SKILL_SHOW")
    m.advance(1)
    -- red under: the window read while Item Search is off (spec §4.2 B)
    assertNil(NS.addon.db.global.itemSearch.learnedRecipes[990901])
end, FOREVER_ONLY)

test("item search: the first read of a session drops learned entries the shipped table covers", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = { global = { itemSearch = { learnedRecipes = {
        [3275] = { skillLine = 129, reagents = { [2589] = 1 } },
        [990901] = { skillLine = 129, reagents = { [2589] = 2 } },
    } } } }
    NS.addon:OnInitialize()
    local store = NS.ItemSearch.Learned()
    assertNil(store[3275], "Linen Bandage is in the table now"); assertTrue(store[990901] ~= nil)
end, FOREVER_ONLY)

-- ── Retail: inert ───────────────────────────────────────────────────────────────────────────

test("item search: on Retail it is inert: no default, no read, no timer, no load, no learner", function()
    local NS, m, fake = enabled()
    local S = NS.ItemSearch
    assertFalse(S.Enabled()); assertFalse(NS.Constants.FEATURE.itemSearch)
    assertNil(NS.C.PROFILE.itemSearch, "no default (clients-§4)")
    assertNil(S.Get(IDS.blade)); assertEqual(S.State(), "client"); assertNil(S.Learned())
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertFalse((S.LoadPending()))
    m.advance(10)
    -- red under: a Retail client asking ForeverDB anything
    assertEqual(fake.loads, 0)
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if row[2]:find("^OnItemSearch") then assertEqual(table.concat(row.clients or {}, ","), "forever", row[2]) end
    end
end, RETAIL_ONLY)

-- ── SF-DW-01's Sources chip, retired (spec §4.8) ─────────────────────────────────────────────

-- A judged drop as the feed records it: a one-hand sword, an upgrade for you, likely tradeable.
local function chipDrop()
    return {
        id = 1, at = 100, link = "|cff1eff00|Hitem:990101::|h[Fixture Blade]|h|r", itemID = IDS.blade, isMine = false,
        sources = { chat = 1 }, situation = "dungeon",
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 15, equipLoc = "INVTYPE_WEAPON", quality = 2, classID = 2, subClassID = 7, bindType = 2,
            stats = { ITEM_MOD_STRENGTH_SHORT = 4 } },
        me = { verdict = "upgrade", ilvlDelta = 5, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 15, 20 }, basis = "inspect", age = 40, rule = "group" },
        inspect = { status = "fresh", at = 60 },
    }
end

test("item search: the detail card draws exactly the cells' chips, ForeverDB installed, and opening it loads nothing", function()
    local fake
    local NS, _, m = T.enableAddon{ mock = function(mm) fake = FDB.install(mm, { preset = "present" }) end }
    m.__now = 100
    local d = chipDrop()
    local group = { key = "run:1", label = "Fixture Hold", kind = "run", situation = "dungeon", at = 90, drops = { d.id } }
    NS.LootFeed.Groups = function() return { group } end
    NS.LootFeed.Get = function(id) if id == d.id then return d end end
    NS.LootFeed.Drops = function() return { d } end
    NS.Inspect.Get = function() return nil end
    NS.TradeHelper.CanTradeWith = function() return false, "range" end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    NS.WindowGroup.ToggleExpand(d.id)
    local card = NS.WindowGroup.Drawn().card
    local shown, want = {}, {}
    for _, c in ipairs(card.chips) do
        if c:IsShown() then shown[#shown + 1] = c.text:GetText() end
    end
    for _, c in ipairs(NS.DetailCells.Chips(d)) do want[#want + 1] = c.text end
    -- red under: SF-DW-01's chip painted after the cells' ("Drops from Fixture Gnoll 25%")
    assertEqual(table.concat(shown, ","), table.concat(want, ","))
    -- red under: the card asking ForeverDB (the first card opened was the 12 MB load)
    assertEqual(fake.loads, 0, "no card loads ForeverDB; only Item Search's timer does")
end)

-- ── objects with names (Item Search feedback spec §2, W15) ──────────────────────────────────

test("item search: same-named objects merge into one row: the highest chance, every id, creatures untouched", function()
    local S = IS()
    local merged = S.MergeNamedObjects({
        { kind = "object", id = 31, chance = 0.4, name = "Invented Chest", ids = { 31 } },
        { kind = "npc", id = 32, chance = 0.5, name = "Invented Chest" },
        { kind = "object", id = 33, chance = 0.6, name = "Invented Chest", ids = { 33 } },
        { kind = "object", id = 34, name = "Invented Chest", ids = { 34 } },
        { kind = "object", id = 35, chance = 0.1, name = "Invented Urn", ids = { 35 } },
    })
    local got = {}
    for i, r in ipairs(merged) do got[i] = ("%s:%d=%s"):format(r.kind, r.id, tostring(r.chance)) end
    -- red under: chances summed (1.0), the lowest kept (0.4), a creature of the same name folded in,
    -- or each spawn id its own row (the owner's six Large Solid Chests)
    assertEqual(table.concat(got, ","), "object:31=0.6,npc:32=0.5,object:35=0.1")
    assertEqual(table.concat(merged[1].ids, ","), "31,33,34", "every part's id, in list order")
    assertNil(merged[2].ids, "a creature carries no ids")
    assertEqual(#S.MergeNamedObjects(nil), 0)
end)

test("item search: an object with no name is dropped and counted, never an Object <id> row", function()
    local S = IS()
    local db = fakeDB()
    db.ItemSources = function()
        return { creatures = {}, objects = { { id = 13, chance = 1 }, { id = 41, chance = 0.9 }, { id = 42 } }, items = {} }
    end
    local f = S.Static(900001, staticCtx(db))
    local names = {}
    for i, d in ipairs(f.drops) do names[i] = d.name end
    -- red under: the stand-in "Object 41" (the owner's W15)
    assertEqual(table.concat(names, ","), "Invented Chest")
    assertEqual(f.unnamedObjects, 2)
    db.Object = nil
    assertEqual(#S.Static(900001, staticCtx(db)).drops, 0, "a reader without Object (minor 2) names none")
end)

test("item search: the fake's strongboxes are one row at the higher chance; the husk and the scrap go", function()
    local NS = loaded()
    local f = NS.ItemSearch.Get(IDS.relic)
    -- red under: the nameless husk (0.9) or scrap (0.8) shown, or two Fixture Strongbox rows
    assertEqual(#f.drops, 1)
    assertEqual(f.drops[1].name, "Fixture Strongbox"); assertEqual(f.drops[1].chance, 0.6)
    assertEqual(table.concat(f.drops[1].ids, ","), IDS.boxB .. "," .. IDS.boxA, "likeliest part first")
    assertEqual(f.unnamedObjects, 2)
end, FOREVER_ONLY)

test("item search: a merged object's window row unions its parts' spots and counts its kinds", function()
    local NS = T.newAddon()
    local ISV = NS.ItemSearchView
    local spots = { [51] = { [7] = { { x = 0.1, y = 0.2 } } }, [52] = { [8] = { { x = 0.3, y = 0.4 }, { x = 0.5, y = 0.6 } } } }
    local rows = ISV.DropRows({ drops = {
        { kind = "object", id = 51, ids = { 51, 52 }, name = "Invented Chest", named = true, chance = 0.5 },
    } }, { spots = function(kind, id) return kind == "object" and spots[id] or nil end,
        mapName = function(map) return "Map " .. map end })
    -- red under: the first part's spots alone (map 7, one spot)
    assertEqual(rows[1].spot.map, 8, "the map with the most spots across both parts")
    assertEqual(rows[1].zone, "Map 8")
    assertEqual(rows[1].kinds, 2)
end)
