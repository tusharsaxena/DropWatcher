-- tests/test_offspec_cells.lua — how off-spec looks (feedback-19 spec §1, DW-O1): a drop your
-- current spec cannot use but another spec of your class can (eval.offSpec, modules/OffSpec.lua)
-- shows as that spec's verdict, in the `offspec` cyan, with the spec's name. Case by case: the tone,
-- the verdict cell (NS.OffSpecCells through WindowCells.Verdict), the Me cell's gear half from the
-- off-spec baseline (a bag item's icon reads its link), the compact line, the tooltip marks' tone
-- override, the detail card (chip, Spec row, rows from the baseline, no worn slot for a bag item),
-- the History snapshot (kept small, compared field by field) and its card, the filter bar (Upgrades,
-- Usable by me, Interesting, Gain) and the legends. A Can't use with no off-spec is pinned unchanged.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local AXE  = "|cffa335ee|Hitem:212::|h[Venom-Etched Crescent]|h|r"
local BAG  = "|cffa335ee|Hitem:400::|h[Bag Mace]|h|r"
local WORN = "|cffa335ee|Hitem:401::|h[Worn Sword]|h|r"

local NONE = {}
local HOLY, PROT = 65, 66

local function with(t, over)
    for k, v in pairs(over or {}) do
        if v == NONE then t[k] = nil else t[k] = v end
    end
    return t
end

-- The off-spec answer: Holy can use the Crescent, +20 over the 291 mace in your bags.
local function off(over)
    return with({ specID = HOLY, mainSpecID = PROT, verdict = "upgrade", ilvlDelta = 20,
        baseline = { link = BAG, ilvl = 291, bag = 0, bagSlot = 3 }, baselineSlot = 16, reasons = {} }, over)
end

-- Protection cannot use it (an Intellect weapon); Holy can.
local function cantMain(o)
    return { verdict = "cantUse", ilvlDelta = -9, reasons = { { key = "primaryStat" } }, offSpec = o }
end

local function drop(over)
    return with({
        id = 1, at = 100, link = AXE, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_WEAPON", quality = 4 },
        me = cantMain(off()),
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }, over)
end

-- What Protection wears: a 300 sword in the main hand, nothing in the off hand.
local MINE = { [16] = { link = WORN, ilvl = 300, slot = 16 }, [17] = false }

local function named(NS, m)
    m.specNames[HOLY], m.specNames[PROT] = "Holy", "Protection"
    return NS
end

local function addon()
    local NS, _, m = T.newAddon()
    return named(NS, m), m
end

local function joined(tip) return T.tipJoined(tip) end

local function has(tip, line)
    for _, l in ipairs(tip) do if T.tipText(l) == line then return true end end
    return false
end

local function byKey(list, key)
    for _, x in ipairs(list) do if x.key == key then return x end end
end

-- ── the tone ────────────────────────────────────────────────────────────────────────────────

test("off-spec cells: the offspec tone is its own cyan, apart from Offer's", function()
    local C = addon().Constants
    local t = C.TONE.offspec
    assertEqual(t.r, 0.30); assertEqual(t.g, 0.85); assertEqual(t.b, 0.85)
    assertFalse(t == C.TONE.cyan, "not the Offer button's token")
end)

test("off-spec cells: OffSpec.Of answers the off-spec part of a Can't use, else nil", function()
    local OS = addon().OffSpec
    local o = off()
    assertTrue(OS.Of(cantMain(o)) == o)
    assertNil(OS.Of(cantMain(nil)), "no off-spec")
    assertNil(OS.Of({ verdict = "upgrade", offSpec = o }), "only on a Can't use")
    assertNil(OS.Of(cantMain(off({ verdict = "doesntWant" }))), "only the three verdicts")
    assertNil(OS.Of(cantMain("junk"))); assertNil(OS.Of(nil)); assertNil(OS.Of("x"))
end)

-- ── the verdict cell ────────────────────────────────────────────────────────────────────────

test("off-spec cells: the Me verdict is the off-spec one, in the offspec tone, with the spec's name", function()
    local NS = addon()
    local c = NS.WindowCells.Me(drop())
    assertEqual(c.glyph, "▲"); assertEqual(c.text, "+20"); assertEqual(c.tone, "offspec")
    assertEqual(c.verdict, "upgrade"); assertEqual(c.offSpec, HOLY); assertEqual(c.mainVerdict, "cantUse")
    assertEqual(c.spec, "Holy"); assertEqual(c.delta, 20); assertEqual(c.base.link, BAG)
    assertEqual(c.tip[1], "For you: Off-spec upgrade for Holy")
    assertTrue(has(c.tip, "Protection can't use it: Its primary stat does not suit the spec."), joined(c.tip))
    assertTrue(has(c.tip, "Compared with your best Holy item: Bag Mace 291."), joined(c.tip))
    local grid
    for _, l in ipairs(c.tip) do if NS.TipMarks.IsGrid(l) then grid = l end end
    assertTrue(grid ~= nil, "the comparison as a grid row")
    assertEqual(grid.grid[1][4].tone, "offspec", "the grid's arrow in the offspec tone")
end)

test("off-spec cells: a sidegrade, a downgrade and an empty slot keep their glyphs, all in the offspec tone", function()
    local WC = addon().WindowCells
    local side = WC.Me(drop({ me = cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 })) }))
    assertEqual(side.glyph .. side.text, "≈+1"); assertEqual(side.tone, "offspec"); assertEqual(side.verdict, "sidegrade")
    local down = WC.Me(drop({ me = cantMain(off({ verdict = "downgrade", ilvlDelta = -6 })) }))
    assertEqual(down.glyph .. down.text, "▼-6"); assertEqual(down.tone, "offspec")
    local empty = WC.Me(drop({ me = cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } })) }))
    assertEqual(empty.glyph .. empty.text, "▲empty"); assertEqual(empty.tone, "offspec")
    assertTrue(has(empty.tip, "Compared with your best Holy item: an empty slot."), joined(empty.tip))
    assertTrue(has(empty.tip, "The slot is empty, so anything is an upgrade."), "the off-spec pass's own reasons")
