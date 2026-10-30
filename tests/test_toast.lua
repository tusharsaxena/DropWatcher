-- tests/test_toast.lua — the upgrade toast (design spec §11.5, board 06 C; feedback-9 spec §0): the
-- pure qualifier and composer (the four rows' parts), then the edge on the bus: the painted rows,
-- off by default, one at a time from a queue, dismissed after its duration, on its close mark or on
-- a right-click, paused while hovered, held in combat unless allowed, each drop once, placed and
-- saved only in test mode, the optional sound, the Ask button, the stand-down and the diagnostics.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function drop(over)
    local d = {
        id = 1, link = link(500), itemID = 500, isMine = false,
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("toast: Qualifies wants someone else's upgrade for you of minGain or more, likely or yes to trade", function()
    local Q = T.newAddon().Toast.Qualifies
    assertTrue(Q(drop(), 10))
    assertTrue(Q(drop({ me = { verdict = "upgrade", ilvlDelta = 10 } }), 10), "exactly the threshold")
    assertTrue(Q(drop({ trade = { state = "yes" } }), 10))
    -- An empty slot is an upgrade with no item-level change (the kernel's emptySlot reason): it
    -- clears any least gain (DW-62 review F-002, design spec §5.2, §11.5).
    local empty = { verdict = "upgrade", reasons = { { key = "emptySlot" } } }
    -- red under: a gain test that reads a missing ilvlDelta as failing (modules/Toast.lua Qualifies)
    assertTrue(Q(drop({ me = empty }), 10))
    assertTrue(Q(drop({ me = empty }), 50))
    local cases = {
        { drop({ isMine = true }), "mine" },
        { drop({ me = { verdict = "sidegrade", ilvlDelta = 19 } }), "notUpgrade" },
        { drop({ me = false }), "notUpgrade" },
        { drop({ me = { verdict = "upgrade", ilvlDelta = 9 } }), "gain" },
        { drop({ me = { verdict = "upgrade" } }), "gain" },
        { drop({ me = { verdict = "upgrade", reasons = { { key = "uniqueEquipped" } } } }), "gain" },
        { drop({ trade = { state = "unknown" } }), "trade" },
        { drop({ trade = { state = "no" } }), "trade" },
        { drop({ trade = false }), "trade" },
        { nil, "mine" },
    }
    for i, c in ipairs(cases) do
        local ok, why = Q(c[1], 10)
        assertFalse(ok, "case " .. i); assertEqual(why, c[2], "case " .. i)
    end
end)

test("toast: Compose answers the four rows' parts (feedback-9 spec §0)", function()
    local NS = T.newAddon()
    local Toast = NS.Toast
    local t = Toast.Compose(drop({ them = { verdict = "downgrade", ilvlDelta = -13 } }))
    assertEqual(t.title, "Big upgrade for you"); assertEqual(t.link, link(500))
    -- Row 2: the name in its quality color (here the link's own code), the item level apart.
    assertEqual(t.item, "Item 500"); assertEqual(t.itemText, "|cffa335eeItem 500|r"); assertEqual(t.ilvl, 311)
    -- Row 3: the looter in their class color, and both verdicts as the Me and Them cells draw them.
    assertEqual(t.looter, "Seta"); assertEqual(t.classFile, "PRIEST")
    assertEqual(t.looterText, NS.TipMarks.ClassName("Seta", "PRIEST"))
    assertEqual(t.me.glyph, "▲"); assertEqual(t.me.text, "19"); assertEqual(t.me.tone, "good")
    assertEqual(t.them.glyph, "▼"); assertEqual(t.them.text, "13"); assertEqual(t.them.tone, "red")
    -- Row 4: the trade word in the Trade cell's tone, the short reason; the full one in the tooltip.
    assertEqual(t.trade, "Likely tradeable"); assertEqual(t.tradeTone, "good")
    assertEqual(t.reason, "not an upgrade for Seta")
    assertEqual(t.tip[1], "Trade: Likely")
    assertEqual(t.tip[2], NS.WindowCells.Trade(drop()).tip[2], "the Trade cell's rows")
    assertEqual(T.tipPlain(t.tip[2]), "• Rule: personal loot")
end)

test("toast: Compose keeps the table's words, the empty slot and each trade reason", function()
    local NS = T.newAddon()
    local C = NS.Toast.Compose
    local side = C(drop({ me = { verdict = "sidegrade", ilvlDelta = 1 } }))
    assertEqual(side.me.glyph, "≈"); assertEqual(side.me.text, "1"); assertEqual(side.me.tone, "yellow")
    local t = C(drop())
    assertNil(t.them.glyph, "their gear not read: the word")
    assertEqual(t.them.text, "?"); assertEqual(t.them.tone, "muted")
    t = C(drop({ them = { verdict = "cantUse" } }))
    assertNil(t.them.glyph); assertEqual(t.them.text, "Can't use"); assertEqual(t.them.tone, "redMuted")
    t = C(drop({ them = { verdict = "doesntWant" } }))
    assertEqual(t.them.text, "Not wanted"); assertEqual(t.them.tone, "bad")
    t = C(drop({ me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } }))
    assertEqual(t.me.text, "empty", "an empty slot reads as the Me column does, never 0")
    assertEqual(t.me.glyph, "▲"); assertEqual(t.me.tone, "good")
    t = C(drop({ trade = { state = "yes", reasonKey = "boe" } }))
    assertEqual(t.trade, "Tradeable"); assertEqual(t.tradeTone, "good"); assertEqual(t.reason, "bind on equip")
    t = C(drop({ trade = { state = "likely", reasonKey = "groupLoot" } }))
    assertEqual(t.reason, "group loot: four hours to trade")
    t = C(drop({ trade = { state = "likely", reasonKey = "error", args = { "x" } } }))
    assertEqual(t.reason, "The estimate failed: x", "any other reason is the Trade cell's, its period dropped")
    t = C(drop({ looter = false, facts = false }))
    assertEqual(t.looter, "?"); assertNil(t.ilvl)
end)

-- Rough widths in the client's GameFontHighlightSmall: under 5 pixels a character (the owner's
-- screenshot 01 draws `Looted by Seta · +19 ↑ · Likely trad…`, 37 characters, in about 170 of the
-- toast's then 340), and a 12-point monospace glyph about 7; both times the toast's SCALE (90 / 74,
-- DW-05: its faces are drawn that much larger).
local SCALE = 90 / 74
local CHAR_W, GLYPH_W = 5 * SCALE, 7 * SCALE

-- Row 3's drawn width: the looter's segment, then each verdict's glyph (when it has one) and text.
local function row3Width(NS, t)
    local TM, G, S = NS.TipMarks, NS.Toast.SEG_GAP, NS.Toast.GLYPH_GAP
    local function verdict(part)
        return G + (part.glyph and GLYPH_W + S or 0) + TM.Chars(part.text) * CHAR_W
    end
    return TM.Chars(("Looted by %s · You"):format(t.looterText)) * CHAR_W + verdict(t.me)
        + G + TM.Chars("· Them") * CHAR_W + verdict(t.them)
end

test("toast: the longest rows fit at Toast.WIDTH, nothing cut (feedback-9 spec §0)", function()
    local NS = T.newAddon()
    local Toast, TM = NS.Toast, NS.TipMarks
    local long = drop({ looter = { name = "Abcdefghijkl-Realm", classFile = "PRIEST" },
        me = { verdict = "upgrade", ilvlDelta = 19 }, them = { verdict = "downgrade", ilvlDelta = -13 } })
    local t = Toast.Compose(long)
    local row4 = TM.Chars(t.trade) * CHAR_W + Toast.SEG_GAP + TM.Chars("· " .. t.reason) * CHAR_W
    assertEqual(Toast.WIDTH, 426)
    local row3 = row3Width(NS, t)
    assertTrue(row3 <= Toast.RowWidth(), ("row 3: %d > %d"):format(row3, Toast.RowWidth()))
    -- red under: WIDTH 340 (an empty slot, `▲ empty`, then a Them word; 267 > 258)
    for _, them in ipairs({ { verdict = "cantUse" }, { verdict = "doesntWant" } }) do
        t = Toast.Compose(drop({ looter = long.looter, them = them,
            me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } }))
        row3 = row3Width(NS, t)
        assertTrue(row3 <= Toast.RowWidth(), ("row 3, %s: %d > %d"):format(them.verdict, row3, Toast.RowWidth()))
    end
    assertTrue(row4 <= Toast.RowWidth(), ("row 4: %d > %d"):format(row4, Toast.RowWidth()))
    assertEqual(Toast.HEIGHT, Toast.ICON + 2 * Toast.INSET, "the icon spans the rows; the frame keeps its insets")
end)

test("toast: 90 px tall, DpsRace's new-best toast, every size scaled to match (DW-05)", function()
    local Toast = T.newAddon().Toast
    -- red under: the first release's 74 (ICON 56 + 2 x INSET 9)
    assertEqual(Toast.HEIGHT, 90, "DpsRace's BestToast.HEIGHT after DR-04")
    assertEqual(Toast.SCALE, 90 / 74, "the first release's sizes times 90 / 74")
    assertEqual(Toast.ICON, 68); assertEqual(Toast.INSET, 11)        -- 56, 9
    assertEqual(Toast.HEIGHT, Toast.ICON + 2 * Toast.INSET)
    assertEqual(Toast.WIDTH, 426); assertEqual(Toast.TEXT_GAP, 10)    -- 350, 8
    assertEqual(Toast.ROW_Y[1], 0); assertEqual(Toast.ROW_Y[2], -18); assertEqual(Toast.ROW_Y[3], -36)
    assertEqual(Toast.SEG_GAP, 5); assertEqual(Toast.GLYPH_GAP, 4)    -- 4, 3
    assertEqual(Toast.ASK_W, 78)                                      -- 64
    assertEqual(Toast.RowWidth(), 426 - 22 - 68 - 10)
end)

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- An enabled instance whose feed answers `drops` by id, the toast turned on unless `off`.
local function enabled(drops, off)
    local NS, _, m = T.enableAddon()
    local byId = {}
    for _, d in ipairs(drops or {}) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    if not off then assertTrue(NS.SchemaRuntime.Set("toast.enabled", true)) end
    return NS, m, byId
end

local function added(NS, id) NS.addon:SendMessage(NS.MSG.DROP_ADDED, id) end

local function shown(NS) return NS.Toast.Stats().shown end

test("toast edge: on for a new profile; turned off, nothing is built or shown", function()
    local NS = enabled({ drop() }, true)
    assertEqual(NS.Setting("toast.enabled"), true, "a new profile's default (2026-10-25)")
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    added(NS, 1)
    assertNil(NS.Toast.Frame()); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: a qualifying drop shows at once, painted, and goes after its duration", function()
    local NS, m = enabled({ drop(), drop({ id = 2, me = { verdict = "upgrade", ilvlDelta = 3 } }) })
    added(NS, 2)
    assertNil(NS.Toast.Frame(), "a small gain does not toast")
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertTrue(shown(NS)); assertEqual(NS.Toast.Stats().dropId, 1)
    assertEqual(f.title:GetText(), "Big upgrade for you")
    assertEqual(f.item:GetText(), "|cffa335eeItem 500|r")
    assertEqual(f.ask.label:GetText(), "Ask"); assertTrue(f.ask:IsEnabled())
    assertTrue(f.ask.art:IsShown() and f.ask.art:GetTexture() == NS.Icon("chat"), "Ask wears chat (feedback-7 spec §1)")
    assertEqual(#m.sounds, 0, "no sound unless asked for")
    local pt = { f:GetPoint(1) }
    assertEqual(pt[1], "TOP"); assertEqual(pt[5], -160)
    m.advance(7.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS)); assertNil(NS.Toast.Stats().dropId)
end)

test("toast edge: the four rows beside a four-row icon, painted (feedback-9 spec §0)", function()
    local NS = enabled({ drop({ them = { verdict = "downgrade", ilvlDelta = -13 } }) })
    added(NS, 1)
    local f = NS.Toast.Frame()
    local C = NS.Constants
    assertEqual(f.icon:GetWidth(), NS.Toast.ICON); assertEqual(f:GetHeight(), NS.Toast.ICON + 2 * NS.Toast.INSET)
    -- Row 2: the item level always shows, after the name, smaller and muted.
    assertEqual(f.ilvl:GetText(), "311"); assertTrue(f.ilvl:IsShown())
    assertEqual(f.ilvl.__template, "GameFontHighlightSmall")
    assertEqual(f.ilvl.__textColor[1], C.TONE.muted.r)
    assertEqual(f.ilvl.__points[1][2], f.item, "the level follows the name")
    -- Row 3: the looter in their class color, then each verdict's mono glyph and number in its tone.
    assertEqual(f.looted:GetText(), "Looted by |cffffffffSeta|r · You")
    assertEqual(f.meGlyph:GetText(), "▲"); assertEqual(f.meGlyph.__font[1], C.FONT_MONO)
    assertEqual(f.meText:GetText(), "19"); assertEqual(f.meText.__textColor[2], C.TONE.good.g)
    assertEqual(f.meGlyph.__textColor[2], C.TONE.good.g)
    assertEqual(f.themLabel:GetText(), "· Them"); assertEqual(f.themLabel.__points[1][2], f.meText)
    assertEqual(f.themGlyph:GetText(), "▼"); assertEqual(f.themGlyph.__font[1], C.FONT_MONO)
    assertEqual(f.themText:GetText(), "13"); assertEqual(f.themText.__textColor[1], C.TONE.red.r)
    local last = f.themText.__points[2]
    assertEqual(last[1], "RIGHT"); assertEqual(last[2], f); assertEqual(last[4], -NS.Toast.INSET, "cut at the inset")
    -- Row 4: the trade word in its tone, the reason muted and running to the right inset.
    assertEqual(f.trade:GetText(), "Likely tradeable"); assertEqual(f.trade.__textColor[2], C.TONE.good.g)
    assertEqual(f.reason:GetText(), "· not an upgrade for Seta")
    local right = f.reason.__points[2]
    assertEqual(right[1], "RIGHT"); assertEqual(right[2], f); assertEqual(right[4], -NS.Toast.INSET)
    -- The tooltip is the Trade cell's: the full reason.
    local tip = NS.Window.TooltipOf(f)
    assertEqual(tip[1], "Trade: Likely")
    assertEqual(T.tipPlainJoined({ tip[2], tip[3] }), "• Rule: personal loot | • For Seta: not an upgrade, so they may trade it")
    -- The arrow texture and the signed gain are gone; no glyph is drawn in the default face.
    for _, r in ipairs(f.__regions) do
        local tx = r.__objType == "FontString" and r.__text
        if type(tx) == "string" and not (r.__font and r.__font[1] == C.FONT_MONO) then
            for _, mark in ipairs({ "▲", "▼", "≈", "|T" }) do assertFalse(tx:find(mark, 1, true) ~= nil, tx) end
            assertFalse(tx:find("+19", 1, true) ~= nil, tx)
        end
    end
end)

-- Two trinkets each side, both read (feedback-21 H7): yours 321/300, Seta's 324/296.
local TRINKET = { ilvl = 311, equipLoc = "INVTYPE_TRINKET", quality = 4 }
local MY_TRINKETS = { [13] = { link = link(601), ilvl = 321 }, [14] = { link = link(602), ilvl = 300 } }
local HER_TRINKETS = { [13] = { link = link(603), ilvl = 324 }, [14] = { link = link(604), ilvl = 296 } }

local function dualDrop(over)
    local d = drop({ facts = TRINKET, me = { verdict = "upgrade", ilvlDelta = 11, either = true },
        them = { verdict = "upgrade", ilvlDelta = 15, either = true }, looter = { name = "Abcdefghijkl-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" } })
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function partsText(p)
    local a, b = p.parts[1], p.parts[2]
    return ("%s %s%s / %s %s%s"):format(a.level, a.glyph, a.text, b.level, b.glyph, b.text)
end

test("toast: on a two-item slot read in full each verdict is the cells' dual mark, and the toast widens for it (H7)", function()
    local NS = T.newAddon()
    local Toast, TM = NS.Toast, NS.TipMarks
    local t = Toast.Compose(dualDrop(), MY_TRINKETS, HER_TRINKETS)
    assertEqual(partsText(t.me), "321 ▼10 / 300 ▲11"); assertEqual(t.me.parts[1].tone, "red")
    assertEqual(partsText(t.them), "324 ▼13 / 296 ▲15")
    assertNil(Toast.Compose(dualDrop()).me.parts, "no gear: the one mark")
    assertNil(Toast.Compose(dualDrop({ facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 } }),
        { [1] = { link = link(605), ilvl = 300 } }).me.parts, "a single slot: the one mark")
    -- Row 3 at the harness's estimate: `Looted by Abcdefghijkl · You 321 ▼10 / 300 ▲11 · Them 324 ▼13 / 296 ▲15`.
    local G, S = Toast.SEG_GAP, Toast.GLYPH_GAP
    local function verdict(p)
        local a, b = p.parts[1], p.parts[2]
        return G + TM.Chars(a.level) * CHAR_W + G + GLYPH_W + S + TM.Chars(a.text) * CHAR_W + G + CHAR_W
            + G + TM.Chars(b.level) * CHAR_W + G + GLYPH_W + S + TM.Chars(b.text) * CHAR_W
    end
    local row3 = TM.Chars(("Looted by %s · You"):format(t.looterText)) * CHAR_W + verdict(t.me)
        + G + TM.Chars("· Them") * CHAR_W + verdict(t.them)
    assertTrue(row3 > Toast.RowWidth(), "two dual marks do not fit WIDTH's row: it would be cut")
    assertTrue(Toast.WidthFor(row3) - (Toast.WIDTH - Toast.RowWidth()) >= row3, "the widened toast holds row 3")
    assertEqual(Toast.WidthFor(100), Toast.WIDTH, "a short row 3 keeps the least width")
end)

test("toast edge: a dual mark is painted part by part, and the toast is only as wide as row 3 needs (H7)", function()
    local d1, d2 = dualDrop(), drop({ id = 2, them = { verdict = "downgrade", ilvlDelta = -13 } })
    local NS, m = enabled({ d1, d2 })
    local C = NS.Constants
    m.textCharWidth = 5
    NS.Gear.Snapshot = function() return { equipped = MY_TRINKETS } end
    NS.Inspect.Get = function() return { status = "fresh", at = 0, gear = HER_TRINKETS } end
    added(NS, 1)
    local f = NS.Toast.Frame()
    local l = f.meLead
    assertEqual(l.leadLevel:GetText(), "321"); assertEqual(l.leadGlyph:GetText(), "▼"); assertEqual(l.leadText:GetText(), "10")
    assertEqual(l.leadGlyph.__font[1], C.FONT_MONO); assertEqual(l.leadText.__textColor[1], C.TONE.red.r)
    assertEqual(l.sep:GetText(), "/"); assertEqual(f.meLevel:GetText(), "300"); assertTrue(f.meLevel:IsShown())
    assertEqual(f.meGlyph:GetText(), "▲"); assertEqual(f.meText:GetText(), "11")
    assertEqual(l.leadLevel.__points[1][2], f.looted); assertEqual(f.meLevel.__points[1][2], l.sep)
    assertEqual(f.meGlyph.__points[1][2], f.meLevel); assertEqual(f.themLabel.__points[1][2], f.meText)
    assertEqual(f.themLead.leadLevel:GetText(), "324"); assertEqual(f.themLevel:GetText(), "296")
    local wide = f:GetWidth()
    assertTrue(wide > NS.Toast.WIDTH, "two dual marks widen it: " .. wide)
    NS.Toast.Dismiss()
    added(NS, 2)
    assertEqual(NS.Toast.Stats().dropId, 2)
    assertEqual(f:GetWidth(), NS.Toast.WIDTH, "the next, single-mark toast is back at WIDTH")
    assertFalse(f.meLead.sep:IsShown() or f.meLevel:IsShown(), "and draws no lead pieces")
end)

test("toast edge: the widened toast holds the Them verdict too, not only up to `· Them` (H7)", function()
    -- A dual mark on your side, one mark on theirs: `You 315 ▼10 / 295 ▲10 · Them ▼10` was cut at ▼.
    local d = dualDrop({ them = { verdict = "downgrade", ilvlDelta = -10 } })
    local NS, m = enabled({ d })
    m.textCharWidth = 5
    NS.Gear.Snapshot = function() return { equipped = MY_TRINKETS } end
    added(NS, 1)
    local f = NS.Toast.Frame()
    local G, S = NS.Toast.SEG_GAP, NS.Toast.GLYPH_GAP
    local function w(fs) return fs:GetUnboundedStringWidth() end
    local l = f.meLead
    local row3 = w(f.looted) + G + w(l.leadLevel) + G + w(l.leadGlyph) + S + w(l.leadText) + G + w(l.sep)
        + G + w(f.meLevel) + G + w(f.meGlyph) + S + w(f.meText) + G + w(f.themLabel)
        + G + w(f.themGlyph) + S + w(f.themText)
    assertTrue(f.themGlyph:IsShown(), "their verdict has its glyph")
    local room = f:GetWidth() - (NS.Toast.WIDTH - NS.Toast.RowWidth())
    assertTrue(room >= row3, ("row 3 needs %d, the toast gives %d"):format(row3, room))
end)

test("toast edge: a verdict in a word takes no glyph's room", function()
    local NS = enabled({ drop({ them = { verdict = "cantUse" } }) })
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertFalse(f.themGlyph:IsShown()); assertEqual(f.themText:GetText(), "Can't use")
    assertEqual(f.themText.__points[1][2], f.themLabel)
end)

test("toast edge: a looter of unknown class is a plain name in row 3's muted tone", function()
    local NS = enabled({ drop({ looter = { name = "Seta" } }) })
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertEqual(f.looted:GetText(), "Looted by Seta · You")
    assertEqual(f.looted.__textColor[1], NS.Constants.TONE.muted.r)
end)

test("toast edge: a right-click anywhere closes it as the close mark does; the left button does not", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    added(NS, 1); added(NS, 2)
    local f = NS.Toast.Frame()
    local pressed = 0
    NS.PressAsk = function() pressed = pressed + 1 end
    f:GetScript("OnMouseUp")(f, "LeftButton")
    assertEqual(NS.Toast.Stats().dropId, 1, "a left click keeps it")
    f:GetScript("OnMouseUp")(f, "RightButton")
    assertEqual(NS.Toast.Stats().dropId, 2, "closed: the next shows")
    -- On its controls too: the icon, Ask and the close mark.
    f.ask:GetScript("OnMouseUp")(f.ask, "RightButton")
    assertFalse(shown(NS)); assertEqual(pressed, 0, "nothing asked for")
    added(NS, 1); added(NS, 2)
    assertFalse(shown(NS), "a closed drop does not toast again")
end)

test("toast edge: in test mode the left button still drags it and a left click keeps it", function()
    local NS = enabled({ drop() })
    NS.State.testMode = true
    added(NS, 1)
    local f = NS.Toast.Frame()
    local moved = 0
    f.StartMoving = function() moved = moved + 1 end
    f:GetScript("OnDragStart")(f)
    f:GetScript("OnDragStop")(f)
    f:GetScript("OnMouseUp")(f, "LeftButton")
    assertEqual(moved, 1); assertTrue(shown(NS))
    f:GetScript("OnMouseUp")(f, "RightButton")
    assertFalse(shown(NS), "a test toast closes on a right-click too")
end)

test("toast edge: without LibKa0s the seam's stub answers: nothing builds or shows, nothing raises", function()
    local NS = T.enableAddon{ skip = T.loadAddon.libFiles }
    NS.LootFeed.Get = function(id) if id == 1 then return drop() end end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    added(NS, 1)
    -- red under: a modules/Toast.lua that builds a frame of its own when LibKa0s-Toast-1.0 is absent
    assertNil(NS.Toast.Frame()); assertFalse(shown(NS))
    local s = NS.Toast.Stats()
    assertEqual(s.waiting, 0); assertEqual(#s.queue, 0); assertFalse(s.held)
    NS.Toast.Dismiss(); NS.Toast.Ask(); NS.Toast.ApplyScale(); NS.Toast.ResetPosition(); NS.Toast.Prune()
end)

test("toast edge: a Core without a close mark draws none; Ask takes its corner, a right-click still closes", function()
    local NS, m = enabled({ drop() })
    m.LibStub("LibKa0s-Core-1.0").MakeCloseButton = nil
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertTrue(f ~= nil and shown(NS), "the toast builds and shows")
    -- red under: restore the typed × fallback in modules/Toast.lua
    assertNil(f.close, "no one-off close mark (standalone-windows)")
    local point, rel = f.ask:GetPoint(1)
    assertEqual(point, "TOPRIGHT", "Ask is anchored in the close mark's corner")
    assertTrue(rel == f, "on the toast itself")
    f:GetScript("OnMouseUp")(f, "RightButton")
    assertFalse(shown(NS), "a right-click closes it")
end)

test("toast edge: a right-click on the item button closes it too", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    f.icon:GetScript("OnMouseUp")(f.icon, "RightButton")
    assertFalse(shown(NS))
end)

test("toast edge: one at a time; the next waits its turn, and each drop toasts once", function()
    local NS, m = enabled({ drop(), drop({ id = 2, link = link(501) }), drop({ id = 3, link = link(502) }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 1); assertEqual(NS.Toast.Stats().waiting, 2)
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    added(NS, 1)
    assertEqual(NS.Toast.Stats().waiting, 2, "a drop already toasted is not queued again")
    m.advance(8)
    assertEqual(NS.Toast.Stats().dropId, 2)
    NS.Toast.Dismiss()
    assertEqual(NS.Toast.Stats().dropId, 3, "a click on the close mark shows the next")
    m.advance(8)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the queue keeps the newest MAX_QUEUE drops", function()
    local list = {}
    for i = 1, 8 do list[i] = drop({ id = i }) end
    local NS = enabled(list)
    for i = 1, 8 do added(NS, i) end
    assertEqual(NS.Toast.Stats().waiting, NS.Toast.MAX_QUEUE)
    NS.Toast.Dismiss()
    assertEqual(NS.Toast.Stats().dropId, 4, "2 and 3 were dropped as the oldest")
end)

test("toast edge: a drop that turns likely later toasts on its DropUpdated", function()
    local NS, _, byId = enabled({ drop({ trade = { state = "unknown" } }) })
    added(NS, 1)
    assertNil(NS.Toast.Frame())
    byId[1] = drop()
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertTrue(shown(NS))
end)

test("toast edge: a hover pauses the countdown, and leaving resumes it with the time left", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    m.advance(5)
    f.__mouseOver = true
    f:GetScript("OnEnter")(f)
    m.advance(30)
    assertTrue(shown(NS), "paused while hovered")
    f:GetScript("OnLeave")(f)
    assertTrue(shown(NS), "still over the frame (a child took the pointer): no resume")
    f.__mouseOver = false
    f:GetScript("OnLeave")(f)
    m.advance(2.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS), "the 3s it had left ran out")
end)

test("toast edge: leaving through the close button resumes the countdown", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    m.advance(5)
    f.__mouseOver = true
    f:GetScript("OnEnter")(f)
    -- The pointer moves onto the close button: still over the frame, so its OnLeave holds the pause.
    f:GetScript("OnLeave")(f)
    f.close:GetScript("OnEnter")(f.close)
    m.advance(30)
    assertTrue(shown(NS), "paused while over the close button")
    -- Then straight off the toast from the close button.
    f.__mouseOver = false
    f.close:GetScript("OnLeave")(f.close)
    m.advance(2.9)
    assertTrue(shown(NS))
    m.advance(0.2)
    assertFalse(shown(NS), "the 3s it had left ran out")
end)

test("toast edge: not shown in combat; held until it ends, unless toast.inCombat", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }) })
    m.inCombat = true
    added(NS, 1)
    assertNil(NS.Toast.Frame()); assertTrue(NS.Toast.Stats().held)
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(shown(NS)); assertEqual(NS.Toast.Stats().dropId, 1)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 1, "back to the head of the queue")
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(shown(NS), "allowed in combat now")
    m.__fire("PLAYER_REGEN_DISABLED")
    assertTrue(shown(NS), "and kept on screen")
