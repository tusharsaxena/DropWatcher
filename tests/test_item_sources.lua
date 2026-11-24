-- tests/test_item_sources.lua — where a drop comes from, on the detail card (SF-DW-01,
-- LibKa0s#105): the characterization of the card's header chips first, so the adoption below is
-- measured against what the card drew before it.

local T = _G.DW_TEST
local test, assertEqual = T.test, T.assertEqual

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