end)

test("off-spec cells: an unknown spec name falls back to words, and the looter's cell says their", function()
    local NS, _, m = T.newAddon()
    m.specNames[HOLY], m.specNames[PROT] = nil, nil
    local c = NS.WindowCells.Me(drop())
    assertEqual(c.spec, "Off-spec")
    assertEqual(c.tip[1], "For you: Off-spec upgrade for Off-spec")
    assertTrue(has(c.tip, "Your spec can't use it: Its primary stat does not suit the spec."), joined(c.tip))
    named(NS, m)
    local them = NS.WindowCells.Them(drop({ them = cantMain(off()) }), 100)
    assertEqual(them.tone, "offspec"); assertEqual(them.tip[1], "For Seta: Off-spec upgrade for Holy")
    assertTrue(has(them.tip, "Compared with their best Holy item: Bag Mace 291."), joined(them.tip))
end)

test("off-spec cells: a Can't use with no off-spec is unchanged", function()
    local WC = addon().WindowCells
    local c = WC.Me(drop({ me = cantMain(nil) }))
    assertEqual(c.text, "Can't use"); assertNil(c.glyph); assertEqual(c.tone, "bad"); assertEqual(c.verdict, "cantUse")
    assertNil(c.offSpec); assertNil(c.mainVerdict); assertNil(c.spec)
    local junk = WC.Me(drop({ me = cantMain(off({ verdict = "unknown" })) }))
    assertEqual(junk.text, "Can't use", "an off-spec verdict that is not one of the three is ignored")
end)

-- ── the Me cell's gear half ─────────────────────────────────────────────────────────────────

