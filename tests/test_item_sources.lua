-- tests/test_item_sources.lua — where a drop comes from, on the detail card (SF-DW-01,
-- LibKa0s#105): the characterization of the card's header chips first, so the adoption below is
-- measured against what the card drew before it.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LINK = "|cff1eff00|Hitem:990101::|h[Fixture Blade]|h|r"

-- A judged drop as the feed records it: a one-hand sword, an upgrade for you, likely tradeable.
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, itemID = 990101, isMine = false, sources = { chat = 1 }, situation = "dungeon",
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 15, equipLoc = "INVTYPE_WEAPON", quality = 2, classID = 2, subClassID = 7, bindType = 2,
            stats = { ITEM_MOD_STRENGTH_SHORT = 4 } },
        me = { verdict = "upgrade", ilvlDelta = 5, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 15, 20 }, basis = "inspect", age = 40, rule = "group" },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- The Drops table shown with one drop, its card open. Answers NS, the card and the mock.
local function openCard(opts, d)
    local NS, _, m = T.enableAddon(opts)
    m.__now = 100
    d = d or drop()
    local group = { key = "run:1", label = "Fixture Hold", kind = "run", situation = "dungeon", at = 90, drops = { d.id } }
    NS.LootFeed.Groups = function() return { group } end
    NS.LootFeed.Get = function(id) if id == d.id then return d end end
    NS.LootFeed.Drops = function() return { d } end
    NS.Inspect.Get = function() return nil end
    NS.TradeHelper.CanTradeWith = function() return false, "range" end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    NS.WindowGroup.ToggleExpand(d.id)
    return NS, NS.WindowGroup.Drawn().card, m, d
end

