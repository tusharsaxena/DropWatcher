-- tests/test_compact_cards.lua — compact mode's cards (compact spec §2 and §3, DW-C1): each card's
-- three lines of text, tones and tooltips for Drops and History, in every state a
-- drop can be in, and the group header's short form (modules/CompactCards.lua, pure). The words,
-- tones and reason tooltips are the full view's composers' (modules/WindowCells.lua,
-- modules/SideCells.lua, modules/MineCells.lua), so each case also checks that the compact piece
-- agrees with its column. Line 3 reads the merged Me and Them cells (feedback-6 spec §1).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Vile Vial of Volatile Venom]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Vial]|h|r"
local OLD2 = "|cffa335ee|Hitem:301::|h[Older Vial]|h|r"
local YOKE = "|cffa335ee|Hitem:230::|h[Yoke of the Charging Bear]|h|r"

local NONE = {}
local NOW = 100

local function with(d, over)
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

-- The spec's Drops card: a trinket Lysandra looted, a downgrade for you (you wear 321 and
-- 308), unusable for her, likely tradeable, inspected two minutes before NOW.
local function groupDrop(over)
    return with({
        id = 7, at = 90, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Lysandra-Realm", guid = "Player-1-0000000L", classFile = "MAGE" },
        facts = { ilvl = 295, equipLoc = "INVTYPE_TRINKET", quality = 4, track = { name = "Champion", rank = 4, max = 8 } },
        me = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        them = { verdict = "cantUse", reasons = { { key = "classRestricted" } } },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 295, 298 }, basis = "inspect", age = 120 },
        inspect = { status = "fresh", at = NOW - 120 },
    }, over)
end

local MY_GEAR = { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD2, ilvl = 308 } }
local HER_GEAR = { [13] = { link = OLD1, ilvl = 298 }, [14] = { link = OLD2, ilvl = 296 } }

local function groupCtx(over)
    return with({ now = NOW, equipped = MY_GEAR, gear = HER_GEAR, ownRealm = "Realm" }, over)
end

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

local function candidates(n)
    local list = {
        cand("Seta", "PRIEST", "ready", { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 169 }, reasons = {} }),
        cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { ilvl = 177 }, reasons = {} }),
        cand("Littlewolf", "ROGUE", "ready", { verdict = "upgrade", ilvlDelta = 3, baseline = { ilvl = 180 }, reasons = {} }),
        cand("Uniquerogue", "ROGUE", "ready", { verdict = "upgrade", ilvlDelta = 1, baseline = { ilvl = 182 }, reasons = {} }),
    }
    local out = {}
    for i = 1, n or 2 do out[list[i].guid] = list[i] end
    return out
end

local function CC() return T.newAddon().CompactCards end

-- A tooltip's lines joined; a non-wrapping line (NS.TipMarks.NoWrap) by its text, a grid by its cells.
local function joined(tip) return T.tipJoined(tip) end

local function has(tip, words) return joined(tip):find(words, 1, true) ~= nil end

-- ── the pieces ──────────────────────────────────────────────────────────────────────────────

test("compact cards: Truncate cuts by characters, not bytes, and marks the cut with …", function()
    local C = CC()
    assertEqual(select(1, C.Truncate("Gate of the Setting Sun", 30)), "Gate of the Setting Sun")
    local s, cut = C.Truncate("Gate of the Setting Sun", 8)
    assertEqual(s, "Gate of…"); assertTrue(cut)
    assertEqual(select(1, C.Truncate("Tiamât Tiamât", 7)), "Tiamât…", "a two-byte character counts once")
    assertEqual(select(1, C.Truncate(nil, 5)), "")
    assertFalse(select(2, C.Truncate("abc", 3)))
end)

test("compact cards: Age is the short duration, then whole days", function()
    local C = CC()
    assertEqual(C.Age(40), "40s"); assertEqual(C.Age(180), "3m"); assertEqual(C.Age(7140), "1h 59m")
    assertEqual(C.Age(86400), "1d"); assertEqual(C.Age(3 * 86400 + 5), "3d"); assertEqual(C.Age(nil), "0s")
end)

