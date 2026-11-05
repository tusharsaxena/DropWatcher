-- tests/test_insights_rows.lua — what the Insights tab draws, as plain data (issue #12, Insights
-- design spec §1.3, §3.4, §4.2; modules/InsightsRows.lua): the eight cards' figures, hovers and
-- tone (a dash with nothing to show, the legacy lines only when a count was inferred), the card
-- grid (4 and 2 columns, a short last row stretched), the bar's wrap at the full, a middle and the
-- compact width, the period caption for a kept window, Never delete and a shorter range, the
-- empty lines, and every chart section's rows (spec §1.4): the outcome rows and their fracs, the
-- instances, bosses and visits, the generous members, the gains, the day buckets and the mixes,
-- their colors resolved from class, quality and tone names.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local DAY = 86400
local NOW = os.time({ year = 2026, month = 11, day = 5, hour = 15 })
local OCT11 = os.time({ year = 2026, month = 10, day = 11, hour = 9 })

local function IR() return T.newAddon().InsightsRows end

local function card(R, key, totals)
    local value, tip, tone = R.Card(key, totals)
    return value, table.concat(tip, " | "), tone
end

-- ── the cards ───────────────────────────────────────────────────────────────────────────────

test("insights rows: eight cards in grid order, the owner's six then Offers sent and Traded away (Q4)", function()
    local keys = {}
    for i, c in ipairs(IR().CARDS) do keys[i] = c.key end
    assertEqual(table.concat(keys, ","), "drops,upgrades,asks,received,success,activeDays,offers,tradedAway")
end)

test("insights rows: each card's figure and hover read the stats' totals", function()
    local R = IR()
    local t = { drops = 452, mine = 204, others = 248, upgrades = 27, upgradesMine = 4, upgradesOff = 1,
        asks = 9, asksLegacy = 8, askHits = 8, received = 8, givers = 5, success = 8 / 9, offers = 9,
        offersLegacy = 6, tradedAway = 6, activeDays = 23, first = OCT11, last = NOW }
    local v, tip = card(R, "drops", t)
    assertEqual(v, "452"); assertEqual(tip, "Drops seen | 204 yours, 248 by others")
    v, tip = card(R, "upgrades", t)
    assertEqual(v, "27"); assertEqual(tip, "Upgrades for me | 4 looted by you, 23 by others; 1 on another spec")
    v, tip = card(R, "asks", t)
    assertEqual(v, "9")
    assertTrue(tip:find("8 recorded before asks were stamped (counted from items received)", 1, true) ~= nil, tip)
    v, tip = card(R, "received", t)
    assertEqual(v, "8"); assertEqual(tip, "Items received | From 5 group members")
    v, tip = card(R, "activeDays", t)
    assertEqual(v, "23"); assertEqual(tip, "Active days | Oct 11 to Nov 5")
    v, tip = card(R, "offers", t)
    assertEqual(v, "9")
    assertTrue(tip:find("6 recorded before offers were stamped", 1, true) ~= nil, tip)
    assertEqual((card(R, "tradedAway", t)), "6")
end)

test("insights rows: Ask success is a rounded percentage, green from 50%, with the legacy warning only when inferred", function()
    local R = IR()
    local v, tip, tone = card(R, "success", { asks = 9, askHits = 8, asksLegacy = 8, success = 8 / 9 })
    assertEqual(v, "89%"); assertEqual(tone, "good")
    assertTrue(tip:find("8 of 9 asks ended in a trade", 1, true) ~= nil)
    assertTrue(tip:find("so the rate reads high", 1, true) ~= nil)
    v, tip, tone = card(R, "success", { asks = 4, askHits = 1, asksLegacy = 0, success = 0.25 })
    assertEqual(v, "25%"); assertNil(tone, "below 50%: the heading color")
    assertTrue(tip:find("reads high", 1, true) == nil, "no legacy line with no inferred ask")
    v, tip, tone = card(R, "success", { asks = 2, askHits = 1, success = 0.5 })
    assertEqual(v, "50%"); assertEqual(tone, "good", "50% is green")
    assertTrue(tip:find("1 of 2 asks", 1, true) ~= nil)
end)

