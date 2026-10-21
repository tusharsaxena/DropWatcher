-- tests/test_side_cells.lua — the Me and Them cells (feedback-6 spec §1, DW-F1): My eq merged into
-- Me and Their eq into Them, `[icon(s)] [item level] [glyph][difference]`. The pure composers
-- (modules/SideCells.lua) case by case: every verdict kind, two worn items, an empty slot, every
-- inspect state, your own drop's `Upgrade for N`, the merged tooltip and History's verdict alone, and
-- the Offer panel's Their eq cell (feedback-7 spec §0, SC.Candidate); then the columns' widths
-- measured over every kind at the harness's character measure (the Offer panel's Their eq too), the
-- shed order, and the cells painted headless on the Drops table.

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

-- Whether the tooltip carries `line`, read plain (a row's colors out: feedback-21).
local function has(tip, line)
    for _, l in ipairs(tip) do if l == line or T.tipPlain(l) == line then return true end end
    return false
end
local P = T.tipPlain

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
    assertEqual(down.glyph .. down.text, "▼8"); assertEqual(down.tone, "red")
end)

test("side cells: Can't use and Not wanted stay words after the gear, dim red and gray", function()
    local S = SC()
    local cant = S.Me(drop({ me = { verdict = "cantUse", reasons = { { key = "armorType" } } } }), MINE)
    assertEqual(cant.level, "292"); assertTrue(cant.glyph == nil); assertEqual(cant.text, "Can't use")
    assertEqual(cant.tone, "redMuted")
    local unwanted = S.Them(drop({ them = { verdict = "doesntWant", reasons = { { key = "undesired" } } } }), HERS, 100)
    assertEqual(unwanted.level, "324"); assertEqual(unwanted.text, "Not wanted"); assertEqual(unwanted.tone, "bad")
end)

test("side cells: two worn items read both levels and carry both icons", function()
    local S = SC()
    local me = S.Me(drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -8, reasons = {} } }), MINE)
    assertEqual(me.level, "321/308"); assertEqual(#me.items, 2)
    assertEqual(me.glyph .. me.text, "▼8")
    local them = S.Them(drop({ facts = TRINKET, them = { verdict = "upgrade", ilvlDelta = 12, reasons = {} } }), HERS, 100)
    assertEqual(them.level, "298/296"); assertEqual(#them.items, 2); assertEqual(them.glyph .. them.text, "▲12")
end)

-- A dual mark's parts as text: `321 ▼10 / 308 ▲3`.
local function partsText(c)
    local a, b = c.parts[1], c.parts[2]
    return ("%s %s%s / %s %s%s"):format(a.level, a.glyph, a.text, b.level, b.glyph, b.text)
end

test("side cells: two worn items both read take a mark each, in the items' order and each its own tone (H7)", function()
    local S = SC()
    -- 311 against your trinkets 321 and 308: the verdict (judged against the lower) on 308, its own on 321.
    local me = S.Me(drop({ facts = TRINKET, me = { verdict = "upgrade", ilvlDelta = 3, either = true, reasons = {} } }), MINE)
    assertEqual(partsText(me), "321 ▼10 / 308 ▲3")
    assertEqual(me.parts[1].tone, "red"); assertEqual(me.parts[2].tone, "good", "each part in its own tone")
    assertEqual(me.level, "321/308", "the single pieces stay for a reader that draws one mark")
    -- The baseline names the worn item: its row takes the verdict's mark whatever its level.
    local them = S.Them(drop({ facts = TRINKET, them = { verdict = "upgrade", ilvlDelta = 13, either = true,
        baseline = { link = OLD1, ilvl = 298 }, reasons = {} } }), HERS, 100)
    assertEqual(partsText(them), "298 ▲13 / 296 ▲15")
    -- The sidegrade band: within it either way reads ≈.
    local band = S.Me(drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -10, band = 4, either = true,
        baseline = { link = OLD1, ilvl = 321 }, reasons = {} } }), { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD2, ilvl = 313 } })
    assertEqual(partsText(band), "321 ▼10 / 313 ≈2"); assertEqual(band.parts[2].tone, "yellow")
end)

