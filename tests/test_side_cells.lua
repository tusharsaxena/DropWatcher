-- tests/test_side_cells.lua — the Me and Them cells (feedback-6 spec §1, DW-F1): My eq merged into
-- Me and Their eq into Them, `[icon(s)] [item level] [glyph][difference]`. The pure composers
-- (modules/SideCells.lua) case by case: every verdict kind, two worn items, an empty slot, every
-- inspect state, your own drop's `(Details)`, the merged tooltip and History's verdict alone; then
-- the columns' widths measured over every kind at the harness's character measure, the shed order,
-- and the cells painted headless on the Drops table.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Band]|h|r"
local OLD2 = "|cffa335ee|Hitem:301::|h[Older Band]|h|r"

local NONE = {}

-- A judged drop: an upgrade for you (+19), a downgrade for its looter (-13), the looter inspected
-- 40s before t = 100.
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

-- What you wear: a 292 helm, one ring (the other slot empty), two trinkets 321/308, no cloak.
local MINE = { [1] = { link = OLD1, ilvl = 292 }, [11] = { link = OLD1, ilvl = 300 }, [12] = false,
    [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD2, ilvl = 308 }, [15] = false }
-- What Seta wears: a 324 helm and two trinkets 298/296.
local HERS = { [1] = { link = OLD1, ilvl = 324 }, [13] = { link = OLD1, ilvl = 298 }, [14] = { link = OLD2, ilvl = 296 } }

local TRINKET = { ilvl = 311, equipLoc = "INVTYPE_TRINKET", quality = 4 }

local function SC() return T.newAddon().SideCells end

local function has(tip, line)
    for _, l in ipairs(tip) do if l == line then return true end end
    return false
end

-- ── the composers ───────────────────────────────────────────────────────────────────────────

test("side cells: Me reads the worn level, then the glyph and the unsigned difference in the verdict's tone", function()
    local S = SC()
    local up = S.Me(drop(), MINE)
    assertEqual(up.level, "292"); assertEqual(up.levelTone, "plain", "the item level stays plain")
    assertEqual(up.glyph, "▲"); assertEqual(up.text, "19"); assertEqual(up.tone, "good")
    assertEqual(#up.items, 1); assertEqual(up.items[1].link, OLD1)
    local side = S.Me(drop({ me = { verdict = "sidegrade", ilvlDelta = 0.4, reasons = {} } }), MINE)
    assertEqual(side.glyph .. side.text, "≈0"); assertEqual(side.tone, "yellow")
    local sideDown = S.Me(drop({ me = { verdict = "sidegrade", ilvlDelta = -1, reasons = {} } }), MINE)
    assertEqual(sideDown.glyph .. sideDown.text, "≈1", "no sign: the glyph says which way")
    local down = S.Me(drop({ me = { verdict = "downgrade", ilvlDelta = -8, reasons = {} } }), MINE)
    assertEqual(down.glyph .. down.text, "▽8"); assertEqual(down.tone, "red")
end)

test("side cells: Can't use and Not wanted stay words after the gear, gray", function()
    local S = SC()
    local cant = S.Me(drop({ me = { verdict = "cantUse", reasons = { { key = "armorType" } } } }), MINE)
    assertEqual(cant.level, "292"); assertTrue(cant.glyph == nil); assertEqual(cant.text, "Can't use")
    assertEqual(cant.tone, "bad")
    local unwanted = S.Them(drop({ them = { verdict = "doesntWant", reasons = { { key = "undesired" } } } }), HERS, 100)
    assertEqual(unwanted.level, "324"); assertEqual(unwanted.text, "Not wanted"); assertEqual(unwanted.tone, "bad")
end)

test("side cells: two worn items read both levels and carry both icons", function()
    local S = SC()
    local me = S.Me(drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -8, reasons = {} } }), MINE)
    assertEqual(me.level, "321/308"); assertEqual(#me.items, 2)
    assertEqual(me.glyph .. me.text, "▽8")
    local them = S.Them(drop({ facts = TRINKET, them = { verdict = "upgrade", ilvlDelta = 12, reasons = {} } }), HERS, 100)
    assertEqual(them.level, "298/296"); assertEqual(#them.items, 2); assertEqual(them.glyph .. them.text, "▲12")
end)

test("side cells: nothing worn reads `empty`, muted, and the verdict follows", function()
    local S = SC()
    local cloak = drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_CLOAK", quality = 4 },
        me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } })
    local c = S.Me(cloak, MINE)
    assertEqual(c.level, "empty"); assertEqual(c.levelTone, "muted"); assertEqual(#c.items, 0)
    assertEqual(c.glyph, "▲"); assertEqual(c.text, "", "the gear part already says empty")
    local them = S.Them(drop({ them = NONE }), { [1] = false }, 100)
    assertEqual(them.level, "empty"); assertEqual(them.text, "?", "an unknown verdict empty does not explain")
end)