test("insights rows: with nothing to show a card reads 0 or a dash, never a nil, and no legacy line", function()
    local R = IR()
    for _, c in ipairs(R.CARDS) do
        local v, tip = R.Card(c.key, nil)
        assertTrue(type(v) == "string" and v ~= "", c.key)
        assertEqual(tip[1], c.caption)
    end
    assertEqual((card(R, "success", {})), R.DASH)
    local _, tip = card(R, "asks", { asks = 3, asksLegacy = 0 })
    assertTrue(tip:find("recorded before", 1, true) == nil)
    assertEqual((card(R, "activeDays", {})), "0")
end)

-- ── the grid and the bar ────────────────────────────────────────────────────────────────────

test("insights rows: the card grid is 4 columns full and 2 compact, a short last row stretched", function()
    local R = IR()
    local cells, h = R.CardGrid(8, 1000, 4, 6, 52)
    assertEqual(#cells, 8); assertEqual(h, 2 * 52 + 6)
    assertEqual(cells[1].w, (1000 - 18) / 4); assertEqual(cells[5].y, 58); assertEqual(cells[4].x, 3 * (cells[1].w + 6))
    cells, h = R.CardGrid(8, 360, 2, 6, 52)
    assertEqual(h, 4 * 52 + 3 * 6); assertEqual(cells[1].w, 177); assertEqual(cells[8].y, 3 * 58)
    cells = R.CardGrid(6, 1000, 4, 6, 52)
    assertEqual(cells[5].w, (1000 - 6) / 2, "the last row's two share the width")
    assertEqual(cells[6].x, cells[5].w + 6)
    cells, h = R.CardGrid(0, 1000, 4, 6, 52)
    assertEqual(#cells, 0); assertEqual(h, 0)
end)

test("insights rows: the bar wraps one row at the full width, two at 600 and four at compact's 400", function()
    local R = IR()
    local K = T.newAddon().Constants.WINDOW
    local function plan(windowW) return R.BarPlan(windowW - 2 * K.INSET, 7) end
    local cells, rows, per = plan(K.WIDTH)
    assertEqual(rows, 1); assertEqual(per, 7)
    assertTrue(cells[7].x + cells[7].w <= K.WIDTH - 2 * K.INSET + 0.001, "the last one ends inside the bar")
    cells, rows, per = plan(600)
    assertEqual(rows, 2); assertEqual(per, 4); assertEqual(cells[5].y, R.BAR_ROW_H)
    cells, rows, per = plan(K.COMPACT_MIN_W)
    assertEqual(rows, 4); assertEqual(per, 2)
    assertEqual(cells[3].y, R.BAR_ROW_H); assertEqual(cells[7].x, 0)
    for _, c in ipairs(cells) do assertTrue(c.w >= R.BAR_MIN_W, "never under the floor") end
    cells, rows = R.BarPlan(50, 7)
    assertEqual(rows, 7, "narrower than the floor: one to a row")
    assertEqual(cells[1].w, 50)
end)

-- ── the period and the empty lines ──────────────────────────────────────────────────────────

test("insights rows: a day reads `Nov 5`, with no leading zero", function()
    local R = IR()
    assertEqual(R.Day(NOW), "Nov 5"); assertEqual(R.Day(OCT11), "Oct 11"); assertEqual(R.Day(nil), R.DASH)
end)

test("insights rows: the period caption names the kept window, Never delete and a shorter range", function()
    local R = IR()
    assertEqual(R.PeriodText({ range = "all", days = 30, from = OCT11, to = NOW, drops = 452, groups = 160 }),
        "Kept for 30 days: Oct 11 – Nov 5 · 452 drops in 160 groups")
    assertEqual(R.PeriodText({ range = "all", days = 0, from = OCT11, to = NOW, drops = 452, groups = 160 }),
        "Every kept day: since Oct 11 · 452 drops in 160 groups")
    assertEqual(R.PeriodText({ range = "7", days = 30, from = NOW - 6 * DAY, to = NOW, drops = 84, groups = 31 }),
        "Last 7 days (Oct 30 – Nov 5) of 30 kept · 84 drops in 31 groups")
    assertEqual(R.PeriodText({ range = "7", days = 0, from = NOW - 6 * DAY, to = NOW, drops = 1, groups = 1 }),
        "Last 7 days (Oct 30 – Nov 5) · 1 drops in 1 groups")
    assertEqual(R.PeriodText({ range = "today", days = 30, from = NOW - 3600, to = NOW, drops = 2, groups = 1 }),
        "Today (Nov 5) of 30 kept · 2 drops in 1 groups")
    assertEqual(R.PeriodText({ range = "all", days = 0, drops = 0, groups = 0 }), "Every kept day · 0 drops in 0 groups")
    assertEqual(R.PeriodText(nil), "Every kept day · 0 drops in 0 groups")
end)

test("insights rows: the empty line says how long drops are kept, or that the filters match nothing", function()
    local R = IR()
    assertEqual(R.EmptyText(0, 30), "No history yet. Drops your group receives are kept for 30 days.")
    assertEqual(R.EmptyText(0, 0), "No history yet. Drops your group receives are kept until you clear them.")
    assertEqual(R.EmptyText(12, 30), "No drops match these filters.")
end)

-- ── the sections' rows ──────────────────────────────────────────────────────────────────────

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"

-- The stats of `groups` through the real pass, and the namespace it ran in.
local function statsOf(groups)
    local NS = T.newAddon()
    local F = NS.InsightsFilters
    local rows = F.Rows(groups)
    return NS.InsightsStats.Compute(rows, F.Period(rows, 30, "all", NOW)), NS
end

local function drop(over)
    local e = { itemLink = LINK, itemID = 212, looter = "Brakk-Testrealm", class = "WARRIOR", outcome = "seen",
        at = NOW - 3600, quality = 4, equipLoc = "INVTYPE_HEAD", me = { verdict = "downgrade", ilvlDelta = -3 },
        trade = { state = "likely" } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local function group(over, drops)
    local g = { key = "k", label = "Boss", kind = "encounter", instance = "Ruby Life Pools", difficulty = "Mythic",
        situation = "raid", at = NOW - 3600, drops = drops }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end

local UP = { verdict = "upgrade", ilvlDelta = 9 }

local function sameColor(a, b)
    return type(a) == "table" and type(b) == "table" and a[1] == b.r and a[2] == b.g and a[3] == b.b
end

test("insights rows: A splits others' drops, their upgrades and yours by outcome, fracs over the largest row", function()
    local s, NS = statsOf({ group(nil, {
        drop({ outcome = "received", settledAt = NOW }), drop({ outcome = "expired" }), drop(), drop(),
        drop({ me = UP }),
        drop({ isMine = true, outcome = "tradedAway" }), drop({ isMine = true }),
    }) })
    local R = NS.InsightsRows
    local rows, legend = R.OutcomeRows(s)
    assertEqual(#rows, 3)
    assertEqual(rows[1].label, "Others' drops"); assertEqual(rows[1].value, "5")
    assertEqual(rows[2].label, "Upgrades for me"); assertEqual(rows[2].sublabel, "looted by others")
    assertEqual(rows[3].label, "Your drops"); assertEqual(rows[3].value, "2")
    local segs = rows[1].segments
    assertEqual(#segs, 3, "received, expired and kept; no empty segment")
    assertEqual(segs[1].frac, 1 / 5); assertEqual(segs[1].tip, "Traded to me: 1 (20%)")
    assertTrue(sameColor(segs[1].color, NS.Constants.TONE.good), "received in the upgrade green")
    assertTrue(sameColor(segs[2].color, NS.Constants.TONE.warn), "expired in the urgent amber")
    assertEqual(segs[3].frac, 3 / 5)
    assertEqual(rows[3].segments[1].frac, 1 / 5, "your row over the largest total too")
    assertTrue(sameColor(rows[3].segments[1].color, NS.Constants.TONE.cyan), "traded away in Offer's cyan")
    assertEqual(rows[1].tip[1], "Others' drops"); assertEqual(rows[1].tip[2], "Traded to me: 1 (20%)")
    assertEqual(#legend, 6); assertEqual(legend[1].label, "Traded to me")
    rows = R.OutcomeRows(statsOf({ group(nil, { drop({ isMine = true }) }) }))
    assertEqual(#rows, 1, "a row with no drop is left out"); assertEqual(rows[1].label, "Your drops")
    rows, legend = R.OutcomeRows(statsOf({}))
    assertEqual(#rows, 0); assertEqual(#legend, 0)
end)

test("insights rows: B ranks the instances by upgrades, yours and others' stacked, top ten with the rest counted", function()
    local groups = {}
    for i = 1, 12 do
        local drops = { drop({ me = UP }) }
        if i == 1 then drops[2] = drop({ me = UP, isMine = true }); drops[3] = drop({ me = UP }) end
        groups[i] = group({ key = "g" .. i, instance = ("Instance %02d"):format(i) }, drops)
    end
    local s, NS = statsOf(groups)
    local mine, others = { 1, 0, 0 }, { 0, 1, 0 }
    local rows, legend, more = NS.InsightsRows.InstanceRows(s, { mine = mine, others = others })
    assertEqual(#rows, 10); assertEqual(more, 2)
    assertEqual(rows[1].label, "Instance 01"); assertEqual(rows[1].value, "3")
    assertEqual(rows[1].segments[1].frac, 1 / 3); assertEqual(rows[1].segments[2].frac, 2 / 3)
    assertTrue(rows[1].segments[1].color == mine and rows[1].segments[2].color == others)
    assertEqual(rows[2].segments[2].frac, 1 / 3, "over the top row's total")
    assertEqual(table.concat(rows[1].tip, " | "), "Instance 01 | 3 upgrades for you | 1 by you | 2 by others")
    assertEqual(legend[1].label, "By you"); assertEqual(legend[2].tip, "Looted by others")
    rows, legend, more = NS.InsightsRows.InstanceRows(statsOf({ group(nil, { drop() }) }), { mine = mine, others = others })
    assertEqual(#rows, 0); assertEqual(#legend, 0); assertEqual(more, 0)
end)

test("insights rows: C names each boss under its instance and difficulty; encounters only", function()
    local s, NS = statsOf({
        group({ key = "a", label = "Kyveza" }, { drop({ me = UP }), drop({ me = UP }) }),
        group({ key = "b", label = "Ansurek", difficulty = false }, { drop({ me = UP }) }),
        group({ key = "c", label = "Ruby Life Pools", kind = "run", difficulty = "Mythic+ 12" }, { drop({ me = UP }) }),
    })
    local rows, more = NS.InsightsRows.BossRows(s)
    assertEqual(#rows, 2, "a key's run is no boss"); assertEqual(more, 0)
    assertEqual(rows[1].label, "Kyveza"); assertEqual(rows[1].sublabel, "Ruby Life Pools · Mythic")
    assertEqual(rows[1].frac, 2); assertEqual(rows[1].value, "2")
    assertEqual(rows[2].sublabel, "Ruby Life Pools", "no difficulty: the instance alone")
    assertEqual(rows[2].tip[3], "1 upgrade for you")
end)

test("insights rows: D reads upgrades a visit with the visits in the hover", function()
    local groups = {}
    for i = 1, 3 do groups[i] = group({ key = "r" .. i }, { drop({ me = i == 1 and UP or nil }) }) end
    local s, NS = statsOf(groups)
    local rows = NS.InsightsRows.RateRows(s)
    assertEqual(#rows, 1); assertEqual(rows[1].name, "Ruby Life Pools")
    assertEqual(rows[1].right, "0.33 / visit"); assertEqual(rows[1].tip[2], "1 upgrades in 3 visits")
    assertEqual(#NS.InsightsRows.RateRows(statsOf({ group(nil, { drop({ me = UP }) }) })), 0, "one visit: under the floor")
end)

test("insights rows: E lists who traded to you most, in their class color, the items in the hover", function()
    local s, NS = statsOf({ group(nil, {
        drop({ outcome = "received", settledAt = NOW, looter = "Seta-Testrealm", class = "PRIEST" }),
        drop({ outcome = "received", settledAt = NOW, looter = "Seta-Testrealm", class = "PRIEST", at = NOW - 60 }),
        drop({ outcome = "received", settledAt = NOW }),
    }) })
    local rows = NS.InsightsRows.GenerousRows(s)
    assertEqual(#rows, 2)
    assertEqual(rows[1].name, "Seta"); assertEqual(rows[1].right, "2")
    local r, g, b = NS.Compat.ClassColor("PRIEST")
    assertEqual(rows[1].nameColor[1], r); assertEqual(rows[1].nameColor[2], g); assertEqual(rows[1].nameColor[3], b)
    assertEqual(rows[1].tip[1], "Seta-Testrealm")
    assertTrue(rows[1].tip[2]:find("^2 items, the last on ") ~= nil, rows[1].tip[2])
    assertEqual(rows[1].tip[3], "Crown of Roaring Storms")
    assertEqual(rows[2].tip[2]:match("^1 item,"), "1 item,")
end)

test("insights rows: F draws each gain from 0, signed, legacy marked, the summed gain in the heading", function()
    local s, NS = statsOf({ group(nil, {
        drop({ outcome = "received", settledAt = NOW, got = { verdict = "upgrade", ilvlDelta = 7 } }),
        drop({ outcome = "received", me = { verdict = "downgrade", ilvlDelta = -3 }, at = NOW - 7200 }),
        drop({ outcome = "received", settledAt = NOW, got = { at = NOW } }),
    }) })
    local R = NS.InsightsRows
    local rows, suffix = R.GainRows(s)
    assertEqual(#rows, 2, "no comparison: no row")
    assertEqual(rows[1].value, "-3"); assertEqual(rows[1].lo, -3); assertEqual(rows[1].hi, 0); assertEqual(rows[1].mark, 0)
    assertTrue(rows[1].sublabel:find("as last judged", 1, true) ~= nil, "legacy")
    assertTrue(sameColor(rows[1].color, NS.Constants.TONE.red))
    assertEqual(rows[2].value, "+7"); assertEqual(rows[2].lo, 0); assertEqual(rows[2].hi, 7)
    assertEqual(rows[2].label, "Crown of Roaring Storms"); assertTrue(rows[2].labelColor ~= nil, "in its quality color")
    assertTrue(rows[2].sublabel:find("^from Brakk · ") ~= nil, rows[2].sublabel)
    assertTrue(rows[2].sublabel:find("last judged", 1, true) == nil)
    assertEqual(suffix, "+7 in all · 1 not compared")
    assertEqual(R.Signed(0.4), "0"); assertEqual(R.Signed(-2.6), "-3"); assertEqual(R.Signed(12), "+12")
end)

test("insights rows: F past ten rows keeps the ten biggest gains, oldest first, and counts the rest", function()
    local drops = {}
    for i = 1, 13 do
        drops[i] = drop({ outcome = "received", settledAt = NOW, at = NOW - 1000 + i,
            got = { verdict = "upgrade", ilvlDelta = i } })
    end
    local s, NS = statsOf({ group(nil, drops) })
    local rows, suffix = NS.InsightsRows.GainRows(s)
    assertEqual(#rows, 10)
    assertEqual(rows[1].value, "+4"); assertEqual(rows[10].value, "+13")
    assertEqual(suffix, "+91 in all · 3 more")
end)

test("insights rows: G and H bucket each day, the zero days kept, the hover naming the counts", function()
    local s, NS = statsOf({
        group({ at = NOW - 2 * DAY }, { drop({ at = NOW - 2 * DAY, askedAt = NOW - 2 * DAY + 60, outcome = "asked" }) }),
        group(nil, { drop({ me = UP }), drop() }),
    })
    local R = NS.InsightsRows
    local asks, n = R.DayBuckets(s, "asks")
    assertEqual(n, 1); assertEqual(asks[1].count, 1); assertEqual(asks[2].count, 0)
    assertEqual(asks[1].label, R.Day(NOW - 2 * DAY))
    assertEqual(asks[1].info[2], "1 ask, 0 offers")
    local drops, total = R.DayBuckets(s, "drops")
    assertEqual(total, 3); assertEqual(drops[#drops].count, 2)
    assertEqual(drops[#drops].info[2], "2 drops, 1 upgrade for you")
    s.weekly = true
    assertEqual(R.DayBuckets(s, "drops")[1].info[1], "Week of " .. R.Day(s.perDay[1].day))
end)

test("insights rows: the mixes read their words and colors, a token under its category and Can't use's off-spec count", function()
    local s, NS = statsOf({ group(nil, {
        drop({ class = "PRIEST", quality = 3, me = { verdict = "cantUse", offSpec = { verdict = "upgrade" } } }),
        drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE", trade = { state = "no" } }),
        drop({ class = false, me = { verdict = "newCollect" }, category = "mount", equipLoc = "" }),
        drop({ isMine = true }),
    }) })
    local R = NS.InsightsRows
    local function find(rows, label)
        for _, r in ipairs(rows) do if r.label == label then return r end end
    end
    local class = R.MixRows(s, "byClass")
    local priest = find(class, "Priest")
    assertTrue(priest ~= nil, "the class's own name"); assertEqual(priest.value, "1")
    assertTrue(priest.color ~= nil and priest.color[1] == select(1, NS.Compat.ClassColor("PRIEST")))
    assertTrue(find(class, "Unknown") ~= nil and find(class, "Unknown").color == nil, "no class: no color")
    local q = R.MixRows(s, "byQuality")
    assertEqual(q[1].label, "Epic"); assertEqual(q[2].label, "Rare"); assertTrue(q[1].color ~= nil)
    local slot = R.MixRows(s, "bySlot")
    assertTrue(find(slot, "Tier token") ~= nil, "a token's slot reads its category")
    assertTrue(find(slot, "Mount") ~= nil and find(slot, "Head") ~= nil)
    local cat = R.MixRows(s, "byCategory")
    assertEqual(cat[1].label, "Equipment"); assertEqual(cat[2].label, "Tier token"); assertEqual(cat[3].label, "Mount")
    local v = R.MixRows(s, "verdicts")
    local cant = find(v, "Can't use")
    assertTrue(sameColor(cant.color, NS.Constants.TONE.redMuted))
    assertEqual(cant.tip[3], "1 usable on another spec")
    assertTrue(sameColor(find(v, "New to your collection").color, NS.Constants.TONE.good))
    assertEqual(find(v, "Downgrade").tip[2], "2 (50%) drops")
    local tr = R.MixRows(s, "tradeStates")
    assertEqual(#tr, 2, "others' drops only")
    assertTrue(sameColor(find(tr, "Likely").color, NS.Constants.TONE.good))
    assertTrue(sameColor(find(tr, "No").color, NS.Constants.TONE.red), "the tone name resolved to its color")
    assertEqual(#R.MixRows(statsOf({}), "byClass"), 0)
end)