end)

test("toast edge: a drop asked for, or gone from the feed, is skipped when its turn comes", function()
    local NS, _, byId = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    local asks = NS.Asks.StateOf
    NS.Asks.StateOf = function(kind, target, id) if id == 2 then return "sent" end return asks(kind, target, id) end
    byId[3] = nil
    NS.Toast.Dismiss()
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: Ask goes through the shared host handler, and the button follows its state", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local pressed = {}
    NS.PressAsk = function(id) pressed[#pressed + 1] = id end
    NS.Asks.StateOf = function() return "queued" end
    local f = NS.Toast.Frame()
    f.ask:GetScript("OnClick")(f.ask)
    assertEqual(pressed[1], 1)
    assertEqual(f.ask.label:GetText(), "Queued")
    assertTrue(f.ask.art:GetTexture() == NS.Icon("clock"), "Queued wears clock")
    NS.Asks.StateOf = function() return "sent" end
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "sent", "ask", "Seta-Testrealm")
    assertEqual(f.ask.label:GetText(), "Asked"); assertFalse(f.ask:IsEnabled())
end)

test("toast edge: toast.sound plays the client's alert from SOUNDKIT", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }) })
    assertTrue(NS.SchemaRuntime.Set("toast.sound", true))
    added(NS, 1)
    assertEqual(#m.sounds, 1); assertEqual(m.sounds[1][1], m.SOUNDKIT.UI_EPICLOOT_TOAST)
    assertEqual(m.sounds[1][2], "Master")
    NS.Toast.Dismiss()
    m.SOUNDKIT = nil
    added(NS, 2)
    assertTrue(shown(NS), "no SOUNDKIT: the toast still shows")
    assertEqual(#m.sounds, 1, "and nothing is played")
end)

test("toast edge: only test mode drags it; the position is saved and Reset position forgets it", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    local moved = 0
    f.StartMoving = function() moved = moved + 1 end
    f:GetScript("OnDragStart")(f)
    assertEqual(moved, 0, "outside test mode it stays put")
    NS.State.testMode = true
    f:GetScript("OnDragStart")(f)
    assertEqual(moved, 1)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 40, 500)
    f:GetScript("OnDragStop")(f)
    local p = NS.addon.db.profile.toast.point
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], "BOTTOMLEFT"); assertEqual(p[4], 500)
    NS.Window.ResetPosition()
    assertNil(NS.addon.db.profile.toast.point)
    assertEqual(({ f:GetPoint(1) })[1], "TOP")