test("compact cards: a verdict reads the glyph and the unsigned difference; a worded one takes ⊘", function()
    local NS = T.newAddon()
    local C, S = NS.CompactCards, NS.SideCells
    local cases = {
        { { verdict = "upgrade", ilvlDelta = 19, reasons = {} }, "▲19", "good" },
        { { verdict = "sidegrade", ilvlDelta = 0.2, reasons = {} }, "≈0", "yellow" },
        { { verdict = "downgrade", ilvlDelta = -13, reasons = {} }, "▼13", "red" },
        { { verdict = "cantUse", reasons = {} }, "⊘ Can't use", "redMuted" },
        { { verdict = "doesntWant", reasons = {} }, "⊘ Not wanted", "bad" },
        { NONE, "?", "muted" },
    }
    for _, c in ipairs(cases) do
        local full = S.Me(groupDrop({ me = c[1] }), MY_GEAR)
        local v = C.Verdict(full)
        assertEqual(C.VerdictText(v), c[2])
        assertEqual(v.tone, c[3], c[2]); assertEqual(v.tone, full.tone, "the full view's tone")
        assertEqual(joined(v.tip), joined(full.tip), "the full view's tooltip")
    end
end)

test("compact cards: the worn level comes before the verdict, plain; a word for the state muted", function()
    local NS = T.newAddon()
    local C, S = NS.CompactCards, NS.SideCells
    local you = C.Half("You", S.Me(groupDrop(), MY_GEAR))
    assertEqual(C.HalfText(you), "You 321/308 ▼13"); assertEqual(you.levelTone, "plain")
    assertEqual(#you.items, 2, "both worn trinkets, though line 3 draws no icons")
    local empty = C.Half("You", S.Me(groupDrop(), { [13] = false, [14] = false }))
    assertEqual(C.HalfText(empty), "You empty ▼13"); assertEqual(empty.levelTone, "muted")
    assertEqual(C.HalfText(C.Half("You", S.Me(groupDrop(), {}))), "You … ▼13")
    assertEqual(C.HalfText(C.Half("You", S.Me(groupDrop({ facts = { ilvl = 295 } }), MY_GEAR))), "You ▼13",
        "not worn: no dash before the verdict")
    local range = C.Half("Them", S.Them(groupDrop({ them = NONE, inspect = { status = "outOfRange" } }), {}, NOW))
    assertEqual(C.HalfText(range), "Them range", "the ? goes: range says why")
end)

test("compact cards: a cross-realm looter takes no mark, the realm in the tooltip", function()
    local C = CC()
    local same = C.Looter(groupDrop(), "Realm")
    assertEqual(same.text, "Lysandra"); assertFalse(same.crossRealm); assertTrue(same.mark == nil)
    assertEqual(same.classFile, "MAGE")
    local other = C.Looter(groupDrop({ looter = { name = "Bùnian-Argent Dawn", classFile = "DRUID" } }), "Realm")
    -- red under: the ⊕ after the name (feedback-20 retired it)
    assertEqual(other.text, "Bùnian"); assertTrue(other.crossRealm); assertTrue(other.mark == nil)
    assertTrue(has(other.tip, "From another realm: Argent Dawn."))
    assertFalse(C.Looter(groupDrop({ looter = { name = "Bùnian-ArgentDawn" } }), "Argent Dawn").crossRealm,
        "realms compare normalized")
    assertFalse(C.Looter(groupDrop(), nil).crossRealm, "your realm unknown: no mark")
    assertFalse(C.Looter(groupDrop({ looter = { name = "Bare" } }), "Realm").crossRealm, "no realm: no mark")
end)

test("compact cards: inspect freshness reads its age or state, dimmed, and the tooltip says why", function()
    local C = CC()
    local cases = {
        { { status = "fresh", at = NOW - 120 }, "2m", "Inspected 2m ago." },
        { { status = "cached", at = NOW - 600 }, "cached", "From the inspect cache, read 10m ago." },
        { { status = "pending" }, "…", "Waiting to inspect Lysandra" },
        { { status = "outOfRange" }, "range", "out of range" },
        { { status = "combatParked" }, "combat", "combat to end" },
        { { status = "failed", reason = "timeout" }, "!", "no answer came" },
        { { status = "unavailable" }, "–", "not in your group" },
        { NONE, "…", "Waiting to inspect" },
        { { status = "fresh" }, "fresh", "Inspected." },
    }
    for _, c in ipairs(cases) do
        local f = C.Freshness(groupDrop({ inspect = c[1] }), NOW)
        assertEqual(f.text, c[2], c[2]); assertEqual(f.tone, "muted", c[2])
        assertEqual(f.tip[1], "Inspect of Lysandra")
        assertTrue(has(f.tip, c[3]), c[2] .. ": " .. joined(f.tip))
    end
    local mine = C.Freshness(groupDrop({ isMine = true }), NOW)
    assertEqual(mine.text, "–"); assertTrue(has(mine.tip, "always current"))
end)

-- ── the Drops card ──────────────────────────────────────────────────────────────────────────

test("compact cards: the Drops card reads the spec's three lines", function()
    local C = CC()
    local card = C.Group(groupDrop(), groupCtx())
    local lines = C.Plain(card)
    -- The item level before the name, the inspect freshness on the right (feedback-10 spec §2).
    assertEqual(lines[1], "295 Vile Vial of Volatile Venom (2m)", "the freshness in brackets after the name")
    -- Line 2's right side is the action (feedback-10 spec §2); the engine offers no Ask for a
    -- downgrade, so No action (feedback-11 spec §1).
    assertEqual(lines[2], "Lysandra · Trinket · Trinkets  No action")
    -- red under: the trade word bare on line 2, read as one more fact about the item
    assertEqual(lines[3], "You 321/308 ▼13  Them 298/296 ⊘ Can't use  Trade Likely")
    assertEqual(card.trade.label, "Trade")
    assertEqual(card.kind, "group"); assertEqual(card.id, 7); assertEqual(card.link, LINK)
end)

test("compact cards: no trade window on the card; the freshness on line 1 with or without a countdown (feedback-10 §2)", function()
    local C = CC()
    for _, t in ipairs({
        { state = "likely", reasonKey = "notUpgrade", args = {} },
        { state = "no", reasonKey = "bonusRoll", basis = "bind" },
        { state = "yes", reasonKey = "boe", basis = "bind" },
    }) do
        local card = C.Group(groupDrop({ trade = t }), groupCtx())
        assertTrue(card.countdown == nil, t.reasonKey .. ": no countdown on the card")
        assertEqual(card.fresh.text, "2m"); assertEqual(card.fresh.tone, "muted")
        assertEqual(C.Plain(card)[1]:sub(-5), " (2m)", t.reasonKey .. ": the freshness after the name")
    end
end)

test("compact cards: the freshness mark is bracketed, and left out where there is nothing to say (feedback-10 §2)", function()
    local C = CC()
    assertEqual(C.FreshMark({ text = "2m" }), "(2m)")
    assertEqual(C.FreshMark({ text = "cached" }), "(cached)")
    assertTrue(C.FreshMark({ text = "…" }) == nil, "pending: Them's … already says it (feedback-11 spec §0)")
    assertEqual(C.FreshMark({ text = "range" }), "(range)")
    assertTrue(C.FreshMark({ text = "–" }) == nil, "the dash is no placeholder")
    assertTrue(C.FreshMark({ text = "" }) == nil)
    assertTrue(C.FreshMark(nil) == nil)
end)

test("compact cards: the Drops card's pieces keep the full view's tones and tooltips", function()
    local NS = T.newAddon()
    local C, W = NS.CompactCards, NS.WindowCells
    local d = groupDrop()
    local card = C.Group(d, groupCtx())
    assertEqual(card.item.quality, 4); assertTrue(card.item.gameTooltip, "the game's own tooltip on hover")
    assertEqual(joined(card.ilvl.tip), joined(W.Ilvl(d).tip))
    assertEqual(card.trade.tone, "good"); assertEqual(joined(card.trade.tip), joined(W.Trade(d).tip))
    assertEqual(card.slot.text, "Trinket"); assertEqual(joined(card.slot.tip), joined(W.Slot(d).tip))
    assertEqual(card.you.tone, "red"); assertEqual(card.them.tone, "redMuted", "can't use is dim red in both columns")
    assertEqual(joined(card.you.tip), joined(NS.SideCells.Me(d, MY_GEAR).tip), "the full view's Me tooltip")
    assertEqual(card.you.label, "You"); assertEqual(card.them.label, "Them")
    assertEqual(joined(card.ask.tip), joined(W.Ask(d, nil, nil, nil).tip))
    assertTrue(card.dismiss == nil, "no dismiss (feedback-4 spec §2)")
    assertEqual(#card.you.items, 2, "both worn trinkets, for the edge's tooltip")
end)

test("compact cards: every trade state keeps its short word and tone on line 2", function()
    local C = CC()
    local cases = {
        { { state = "yes", reasonKey = "boe", basis = "bind" }, "Yes", "good" },
        { { state = "likely", reasonKey = "notUpgrade", args = {} }, "Likely", "good" },
        { { state = "unknown", reasonKey = "noInspect", args = { "pending" } }, "Unknown", "muted" },
        { { state = "no", reasonKey = "warbound" }, "No", "red" },
        { NONE, "Unknown", "muted" },
    }
    for _, c in ipairs(cases) do
        local card = C.Group(groupDrop({ trade = c[1] }), groupCtx())
        assertEqual(card.trade.text, c[2]); assertEqual(card.trade.tone, c[3], c[2])
        assertTrue(#card.trade.tip >= 2, "never a bare title")
    end
end)

test("compact cards: the Ask button keeps its states, and a drop you cannot ask for shows a dash", function()
    local C = CC()
    local up = groupDrop({ me = { verdict = "upgrade", ilvlDelta = 12, reasons = {} },
        them = { verdict = "downgrade", ilvlDelta = -4, reasons = {} } })
    local states = { ready = "Ask", queued = "Queued", sent = "Asked", failed = "Retry", traded = "Traded" }
    for state, text in pairs(states) do
        local card = C.Group(up, groupCtx({ askState = state, askReason = "busy" }))
        assertEqual(card.ask.text, text, state); assertTrue(card.ask.offered, state)
        assertFalse(card.ask.text:find("…", 1, true) ~= nil, "no ellipsis")
    end
    local no = C.Group(groupDrop(), groupCtx())
    assertFalse(no.ask.offered); assertEqual(C.Plain(no)[2], "Lysandra · Trinket · Trinkets  No action")
    assertTrue(has(no.ask.tip, "not an upgrade for you"))
end)

test("compact cards: your own drop on Drops reads Name [YOU], No upgrades for Them, and offers it", function()
    local C = CC()
    local me = { name = "Me-Realm", classFile = "PALADIN" }
    local card = C.Group(groupDrop({ isMine = true, them = NONE, looter = me }), groupCtx())
    local lines = C.Plain(card)
    assertEqual(lines[1], "295 Vile Vial of Volatile Venom", "your own drop needs no inspect: nothing after the name")
    assertTrue(card.ask.offer and card.ask.offered)
    assertEqual(lines[3], "You 321/308 ▼13  Them No upgrades  Trade Likely")
    assertEqual(card.them.tone, "muted", "nobody's upgrade")
    assertTrue(has(card.them.tip, "Nobody else in your group."))
    assertEqual(lines[2], "Me [YOU] · Trinket · Trinkets  Offer",
        "your own name marked (feedback-7 spec §2); line 2's button is Offer (feedback-10 spec §2)")
    assertEqual(card.looter.you, "[YOU]"); assertEqual(card.looter.text, "Me")
    local dead = C.Group(groupDrop({ isMine = true, them = NONE, looter = me,
        trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }), groupCtx())
    assertEqual(C.Plain(dead)[2], "Me [YOU] · Trinket · Trinkets  No action", "where it cannot be traded")
    assertTrue(C.Plain(dead)[3]:find("Trade No$") ~= nil, C.Plain(dead)[3])
    assertTrue(has(dead.ask.tip, "Bonus roll loot"))
end)

test("compact cards: your own drop's trade tooltip counts its upgrades and Them names them, unless kept", function()
    local C = CC()
    local me = { name = "Me-Realm", classFile = "PALADIN" }
    local card = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, candidates = candidates(2) }),
        groupCtx({ offerTone = "sent" }))
    assertEqual(card.trade.text, "Likely", "the count is in the tooltip, not the cell (feedback-7 spec §2)")
    assertTrue(has(card.trade.tip, "Upgrades 2 members: Offer shows who."))
    assertEqual(card.them.text, "Upgrade for 2"); assertEqual(card.them.tone, "good")
    assertTrue(has(card.them.tip, "|cffffffffSeta|r  169  "), "a priest's name in white, a grid row (feedback-7 spec §3)")
    assertEqual(card.ask.text, "Offered"); assertEqual(card.ask.state, "sent")
    -- An upgrade for you (the keep? rule): no count and Hidden until its Offer panel is opened.
    local up = { verdict = "upgrade", ilvlDelta = 9, reasons = {} }
    local kept = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, me = up, candidates = candidates(2) }),
        groupCtx())
    assertEqual(kept.trade.text, "Likely"); assertEqual(kept.them.text, "Hidden")
    assertTrue(has(kept.them.tip, "nobody is offered it unless you choose to"))
    local shown = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, me = up, candidates = candidates(2) }),
        groupCtx({ revealed = true }))
    assertEqual(shown.trade.text, "Likely"); assertEqual(shown.them.text, "Upgrade for 2")
