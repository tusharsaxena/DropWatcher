-- tests/test_compact_cards.lua — compact mode's cards (compact spec §2 and §3, DW-C1): each card's
-- three lines of text, tones and tooltips for Group drops, My drops and History, in every state a
-- drop can be in, and the group header's short form (modules/CompactCards.lua, pure). The words,
-- tones and reason tooltips are the full view's composers' (modules/WindowCells.lua,
-- modules/MineCells.lua), so each case also checks that the compact piece agrees with its column.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Vile Vial of Volatile Venom]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Vial]|h|r"
local OLD2 = "|cffa335ee|Hitem:301::|h[Older Vial]|h|r"
local BRACERS = "|cffa335ee|Hitem:220::|h[Leggings of the Frenzy]|h|r"
local YOKE = "|cffa335ee|Hitem:230::|h[Yoke of the Charging Bear]|h|r"

local NONE = {}
local NOW = 100

local function with(d, over)
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

-- The spec's Group drops card: a trinket Lysandra looted, a downgrade for you (you wear 321 and
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

-- The spec's My drops card: your leggings, an upgrade for you (+49), 1:44:46 left on the item's
-- own timer, an upgrade for Seta (+14) and Butterz (+6).
local function mineDrop(over)
    return with({
        id = 3, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 183, equipLoc = "INVTYPE_LEGS", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 49, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6286 }, expiresAt = NOW + 6286 },
        candidates = candidates(2),
    }, over)
end

local function CC() return T.newAddon().CompactCards end

local function joined(tip) return table.concat(tip, " | ") end

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

test("compact cards: a verdict reads glyph then change; a worded one takes ⊘", function()
    local NS = T.newAddon()
    local C, W = NS.CompactCards, NS.WindowCells
    local cases = {
        { { verdict = "upgrade", ilvlDelta = 19, reasons = {} }, "▲ +19", "good" },
        { { verdict = "sidegrade", ilvlDelta = 0.2, reasons = {} }, "≈ +0", "yellow" },
        { { verdict = "downgrade", ilvlDelta = -13, reasons = {} }, "▽ -13", "red" },
        { { verdict = "cantUse", reasons = {} }, "⊘ Can't use", "bad" },
        { { verdict = "doesntWant", reasons = {} }, "⊘ Not wanted", "bad" },
        { NONE, "?", "muted" },
    }
    for _, c in ipairs(cases) do
        local full = W.Me(groupDrop({ me = c[1] }))
        local v = C.Verdict(full)
        assertEqual(C.VerdictText(v), c[2])
        assertEqual(v.tone, c[3], c[2]); assertEqual(v.tone, full.tone, "the full view's tone")
        assertEqual(joined(v.tip), joined(full.tip), "the full view's tooltip")
    end
end)

test("compact cards: the worn levels sit in parentheses, dimmed; none where the full view has a dash", function()
    local NS = T.newAddon()
    local C, W = NS.CompactCards, NS.WindowCells
    assertEqual(C.Eq(W.MyEq(groupDrop(), MY_GEAR)).text, "(321/308)")
    assertEqual(C.Eq(W.MyEq(groupDrop(), MY_GEAR)).tone, "muted")
    assertEqual(C.Eq(W.MyEq(groupDrop(), { [13] = false, [14] = false })).text, "(empty)")
    assertEqual(C.Eq(W.MyEq(groupDrop(), {})).text, "(…)")
    assertTrue(C.Eq(W.MyEq(groupDrop({ facts = { ilvl = 295 } }), MY_GEAR)) == nil, "not worn")
    assertTrue(C.Eq(W.TheirEq(groupDrop({ isMine = true }), HER_GEAR, NOW)) == nil, "your own drop")
    assertEqual(C.Eq(W.TheirEq(groupDrop({ inspect = { status = "outOfRange" } }), {}, NOW)).text, "(range)")
    assertTrue(C.Eq(nil) == nil)
end)