test("side cells: one worn item, an empty or unread slot, a word or an off-spec verdict keep one mark (H7)", function()
    local S = SC()
    local up = { verdict = "upgrade", ilvlDelta = 11, either = true, reasons = {} }
    assertEqual(S.Me(drop({ me = up }), MINE).parts, nil, "a single slot")
    local ring = { ilvl = 311, equipLoc = "INVTYPE_FINGER", quality = 4 }
    assertEqual(S.Me(drop({ facts = ring, me = up }), MINE).parts, nil, "a ring slot worn empty")
    assertEqual(S.Me(drop({ facts = TRINKET, me = up }), { [13] = { link = OLD1, ilvl = 321 } }).parts, nil, "one not read")
    assertEqual(S.Me(drop({ facts = TRINKET, me = up }), { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD2 } }).parts,
        nil, "a level not read")
    assertEqual(S.Me(drop({ facts = TRINKET, me = { verdict = "cantUse", either = true, reasons = {} } }), MINE).parts, nil, "a word")
    assertEqual(S.Me(drop({ facts = TRINKET, me = { verdict = "upgrade", either = true, reasons = {} } }), MINE).parts, nil, "no difference")
    assertEqual(S.Them(drop({ facts = TRINKET, them = up, inspect = { status = "pending" } }), nil, 100).parts, nil, "not read")
    local NS = T.newAddon()
    assertEqual(NS.WindowHistory.MeCell(drop({ facts = TRINKET, me = up })).parts, nil, "History keeps no worn items")
    assertEqual(NS.SideCells.Parts({ offSpec = true, either = true, verdict = "upgrade", delta = 3, ilvl = 311 },
        { { ilvl = 321 }, { ilvl = 308 } }, 0), nil, "an off-spec verdict is judged against one item")
end)