end)

test("compact cards: an unread looter's Them says why in the gear's place, and the tooltip too", function()
    local C = CC()
    local card = C.Group(groupDrop({ them = NONE, inspect = { status = "outOfRange" } }), groupCtx({ gear = {} }))
    assertEqual(C.HalfText(card.them), "Them range")
    assertTrue(has(card.them.tip, "out of range"))
    local read = C.Group(groupDrop({ them = NONE }), groupCtx())
    assertEqual(C.HalfText(read.them), "Them 298/296 ?", "read gear does not say why: the ? stays")
    assertEqual(card.fresh.text, "range")
end)

test("compact cards: a different upgrade track is in the verdict's tooltip, not on line 3", function()
    local C = CC()
    local d = groupDrop({ me = { verdict = "upgrade", ilvlDelta = 6, reasons = {}, trackDelta = { sign = 1 } } })
    local card = C.Group(d, groupCtx())
    assertEqual(C.HalfText(card.you), "You 321/308 ▲6")
    assertTrue(has(card.you.tip, "Upgrade track: a higher track or rank."))
    assertTrue(has(card.ilvl.tip, "Champion 4/8"))
end)

test("compact cards: a drop whose details have not loaded is never blank", function()
    local C = CC()
    local card = C.Group(groupDrop({ facts = NONE, me = NONE, them = NONE, trade = NONE, inspect = NONE,
        link = NONE }), groupCtx())
    local lines = C.Plain(card)
    assertEqual(lines[1], "? ?", "pending: nothing after the name, Them says it")
    assertEqual(lines[2], "Lysandra · – · –  No action")
    assertEqual(lines[3], "You –  Them –  Trade Unknown", "not worn, or not loaded: the dash says why")
end)