test("compact cards: a cross-realm looter takes ⊕ and the realm in the tooltip", function()
    local C = CC()
    local same = C.Looter(groupDrop(), "Realm")
    assertEqual(same.text, "Lysandra"); assertFalse(same.crossRealm); assertTrue(same.mark == nil)
    assertEqual(same.classFile, "MAGE")
    local other = C.Looter(groupDrop({ looter = { name = "Bùnian-Argent Dawn", classFile = "DRUID" } }), "Realm")
    assertEqual(other.text, "Bùnian"); assertTrue(other.crossRealm); assertEqual(other.mark, "⊕")
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

-- ── the Group drops card ────────────────────────────────────────────────────────────────────

test("compact cards: the Group drops card reads the spec's three lines", function()
    local C = CC()
    local card = C.Group(groupDrop(), groupCtx())
    local lines = C.Plain(card)
    -- The spec's sketch shows [Ask]; the engine offers none for a downgrade, so the full view's dash.
    assertEqual(lines[1], "Vile Vial of Volatile Venom  295  –")
    -- Line 2's right side is the countdown (feedback-5 spec §1): her drop's, estimated from when it dropped.
    assertEqual(lines[2], "Lysandra · Trinket · Trinkets · Likely  ~1:59:50")
    assertEqual(lines[3], "You ▽ -13 (321/308)  Them ⊘ Can't use (298/296)")
    assertEqual(card.kind, "group"); assertEqual(card.id, 7); assertEqual(card.link, LINK)
end)

test("compact cards: line 2 shows the countdown for a drop with one, else the inspect freshness (feedback-5 §1)", function()
    local NS = T.newAddon()
    local C, MC = NS.CompactCards, NS.MineCells
    local d = groupDrop()
    local card = C.Group(d, groupCtx())
    assertEqual(card.countdown.text, "~1:59:50"); assertEqual(card.countdown.tone, "plain")
    assertEqual(joined(card.countdown.tip), joined(MC.TradeWindow(d, NOW).tip), "the full view's Trade window cell")
    assertTrue(card.countdown.fraction > 0.9, "its bar"); assertEqual(card.fresh.text, "2m", "the freshness is still built")
    local late = C.Group(groupDrop({ at = NOW - 7000 }), groupCtx({ warnAt = 600 }))
    assertEqual(late.countdown.text, "~0:03:20"); assertEqual(late.countdown.tone, "warn"); assertTrue(late.countdown.bold)
    assertTrue(late.countdown.soon, "its bar turns amber")
    for _, t in ipairs({
        { state = "no", reasonKey = "bonusRoll", basis = "bind" },
        { state = "yes", reasonKey = "boe", basis = "bind" },
    }) do
        local none = C.Group(groupDrop({ trade = t }), groupCtx())
        assertTrue(none.countdown == nil, t.reasonKey .. ": no countdown")
        assertEqual(C.Plain(none)[2]:sub(-4), "  2m", t.reasonKey .. ": the freshness keeps its place")
    end
    assertTrue(C.Group(groupDrop({ trade = NONE }), groupCtx()).countdown == nil, "not estimated yet")
end)

test("compact cards: the Group drops card's pieces keep the full view's tones and tooltips", function()
    local NS = T.newAddon()
    local C, W = NS.CompactCards, NS.WindowCells
    local d = groupDrop()
    local card = C.Group(d, groupCtx())
    assertEqual(card.item.quality, 4); assertTrue(card.item.gameTooltip, "the game's own tooltip on hover")
    assertEqual(joined(card.ilvl.tip), joined(W.Ilvl(d).tip))
    assertEqual(card.trade.tone, "good"); assertEqual(joined(card.trade.tip), joined(W.Trade(d).tip))
    assertEqual(card.slot.text, "Trinket"); assertEqual(joined(card.slot.tip), joined(W.Slot(d).tip))
    assertEqual(card.you.verdict.tone, "red"); assertEqual(card.them.verdict.tone, "bad", "can't use is gray in both columns")
    assertEqual(card.you.label, "You"); assertEqual(card.them.label, "Them")
    assertEqual(joined(card.ask.tip), joined(W.Ask(d, nil, nil, nil).tip))
    assertTrue(card.dismiss == nil, "no dismiss (feedback-4 spec §2)")
    assertEqual(#card.you.eq.items, 2, "both worn trinkets, for the edge's tooltip")
end)

test("compact cards: every trade state keeps its short word and tone on line 2", function()
    local C = CC()
    local cases = {
        { { state = "yes", reasonKey = "boe", basis = "bind" }, "Yes", "good" },
        { { state = "likely", reasonKey = "notUpgrade", args = {} }, "Likely", "good" },
        { { state = "unknown", reasonKey = "noInspect", args = { "pending" } }, "Unknown", "muted" },
        { { state = "no", reasonKey = "warbound" }, "No", "bad" },
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
    assertFalse(no.ask.offered); assertEqual(C.Plain(no)[1], "Vile Vial of Volatile Venom  295  –")
    assertTrue(has(no.ask.tip, "not an upgrade for you"))
end)

test("compact cards: your own drop on Group drops reads (Multiple) for Them and offers it", function()
    local C = CC()
    local me = { name = "Me-Realm", classFile = "PALADIN" }
    local card = C.Group(groupDrop({ isMine = true, them = NONE, looter = me }), groupCtx())
    local lines = C.Plain(card)
    assertEqual(lines[1], "Vile Vial of Volatile Venom  295  Offer", "line 1's button is Offer (feedback-5 spec §2)")
    assertTrue(card.ask.offer and card.ask.offered)
    assertEqual(lines[3], "You ▽ -13 (321/308)  Them (Multiple)")
    assertEqual(card.them.verdict.tone, "muted", "nobody's upgrade")
    assertTrue(has(card.them.verdict.tip, "Nobody else in your group."))
    assertEqual(lines[2], "Me · Trinket · Trinkets · Likely  ~1:59:50", "the bare word with no upgrade")
    local dead = C.Group(groupDrop({ isMine = true, them = NONE, looter = me,
        trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }), groupCtx())
    assertEqual(C.Plain(dead)[2], "Me · Trinket · Trinkets · No  –", "no countdown: the freshness, a dash on yours")
    assertEqual(C.Plain(dead)[1], "Vile Vial of Volatile Venom  295  –", "a dash where it cannot be traded")
    assertTrue(has(dead.ask.tip, "Bonus roll loot"))
end)

test("compact cards: your own drop's trade counts its upgrades and Them names them, unless kept", function()
    local C = CC()
    local me = { name = "Me-Realm", classFile = "PALADIN" }
    local card = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, candidates = candidates(2) }),
        groupCtx({ offerTone = "sent" }))
    assertEqual(card.trade.text, "Likely (2)")
    assertTrue(has(card.trade.tip, "Upgrades 2 members: Offer shows who."))
    assertEqual(card.them.verdict.text, "(Multiple)"); assertEqual(card.them.verdict.tone, "good")
    assertTrue(has(card.them.verdict.tip, "Seta ▲ +14 · wears 169"))
    assertEqual(card.ask.text, "Offered"); assertEqual(card.ask.state, "sent")
    -- An upgrade for you (the keep? rule): no count and Hidden until its Offer panel is opened.
    local up = { verdict = "upgrade", ilvlDelta = 9, reasons = {} }
    local kept = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, me = up, candidates = candidates(2) }),
        groupCtx())
    assertEqual(kept.trade.text, "Likely"); assertEqual(kept.them.verdict.text, "Hidden")
    assertTrue(has(kept.them.verdict.tip, "nobody is offered it unless you choose to"))
    local shown = C.Group(groupDrop({ isMine = true, them = NONE, looter = me, me = up, candidates = candidates(2) }),
        groupCtx({ revealed = true }))
    assertEqual(shown.trade.text, "Likely (2)"); assertEqual(shown.them.verdict.text, "(Multiple)")