test("side cells: an unknown verdict's ? goes where the gear part says why, and stays where it does not", function()
    local S = SC()
    local want = { pending = "…", outOfRange = "range", combatParked = "combat", failed = "!", unavailable = "–" }
    for status, word in pairs(want) do
        local c = S.Them(drop({ them = NONE, inspect = { status = status } }), nil, 100)
        assertEqual(c.level, word, status); assertEqual(c.levelTone, "muted", status)
        assertEqual(c.text, "", status .. ": the ? is dropped"); assertTrue(c.glyph == nil)
        assertTrue(#c.tip >= 3, status .. ": the reason is in the tooltip")
    end
    local read = S.Them(drop({ them = NONE }), HERS, 100)
    assertEqual(read.level, "324"); assertEqual(read.text, "?", "the gear is read, the verdict is not")
    local loading = S.Me(drop({ me = NONE }), {})
    assertEqual(loading.level, "…"); assertEqual(loading.text, "")
end)

test("side cells: a dash gear part goes when the verdict says something, and stays alone when it does not", function()
    local S = SC()
    local token = S.Me(drop({ facts = { ilvl = 311, quality = 4 } }), MINE)
    assertTrue(token.level == nil, "no dash before the verdict"); assertEqual(token.glyph .. token.text, "▲19")
    local nothing = S.Me(drop({ facts = { ilvl = 311, quality = 4 }, me = NONE }), MINE)
    assertEqual(nothing.level, "–"); assertEqual(nothing.text, "")
end)

test("side cells: the tooltip is the gear's lines, then the verdict's, a shared line said once", function()
    local S = SC()
    local me = S.Me(drop(), MINE)
    assertEqual(me.tip[1], "You wear"); assertEqual(me.tip[2], "Old Band (292)")
    assertEqual(me.tip[3], "For you: Upgrade")
    local them = S.Them(drop(), HERS, 100)
    assertEqual(them.tip[1], "Seta wears"); assertTrue(has(them.tip, "Inspected 40s ago."), "the read's age")
    assertTrue(has(them.tip, "For Seta: Downgrade"), "the verdict's title")
    local range = S.Them(drop({ them = NONE, inspect = { status = "outOfRange" } }), nil, 100)
    local seen = {}
    for _, l in ipairs(range.tip) do
        assertFalse(seen[l], "said once: " .. l)
        seen[l] = true
    end
    assertTrue(has(range.tip, "For Seta: Unknown"))
end)

test("side cells: your own drop's Them is (Details), in its tones, with every upgrade in the tooltip", function()
    local S = SC()
    local function cand(name, gain)
        return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = "MAGE", status = "ready",
            eval = { verdict = "upgrade", ilvlDelta = gain, baseline = { ilvl = 280 }, reasons = {} } }
    end
    local own = drop({ isMine = true, me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        candidates = { a = cand("Butterz", 11) } })
    local c = S.Them(own, HERS, 100, false)
    assertEqual(c.text, "(Details)"); assertEqual(c.tone, "good"); assertTrue(c.level == nil)
    assertEqual(#c.items, 0, "no worn icons on your own drop"); assertEqual(c.upgrades, 1)
    assertEqual(c.tip[1], "Them")
    local none = S.Them(drop({ isMine = true, me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        candidates = {} }), nil, 100)
    assertEqual(none.text, "(Details)"); assertEqual(none.tone, "muted")
    local kept = S.Them(drop({ isMine = true, candidates = { a = cand("Butterz", 11) } }), nil, 100, false)
    assertEqual(kept.text, "Hidden"); assertTrue(kept.hidden)
    assertEqual(S.Them(drop({ isMine = true, candidates = { a = cand("Butterz", 11) } }), nil, 100, true).text,
        "(Details)", "revealed")
    assertEqual(S.Me(own, MINE).level, "292", "your own drop's Me still shows what you wear")
end)

test("side cells: History's Me and Them are the verdict alone, worded as the Drops table's", function()
    local NS = T.newAddon()
    local WH = NS.WindowHistory
    local d = WH.AsDrop({ itemLink = LINK, looter = "Seta-Realm", class = "PRIEST", ilvl = 311,
        equipLoc = "INVTYPE_HEAD", me = { verdict = "upgrade", ilvlDelta = 6 },
        them = { verdict = "downgrade", ilvlDelta = -8 } }, 1)
    local me, them = WH.Me(d), WH.ThemCell(d)
    assertTrue(me.level == nil, "a kept entry holds no worn items"); assertEqual(#me.items, 0)
    assertEqual(me.glyph .. me.text, "▲6"); assertEqual(them.glyph .. them.text, "▽8")
    assertEqual(me.tip[1], "For you: Upgrade")
    local unread = WH.ThemCell(WH.AsDrop({ itemLink = LINK, looter = "Seta-Realm", ilvl = 311 }, 2))
    assertEqual(unread.text, "?", "shown alone: nothing else says why")
end)

-- ── the widths (measured) ───────────────────────────────────────────────────────────────────

local CHAR = 5   -- the harness's character measure (the small template's average; a glyph is one)

local function chars(s) return #((s or ""):gsub("[\128-\191]", "")) end

-- A cell's width as WindowGroup.PlaceSide lays it out: the icons, then each piece shown after the
-- last with its gap.
local function sideWidth(WG, K, c)
    local S, x, gap = WG.SIDE, 0, 0
    local n = math.min(#c.items, 2)
    if n > 0 then x, gap = n * K.EQ_ICON + (n - 1) * S.ICON_GAP, S.LEVEL_GAP end
    local function add(w, after) x, gap = x + gap + w, after end
    if c.level then add(chars(c.level) * CHAR, S.VERDICT_GAP) end
    if c.glyph then add(CHAR, S.GLYPH_GAP) end
    if c.text ~= "" then add(chars(c.text) * CHAR, 0) end
    return x
end

-- Every kind of cell each column can show, on a two-item slot and a one-item slot.
local VERDICTS = {
    { verdict = "upgrade", ilvlDelta = 13, reasons = {} }, { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
    { verdict = "sidegrade", ilvlDelta = 1, reasons = {} }, { verdict = "cantUse", reasons = {} },
    { verdict = "doesntWant", reasons = {} }, NONE,
}

local function allCells(S)
    local out = { me = {}, them = {} }
    for _, facts in ipairs({ TRINKET, { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 } }) do
        for _, v in ipairs(VERDICTS) do
            out.me[#out.me + 1] = S.Me(drop({ facts = facts, me = v }), MINE)
            out.me[#out.me + 1] = S.Me(drop({ facts = facts, me = v }), {})
            out.them[#out.them + 1] = S.Them(drop({ facts = facts, them = v }), HERS, 100)
            for _, status in ipairs({ "pending", "outOfRange", "combatParked", "failed", "unavailable" }) do
                out.them[#out.them + 1] = S.Them(drop({ facts = facts, them = v, inspect = { status = status } }), nil, 100)
            end
        end
    end
    out.them[#out.them + 1] = S.Them(drop({ isMine = true, candidates = {} }), nil, 100)
    return out
end

test("widths: Me and Them are each their widest cell, measured (two icons, 321/308, then a word)", function()
    local NS = T.newAddon()
    local WG, K = NS.WindowGroup, NS.Constants.WINDOW
    local widest = {}
    for key, cells in pairs(allCells(NS.SideCells)) do
        widest[key] = 0
        for _, c in ipairs(cells) do widest[key] = math.max(widest[key], sideWidth(WG, K, c)) end
    end
    local spec = sideWidth(WG, K, { items = { 1, 2 }, level = "321/308", glyph = "▽", text = "13" })
    assertTrue(widest.me >= spec, "the spec's worst case fits")
    for _, col in ipairs(WG.COLUMNS) do
        if widest[col.key] then assertEqual(col.width, widest[col.key], col.key .. ": nothing cut, no margin") end
    end
    assertEqual(widest.me, 2 * K.EQ_ICON + 2 + 4 + 7 * CHAR + 4 + #"Not wanted" * CHAR, "two icons, 321/308, Not wanted")
end)

test("widths: the column set and the shed order keep Me and Them where the verdict columns sat", function()
    local NS = T.newAddon()
    local WG = NS.WindowGroup
    local keys = {}
    for _, col in ipairs(WG.COLUMNS) do keys[#keys + 1] = col.key end
    assertEqual(table.concat(keys, ","), "item,ilvl,slot,armorType,looter,me,them,trade,tradeWindow,actions")
    local byShed = {}
    for _, col in ipairs(WG.COLUMNS) do if col.shed then byShed[#byShed + 1] = col end end
    table.sort(byShed, function(a, b) return a.shed < b.shed end)
    local order = {}
    for _, col in ipairs(byShed) do order[#order + 1] = col.key end
    assertEqual(table.concat(order, ","), "armorType,slot,looter,tradeWindow,ilvl,them,trade,me")
    for _, col in ipairs(WG.COLUMNS) do
        if col.key == "me" or col.key == "them" then
            assertEqual(col.label, col.key == "me" and "Me" or "Them")
            assertTrue(col.tip:find("wears", 1, true) ~= nil or col.tip:find("wear", 1, true) ~= nil,
                col.key .. "'s tooltip describes the gear half")
            assertTrue(col.tip:find("judged", 1, true) ~= nil, col.key .. "'s tooltip describes the verdict half")
        end
    end
end)

-- ── painted on the Drops table ──────────────────────────────────────────────────────────────

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } }

local function shown(d)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    NS.LootFeed.Groups = function() return { GROUP } end
    NS.LootFeed.Get = function(id) return id == d.id and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.Gear.Snapshot = function() return { equipped = MINE } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn().rows[1]
end

local function textOf(fs) return fs:GetText() end

test("table: the Me cell paints its icons, level, glyph and difference left to right", function()
    local NS, row = shown(drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -8, reasons = {} } }))
    local c, C = row.cells.me, NS.Constants
    assertTrue(c.icons[1]:IsShown() and c.icons[2]:IsShown(), "both worn trinkets")
    assertEqual(textOf(c.level), "321/308"); assertEqual(textOf(c.glyph), "▽"); assertEqual(textOf(c.text), "8")
    assertEqual(c.level.__points[1][2], c.icons[2], "the level after the second icon")
    assertEqual(c.glyph.__points[1][2], c.level, "the glyph after the level")
    assertEqual(c.text.__points[1][2], c.glyph, "the difference after the glyph")
    assertEqual(select(1, c.level:GetTextColor()), C.TONE.plain.r, "the level is plain")
    assertEqual(select(2, c.glyph:GetTextColor()), C.TONE.red.g, "the glyph in the verdict's tone")
    assertEqual(select(2, c.text:GetTextColor()), C.TONE.red.g)
    assertEqual(NS.Window.TooltipOf(c)[1], "You wear")
    assertTrue(row.cells.myEq == nil and row.cells.theirEq == nil, "no eq columns")
    assertEqual(textOf(NS.WindowGroup.Drawn().pane.colHead.labels.me.text), "Me")
end)

test("table: a word starts after the level, and a cell with nothing worn starts at its left edge", function()
    local _, row = shown(drop({ them = NONE, inspect = { status = "outOfRange" } }))
    local c = row.cells.them
    assertFalse(c.icons[1]:IsShown())
    assertEqual(textOf(c.level), "range"); assertEqual(c.level.__points[1][2], c, "at the cell's edge")
    assertEqual(textOf(c.text), "")
    local _, row2 = shown(drop({ me = { verdict = "cantUse", reasons = {} } }))
    local me = row2.cells.me
    assertEqual(textOf(me.text), "Can't use"); assertEqual(textOf(me.glyph), "")
    assertEqual(me.text.__points[1][2], me.level, "the word after the level")
end)