-- ── the History card ────────────────────────────────────────────────────────────────────────

-- A strftime stand-in for the client's `date`, over a fixed day: 17:02 on Oct 11.
local function fakeDate(fmt, at)
    local h, m = math.floor(at / 3600) % 24, math.floor(at / 60) % 60
    local day = 11 - math.floor((1000000 - at) / 86400)
    return (fmt:gsub("%%H", ("%02d"):format(h)):gsub("%%M", ("%02d"):format(m)):gsub("%%b", "Oct")
        :gsub("%%d", ("%02d"):format(day)):gsub("%%Y", "2026"):gsub("%%m", "10"))
end

local function historyDrop(NS, over)
    local e = with({
        itemLink = YOKE, at = 1000000 - 120, looter = "Bùnian-Argent Dawn", class = "DRUID", isMine = false,
        ilvl = 311, equipLoc = "INVTYPE_NECK", quality = 4, outcome = "seen",
        me = { verdict = "downgrade", ilvlDelta = -4, reasons = {} },
        them = { verdict = "sidegrade", ilvlDelta = 0, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} },
    }, over)
    return NS.WindowHistory.AsDrop(e, 1)
end

test("compact cards: the History card reads the spec's three lines", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local at = 1000000 - 120
    local d = historyDrop(NS, { at = at })
    local card = C.History(d, { nowEpoch = 1000000, dateFn = fakeDate, ownRealm = "Realm" })
    local lines = C.Plain(card)
    local clock = fakeDate("%H:%M", at)
    assertEqual(lines[1], "311 Yoke of the Charging Bear  Seen", "the item level before the name (feedback-10 spec §2)")
    assertEqual(lines[2], "Bùnian · Neck · Jewelry  " .. clock)
    assertEqual(lines[3], "You ▼4  Them ≈0  Trade Likely", "a kept entry holds no worn items: the verdict alone")
    assertEqual(card.outcome.tone, "bad", "Seen in gray (feedback-12 spec §0)"); assertEqual(card.time.tone, "muted")
    assertTrue(has(card.time.tip, "2m ago"))
end)