test("side cells: a drop judged against one of two worn items, or a bag item, keeps one mark (R5)", function()
    local S = SC()
    local MACE = "|cffa335ee|Hitem:302::|h[Old Mace]|h|r"
    local SHIELD = "|cffa335ee|Hitem:303::|h[Old Shield]|h|r"
    local hands = { [16] = { link = MACE, ilvl = 320 }, [17] = { link = SHIELD, ilvl = 310 } }
    -- No dual wield: a one-hander is judged against the main hand alone, never the shield.
    local oneH = { ilvl = 315, equipLoc = "INVTYPE_WEAPON", quality = 4 }
    local mh = S.Me(drop({ facts = oneH, me = { verdict = "downgrade", ilvlDelta = -5,
        baseline = { link = MACE, ilvl = 320 }, reasons = {} } }), hands)
    assertEqual(mh.parts, nil, "the main hand alone: no mark against the shield")
    assertEqual(mh.level .. " " .. mh.glyph .. mh.text, "320 ▼5", "the main hand's level alone: the shield is not one it replaces")
    assertEqual(#mh.items, 1, "one icon, the main hand's")
    -- A two-hander against both hands averaged: the difference is the pair's, not the main hand's.
    local twoH = { ilvl = 320, equipLoc = "INVTYPE_2HWEAPON", quality = 4 }
    local avg = S.Me(drop({ facts = twoH, me = { verdict = "upgrade", ilvlDelta = 5, averaged = true,
        baseline = { link = MACE, ilvl = 330 }, reasons = {} } }),
        { [16] = { link = MACE, ilvl = 330 }, [17] = { link = SHIELD, ilvl = 300 } })
    assertEqual(avg.parts, nil, "both hands averaged: one mark")
    assertEqual(avg.level .. " " .. avg.glyph .. avg.text, "330/300 ▲5")
    -- Of two, but the baseline is a bag item (compareOwned): neither worn item takes the verdict's mark.
    local ring = { ilvl = 310, equipLoc = "INVTYPE_FINGER", quality = 4 }
    local bag = S.Me(drop({ facts = ring, me = { verdict = "downgrade", ilvlDelta = -5, either = true,
        baseline = { link = LINK, ilvl = 315 }, reasons = {} } }),
        { [11] = { link = OLD1, ilvl = 300 }, [12] = { link = OLD2, ilvl = 310 } })
    assertEqual(bag.parts, nil, "a baseline neither worn item is: one mark")
    -- Of two, the baseline worn: a mark each.
    local worn = S.Me(drop({ facts = ring, me = { verdict = "upgrade", ilvlDelta = 10, either = true,
        baseline = { link = OLD1, ilvl = 300 }, reasons = {} } }),
        { [11] = { link = OLD1, ilvl = 300 }, [12] = { link = OLD2, ilvl = 310 } })
    assertEqual(partsText(worn), "300 ▲10 / 310 ≈0")
    -- A unique-equipped ring already worn (feedback-22): the kernel judges it against that ring but
    -- marks both (`either`), so a ring slot always reads both rings, `315 ▲3 / 295 ▲23`.
    local BAND = "|cffa335ee|Hitem:304::|h[Pilfered Precious Band]|h|r"
    local unique = S.Me(drop({ facts = { ilvl = 318, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 3, either = true, baseline = { link = BAND, ilvl = 315 },
            reasons = { { key = "uniqueEquipped" } } } }),
        { [11] = { link = BAND, ilvl = 315 }, [12] = { link = OLD2, ilvl = 295 } })
    assertEqual(partsText(unique), "315 ▲3 / 295 ▲23", "both rings, each its own mark")
    assertEqual(#unique.items, 2, "both icons")
    local grid = 0
    for _, l in ipairs(unique.tip) do if type(l) == "table" then grid = grid + 1 end end
    assertTrue(grid >= 1, "the tooltip still has the gear grid")
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

local OLD_BAND, OLDER_BAND = "|cffa335eeOld Band|r", "|cffa335eeOlder Band|r"   -- the links' own color

test("side cells: the tooltip is the verdict's title, the worn gear as a grid, then the read's age and the verdict's lines", function()
    local S = SC()
    local me = S.Me(drop(), MINE, "MAGE")
    assertEqual(me.tip[1], "For you: Upgrade")
    assertEqual(T.tipText(me.tip[2]), "|cff40c7ebYou|r  292  " .. OLD_BAND .. "  ▲19", "[Name] [ilvl] [item] [arrow and difference]")
    assertEqual(me.tip[2].grid[1][4].tone, "good", "the glyph and the difference in the verdict's tone")
    assertEqual(P(me.tip[3]), "• Means: a higher item level (and score, when scored)")
    assertFalse(has(me.tip, "You wear"), "the X wears line gives way to the grid")
    for _, l in ipairs(me.tip) do assertTrue(T.tipText(l):find("against", 1, true) == nil, "no comparison prose: " .. T.tipText(l)) end
    local them = S.Them(drop(), HERS, 100)
    assertEqual(them.tip[1], "For Seta: Downgrade")
    assertEqual(T.tipText(them.tip[2]), "|cffffffffSeta|r  324  " .. OLD_BAND .. "  ▼13", "the looter in their class color")
    assertEqual(them.tip[2].grid[1][4].tone, "red")
    assertEqual(P(them.tip[3]), "• Inspected: 40s ago", "the read's age after the grid")
    assertEqual(P(them.tip[4]), "• Means: a lower item level, no score gain")
    local range = S.Them(drop({ them = NONE, inspect = { status = "outOfRange" } }), nil, 100)
    local seen = {}
    for _, l in ipairs(range.tip) do
        assertEqual(type(l), "string", "nothing read: no grid")
        assertFalse(seen[l], "said once: " .. l)
        seen[l] = true
    end
    assertTrue(has(range.tip, "For Seta: Unknown"))
end)

test("side cells: two worn items are two rows, each with its own arrow against the drop; a slot worn empty reads empty", function()
    local S = SC()
    local judged = drop({ facts = TRINKET, them = { verdict = "upgrade", ilvlDelta = 13, either = true, baseline = { link = OLD2, ilvl = 296 }, reasons = {} } })
    local g = S.Them(judged, HERS, 100).tip[2].grid
    assertEqual(#g, 2, "a row per trinket")
    assertEqual(T.tipText({ grid = { g[1] } }), "|cffffffffSeta|r  298  " .. OLD_BAND .. "  ▲13",
        "the name on the first row; the other worn item its own arrow, 311 against 298 (feedback-21 H3)")
    assertEqual(T.tipText({ grid = { g[2] } }), "296  " .. OLDER_BAND .. "  ▲13", "the replaced item keeps the verdict's own arrow")
    assertEqual(g[2][1], "")
    local unlinked = drop({ facts = TRINKET, them = { verdict = "upgrade", ilvlDelta = 13, reasons = {} } })
    assertEqual(S.Them(unlinked, HERS, 100).tip[2].grid[2][4].glyph, "▲", "no baseline named: the lower one")
    local ring = drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } })
    local rg = S.Me(ring, MINE).tip[2].grid
    assertEqual(#rg, 2)
    assertEqual(rg[1][4].glyph .. rg[1][4].text, "▲11", "the worn ring its own arrow, 311 against 300")
    assertEqual(rg[1][4].tone, "good")
    assertEqual(rg[2][3].text, "empty"); assertEqual(rg[2][3].tone, "muted")
    assertEqual(rg[2][4].glyph, "▲"); assertEqual(rg[2][4].text, "", "into an empty slot: the glyph alone")
    assertEqual(rg[1][1], "You", "no class known: plain")
end)

test("side cells: a dual slot gives each worn item its own arrow and tone against the drop, the band as the kernel's", function()
    local S = SC()
    -- You wear trinkets 321 and 308; the drop is 311, judged against the 308 (+3).
    local d = drop({ facts = TRINKET, me = { verdict = "upgrade", ilvlDelta = 3, either = true, baseline = { link = OLD2, ilvl = 308 }, reasons = {} } })
    local g = S.Me(d, MINE).tip[2].grid
    assertEqual(#g, 2)
    assertEqual(g[1][4].glyph .. g[1][4].text, "▼10", "the higher trinket: a downgrade against it"); assertEqual(g[1][4].tone, "red")
    assertEqual(g[2][4].glyph .. g[2][4].text, "▲3", "the replaced one: the verdict's"); assertEqual(g[2][4].tone, "good")
    local banded = drop({ facts = TRINKET, me = { verdict = "sidegrade", ilvlDelta = 3, band = 10, either = true,
        baseline = { link = OLD2, ilvl = 308 }, reasons = {} } })
    local bg = S.Me(banded, MINE).tip[2].grid
    assertEqual(bg[1][4].glyph .. bg[1][4].text, "≈10", "within the sidegrade band: a sidegrade"); assertEqual(bg[1][4].tone, "yellow")
    local cant = drop({ facts = TRINKET, me = { verdict = "cantUse", reasons = {} } })
    for _, r in ipairs(S.Me(cant, MINE).tip[2].grid) do assertEqual(r[4], "", "no verdict: no arrow on any row") end
    -- Judged against one item (a one-hander for a non dual wielder: R5): the other row takes no arrow.
    local hands = { [16] = { link = OLD1, ilvl = 320 }, [17] = { link = OLD2, ilvl = 310 } }
    local oneH = drop({ facts = { ilvl = 315, equipLoc = "INVTYPE_WEAPON", quality = 4 }, me = { verdict = "downgrade",
        ilvlDelta = -5, baseline = { link = OLD1, ilvl = 320 }, reasons = {} } })
    local hg = S.Me(oneH, hands).tip[2].grid
    assertEqual(hg[1][4].glyph .. hg[1][4].text, "▼5", "the main hand: the verdict's")
    assertEqual(hg[2][4], "", "the shield: never compared, no arrow")
end)

test("side cells: History's verdict alone keeps its own one-row grid from the judged item", function()
    local S = SC()
    local v = S.Merge(T.newAddon().WindowCells.Me(drop({ me = { verdict = "upgrade", ilvlDelta = 6,
        baseline = { link = OLD1, ilvl = 305 }, reasons = {} } })))
    assertEqual(v.tip[1], "For you: Upgrade")
    assertEqual(T.tipText(v.tip[2]), "You  305  " .. OLD_BAND .. "  ▲6", "right under the title, above the rows (feedback-21 H3)")
    assertEqual(P(v.tip[3]), "• Means: a higher item level (and score, when scored)")
end)

test("side cells: your own drop's Them is Upgrade for N or No upgrades, in its tones, with every upgrade in the tooltip", function()
    local S = SC()
    local function cand(name, gain)
        return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = "MAGE", status = "ready",
            eval = { verdict = "upgrade", ilvlDelta = gain, baseline = { ilvl = 280 }, reasons = {} } }
    end
    local own = drop({ isMine = true, me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        candidates = { a = cand("Butterz", 11) } })
    local c = S.Them(own, HERS, 100, false)
    assertEqual(c.text, "Upgrade for 1"); assertEqual(c.tone, "good"); assertTrue(c.level == nil)
    assertEqual(#c.items, 0, "no worn icons on your own drop"); assertEqual(c.upgrades, 1)
    assertEqual(c.tip[1], "Them")
    local none = S.Them(drop({ isMine = true, me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        candidates = {} }), nil, 100)
    assertEqual(none.text, "No upgrades"); assertEqual(none.tone, "muted")
    local kept = S.Them(drop({ isMine = true, candidates = { a = cand("Butterz", 11) } }), nil, 100, false)
    assertEqual(kept.text, "Hidden"); assertTrue(kept.hidden)
    assertEqual(S.Them(drop({ isMine = true, candidates = { a = cand("Butterz", 11) } }), nil, 100, true).text,
        "Upgrade for 1", "revealed")
    assertEqual(S.Me(own, MINE).level, "292", "your own drop's Me still shows what you wear")
end)

test("side cells: History's Me and Them are the verdict alone, worded as the Drops table's", function()
    local NS = T.newAddon()
    local WH = NS.WindowHistory
    local d = WH.AsDrop({ itemLink = LINK, looter = "Seta-Realm", class = "PRIEST", ilvl = 311,
        equipLoc = "INVTYPE_HEAD", me = { verdict = "upgrade", ilvlDelta = 6 },
        them = { verdict = "downgrade", ilvlDelta = -8 } }, 1)
    local me, them = WH.MeCell(d), WH.ThemCell(d)
    assertTrue(me.level == nil, "a kept entry holds no worn items"); assertEqual(#me.items, 0)
    assertEqual(me.glyph .. me.text, "▲6"); assertEqual(them.glyph .. them.text, "▼8")
    assertEqual(me.tip[1], "For you: Upgrade")
    local unread = WH.ThemCell(WH.AsDrop({ itemLink = LINK, looter = "Seta-Realm", ilvl = 311 }, 2))
    assertEqual(unread.text, "?", "shown alone: nothing else says why")
end)

test("side cells: History's Me grid names you in your class color, as on Drops", function()
    local NS = T.newAddon()
    local WH = NS.WindowHistory
    NS.Gear.Snapshot = function() return { classFile = "MAGE", equipped = {} } end
    local d = WH.AsDrop({ itemLink = LINK, looter = "Seta-Realm", class = "PRIEST", ilvl = 311, equipLoc = "INVTYPE_HEAD",
        me = { verdict = "upgrade", ilvlDelta = 6, baseline = { link = OLD1, ilvl = 305 }, reasons = {} } }, 1)
    assertEqual(T.tipText(WH.MeCell(d).tip[2]), "|cff40c7ebYou|r  305  " .. OLD_BAND .. "  ▲6")
end)

test("side cells: Them read but not judged names the looter in the grid, in their class color", function()
    local S = SC()
    local u = S.Them(drop({ them = NONE }), { [1] = { link = OLD1, ilvl = 324 } }, 100)
    local grid
    for _, l in ipairs(u.tip) do if type(l) == "table" and l.grid then grid = l.grid end end
    assertTrue(grid ~= nil, "the worn helm as a grid")
    assertEqual(grid[1][1], "|cffffffffSeta|r", "the looter's name, not `?`")
end)

-- ── the Offer panel's Their eq (feedback-7 spec §0) ─────────────────────────────────────────

local function mine(over)
    return drop({ isMine = true, them = NONE, inspect = NONE, facts = over or TRINKET })
end

local function entry(status, eval, guid)
    return { guid = guid or "Player-1-B", name = "Butterz-Realm", classFile = "MAGE", status = status, eval = eval }
end

-- The candidate as the Offer panel draws it: MineCells.Candidates' entry, then SC.Candidate.
local function candidate(NS, d, c, insp)
    d.candidates = { [c.guid] = c }
    return NS.SideCells.Candidate(d, NS.MineCells.Candidates(d)[1], insp, 100)
end

test("side cells: the Offer panel's Their eq reads like Them: both worn items from the read, glyph and difference", function()
    local NS = T.newAddon()
    local base = { link = OLD2, ilvl = 296 }
    local read = { status = "fresh", at = 60, gear = HERS }
    local up = candidate(NS, mine(), entry("ready", { verdict = "upgrade", ilvlDelta = 15, either = true, baseline = base, reasons = {} }), read)
    assertEqual(#up.items, 2, "both trinkets from the inspect read"); assertEqual(up.level, "298/296"); assertEqual(up.levelTone, "plain")
    assertEqual(up.glyph .. up.text, "▲15"); assertEqual(up.tone, "good")
    assertEqual(up.tip[1], "For Butterz: Upgrade"); assertTrue(has(up.tip, "• Inspected: 40s ago"), "the read's age")
    assertEqual(T.tipText(up.tip[2]), "|cff40c7ebButterz|r  298  " .. OLD_BAND .. "  ▲13\n296  " .. OLDER_BAND .. "  ▲15",
        "both trinkets from the read, each with its own arrow (feedback-21 H3)")
    assertTrue(has(up.tip, "For Butterz: Upgrade")); assertTrue(has(up.tip, "• For them: a higher item level than they wear there"),
        "the old pill's explanation moved into the tooltip")
    local noRead = candidate(NS, mine(), entry("ready", { verdict = "downgrade", ilvlDelta = -4, baseline = base, reasons = {} }))
    assertEqual(#noRead.items, 1, "without a read, the item it was judged against"); assertEqual(noRead.items[1].link, OLD2)
    assertEqual(noRead.level, "296"); assertEqual(noRead.glyph .. noRead.text, "▼4"); assertEqual(noRead.tone, "red")
    local side = candidate(NS, mine(), entry("ready", { verdict = "sidegrade", ilvlDelta = 0, baseline = { ilvl = 311 }, reasons = {} }))
    assertEqual(#side.items, 0); assertEqual(side.level, "311"); assertEqual(side.levelTone, "plain", "a level known without its item")
    assertEqual(side.glyph .. side.text, "≈0"); assertEqual(side.tone, "yellow")
end)

test("side cells: the Offer panel's Their eq says Can't use, …, Unavailable and empty in words", function()
    local NS = T.newAddon()
    local cant = candidate(NS, mine(), entry("ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }))
    assertTrue(cant.level == nil, "no dash beside the word"); assertEqual(cant.text, "Can't use"); assertEqual(cant.tone, "redMuted")
    local checking = candidate(NS, mine(), entry("checking"))
    assertEqual(checking.text, "…"); assertEqual(checking.tone, "muted"); assertEqual(checking.tip[1], "Butterz: Checking")
    assertEqual(P(checking.tip[2]), "• For them: their gear is being inspected")
    local gone = candidate(NS, mine(), entry("unavailable"))
    assertEqual(gone.text, "Unavailable"); assertEqual(gone.tone, "muted"); assertTrue(#gone.tip >= 2)
    local unknown = candidate(NS, mine(), entry("ready", { verdict = "unknown", reasons = {} }))
    assertTrue(unknown.level == nil); assertEqual(unknown.text, "Unavailable")
    local empty = candidate(NS, mine({ ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 }),
        entry("ready", { verdict = "upgrade", reasons = { { key = "emptySlot" } } }))
    assertEqual(empty.level, "empty"); assertEqual(empty.glyph, "▲"); assertEqual(empty.text, "")
    assertEqual(T.tipText(empty.tip[2]), "|cff40c7ebButterz|r  empty  ▲", "nothing worn: the item cell reads empty")
    local stale = candidate(NS, mine(), entry("ready", { verdict = "upgrade", ilvlDelta = 3, baseline = { link = OLD1, ilvl = 308 }, reasons = {} }),
        { status = "pending" })
    assertEqual(#stale.items, 1, "a read not done yet gives no gear: the judged item stands in")
end)

test("side cells: the Offer panel's Their eq lists a ring slot read empty as its own row, as Them does", function()
    local NS = T.newAddon()
    local RING = { ilvl = 311, equipLoc = "INVTYPE_FINGER", quality = 4 }
    local gear = { [11] = { link = OLD1, ilvl = 320 }, [12] = false }
    local eval = { verdict = "upgrade", reasons = { { key = "emptySlot" } } }
    local c = candidate(NS, mine(RING), entry("ready", eval), { status = "fresh", at = 60, gear = gear })
    local g = c.tip[2].grid
    assertEqual(#g, 2, "the worn ring and the slot read empty")
    assertEqual(g[1][4].glyph .. g[1][4].text, "▼9", "the worn ring its own arrow, 311 against 320"); assertEqual(g[1][4].tone, "red")
    assertEqual(g[2][3].text, "empty"); assertEqual(g[2][4].glyph, "▲", "the arrow on the slot the drop would fill")
    local them = NS.SideCells.Them(drop({ facts = RING, them = eval }), gear, 100)
    assertEqual(c.level, "320"); assertEqual(c.level, them.level, "Their eq's level is Them's for the same gear")
    local bare = candidate(NS, mine(RING), entry("ready", { verdict = "downgrade", ilvlDelta = -2, baseline = { ilvl = 313 }, reasons = {} }),
        { status = "fresh", at = 60, gear = { [11] = false, [12] = false } })
    assertEqual(bare.level, "empty", "both slots read empty: empty, not the judged level")
end)

-- ── the widths (measured) ───────────────────────────────────────────────────────────────────

local CHAR = 5   -- the harness's character measure (the small template's average; a glyph is one)

local function chars(s) return #((s or ""):gsub("[\128-\191]", "")) end

-- A cell's width as WindowGroup.PlaceSide lays it out: the icons, then each piece shown after the
-- last with its gap; a dual mark (feedback-21 H7) its first part, PART_GAP, `/`, PART_GAP, then the
-- second part in the single pieces.
local function sideWidth(WG, K, c)
    local S, x, gap = WG.SIDE, 0, 0
    local n = math.min(#c.items, 2)
    if n > 0 then x, gap = n * K.EQ_ICON + (n - 1) * S.ICON_GAP, S.LEVEL_GAP end
    local function add(w, after) x, gap = x + gap + w, after end
    local level, glyph, text = c.level, c.glyph, c.text
    if c.parts then
        local a, b = c.parts[1], c.parts[2]
        add(chars(a.level) * CHAR, S.VERDICT_GAP); add(CHAR, S.GLYPH_GAP); add(chars(a.text) * CHAR, S.PART_GAP)
        add(chars(WG.PART_SEP) * CHAR, S.PART_GAP)
        level, glyph, text = b.level, b.glyph, b.text
    end
    if level then add(chars(level) * CHAR, S.VERDICT_GAP) end
    if glyph then add(CHAR, S.GLYPH_GAP) end
    if text ~= "" then add(chars(text) * CHAR, 0) end
    return x
end

-- Every kind of cell each column can show, on a two-item slot and a one-item slot.
local VERDICTS = {
    { verdict = "upgrade", ilvlDelta = 13, either = true, reasons = {} }, { verdict = "downgrade", ilvlDelta = -13, either = true, reasons = {} },
    { verdict = "sidegrade", ilvlDelta = 1, either = true, reasons = {} }, { verdict = "cantUse", reasons = {} },
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

-- Every kind of cell the Offer panel's Their eq can show: each verdict on two worn items and on
-- none, checking and unavailable.
local function candidateCells(NS)
    local out, read = {}, { status = "fresh", at = 60, gear = HERS }
    for _, v in ipairs(VERDICTS) do
        local eval = v ~= NONE and v or nil
        for _, insp in ipairs({ read, false }) do
            out[#out + 1] = candidate(NS, mine(), entry("ready", eval), insp or nil)
        end
    end
    out[#out + 1] = candidate(NS, mine(), entry("checking"))
    out[#out + 1] = candidate(NS, mine(), entry("unavailable"))
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
    local spec = sideWidth(WG, K, { items = { 1, 2 }, level = "321/308", glyph = "▼", text = "13" })
    assertTrue(widest.me >= spec, "the spec's worst case fits")
    -- The dual mark at its longest realistic (feedback-21 H7): two worn levels, two two-digit
    -- differences, `321 ▼10 / 324 ▼23`: 125, inside the 127 that `Not wanted` sets, so no column widens.
    local dual = sideWidth(WG, K, { items = { 1, 2 }, text = "", parts = {
        { level = "321", glyph = "▼", text = "10" }, { level = "324", glyph = "▼", text = "23" } } })
    assertEqual(dual, 125)
    for _, col in ipairs(WG.COLUMNS) do
        if widest[col.key] then assertTrue(dual <= col.width, col.key .. ": the dual mark fits, nothing cut") end
    end
    for _, col in ipairs(WG.COLUMNS) do
        if widest[col.key] then assertEqual(col.width, widest[col.key], col.key .. ": nothing cut, no margin") end
    end
    assertEqual(widest.me, 2 * K.EQ_ICON + 2 + 4 + 7 * CHAR + 4 + #"Not wanted" * CHAR, "two icons, 321/308, Not wanted")
end)

test("widths: the Offer panel's Their eq is at least Them's width and fits its widest cell", function()
    local NS = T.newAddon()
    local WG, K, COLS = NS.WindowGroup, NS.Constants.WINDOW, NS.OfferPanel.COLS
    local keys = {}
    for i, col in ipairs(COLS) do keys[i] = col.key end
    assertEqual(table.concat(keys, ","), "member,eq,actions", "Eq -> drop and Status are one column")
    assertEqual(COLS[2].label, "Their eq")
    local width = COLS[3].x - COLS[2].x - 6
    local them
    for _, col in ipairs(WG.COLUMNS) do if col.key == "them" then them = col.width end end
    assertTrue(width >= them, "at least the Drops table's Them width")
    for _, c in ipairs(candidateCells(NS)) do
        assertTrue(sideWidth(WG, K, c) <= width, (c.level or "") .. " " .. c.text .. " fits")
    end
    local rowW = K.OFFER_W - K.SCROLL_W - 24
    assertTrue(COLS[3].x + K.PANEL_BTN_W <= rowW, "the Offer button inside the row")
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
            local tip = T.tipPlainJoined(col.tip)
            assertTrue(tip:find("wear", 1, true) ~= nil, col.key .. "'s tooltip describes the gear half")
            assertTrue(tip:find("judged", 1, true) ~= nil, col.key .. "'s tooltip describes the verdict half")
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
    local NS, row = shown(drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -8, either = true, reasons = {} } }))
    local c, C = row.cells.me, NS.Constants
    assertTrue(c.icons[1]:IsShown() and c.icons[2]:IsShown(), "both worn trinkets")
    -- A mark each (feedback-21 H7): `321 ▼10 / 308 ▼8`, the first part in the lead pieces.
    assertEqual(textOf(c.leadLevel), "321"); assertEqual(textOf(c.leadGlyph), "▼"); assertEqual(textOf(c.leadText), "10")
    assertEqual(textOf(c.sep), "/"); assertTrue(c.sep:IsShown(), "the separator shows")
    assertEqual(select(2, c.sep:GetTextColor()), C.TONE.muted.g, "the separator muted")
    assertEqual(c.leadLevel.__points[1][2], c.icons[2], "the first level after the second icon")
    assertEqual(c.leadGlyph.__points[1][2], c.leadLevel); assertEqual(c.leadText.__points[1][2], c.leadGlyph)
    assertEqual(c.sep.__points[1][2], c.leadText); assertEqual(c.level.__points[1][2], c.sep, "the second part after it")
    assertEqual(textOf(c.level), "308"); assertEqual(textOf(c.glyph), "▼"); assertEqual(textOf(c.text), "8")
    assertEqual(c.glyph.__points[1][2], c.level, "the glyph after the level")
    assertEqual(c.text.__points[1][2], c.glyph, "the difference after the glyph")
    assertEqual(c.text.__points[2][1], "RIGHT"); assertEqual(c.text.__points[2][2], c,
        "the difference ends at the cell's right edge: a long word or a larger font is cut short there")
    assertEqual(select(1, c.level:GetTextColor()), C.TONE.plain.r, "the level is plain")
    assertEqual(select(2, c.glyph:GetTextColor()), C.TONE.red.g, "the glyph in the verdict's tone")
    assertEqual(select(2, c.text:GetTextColor()), C.TONE.red.g)
    local tip = NS.Window.TooltipOf(c)
    assertEqual(tip[1], "For you: Downgrade", "the verdict's title, then the gear grid (feedback-7 spec §3)")
    assertEqual(#tip[2].grid, 2, "a row per worn trinket")
    c:__fire("OnEnter")   -- the hover paints the grid as columns
    local by = {}
    for _, d in ipairs(NS.TipGrid.Painted()) do by[d.text] = d end
    assertTrue(by["▼"] and by["▼"].mono, "the table's glyph, in the monospace face")
    assertEqual(by["8"].line, by["308"].line, "the arrow on the lower trinket's row")
    assertEqual(by["321"].x, by["308"].x, "the levels in one column")
    assertTrue(row.cells.myEq == nil and row.cells.theirEq == nil, "no eq columns")
    assertEqual(textOf(NS.WindowGroup.Drawn().pane.colHead.labels.me.text), "Me")
end)

-- feedback-21 R5: the columns keep the width the Default size measures, so at a larger Font size a
-- dual mark that would run past its cell into the next column gives way to the one mark.
test("table: a dual mark that does not fit its cell at a larger font is the one mark instead (R5)", function()
    local function painted(charWidth)
        local NS, _, m = T.enableAddon()
        m.__now, m.textCharWidth = 100, charWidth
        local d = drop({ facts = TRINKET, me = { verdict = "downgrade", ilvlDelta = -8, either = true, reasons = {} } })
        NS.LootFeed.Groups = function() return { GROUP } end
        NS.LootFeed.Get = function(id) return id == d.id and d or nil end
        NS.LootFeed.Drops = function() return { d } end
        NS.Gear.Snapshot = function() return { equipped = MINE } end
        NS.WindowFilterBar.Set("group", "view", "all")
        NS.ShowWindow()
        return NS.WindowGroup.Drawn().rows[1].cells.me
    end
    local fits = painted(3)
    assertTrue(fits.sep:IsShown(), "it fits: a mark each"); assertEqual(textOf(fits.level), "308")
    local big = painted(9)
    assertFalse(big.sep:IsShown() or big.leadLevel:IsShown(), "too wide: no lead pieces")
    assertEqual(textOf(big.level), "321/308"); assertEqual(textOf(big.glyph), "▼"); assertEqual(textOf(big.text), "8")
    assertEqual(big.level.__points[1][2], big.icons[2], "placed as the one mark, after the icons")
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
    assertEqual(me.text.__points[2][2], me, "the word ends at the cell's right edge")
    assertFalse(me.sep:IsShown() or me.leadLevel:IsShown(), "one worn helm: one mark, no lead pieces (feedback-21 H7)")
end)