end)

-- feedback-21 G10: toast.scale is the frame's scale, and the saved point is in UIParent's units.
test("toast edge: toast.scale scales a toast on screen live about its saved anchor, the point unchanged", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertEqual(f:GetScale(), 1, "today's size by default")
    assertTrue(NS.SchemaRuntime.Set("toast.scale", 2))
    -- red under: the row without its onChange, or applyPoint without SetScale (modules/Toast.lua)
    assertEqual(f:GetScale(), 2, "live, on the toast on screen")
    assertTrue(shown(NS), "still on screen")
    local point, _, rel, x, y = f:GetPoint(1)
    assertEqual(point, "TOP"); assertEqual(rel, "TOP"); assertEqual(x, 0)
    assertEqual(y, -80, "the default -160 in the toast's own units at scale 2: the anchor stays put")
    assertNil(NS.addon.db.profile.toast.point, "nothing saved by a scale change")
    -- A drag at scale 2 saves the offsets in UIParent's units, and a scale change keeps them.
    NS.State.testMode = true
    f:GetScript("OnDragStart")(f)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 20, 250)
    f:GetScript("OnDragStop")(f)
    local p = NS.addon.db.profile.toast.point
    assertEqual(p[3], 40); assertEqual(p[4], 500, "times the scale")
    assertTrue(NS.SchemaRuntime.Set("toast.scale", 0.5))
    assertEqual(f:GetScale(), 0.5)
    local _, _, _, x2, y2 = f:GetPoint(1)
    assertEqual(x2, 80); assertEqual(y2, 1000, "divided by the new scale: the same place on screen")
    assertEqual(NS.addon.db.profile.toast.point[4], 500, "the saved point is unchanged")
