-- tests/test_item_search_rank.lua — what Item Search shows first (Item Search feedback spec §3), the
-- professions you know (§4) and the per-section cap (§7): modules/ItemSearchModel.lua's IS.Rank, the
-- level band, IS.FilterProfessions, IS.Cap and schema step 16 (dropsShown -> rows). Every context and
-- row here is invented: no ForeverDB value, no client data.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): Item Search has no defaults on Retail" or nil

local function IS() return T.newAddon().ItemSearch end

local ZONE, OTHER_ZONE, FAR_ZONE = 101, 102, 201
local CONTINENT, FAR_CONTINENT = 10, 20

-- An invented player: level 30, standing in ZONE on CONTINENT, Alliance; spots from `spots`
-- (`["npc:5"] = { [map] = { { x, y } } }`).
local function me(over)
    local spots = over and over.spotTable or {}
    local ctx = {
        level = 30, mapID = ZONE, continentID = CONTINENT, faction = "A",
        continentOf = function(map) return (map == ZONE or map == OTHER_ZONE) and CONTINENT or FAR_CONTINENT end,
        spots = function(kind, id) return spots[kind .. ":" .. id] end,
    }
    for k, v in pairs(over or {}) do if k ~= "spotTable" then ctx[k] = v end end
    return ctx
end

local function at(map) return { [map] = { { x = 0.5, y = 0.5 } } } end