test("compact cards: every History outcome keeps its word and tone", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    -- The action buttons' convention (feedback-12 spec §0): waiting yellow, done green, nothing gray, fell through red.
    local cases = { seen = { "Seen", "bad" }, asked = { "Asked", "yellow" }, offered = { "Offered", "yellow" },
        received = { "Received", "good" }, tradedAway = { "Traded away", "good" }, expired = { "Expired", "red" },
        declined = { "Declined", "bad" } }
    for outcome, want in pairs(cases) do
        local card = C.History(historyDrop(NS, { outcome = outcome }), { nowEpoch = 1000000, dateFn = fakeDate })
        assertEqual(card.outcome.text, want[1], outcome); assertEqual(card.outcome.tone, want[2], outcome)
        assertTrue(has(card.outcome.tip, "Right-click"), outcome)
    end
end)

test("compact cards: an older kept drop reads its day, and one with no time `?`", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local old = C.History(historyDrop(NS, { at = 1000000 - 2 * 86400 }), { nowEpoch = 1000000, dateFn = fakeDate })
    assertEqual(old.time.text, "Oct 9"); assertTrue(has(old.time.tip, "2 days ago"))
    local none = C.History(historyDrop(NS, { at = NONE }), { nowEpoch = 1000000, dateFn = fakeDate })
    assertEqual(none.time.text, "?"); assertTrue(#none.time.tip >= 2)
    local noDate = C.History(historyDrop(NS), { nowEpoch = 1000000 })
    assertEqual(noDate.time.text, "?")
end)

test("compact cards: a kept drop whose looter was never read, and your own kept drop", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local unread = C.History(historyDrop(NS, { them = NONE }), { nowEpoch = 1000000, dateFn = fakeDate })
    assertEqual(C.HalfText(unread.them), "Them ?")
    assertTrue(has(unread.them.tip, "was not read while the drop was in the feed"))
    local mine = C.History(historyDrop(NS, { isMine = true, them = NONE }), { nowEpoch = 1000000, dateFn = fakeDate })
    assertEqual(C.HalfText(mine.them), "Them –")
end)

-- ── the header's short form ─────────────────────────────────────────────────────────────────

local function encounter(over)
    return with({ key = "e1", label = "Commander Ri'mok", kind = "encounter", situation = "dungeon", at = NOW - 180,
        instance = "Gate of the Setting Sun", difficulty = "Timewalking", seenBy = "Tiamât-Realm",
        seenByClass = "MAGE" }, over)
end

local function stripColor(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

test("compact cards: the header's short form drops `ago` and `drops`", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local h = C.Header(encounter(), 2, NOW, "Dungeon", false, nil, nil, 0)
    assertEqual(stripColor(h.text), "Gate of the S… · Commander Ri'… · Timewalking · 3m · 2 · Tiamât")
    assertTrue(h.cut)
    local full = NS.WindowCells.Header(encounter(), 2, NOW, "Dungeon", false, nil, nil, 0)
    assertEqual(joined(h.tip), joined(full.tip), "the full view's tooltip (feedback-17)")
    local tip = stripColor(T.tipJoined(h.tip, "\n"))
    -- red under: the long form on one line, the place, time, count and recorder run together
    assertTrue(tip:find("Instance  Gate of the Setting Sun\nDifficulty  Timewalking\nWhen  3m ago\nDrops  2\n"
        .. "Seen by  Tiamât", 1, true) ~= nil, tip)
    assertFalse(tip:find(" · 3m ago · ", 1, true) ~= nil, "no long form")
end)

test("compact cards: a filter that hides drops reads `1 of 2`, the hidden ones in the tooltip", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local hidden = { { drop = groupDrop(), why = "view" } }
    local h = C.Header(encounter(), 1, NOW, "Dungeon", false, hidden, { view = "upgrades" })
    assertTrue(stripColor(h.text):find(" · 3m · 1 of 2 · ", 1, true) ~= nil, h.text)
    assertTrue(has(h.tip, "Hidden by the filters:"))
    assertTrue(stripColor(joined(h.tip)):find("Drops  2 · 1 shown", 1, true) ~= nil, "the reconciling counts")
    assertFalse(has(h.tip, "yours"), "no `yours` count (feedback-5 spec §2)")
    assertEqual(C.Count(0, nil), "0"); assertEqual(C.Count(3, {}), "3")
end)

test("compact cards: a long instance name is cut, the full name in the tooltip", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = encounter({ instance = "The Most Excessively Long Instance Name Ever" })
    local h = C.Header(g, 1, NOW, "Dungeon", true, nil, nil, 0)
    assertTrue(h.cut)
    assertEqual(stripColor(h.text):match("^[^·]+"), "The Most Exce… ")
    assertTrue(has(h.tip, "The Most Excessively Long Instance Name Ever"))
    assertFalse(h.text:find("collapsed", 1, true) ~= nil, "the chevron says it")
    assertTrue(has(h.tip, "Click to expand this group."))
end)

test("compact cards: an LFR header fits the default width, each piece cut to its own limit", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = encounter({ label = "Vashnik the Malignant", instance = "The Venomous Abyss", difficulty = "Looking For Raid",
        seenBy = "Sacrilègeous-Realm", at = NOW - 2 * 86400 })
    -- red under: one cut for the instance alone, the line running past the pane and cutting the recorder
    local h = C.Header(g, 2, NOW, "Raid", false, nil, nil, 0)
    assertEqual(stripColor(h.text), "The Venomous… · Vashnik the M… · LFR · 2d · 2 · Sacrilèg…")
    assertTrue(h.cut)
    local tip = stripColor(joined(h.tip))
    assertEqual(h.tip[1], "Vashnik the Malignant", "the boss, whole, titles the tooltip")
    assertTrue(tip:find("Instance  The Venomous Abyss", 1, true) ~= nil, tip)
    assertTrue(tip:find("Difficulty  Looking For Raid", 1, true) ~= nil, "the difficulty's full name")
    local M = C.HEADER_MAX
    assertTrue(M.instance + M.label + M.difficulty + M.age + M.count + M.who + 5 * 3 <= C.HEADER_CHARS,
        "an encounter's six pieces, each at its limit, fit the line a default-width pane holds")
    assertTrue(M.label + M.situation + M.age + M.count + M.who + 4 * 3 <= C.HEADER_CHARS, "and an area's five")
end)

test("compact cards: a group with no time or recorder, and the open world's area header", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = { key = "a", label = "Dornogal", kind = "area", situation = "solo" }
    assertEqual(C.Header(g, 1, nil, "Solo", false).text, "Dornogal · Solo · 1")
end)

test("compact cards: the History header reads days once a day old, its tooltip the full view's", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = encounter({ at = 1000000 - 2 * 86400 - 60 })
    local h = C.HistoryHeader(g, 4, 1000000, "Dungeon", false)
    assertEqual(stripColor(h.text), "Gate of the S… · Commander Ri'… · Timewalking · 2d · 4 · Tiamât")
    assertTrue(has(h.tip, "2 days ago"))
    assertTrue(has(h.tip, "Kept in the history across sessions."))
end)