test("off-spec cells: the Me cell's gear half is the off-spec baseline, a bag item with no slot", function()
    local S = addon().SideCells
    local c = S.Me(drop(), MINE)
    assertEqual(c.level, "291", "the bag mace, not the worn sword")
    assertEqual(#c.items, 1); assertEqual(c.items[1].link, BAG); assertNil(c.items[1].slot, "a bag item: no inventory slot")
    assertEqual(c.glyph, "▲"); assertEqual(c.text, "20 Holy"); assertEqual(c.tone, "offspec")
    assertEqual(c.verdict, "upgrade"); assertEqual(c.offSpec, HOLY); assertEqual(c.mainVerdict, "cantUse")
    local row = c.tip[2].grid[1]
    assertEqual(row[2], "291", "the grid lists the baseline"); assertTrue(row[3]:find("Bag Mace", 1, true) ~= nil)
    assertEqual(row[4].glyph .. row[4].text, "▲20"); assertEqual(row[4].tone, "offspec")
    local worn = S.Me(drop({ me = cantMain(off({ baseline = { link = WORN, ilvl = 300, slot = 16 }, ilvlDelta = 11 })) }), MINE)
    assertEqual(worn.items[1].slot, 16, "a worn baseline keeps its slot")
    local empty = S.Me(drop({ me = cantMain(off({ ilvlDelta = NONE, baseline = NONE, reasons = { { key = "emptySlot" } } })) }), MINE)
    assertEqual(empty.level, "empty"); assertEqual(#empty.items, 0)
    assertEqual(empty.glyph, "▲"); assertEqual(empty.text, "Holy")
end)

test("off-spec cells: a Can't use with no off-spec keeps the worn gear", function()
    local S = addon().SideCells
    local c = S.Me(drop({ me = cantMain(nil) }), MINE)
    assertEqual(c.level, "300"); assertEqual(c.text, "Can't use"); assertEqual(c.tone, "bad")
end)

test("off-spec cells: the compact line reads You 291 ▲20 Holy", function()
    local NS = addon()
    local h = NS.CompactCards.Half("You", NS.SideCells.Me(drop(), MINE))
    assertEqual(NS.CompactCards.HalfText(h), "You 291 ▲20 Holy")
end)

-- ── the marks ───────────────────────────────────────────────────────────────────────────────

test("off-spec cells: TipMarks' Mark and ArrowCell take a tone override", function()
    local NS = addon()
    local TM = NS.TipMarks
    assertTrue(TM.Mark("upgrade", "offspec"):find(":77:217:217|t", 1, true) ~= nil, TM.Mark("upgrade", "offspec"))
    assertTrue(TM.Mark("upgrade"):find(":77:217:102|t", 1, true) ~= nil, "no override: the verdict's own green")
    assertEqual(TM.Mark("upgrade", "nonsense"), TM.Mark("upgrade"), "an unknown tone keeps the verdict's")
    assertEqual(TM.ArrowCell("upgrade", 20, "offspec").tone, "offspec")
    assertEqual(TM.ArrowCell("downgrade", -3, "offspec").glyph, "▼")
    assertEqual(TM.ArrowCell("upgrade", 20).tone, "good")
    assertEqual(TM.ArrowCell("cantUse", 20, "offspec"), "", "no glyph, no cell")
end)

-- ── the detail card ─────────────────────────────────────────────────────────────────────────

test("off-spec cells: the detail card's FOR YOU takes its chip and rows from the off-spec result", function()
    local DC = addon().DetailCells
    local side = DC.ForYou(drop({ me = cantMain(off({ trackDelta = { tier = 1, rank = 0, sign = 1 } })) }), "pawn")
    assertEqual(T.marks(side.verdict.text), "[arrow-up] OFF-SPEC UPGRADE"); assertEqual(side.verdict.tone, "offspec")
    local spec = byKey(side.rows, "spec")
    assertEqual(spec.text, "Holy (off-spec): Protection can't use it"); assertEqual(side.rows[1].key, "spec", "first")
    local rep = byKey(side.rows, "replaces")
    assertEqual(rep.text, "Bag Mace · 291"); assertEqual(rep.link, BAG); assertNil(rep.wornSlot, "a bag item: no worn slot")
    assertEqual(T.marks(byKey(side.rows, "ilvl").text), "291 [arrow-right] 311 · +20")
    assertEqual(byKey(side.rows, "ilvl").tone, "offspec")
    assertTrue(byKey(side.rows, "score").tip[2]:find("item level alone") ~= nil, "off-spec is never scored")
    local worn = DC.ForYou(drop({ me = cantMain(off({ baseline = { link = WORN, ilvl = 300, slot = 16 }, ilvlDelta = 11 })) }), "pawn")
    assertEqual(byKey(worn.rows, "replaces").wornSlot, 16, "a worn baseline keeps its slot")
    local side2 = DC.ForYou(drop({ me = cantMain(off({ verdict = "sidegrade", ilvlDelta = 2 })) }), "pawn")
    assertEqual(T.marks(side2.verdict.text), "[transfer] OFF-SPEC SIDEGRADE")
    local down = DC.ForYou(drop({ me = cantMain(off({ verdict = "downgrade", ilvlDelta = -4 })) }), "pawn")
    assertEqual(T.marks(down.verdict.text), "[arrow-down] OFF-SPEC DOWNGRADE")
end)

test("off-spec cells: the detail card's Can't use with no off-spec is unchanged", function()
    local DC = addon().DetailCells
    local side = DC.ForYou(drop({ me = cantMain(nil) }), "pawn")
    assertEqual(side.verdict.text, "CAN'T USE"); assertNil(byKey(side.rows, "spec"))
    assertEqual(#side.rows, 5)
end)

-- ── History ─────────────────────────────────────────────────────────────────────────────────

local function rec(me)
    return { id = 1, link = AXE, itemID = 212, looter = { name = "Seta-Realm", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_WEAPON", quality = 4 }, me = me,
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} } }
end

test("off-spec cells: the History snapshot keeps the off-spec part small", function()
    local H = addon().History
    local e = H.Snapshot(rec(cantMain(off())), 1)
    assertEqual(e.me.verdict, "cantUse")
    local o = e.me.offSpec
    assertEqual(o.specID, HOLY); assertEqual(o.mainSpecID, PROT); assertEqual(o.verdict, "upgrade"); assertEqual(o.ilvlDelta, 20)
    assertNil(o.baseline, "no baseline kept"); assertNil(o.reasons, "no reasons kept"); assertNil(o.baselineSlot)
    assertNil(H.Snapshot(rec(cantMain(nil)), 1).me.offSpec, "none without one")
    assertNil(H.Snapshot(rec(cantMain(off({ verdict = "unknown" }))), 1).me.offSpec, "nor for a verdict not kept")
end)

test("off-spec cells: an unchanged off-spec part never reports a change", function()
    local H = addon().History
    local e = H.Snapshot(rec(cantMain(off())), 1)
    local _, moved = H.Refresh(e, rec(cantMain(off())))
    assertFalse(moved, "the same values, a new table")
    _, moved = H.Refresh(e, rec(cantMain(off({ ilvlDelta = 21 }))))
    assertTrue(moved, "the difference moved")
    _, moved = H.Refresh(e, rec(cantMain(nil)))
    assertTrue(moved, "the off-spec part went")
    _, moved = H.Refresh(e, rec(cantMain(nil)))
    assertFalse(moved)
end)

test("off-spec cells: the History card takes its chip, Spec row and deltas from the snapshot", function()
    local NS = addon()
    local e = { itemLink = AXE, itemID = 212, looter = "Seta-Realm", class = "PRIEST", outcome = "seen", at = 1,
        ilvl = 311, equipLoc = "INVTYPE_WEAPON", quality = 4,
        me = { verdict = "cantUse", offSpec = { specID = HOLY, mainSpecID = PROT, verdict = "upgrade", ilvlDelta = 20 } } }
    local d = NS.WindowHistory.AsDrop(e, 1, { key = "g", label = "G" })
    local m = NS.HistoryCard.Model(d, { dateFn = function(f, t) return f .. t end, nowEpoch = 10 })
    assertEqual(T.marks(m.me.verdict.text), "[arrow-up] OFF-SPEC UPGRADE"); assertEqual(m.me.verdict.tone, "offspec")
    assertEqual(byKey(m.me.rows, "spec").text, "Holy (off-spec): Protection can't use it")
    assertEqual(byKey(m.me.rows, "ilvl").text, "+20"); assertEqual(byKey(m.me.rows, "ilvl").tone, "offspec")
    local cell = NS.SideCells.Merge(NS.WindowCells.Me(d))
    assertEqual(cell.glyph .. cell.text, "▲20 Holy", "the History row's Me cell")
    e.me = { verdict = "cantUse" }
    local plain = NS.HistoryCard.Model(NS.WindowHistory.AsDrop(e, 1, { key = "g", label = "G" }), { dateFn = function(f, t) return f .. t end })
    assertEqual(plain.me.verdict.text, "CAN'T USE"); assertNil(byKey(plain.me.rows, "spec"))
end)

-- A snapshot keeps no baseline, so its tooltip names the level it was compared with, never an
-- empty slot it did not have; only a snapshot with no difference was an empty slot.
test("off-spec cells: a History row's tooltip names the level compared with, not an empty slot", function()
    local NS = addon()
    local e = { itemLink = AXE, itemID = 212, looter = "Seta-Realm", class = "PRIEST", outcome = "seen", at = 1,
        ilvl = 311, equipLoc = "INVTYPE_WEAPON", quality = 4,
        me = { verdict = "cantUse", offSpec = { specID = HOLY, mainSpecID = PROT, verdict = "upgrade", ilvlDelta = 20 } } }
    local c = NS.WindowCells.Me(NS.WindowHistory.AsDrop(e, 1, { key = "g", label = "G" }))
    assertTrue(has(c.tip, "Compared with your best Holy item: 291."), joined(c.tip))
    e.me.offSpec.ilvlDelta = nil
    c = NS.WindowCells.Me(NS.WindowHistory.AsDrop(e, 1, { key = "g", label = "G" }))
    assertTrue(has(c.tip, "Compared with your best Holy item: an empty slot."), joined(c.tip))
end)

-- ── the filter bar ──────────────────────────────────────────────────────────────────────────

local VIEW_ONLY = { view = true }

test("off-spec cells: Upgrades and Interesting count an off-spec upgrade, not a sidegrade", function()
    local FB = addon().WindowFilterBar
    local upgrade = drop({ them = { verdict = "upgrade", ilvlDelta = 4, reasons = {} } })
    local side = drop({ me = cantMain(off({ verdict = "sidegrade", ilvlDelta = 1 })), them = upgrade.them })
    assertTrue(FB.IsInteresting(upgrade), "an off-spec upgrade is interesting")
    assertFalse(FB.IsInteresting(side))
    assertFalse(FB.IsInteresting(drop({ me = cantMain(nil), them = upgrade.them })), "a plain Can't use is not")
    assertTrue(FB.Matches(upgrade, { view = { upgrade = true } }, nil, VIEW_ONLY))
    assertFalse(FB.Matches(side, { view = { upgrade = true } }, nil, VIEW_ONLY))
    -- the looter's off-spec changes nothing: a Can't use on their main spec still gives it
    local gives = drop({ me = { verdict = "downgrade", ilvlDelta = -2, reasons = {} }, them = cantMain(off()) })
    assertTrue(FB.IsInteresting(gives))
end)

test("off-spec cells: Usable by me counts an off-spec upgrade or sidegrade", function()
    local FB = addon().WindowFilterBar
    local st = { view = { usable = true } }
    assertTrue(FB.Matches(drop(), st, nil, VIEW_ONLY))
    assertTrue(FB.Matches(drop({ me = cantMain(off({ verdict = "sidegrade" })) }), st, nil, VIEW_ONLY))
    assertFalse(FB.Matches(drop({ me = cantMain(off({ verdict = "downgrade", ilvlDelta = -3 })) }), st, nil, VIEW_ONLY))
    assertFalse(FB.Matches(drop({ me = cantMain(nil) }), st, nil, VIEW_ONLY), "a plain Can't use stays hidden")
end)

test("off-spec cells: Gain sorts the off-spec difference below a main-spec upgrade of the same size", function()
    local FB = addon().WindowFilterBar
    local function main(id, d) return drop({ id = id, me = { verdict = "upgrade", ilvlDelta = d, reasons = {} } }) end
    local function offd(id, d) return drop({ id = id, me = cantMain(off({ ilvlDelta = d })) }) end
    local list = { offd(1, 20), main(2, 19), main(3, 20), offd(4, 21), drop({ id = 5, me = cantMain(nil) }) }
    table.sort(list, FB.Comparator("gain"))
    local ids = {}
    for i, d in ipairs(list) do ids[i] = d.id end
    assertEqual(table.concat(ids, ","), "4,3,1,2,5")
end)

-- ── the legends ─────────────────────────────────────────────────────────────────────────────

local CYAN = "Cyan: an upgrade for another of your specs (off-spec); your current spec can't use it."

test("off-spec cells: the Me column's tooltip and the Offer panel's legend name the cyan", function()
    local NS = addon()
    local me
    for _, c in ipairs(NS.WindowGroup.COLUMNS) do if c.key == "me" then me = c end end
    assertTrue(T.marks(me.tip):find(CYAN, 1, true) ~= nil, me.tip)
    assertTrue(T.marks(NS.OfferPanel.COLS[2].tip):find(CYAN, 1, true) ~= nil, NS.OfferPanel.COLS[2].tip)
end)

-- ── painted on the Drops table ──────────────────────────────────────────────────────────────

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } }

local function shown(d)
    local NS, _, m = T.enableAddon()
    named(NS, m)
    m.__now = 100
    NS.LootFeed.Groups = function() return { GROUP } end
    NS.LootFeed.Get = function(id) return id == d.id and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.Gear.Snapshot = function() return { equipped = MINE, classFile = "PALADIN" } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn().rows[1]
end

test("table: an off-spec Me cell paints the baseline's icon, its tooltip from the link for a bag item", function()
    local _, row = shown(drop())
    local c = row.cells.me
    assertEqual(c.icons[1].link, BAG); assertTrue(c.icons[1]:IsShown())
    assertNil(c.icons[1].worn, "a bag item: never an inventory slot")
    assertFalse(c.icons[2]:IsShown())
    assertEqual(c.level:GetText(), "291"); assertEqual(c.glyph:GetText(), "▲"); assertEqual(c.text:GetText(), "20 Holy")
    local _, row2 = shown(drop({ me = cantMain(off({ baseline = { link = WORN, ilvl = 300, slot = 16 }, ilvlDelta = 11 })) }))
    assertEqual(row2.cells.me.icons[1].worn.slot, 16, "a worn baseline reads its slot")
end)