end)

test("compact cards: an unread looter says `?` for Them, and the tooltip says why", function()
    local C = CC()
    local card = C.Group(groupDrop({ them = NONE, inspect = { status = "outOfRange" } }), groupCtx({ gear = {} }))
    assertEqual(C.HalfText(card.them), "Them ? (range)")
    assertTrue(has(card.them.verdict.tip, "out of range"))
    assertEqual(card.fresh.text, "range")
end)

test("compact cards: a different upgrade track is in the verdict's tooltip, not on line 3", function()
    local C = CC()
    local d = groupDrop({ me = { verdict = "upgrade", ilvlDelta = 6, reasons = {}, trackDelta = { sign = 1 } } })
    local card = C.Group(d, groupCtx())
    assertEqual(C.HalfText(card.you), "You ▲ +6 (321/308)")
    assertTrue(has(card.you.verdict.tip, "Upgrade track: a higher track or rank."))
    assertTrue(has(card.ilvl.tip, "Champion 4/8"))
end)

test("compact cards: a drop whose details have not loaded is never blank", function()
    local C = CC()
    local card = C.Group(groupDrop({ facts = NONE, me = NONE, them = NONE, trade = NONE, inspect = NONE,
        link = NONE }), groupCtx())
    local lines = C.Plain(card)
    assertEqual(lines[1], "?  ?  –")
    assertEqual(lines[2], "Lysandra · – · – · Unknown  …")
    assertEqual(lines[3], "You ?  Them ?")
end)