end)

test("toast edge: the first toast is built at toast.scale, and a profile switch takes the incoming scale", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    assertTrue(NS.SchemaRuntime.Set("toast.scale", 1.25))
    added(NS, 1)
    local f = NS.Toast.Frame()
    assertEqual(f:GetScale(), 1.25, "built at the stored scale")
    NS.addon.db:SetProfile("Other")
    -- red under: OnProfileReloaded without re-applying the point (modules/Toast.lua)
    assertEqual(f:GetScale(), 1, "the incoming profile's default")
    assertEqual(({ f:GetPoint(1) })[5], -160)
end)

test("toast edge: test mode's placeholder toasts and stays until test mode ends", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.seedGearJournal()
    NS.SetTestMode(true)
    local id = NS.Toast.Stats().dropId
    assertTrue(id ~= nil, "the +19 crown qualifies")
    assertTrue(NS.LootFeed.Get(id).test)
    m.advance(60)
    assertTrue(shown(NS), "a test toast waits to be placed")
    NS.SetTestMode(false)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

-- ── the toast follows its drop and its switch (DW-62 review F-001, F-004) ───────────────────

test("toast edge: a drop that leaves the feed takes its toast and its place in the queue", function()
    local NS, _, byId = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 1); assertEqual(NS.Toast.Stats().waiting, 2)
    -- `/dw clear` and clear-on-boss-kill empty the feed through LootFeed.Clear, which tells its sinks.
    byId[1], byId[2] = nil, nil
    -- red under: a toast with no removal sink (modules/Toast.lua)
    NS.LootFeed.Clear("live")
    assertEqual(NS.Toast.Stats().dropId, 3, "the gone toast went, and the gone drop in the queue was skipped")
    byId[3] = nil
    NS.LootFeed.Clear("live")
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the cap's trim takes the trimmed drop's toast, through the real feed", function()
    local NS, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    local LF = NS.LootFeed
    local first = LF.AddTest({ link = link(500), looter = { name = "Seta", classFile = "PRIEST" },
        group = { key = "g", label = "G", kind = "encounter" }, me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", args = {} } })
    assertEqual(NS.Toast.Stats().dropId, first)
    LF.MAX_DROPS = 1
    LF.AddTest({ link = link(501), looter = { name = "Seta", classFile = "PRIEST" },
        group = { key = "g", label = "G", kind = "encounter" }, me = { verdict = "downgrade", ilvlDelta = -3 },
        trade = { state = "likely", args = {} } })
    LF.MAX_DROPS = 200
    assertEqual(LF.Get(first), nil, "the first drop was trimmed")
    assertFalse(shown(NS), "and its toast went with it")
    m.advance(1)
end)

test("toast edge: Ask on a toast whose drop is gone takes the toast down and asks nothing", function()
    local NS, _, byId = enabled({ drop() })
    added(NS, 1)
    local pressed = 0
    NS.PressAsk = function() pressed = pressed + 1 end
    byId[1] = nil
    NS.Toast.Ask()
    assertEqual(pressed, 0); assertFalse(shown(NS))
end)

test("toast edge: turning the toast off takes it down and empties the queue; on again, new drops toast", function()
    local NS = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    added(NS, 1); added(NS, 2)
    -- red under: a toast.enabled row with no reaction (settings/SchemaRows.lua)
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    assertFalse(shown(NS), "what was dropped stays dropped")
    added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 3)
end)

test("toast edge: a test toast goes when the toast is turned off, though it has no countdown", function()
    local NS, _, m = T.enableAddon()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.seedGearJournal()
    NS.SetTestMode(true)
    assertTrue(shown(NS))
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    assertFalse(shown(NS))
end)

test("toast edge: a profile switch to one with the toast off takes it down", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    local db = NS.addon.db
    local home = db:GetCurrentProfile()
    db:SetProfile("Other")
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    db:SetProfile(home)
    added(NS, 1); added(NS, 2)
    assertTrue(shown(NS))
    db:SetProfile("Other")
    assertEqual(NS.Setting("toast.enabled"), false)
    -- red under: reloadProfile without NS.Toast.OnProfileReloaded (core/DropWatcher.lua)
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

test("toast edge: the stand-down empties the queue and takes the toast down", function()
    local NS = enabled({ drop(), drop({ id = 2 }) })
    added(NS, 1); added(NS, 2)
    assertTrue(NS.SchemaRuntime.Set("enabled", false))
    assertFalse(shown(NS)); assertEqual(NS.Toast.Stats().waiting, 0)
end)

-- ── on the shell: what the player saw before LibKa0s-Toast-1.0 still holds (AT-A2) ───────────

test("toast edge: a point saved before the shell moved to LibKa0s places it, with no migration", function()
    local NS = enabled({ drop() })
    NS.addon.db.profile.toast.point = { "TOPLEFT", "BOTTOMLEFT", 40, 500 }
    assertTrue(NS.SchemaRuntime.Set("toast.scale", 2))
    added(NS, 1)
    local f = NS.Toast.Frame()
    local point, _, rel, x, y = f:GetPoint(1)
    -- red under: a getPosition that reads anything but profile.toast.point as stored
    assertEqual(point, "TOPLEFT"); assertEqual(rel, "BOTTOMLEFT")
    assertEqual(x, 20); assertEqual(y, 250, "UIParent's units, divided by the scale, as before")
    assertEqual(NS.addon.db.profile.toast.point[4], 500, "and the saved point is left as it was")
end)

test("toast edge: hovering the item button or Ask holds the countdown too", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    local f = NS.Toast.Frame()
    m.advance(5)
    -- red under: a builder that does not Attach the icon and Ask to the shell
    f.icon:GetScript("OnEnter")(f.icon)
    m.advance(30)
    assertTrue(shown(NS), "paused over the item button")
    f.icon:GetScript("OnLeave")(f.icon)
    f.ask:GetScript("OnEnter")(f.ask)
    m.advance(30)
    assertTrue(shown(NS), "paused over Ask")
    f.ask:GetScript("OnLeave")(f.ask)
    m.advance(3.1)
    assertFalse(shown(NS), "the 3s it had left ran out")
end)

test("toast edge: a drop met in combat waits after a switch's Clear; toast.inCombat on mid-combat shows the next", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    added(NS, 1)
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", false))
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    -- red under: a Consider that does not re-take the hold (the switch's Clear released it)
    added(NS, 2)
    assertFalse(shown(NS), "still held in combat"); assertTrue(NS.Toast.Stats().held)
    assertEqual(NS.Toast.Stats().queue[1], 2, "the diagnostics name it waiting")
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    added(NS, 3)
    assertEqual(NS.Toast.Stats().dropId, 2, "allowed in combat now: the one waiting shows first")
    assertEqual(NS.Toast.Stats().queue[1], 3)
end)

test("toast edge: a toast held for combat comes back with its full duration", function()
    local NS, m = enabled({ drop() })
    added(NS, 1)
    m.advance(6)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(shown(NS))
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    m.advance(7.9)
    assertTrue(shown(NS), "8 seconds again, not the 2 it had left")
    m.advance(0.2)
    assertFalse(shown(NS))
end)

test("toast edge: Show in combat turned off mid-combat keeps the toast on screen and holds the next", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }) })
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    added(NS, 1); added(NS, 2)
    assertEqual(NS.Toast.Stats().dropId, 1)
    -- red under: a toast.inCombat row with no reaction (the hold re-taken only by the next drop)
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", false))
    assertEqual(NS.Toast.Stats().dropId, 1, "the toast on screen stays up, as the old live check left it")
    assertTrue(NS.Toast.Stats().held)
    NS.Toast.Dismiss()
    assertFalse(shown(NS), "the next waits for combat's end"); assertEqual(NS.Toast.Stats().queue[1], 2)
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(NS.Toast.Stats().dropId, 2)
end)