local function names(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.name end
    return table.concat(out, ",")
end

-- ── the level band ──────────────────────────────────────────────────────────────────────────

test("item search rank: the level band is [level - 5, level + 3], a range overlapping it is in", function()
    local S = IS()
    assertTrue(S.InBand(25, 25, 30), "five below"); assertFalse(S.InBand(24, 24, 30), "six below")
    assertTrue(S.InBand(33, nil, 30), "three above"); assertFalse(S.InBand(34, 36, 30), "four above")
    -- red under: a check of the range's minimum alone (20-26 reaches into the band)
    assertTrue(S.InBand(20, 26, 30), "a wide range reaching in")
    assertFalse(S.InBand(nil, nil, 30)); assertFalse(S.InBand(30, 30, nil))
end)

-- ── drops ───────────────────────────────────────────────────────────────────────────────────

test("item search rank: drops: your zone first, then band creatures with objects and containers, then the rest", function()
    local S = IS()
    local rows = {
        { kind = "npc", id = 1, name = "Far Ogre", minLevel = 50, maxLevel = 52, chance = 0.9 },
        { kind = "npc", id = 2, name = "Band Wolf", minLevel = 28, maxLevel = 29, chance = 0.1 },
        { kind = "object", id = 3, name = "Chest", chance = 0.2 },
        { kind = "item", id = 4, name = "Coffer", chance = 0.05 },
        { kind = "npc", id = 5, name = "Local Rat", minLevel = 60, chance = 0.01 },
        { kind = "object", id = 6, ids = { 6, 7 }, name = "Merged Crate", chance = 0.02 },
    }
    local ranked = S.Rank.drops(rows, me({ spotTable = { ["npc:5"] = at(ZONE), ["object:7"] = at(ZONE),
        ["npc:1"] = at(FAR_ZONE) } }))
    -- red under: chance alone (Far Ogre first), a merged object's second part's spot ignored, or a
    -- creature far above you ranked with the band
    assertEqual(names(ranked), "Merged Crate,Local Rat,Chest,Band Wolf,Coffer,Far Ogre")
    assertEqual(names(rows), "Far Ogre,Band Wolf,Chest,Coffer,Local Rat,Merged Crate", "the input is not reordered")
end)

test("item search rank: drops: within a tier the higher chance first, an unknown chance last, then the name", function()
    local S = IS()
    local ranked = S.Rank.drops({
        { kind = "npc", id = 1, name = "B Unknown", minLevel = 30 },
        { kind = "npc", id = 2, name = "Low", minLevel = 30, chance = 0.05 },
        { kind = "npc", id = 3, name = "A Unknown", minLevel = 30 },
        { kind = "npc", id = 4, name = "High", minLevel = 30, chance = 0.5 },
    }, me())
    assertEqual(names(ranked), "High,Low,A Unknown,B Unknown")
    assertEqual(#S.Rank.drops(nil, nil), 0, "no rows, no context")
end)

-- ── vendors ─────────────────────────────────────────────────────────────────────────────────

test("item search rank: vendors: your zone, your continent, elsewhere, and last the other side's", function()
    local S = IS()
    local ranked = S.Rank.vendors({
        { id = 1, name = "Elsewhere", faction = "AH" },
        { id = 2, name = "Horde Local", faction = "H" },
        { id = 3, name = "Continent", faction = "A" },
        { id = 4, name = "Local" },
        { id = 5, name = "Limited Local", limited = true },
    }, me({ spotTable = { ["npc:1"] = at(FAR_ZONE), ["npc:2"] = at(ZONE), ["npc:3"] = at(OTHER_ZONE),
        ["npc:4"] = at(ZONE), ["npc:5"] = at(ZONE) } }))
    -- red under: a Horde-only vendor in your zone first for an Alliance player, or limited stock
    -- ranked with unlimited
    assertEqual(names(ranked), "Local,Limited Local,Continent,Elsewhere,Horde Local")
    local neutral = S.Rank.vendors({ { id = 2, name = "Horde Local", faction = "H" }, { id = 1, name = "Elsewhere" } },
        me({ faction = "", spotTable = { ["npc:2"] = at(ZONE) } }))
    assertEqual(names(neutral), "Horde Local,Elsewhere", "no side known: nobody is the other side")
end)

-- ── quests ──────────────────────────────────────────────────────────────────────────────────

test("item search rank: quests: in your log, can pick up, too high, completed; the lower level first", function()
    local S = IS()
    local ranked = S.Rank.quests({
        { id = 1, name = "Done", level = 5, minLevel = 1, state = "done" },
        { id = 2, name = "High", level = 40, minLevel = 35 },
        { id = 3, name = "Open B", level = 28, minLevel = 25 },
        { id = 4, name = "Log", level = 50, minLevel = 45 },
        { id = 5, name = "Open A", level = 20 },
    }, me({ questState = function(id) return id == 4 and "log" or "todo" end }))
    -- red under: quest level alone (Done first), or a level-35 quest called pickable at 30
    assertEqual(names(ranked), "Log,Open A,Open B,High,Done")
end)

-- ── crafting ────────────────────────────────────────────────────────────────────────────────

test("item search rank: crafting: known skill-ups orange, yellow, green, then gray, then not known, then other professions", function()
    local S = IS()
    local ranked = S.Rank.crafting({
        { spell = 1, name = "Other Prof", skillLine = 999, known = false, yellow = 100 },
        { spell = 2, name = "Green", skillLine = 171, known = true, color = "green" },
        { spell = 3, name = "Gray", skillLine = 171, known = true, color = "gray" },
        { spell = 4, name = "Far Unknown", skillLine = 171, known = false, yellow = 250 },
        { spell = 5, name = "Orange", skillLine = 171, known = true, color = "orange" },
        { spell = 6, name = "Near Unknown", skillLine = 171, known = false, yellow = 160 },
        { spell = 7, name = "Yellow", skillLine = 171, known = true, color = "yellow" },
        { spell = 8, name = "No Breakpoints", skillLine = 171, known = true },
    }, me({ ranks = { [171] = 150 } }))
    -- red under: the min-skill order (every min is 1), or not-known recipes before known gray ones
    assertEqual(names(ranked), "Orange,Yellow,Green,Gray,No Breakpoints,Near Unknown,Far Unknown,Other Prof")
end)

test("item search rank: crafting: a row with no known mark asks the context, and its color comes from the rank", function()
    local S = IS()
    local ranked = S.Rank.crafting({
        { spell = 11, name = "Unread Gray", skillLine = 171, yellow = 50, gray = 90 },
        { spell = 12, name = "Unread Orange", skillLine = 171, yellow = 200, gray = 240 },
    }, me({ ranks = { [171] = 150 }, known = function() return true end }))
    assertEqual(names(ranked), "Unread Orange,Unread Gray")
end)

-- ── skinned ─────────────────────────────────────────────────────────────────────────────────

test("item search rank: skinned: your zone, then your band, then the rest; the higher chance first", function()
    local S = IS()
    local ranked = S.Rank.skinned({
        { id = 1, name = "Far Bear", minLevel = 55, chance = 0.9 },
        { id = 2, name = "Band Boar", minLevel = 31, chance = 0.3 },
        { id = 3, name = "Local Cat", minLevel = 60, chance = 0.1 },
        { id = 4, name = "Band Hyena", minLevel = 27, chance = 0.6 },
    }, me({ spotTable = { ["npc:3"] = at(ZONE) } }))
    assertEqual(names(ranked), "Local Cat,Band Hyena,Band Boar,Far Bear")
end)

-- ── the professions you know ────────────────────────────────────────────────────────────────

test("item search rank: only the professions you know: the others counted; off, or skills unread, everything passes", function()
    local S = IS()
    local rows = { { spell = 1, skillLine = 171 }, { spell = 2, skillLine = 164 }, { spell = 3, skillLine = 197 },
        { spell = 4 } }
    local kept, hidden = S.FilterProfessions(rows, { [171] = 100 }, true)
    -- red under: the other professions shown, or the hidden ones not counted ("+2 in professions...")
    assertEqual(#kept, 2); assertEqual(kept[1].spell, 1); assertEqual(kept[2].spell, 4, "no skill line passes")
    assertEqual(hidden, 2)
    kept, hidden = S.FilterProfessions(rows, { [171] = 100 }, false)
    assertEqual(#kept, 4); assertEqual(hidden, 0, "the setting off")
    kept, hidden = S.FilterProfessions(rows, nil, true)
    assertEqual(#kept, 4); assertEqual(hidden, 0, "before the skills are read")
    kept, hidden = S.FilterProfessions(rows, {}, true)
    assertEqual(#kept, 4); assertEqual(hidden, 0, "an empty read is an unread one")
    kept, hidden = S.FilterProfessions(rows, { [999] = 1 }, true)
    assertEqual(#kept, 1); assertEqual(hidden, 3, "every recipe filtered: the count stays")
end)

test("item search rank: Ranked filters crafting before ranking it and ranks every section", function()
    local S = IS()
    local facts = {
        drops = { { kind = "npc", id = 1, name = "B", minLevel = 30, chance = 0.1 }, { kind = "npc", id = 2, name = "A", minLevel = 30, chance = 0.2 } },
        vendors = {}, quests = {}, skinnedFrom = {},
        crafting = { { spell = 1, name = "Mine", skillLine = 171, known = true, color = "green" },
            { spell = 2, name = "Theirs", skillLine = 164, known = false } },
    }
    local r = S.Ranked(facts, me({ ranks = { [171] = 100 } }), true)
    assertEqual(names(r.drops), "A,B")
    assertEqual(names(r.crafting), "Mine"); assertEqual(r.craftHidden, 1)
    r = S.Ranked(facts, me({ ranks = { [171] = 100 } }), false)
    assertEqual(names(r.crafting), "Mine,Theirs", "off: the other profession last"); assertEqual(r.craftHidden, 0)
end)

-- ── the cap ─────────────────────────────────────────────────────────────────────────────────

test("item search rank: the cap shows the first n, counts the rest, and clamps n to a whole 1 to 20", function()
    local S = IS()
    local rows = {}
    for i = 1, 25 do rows[i] = { id = i } end
    local shown, more = S.Cap(rows, 5)
    assertEqual(#shown, 5); assertEqual(more, 20); assertEqual(shown[5].id, 5)
    shown, more = S.Cap(rows, 99)
    assertEqual(#shown, 20); assertEqual(more, 5, "20 at most")
    shown, more = S.Cap(rows, 0)
    assertEqual(#shown, 1); assertEqual(more, 24, "1 at least")
    shown, more = S.Cap({ { id = 1 } }, 5)
    assertEqual(#shown, 1); assertEqual(more, 0)
    assertEqual(S.ClampRows("x"), 5); assertEqual(S.ClampRows(7.9), 7); assertEqual(S.TIP_ROWS, 5)
end)

-- ── schema step 16 ──────────────────────────────────────────────────────────────────────────

test("item search rank: step 16 carries a stored dropsShown into rows, and the old key goes", function()
    local NS = T.newAddon()
    _G.DropWatcherDB = {
        global = { schemaVersion = 15 },
        profileKeys = { ["Me - Realm"] = "Default" },
        profiles = {
            Default = { itemSearch = { tooltip = { dropsShown = 8, shiftOnly = true } } },
            Both = { itemSearch = { tooltip = { dropsShown = 2, rows = 12 } } },
            Odd = { itemSearch = { tooltip = { dropsShown = 7.6 } } },
            Bare = { feed = { sort = "oldest" } },
        },
    }
    -- red under: no step 16 (the stored 8 lost to the new default, 5)
    NS.addon:OnInitialize()
    local p = _G.DropWatcherDB.profiles
    assertEqual(p.Default.itemSearch.tooltip.rows, 8); assertNil(p.Default.itemSearch.tooltip.dropsShown)
    assertTrue(p.Default.itemSearch.tooltip.shiftOnly, "the rest stays")
    assertEqual(p.Both.itemSearch.tooltip.rows, 12, "a stored rows wins"); assertNil(p.Both.itemSearch.tooltip.dropsShown)
    assertEqual(p.Odd.itemSearch.tooltip.rows, 7)
    assertNil(p.Bare.itemSearch)
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 16)
    NS.MigrateTipRows(nil); NS.MigrateTipRows({}); NS.MigrateTipRows({ itemSearch = 3 })
end)

test("item search rank: the defaults: rows 5, only the professions you know on, no dropsShown", function()
    local NS = T.newAddon()
    NS.addon:OnInitialize()
    local P = NS.addon.db.profile.itemSearch
    assertEqual(P.tooltip.rows, 5); assertNil(P.tooltip.dropsShown)
    assertTrue(P.myProfessionsOnly)
    assertTrue(NS.ItemSearch.MyProfessionsOnly())
    assertNil(NS.SchemaRuntime.FindRow("itemSearch.tooltip.dropsShown"), "its row is gone")
end, FOREVER_ONLY)