-- ── the My drops card ───────────────────────────────────────────────────────────────────────

test("compact cards: the My drops card reads the spec's three lines", function()
    local C = CC()
    local card = C.Mine(mineDrop(), { now = NOW, revealed = true })
    local lines = C.Plain(card)
    assertEqual(lines[1], "Leggings of the Frenzy  183  Offer")
    assertEqual(lines[2], "For you ▲ +49 (keep?)  1:44:46")
    assertEqual(lines[3], "Seta +14 · Butterz +6  Announce")
    assertTrue(card.tradeable); assertEqual(card.kind, "mine")
end)

test("compact cards: the countdown keeps its bar fraction, its warning and its estimate", function()
    local C = CC()
    local card = C.Mine(mineDrop(), { now = NOW })
    assertTrue(card.trade.fraction > 0.8 and card.trade.fraction <= 1, tostring(card.trade.fraction))
    assertEqual(card.trade.tone, "plain")
    local soon = C.Mine(mineDrop({ trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 300 },
        expiresAt = NOW + 300 } }), { now = NOW, warnAt = 600 })
    assertEqual(soon.trade.text, "0:05:00"); assertEqual(soon.trade.tone, "warn"); assertTrue(soon.trade.bold)
    local est = C.Mine(mineDrop({ trade = { state = "likely", reasonKey = "groupLoot" } }), { now = NOW })
    assertEqual(est.trade.text:sub(1, 1), "~", "an estimate says so")
    local boe = C.Mine(mineDrop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }), { now = NOW })
    assertEqual(boe.trade.text, "No limit (BoE)"); assertEqual(boe.trade.fraction, 1)
end)

test("compact cards: a drop that cannot be traded shows Not tradeable and a dash for Offer, and no Hide", function()
    local C = CC()
    local card = C.Mine(mineDrop({ trade = { state = "no", reasonKey = "bonusRoll" } }), { now = NOW })
    local lines = C.Plain(card)
    assertEqual(lines[1], "Leggings of the Frenzy  183  –")
    assertEqual(lines[2], "For you ▲ +49 (keep?)  Not tradeable")
    assertEqual(lines[3], "–")
    assertFalse(card.tradeable); assertTrue(card.offer.dash); assertTrue(card.action == nil, "nothing hides it")
    assertEqual(card.trade.tone, "bad"); assertTrue(has(card.trade.tip, "Bonus roll loot can't be traded."))
    assertTrue(has(card.offer.tip, "Not tradeable"))
end)

test("compact cards: an upgrade for you hides its candidates until you choose to offer it", function()
    local C = CC()
    local hidden = C.Mine(mineDrop(), { now = NOW, revealed = false })
    assertTrue(hidden.candidates.hidden); assertEqual(#hidden.candidates.parts, 0)
    assertEqual(C.Plain(hidden)[3], "Hidden: an upgrade for you  Announce")
    assertFalse(hidden.offer.primary, "Offer is not the call to action while hidden")
    local down = C.Mine(mineDrop({ me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} } }), { now = NOW })
    assertEqual(C.Plain(down)[2], "For you ▽ -5  1:44:46"); assertTrue(down.forYou.sub == nil)
    assertTrue(down.offer.primary)
end)

test("compact cards: the candidates are class-colored parts, the top three and `+n more`", function()
    local C = CC()
    local d = mineDrop({ me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} }, candidates = candidates(4) })
    local c = C.Mine(d, { now = NOW }).candidates
    assertEqual(#c.parts, 3)
    assertEqual(c.parts[1].text, "Seta +14"); assertEqual(c.parts[1].classFile, "PRIEST")
    assertEqual(c.parts[2].classFile, "MAGE"); assertEqual(c.more, "+1 more")
    assertEqual(c.text, "Seta +14 · Butterz +6 · Littlewolf +3 · +1 more", "the full view's cell agrees")
    local nobody = C.Mine(mineDrop({ me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} }, candidates = {} }),
        { now = NOW }).candidates
    assertEqual(nobody.text, "Nobody else in your group"); assertEqual(#nobody.parts, 0)
end)