test("toast edge: a profile switch mid-combat to one without Show in combat holds the next", function()
    local NS, m = enabled({ drop(), drop({ id = 2 }) })
    local db = NS.addon.db
    local home = db:GetCurrentProfile()
    db:SetProfile("Other")
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", false))
    db:SetProfile(home)
    assertTrue(NS.SchemaRuntime.Set("toast.inCombat", true))
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    added(NS, 1); added(NS, 2)
    -- red under: an OnProfileReloaded that does not re-sync the hold
    db:SetProfile("Other")
    assertEqual(NS.Toast.Stats().dropId, 1, "the toast on screen stays up")
    NS.Toast.Dismiss()
    assertFalse(shown(NS), "the next waits for combat's end"); assertTrue(NS.Toast.Stats().held)
end)

test("toast edge: on a shell that names no waiting keys, the drops gone from the feed still leave the queue", function()
    local NS, m, byId = enabled({ drop(), drop({ id = 2 }), drop({ id = 3 }) })
    -- An earlier copy of the same minor registered first by another addon: Stats has no `keys`.
    local shell = NS.Toast.Shell()
    local stats = shell.Stats
    shell.Stats = function(self)
        local s = stats(self)
        s.keys = nil
        return s
    end
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(NS.Toast.Stats().waiting, 3)
    byId[1], byId[2] = nil, nil
    -- red under: a Prune that reads `s.keys or {}` (only the toast on screen would be checked)
    NS.LootFeed.Clear("live")
    assertEqual(NS.Toast.Stats().waiting, 1, "only the drop still in the feed waits")
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(NS.Toast.Stats().dropId, 3)
end)

