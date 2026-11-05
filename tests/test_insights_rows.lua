-- tests/test_insights_rows.lua — what the Insights tab draws, as plain data (issue #12, Insights
-- design spec §1.3, §3.4, §4.2; modules/InsightsRows.lua): the eight cards' figures, hovers and
-- tone (a dash with nothing to show, the legacy lines only when a count was inferred), the card
-- grid (4 and 2 columns, a short last row stretched), the bar's wrap at the full, a middle and the
-- compact width, the period caption for a kept window, Never delete and a shorter range, and the
-- empty lines.

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