test("compact cards: Announce follows the ask's lifecycle", function()
    local C = CC()
    local states = { ready = "Announce", queued = "Queued", sent = "Announced", failed = "Retry" }
    for state, text in pairs(states) do
        local card = C.Mine(mineDrop(), { now = NOW, announceState = state, announceReason = "busy" })
        assertEqual(card.action.text, text, state)
    end
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
    assertEqual(lines[1], "Yoke of the Charging Bear  311  Seen")
    assertEqual(lines[2], "Bùnian ⊕ · Neck · Jewelry · Likely  " .. clock)
    assertEqual(lines[3], "You ▽ -4  Them ≈ +0")
    assertEqual(card.outcome.tone, "muted"); assertEqual(card.time.tone, "muted")
    assertTrue(has(card.time.tip, "2m ago"))
end)

test("compact cards: every History outcome keeps its word and tone", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local cases = { seen = { "Seen", "muted" }, asked = { "Asked", "plain" }, offered = { "Offered", "plain" },
        received = { "Received", "good" }, tradedAway = { "Traded away", "good" }, expired = { "Expired", "bad" },
        declined = { "Declined", "muted" } }
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
    assertTrue(has(unread.them.verdict.tip, "was not read while the drop was in the feed"))
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
    assertEqual(stripColor(h.text), "Gate of the Setting Sun · Commander Ri'mok · Timewalking · 3m · 2 · Tiamât")
    assertFalse(h.cut)
    local full = NS.WindowCells.Header(encounter(), 2, NOW, "Dungeon", false, nil, nil, 0)
    assertEqual(h.tip[1], full.tip[1]); assertEqual(h.tip[2], full.text, "the long form opens the tooltip")
    assertEqual(#h.tip, #full.tip + 1, "and every line of the full view's tooltip follows")
end)

test("compact cards: a filter that hides drops reads `1 of 2`, the hidden ones in the tooltip", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local hidden = { { drop = groupDrop(), why = "view" } }
    local h = C.Header(encounter(), 1, NOW, "Dungeon", false, hidden, { view = "upgrades" })
    assertTrue(stripColor(h.text):find(" · 3m · 1 of 2 · ", 1, true) ~= nil, h.text)
    assertTrue(has(h.tip, "Hidden by the filters:"))
    assertTrue(has(h.tip, "2 drops · 1 shown"), "the reconciling counts in the long form")
    assertFalse(has(h.tip, "yours"), "no `yours on My drops` (feedback-5 spec §2)")
    assertEqual(C.Count(0, nil), "0"); assertEqual(C.Count(3, {}), "3")
end)

test("compact cards: a long instance name is cut, the full name in the tooltip", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = encounter({ instance = "The Most Excessively Long Instance Name Ever" })
    local h = C.Header(g, 1, NOW, "Dungeon", true, nil, nil, 0)
    assertTrue(h.cut)
    assertEqual(stripColor(h.text):match("^[^·]+"), "The Most Excessively Lo… ")
    assertTrue(has(h.tip, "The Most Excessively Long Instance Name Ever"))
    assertFalse(h.text:find("collapsed", 1, true) ~= nil, "the chevron says it")
    assertTrue(has(h.tip, "Click to expand this group."))
end)

test("compact cards: a group with no time or recorder, and the open world's area header", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = { key = "a", label = "Dornogal", kind = "area", situation = "solo" }
    assertEqual(C.Header(g, 1, nil, "Solo", false).text, "Dornogal · Solo · 1")
end)

test("compact cards: the History header reads days once a day old, its tooltip the long form", function()
    local NS = T.newAddon()
    local C = NS.CompactCards
    local g = encounter({ at = 1000000 - 2 * 86400 - 60 })
    local h = C.HistoryHeader(g, 4, 1000000, "Dungeon", false)
    assertEqual(stripColor(h.text), "Gate of the Setting Sun · Commander Ri'mok · Timewalking · 2d · 4 · Tiamât")
    assertTrue(has(h.tip, "2 days ago"))
    assertTrue(has(h.tip, "Kept in the history across sessions."))
end)