test("toast: the diagnostics' window section reports the toast", function()
    local NS = enabled({ drop() })
    added(NS, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("toast: enabled=true built=true shown=true drop=1 waiting=0 held=false", 1, true) ~= nil, text)
    assertTrue(text:find("toast: point", 1, true) ~= nil)
end)

-- ── the scale (DW-05) ───────────────────────────────────────────────────────────────────────

local function near(a, b, what) assertTrue(math.abs(a - b) < 0.01, ("%s: %s, not %s"):format(what, a, b)) end

test("toast edge: 90 px tall, its icon, Ask and every face scaled to match DpsRace's toast (DW-05)", function()
    local NS = enabled({ drop({ them = { verdict = "downgrade", ilvlDelta = -13 } }) })
    added(NS, 1)
    local f, Toast = NS.Toast.Frame(), NS.Toast
    assertEqual(f:GetHeight(), 90); assertEqual(f:GetWidth(), 426)
    assertEqual(f.icon:GetWidth(), 68); assertEqual(f.icon:GetHeight(), 68)
    local pt = f.icon.__points[1]
    assertEqual(pt[4], 11); assertEqual(pt[5], -11, "the inset above the icon equals the one below it")
    assertEqual(f.ask:GetWidth(), 78); assertEqual(f.ask:GetHeight(), 24, "CONTROL_H 20, scaled")
    assertEqual(f.ask.markNudge, 9, "the word's nudge past the mark, 7 scaled")
    local lp = f.ask.label.__points[#f.ask.label.__points]
    assertEqual(lp[1], "CENTER"); assertEqual(lp[4], 9)
    local s = Toast.SCALE
    -- The faces: GameFontNormalSmall's and GameFontHighlightSmall's 10 px, GameFontHighlight's 12, the
    -- mono glyphs' 12, each times SCALE.
    near(select(2, f.title:GetFont()), 10 * s, "row 1")
    near(select(2, f.item:GetFont()), 12 * s, "row 2's name")
    near(select(2, f.ilvl:GetFont()), 10 * s, "row 2's level")
    near(select(2, f.looted:GetFont()), 10 * s, "row 3")
    near(select(2, f.meText:GetFont()), 10 * s, "row 3's verdict")
    near(select(2, f.meGlyph:GetFont()), 12 * s, "row 3's glyph")
    near(select(2, f.trade:GetFont()), 10 * s, "row 4")
    near(select(2, f.reason:GetFont()), 10 * s, "row 4's reason")
    near(select(2, f.ask.label:GetFont()), 10 * s, "Ask's word")
    assertEqual(f.meText.__points[1][4], Toast.GLYPH_GAP, "the glyph gap scaled too")
end)

test("toast edge: with CreateFont, each scaled face is a named font object, so Ignore fonts keeps the scale (DW-05)", function()
    local NS, m = enabled({ drop() })
    local made = {}
    m.CreateFont = function(name)
        local obj = { name = name }
        function obj:GetName() return self.name end
        function obj:CopyFontObject(base) self.base = base end
        function obj:SetFont(p, size, flags) self.font = { p, size, flags } end
        function obj:GetFont() return self.font[1], self.font[2], self.font[3] end
        made[name] = obj
        rawset(m, name, obj)
        return obj
    end
    added(NS, 1)
    local f, s = NS.Toast.Frame(), NS.Toast.SCALE
    assertEqual(f.item.__template, "DropWatcher_GameFontHighlight_122")
    assertEqual(f.trade.__template, "DropWatcher_GameFontHighlightSmall_122")
    assertEqual(f.title.__template, "DropWatcher_GameFontNormalSmall_122")
    near(made.DropWatcher_GameFontHighlight_122.font[2], 12 * s, "the name's object")
    near(made.DropWatcher_GameFontHighlightSmall_122.font[2], 10 * s, "the small object")
    assertEqual(NS.ScaledFont("GameFontHighlight", s), "DropWatcher_GameFontHighlight_122", "made once, then reused")
    assertNil(NS.ScaledFont("GameFontNormalHuge", s), "a face with no known size is not scaled")
end)