-- The shown chips' texts, `,`-joined.
local function shownChips(card)
    local out = {}
    for _, c in ipairs(card.chips) do
        if c:IsShown() then out[#out + 1] = c.text:GetText() end
    end
    return table.concat(out, ",")
end

local function chipTexts(list)
    local out = {}
    for _, c in ipairs(list) do out[#out + 1] = c.text end
    return table.concat(out, ",")
end

-- ── characterization: the header before the adoption ────────────────────────────────────────

test("item sources: characterization, the card's header draws exactly the cells' chips", function()
    local NS, card, _, d = openCard()
    -- red under: a chip painted that NS.DetailCells.Chips did not compose
    assertEqual(shownChips(card), chipTexts(NS.DetailCells.Chips(d)))
end)

-- ── the pure model and chip ─────────────────────────────────────────────────────────────────

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case below asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases above cover WoW Forever" or nil

local function IS() return T.newAddon().ItemSources end

-- A name reader for the pure cases: `npc:990001`.
local function names(kind, id) return ("%s:%d"):format(kind, id) end

test("item sources: a chance reads as a whole percent from 10%, one decimal below, <0.1% under that", function()
    local S = IS()
    assertEqual(S.Percent(1), "100%"); assertEqual(S.Percent(0.25), "25%"); assertEqual(S.Percent(0.1), "10%")
    assertEqual(S.Percent(0.05), "5.0%"); assertEqual(S.Percent(0.001), "0.1%"); assertEqual(S.Percent(0.0002), "<0.1%")
    -- red under: an unknown rate (the database's 0, the library's nil) printed as 0%
    assertNil(S.Percent(nil)); assertNil(S.Percent(0)); assertNil(S.Percent("25"))
end)

test("item sources: the model merges creatures, objects and containers, most likely first, top three", function()
    local S = IS()
    local m = S.Model({
        creatures = { { id = 5, chance = 0.25 }, { id = 6, chance = nil } },
        objects = { { id = 7, chance = 1 } }, items = { { id = 8, chance = 0.05 }, { id = 9, chance = 0.25 } },
        vendors = { 11, 12, 13, 14, 15 }, worldMinLevel = 8,
    }, names)
    local top = {}
    for i, s in ipairs(m.top) do top[i] = s.name .. "=" .. tostring(s.chance) end
    -- red under: each list kept apart, or a tie broken by the list's order rather than creature first
    assertEqual(table.concat(top, ","), "object:7=1,npc:5=0.25,item:9=0.25")
    assertEqual(m.more, 2, "the 5% container and the unknown rate are past the top three")
    assertEqual(table.concat(m.vendors, ","), "npc:11,npc:12,npc:13"); assertEqual(m.vendorMore, 2)
    assertEqual(m.worldMinLevel, 8)
end)

test("item sources: nothing to say is no model; a vendor or a world level alone is one", function()
    local S = IS()
    assertNil(S.Model(nil, names)); assertNil(S.Model("reshaped", names))
    assertNil(S.Model({ creatures = {}, objects = {}, items = {}, vendors = {} }, names))
    assertEqual(S.Model({ vendors = { 3 } }, names).vendors[1], "npc:3")
    assertEqual(S.Model({ worldMinLevel = 20 }, names).worldMinLevel, 20)
end)

test("item sources: the chip reads the likeliest source, else the vendor, else World drop", function()
    local S = IS()
    local P = T.tipPlainJoined
    local full = S.Chip(S.Model({ creatures = { { id = 5, chance = 0.25 }, { id = 6 } }, vendors = { 11 }, worldMinLevel = 8 }, names))
    assertEqual(full.text, "Drops from npc:5 25%")
    assertEqual(P(full.tip), "Where it comes from | • npc:5: 25% | • npc:6: rate unknown | • World drop: from level 8"
        .. " | • Sold by: npc:11 | From the ForeverDB addon.")
    assertEqual(S.Chip(S.Model({ creatures = { { id = 6 } } }, names)).text, "Drops from npc:6", "no rate, no percent")
    assertEqual(S.Chip(S.Model({ vendors = { 11, 12, 13, 14 } }, names)).text, "Sold by npc:11")
    assertEqual(P(S.Chip(S.Model({ vendors = { 11, 12, 13, 14 } }, names)).tip),
        "Where it comes from | • Sold by: npc:11, npc:12, npc:13 and 1 more | From the ForeverDB addon.")
    assertEqual(S.Chip(S.Model({ worldMinLevel = 20 }, names)).text, "World drop")
    assertNil(S.Chip(nil))
end)

test("item sources: the headline names the likeliest named source; an unnamed object never leads by its id", function()
    local S = IS()
    -- objects have no name in the library's version 1: the reader says so with a false second answer
    local function stand(kind, id)
        if kind == "object" then return ("Object %d"):format(id), false end
        return ("%s:%d"):format(kind, id)
    end
    local m = S.Model({ creatures = { { id = 5, chance = 0.25 } }, objects = { { id = 7, chance = 1 } } }, stand)
    -- red under: the 100% object leading as `Drops from Object 7 100%`
    assertEqual(S.Chip(m).text, "Drops from npc:5 25%")
    assertEqual(T.tipPlainJoined(S.Chip(m).tip),
        "Where it comes from | • Object 7: 100% | • npc:5: 25% | From the ForeverDB addon.", "the tooltip keeps the order and the id")
    assertEqual(S.Chip(S.Model({ objects = { { id = 7, chance = 1 } } }, stand)).text, "Drops from an object 100%")
    assertEqual(S.Chip(S.Model({ creatures = { { id = 5, chance = 0.5 } } }, function(_, id)
        return ("Creature %d"):format(id), false end)).text, "Drops from Creature 5 50%", "an unnamed creature keeps its stand-in")
end)

-- ── the card, on WoW Forever, against the kit's ForeverDB fake ─────────────────────────────

-- The card opened with the fake installed before the addon loads; answers NS, the card, the fake.
local function withFake(opts, d)
    local fake
    local NS, card = openCard({ mock = function(m) fake = FDB.install(m, opts) end }, d)
    return NS, card, fake
end

local function lastChip(card)
    local last
    for _, c in ipairs(card.chips) do if c:IsShown() then last = c end end
    return last
end

test("item sources: with ForeverDB, the card's last chip says where it comes from; opening it is the load", function()
    local fake
    local NS = T.enableAddon{ mock = function(m) fake = FDB.install(m, { preset = "present" }) end }
    -- red under: a lookup at file load or at login (the 12 MB load before anyone asked)
    assertEqual(fake.loads, 0, "nothing loads ForeverDB at login")
    assertEqual(NS.ForeverDB.MAJOR, "LibKa0s-ForeverDB-1.0", "the live library, not the stand-in")
    local card
    NS, card, fake = withFake({ preset = "present" })
    assertEqual(fake.loads, 1, "the first card opened loads it, once")
    local chip = lastChip(card)
    -- the crate (an object, no name in the library's version 1) leads the tooltip, not the headline
    assertEqual(chip.text:GetText(), "Drops from Fixture Gnoll 25%")
    assertEqual(T.tipPlainJoined(NS.Window.TooltipOf(chip)), ("Where it comes from | • Object %d: 100%% | • Fixture Gnoll: 25%%"
        .. " | • Fixture Coffer: 5.0%% | • and 1 more | • World drop: from level 8 | • Sold by: Fixture Vendor, Fixture Trainer"
        .. " | From the ForeverDB addon."):format(IDS.crate))
    -- red under: a chip that replaces one of the cells' chips rather than following them
    local d = NS.LootFeed.Get(1)
    assertEqual(shownChips(card), chipTexts(NS.DetailCells.Chips(d)) .. "," .. chip.text:GetText())
    NS.Window.Refresh()
    assertEqual(fake.loads, 1, "a repaint does not load it again")
end, FOREVER_ONLY)

test("item sources: an item ForeverDB names no source for draws the header it always drew", function()
    local NS, card, fake = withFake({ preset = "present" }, drop({ itemID = IDS.pebble, link = "|cff9d9d9d|Hitem:990102::|h[Fixture Pebble]|h|r" }))
    assertEqual(fake.loads, 1)
    assertEqual(shownChips(card), chipTexts(NS.DetailCells.Chips(NS.LootFeed.Get(1))))
end, FOREVER_ONLY)

for _, case in ipairs({
    { preset = "missing", loads = 0, why = "not installed: nothing to load" },
    { preset = "loadfails", loads = 1, why = "disabled in the addon list: the load is refused" },
    { preset = "reshaped", loads = 1, why = "a ForeverDB global that is not a table" },
}) do
    test("item sources: without ForeverDB (" .. case.preset .. ") the card draws its header unchanged", function()
        local NS, card, fake = withFake({ preset = case.preset })
        assertEqual(fake.loads, case.loads, case.why)
        -- red under: a chip that says nothing, or a lookup that raises on the reshaped database
        assertEqual(shownChips(card), chipTexts(NS.DetailCells.Chips(NS.LootFeed.Get(1))), case.why)
    end, FOREVER_ONLY)
end

test("item sources: the switch off shows no chip and never loads ForeverDB", function()
    local fake
    local NS = T.enableAddon{ mock = function(m) fake = FDB.install(m, { preset = "present" }) end }
    NS.SchemaRuntime.Set("window.itemSources", false)
    assertNil(NS.ItemSources.For(IDS.blade))
    assertEqual(fake.loads, 0, "the switch is read before the library")
    NS.SchemaRuntime.Set("window.itemSources", true)
    assertTrue(NS.ItemSources.For(IDS.blade) ~= nil); assertEqual(fake.loads, 1)
end, FOREVER_ONLY)

test("item sources: the row is Window > Layout > Detail card, on by default, and says it needs ForeverDB", function()
    local NS = T.newAddon()
    local row = NS.SchemaRuntime.FindRow("window.itemSources")
    assertEqual(row.page .. ">" .. row.group .. ">" .. row.subgroup, "window>Layout>Detail card")
    assertEqual(row.default, true); assertEqual(table.concat(row.clients, ","), "forever")
    assertTrue(row.tooltip:find("Needs the ForeverDB addon", 1, true) ~= nil, row.tooltip)
end, FOREVER_ONLY)

-- ── Retail: inert ───────────────────────────────────────────────────────────────────────────

test("item sources: on Retail the feature is inert: no row, no default, no chip, no load", function()
    local NS, card, fake = withFake({ preset = "present" })
    assertFalse(NS.Constants.FEATURE.itemSources)
    assertNil(NS.SchemaRuntime.FindRow("window.itemSources")); assertNil(NS.C.PROFILE.window.itemSources)
    assertNil(NS.ItemSources.For(IDS.blade))
    -- red under: a Retail card that asks ForeverDB (the library answers "client", but nothing should ask)
    assertEqual(fake.loads, 0)
    assertEqual(shownChips(card), chipTexts(NS.DetailCells.Chips(NS.LootFeed.Get(1))))
end, RETAIL_ONLY)
