-- tests/test_insights_stats.lua — the Insights tab's one stats pass (issue #12, Insights design
-- spec §1, §2; modules/InsightsStats.lua): every §1 definition on fixture logs. Asks and offers from
-- the stamps, the held outcomes and the legacy trades (a stamped received with no ask is none); the
-- success rate; the three outcome rows; upgrades with the off-spec part, in parity with the filter
-- bar's rule; by instance, by boss (encounters only) and per visit (the 2-visit floor); the most
-- generous members; the gain from `got` against the legacy one; the continuous days and the weeks;
-- the mixes, #13's verdicts among them; the empty pass; each reducer seeing each row once.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DAY = 86400
local NOW = os.time({ year = 2026, month = 11, day = 5, hour = 15 })

local function load()
    local NS = T.newAddon()
    return NS, NS.InsightsFilters, NS.InsightsStats
end

local function drop(over)
    local e = { itemLink = "x", itemID = 1, looter = "Brakk-Testrealm", class = "WARRIOR", outcome = "seen",
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

local function compute(groups, period)
    local _, F, S = load()
    local rows = F.Rows(groups)
    return S.Compute(rows, period or F.Period(rows, 30, "all", NOW)), S
end

local function pairsOf(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = tostring(r.key) .. "=" .. r.n end
    return table.concat(out, ",")
end

local UP = { verdict = "upgrade", ilvlDelta = 9 }

-- ── the cards ───────────────────────────────────────────────────────────────────────────────

test("insights stats: asks from the stamp, the held outcomes and the legacy received; success over them", function()
    local s = compute({ group(nil, {
        drop({ askedAt = NOW - 60, outcome = "expired" }),                -- stamped
        drop({ outcome = "declined", before = "asked" }),                 -- held before a decline
        drop({ outcome = "expired", beforeExpired = "asked" }),           -- held before an expiry
        drop({ outcome = "received" }),                                   -- legacy: no settledAt
        drop({ outcome = "received", settledAt = NOW, askedAt = NOW - 99 }), -- asked, then traded
        drop({ outcome = "received", settledAt = NOW }),                  -- traded with no ask
        drop({ outcome = "asked", isMine = true }),                       -- never your own drop
        drop(),
    }) }).totals
    assertEqual(s.asks, 5); assertEqual(s.asksLegacy, 1)
    assertEqual(s.received, 3); assertEqual(s.askHits, 2, "a received item never asked for is not in the rate")
    assertEqual(s.success, 2 / 5)
    assertEqual(s.drops, 8); assertEqual(s.mine, 1); assertEqual(s.others, 7)
    assertEqual(s.givers, 1)
    assertNil(compute({ group(nil, { drop() }) }).totals.success, "no ask: no rate")
end)

test("insights stats: offers and traded away, your own drops only, the legacy one counted", function()
    local s = compute({ group(nil, {
        drop({ isMine = true, offeredAt = NOW - 5 }),
        drop({ isMine = true, outcome = "offered" }),
        drop({ isMine = true, outcome = "tradedAway" }),                   -- legacy
        drop({ isMine = true, outcome = "tradedAway", settledAt = NOW }),  -- traded with no offer
        drop({ outcome = "offered" }),
    }) }).totals
    assertEqual(s.offers, 3); assertEqual(s.offersLegacy, 1); assertEqual(s.tradedAway, 2)
end)

test("insights stats: an ask or offer from before the stamps, settled after, still counts as sent", function()
    local NS = load()
    local asked, offered = drop({ outcome = "asked" }), drop({ isMine = true, outcome = "offered" })
    NS.History.Settle(asked, "received", NOW); NS.History.Settle(offered, "tradedAway", NOW)
    local s = compute({ group(nil, { asked, offered }) }).totals
    assertEqual(s.asks, 1); assertEqual(s.askHits, 1); assertEqual(s.received, 1); assertEqual(s.success, 1)
    assertEqual(s.offers, 1); assertEqual(s.tradedAway, 1)
end)

test("insights stats: upgrades for you include the off-spec part, as the filter bar's rule does", function()
    local NS, F, S = load()
    local offUp = { verdict = "cantUse", offSpec = { specID = 2, mainSpecID = 1, verdict = "upgrade", ilvlDelta = 4 } }
    local offDown = { verdict = "cantUse", offSpec = { specID = 2, mainSpecID = 1, verdict = "downgrade" } }
    local drops = { drop({ me = UP }), drop({ me = offUp, isMine = true }), drop({ me = offDown }), drop({ me = UP, isMine = true }),
        drop({ me = { verdict = "sidegrade" } }), drop({ me = false }) }
    local t = S.Compute(F.Rows({ group(nil, drops) })).totals
    assertEqual(t.upgrades, 3); assertEqual(t.upgradesMine, 2); assertEqual(t.upgradesOff, 1)
    -- parity: the History tab's View: Upgrade for me keeps exactly these
    local FB = NS.WindowFilterBar
    for i, e in ipairs(drops) do
        local shown = FB.HiddenBy(e, { view = { upgrade = true } }, nil, { view = true }) == nil
        assertEqual(S.UpgradeForMe(e), shown, "drop " .. i)
    end
end)

test("insights stats: three outcome rows, the upgrades row a subset of the others'", function()
    local o = compute({ group(nil, {
        drop({ outcome = "received", me = UP }), drop({ outcome = "asked" }), drop({ outcome = "declined" }),
        drop({ outcome = "expired", me = UP }), drop(), drop({ outcome = "offered" }),
        drop({ isMine = true, outcome = "tradedAway" }), drop({ isMine = true, outcome = "offered" }),
        drop({ isMine = true, outcome = "expired" }), drop({ isMine = true, outcome = "declined" }),
        drop({ isMine = true, outcome = "asked" }),
    }) }).outcomes
    assertEqual(o.others.received, 1); assertEqual(o.others.asked, 1); assertEqual(o.others.declined, 1)
    assertEqual(o.others.expired, 1); assertEqual(o.others.kept, 2, "seen, and anything else, is kept")
    assertEqual(o.upgrades.received, 1); assertEqual(o.upgrades.expired, 1); assertEqual(o.upgrades.kept, 0)
    assertEqual(o.mine.tradedAway, 1); assertEqual(o.mine.offered, 1); assertEqual(o.mine.expired, 1)
    assertEqual(o.mine.declined, 1); assertEqual(o.mine.kept, 1)
end)

test("insights stats: active days in local time, first and last", function()
    local t = compute({ group(nil, { drop({ at = NOW - 2 * DAY }), drop({ at = NOW - 2 * DAY + 60 }), drop({ at = NOW }) }) }).totals
    assertEqual(t.activeDays, 2); assertEqual(t.first, NOW - 2 * DAY); assertEqual(t.last, NOW)
end)

-- ── the sections ────────────────────────────────────────────────────────────────────────────

test("insights stats: upgrades by instance and by boss (encounters only), and per visit over two visits", function()
    local s = compute({
        group({ label = "Boss A" }, { drop({ me = UP }), drop({ me = UP, isMine = true }) }),
        group({ label = "Boss B" }, { drop() }),
        group({ kind = "run", instance = "Altar of Fangs", label = "Altar of Fangs" }, { drop({ me = UP }) }),
        group({ kind = "run", instance = "Altar of Fangs", label = "Altar of Fangs" }, { drop({ me = UP }), drop({ me = UP }) }),
        group({ kind = "run", instance = "Temple", label = "Temple" }, { drop({ me = UP }) }),
    })
    local by = {}
    for _, r in ipairs(s.byInstance) do by[#by + 1] = r.key .. "=" .. r.upgrades .. "/" .. r.mine .. "/" .. r.others end
    assertEqual(table.concat(by, ","), "Altar of Fangs=3/0/3,Ruby Life Pools=2/1/1,Temple=1/0/1")
    assertEqual(#s.byBoss, 1, "a key's run is no boss")
    assertEqual(s.byBoss[1].label, "Boss A"); assertEqual(s.byBoss[1].upgrades, 2)
    assertEqual(s.byBoss[1].instance, "Ruby Life Pools"); assertEqual(s.byBoss[1].difficulty, "Mythic")
    local rate = {}
    for _, r in ipairs(s.topRate) do rate[#rate + 1] = r.key .. "=" .. r.upgrades .. "/" .. r.visits end
    assertEqual(table.concat(rate, ","), "Altar of Fangs=3/2,Ruby Life Pools=2/2", "Temple's one visit is under the floor")
    assertEqual(s.topRate[1].rate, 1.5)
end)

test("insights stats: the most generous members by count, then the most recent", function()
    local s = compute({ group(nil, {
        drop({ outcome = "received", looter = "Ana-R", at = NOW - 300 }),
        drop({ outcome = "received", looter = "Bo-R", class = "MAGE", at = NOW - 100 }),
        drop({ outcome = "received", looter = "Ana-R", at = NOW - 200 }),
        drop({ outcome = "received", looter = "Cy-R", at = NOW - 50 }),
        drop({ outcome = "received", looter = "Bo-R", isMine = true }),
        drop({ outcome = "asked", looter = "Dee-R" }),
    }) })
    local names = {}
    for _, g in ipairs(s.generous) do names[#names + 1] = g.looter .. "=" .. g.n end
    assertEqual(table.concat(names, ","), "Ana-R=2,Cy-R=1,Bo-R=1", "a tie goes to the most recent")
    assertEqual(#s.generous[1].items, 2); assertEqual(s.generous[3].class, "MAGE")
end)

test("insights stats: a generous member's last trade is when it settled, not when it dropped", function()
    -- red under: rReceived taking gv.last from the drop's loot time (row.at) alone
    local s = compute({ group(nil, {
        drop({ outcome = "received", looter = "Ana-R", at = NOW - 300, settledAt = NOW - 10 }),
        drop({ outcome = "received", looter = "Bo-R", at = NOW - 100, settledAt = NOW - 200 }),
        drop({ outcome = "received", looter = "Cy-R", at = NOW - 150 }),   -- legacy: no settledAt
    }) })
    local names = {}
    for _, g in ipairs(s.generous) do names[#names + 1] = g.looter .. "@" .. (NOW - g.last) end
    assertEqual(table.concat(names, ","), "Ana-R@10,Cy-R@150,Bo-R@200", "the tie goes to the latest trade")
end)

test("insights stats: the gain is the frozen verdict's, the legacy one as last judged, none skipped", function()
    local _, F, S = load()
    local s = S.Compute(F.Rows({ group(nil, {
        drop({ outcome = "received", settledAt = NOW, got = { verdict = "upgrade", ilvlDelta = 7, at = NOW },
            me = { verdict = "sidegrade", ilvlDelta = 0 }, at = NOW - 10 }),
        drop({ outcome = "received", me = { verdict = "downgrade", ilvlDelta = -7 }, at = NOW - 20 }),
        drop({ outcome = "received", settledAt = NOW, got = { verdict = "cantUse", at = NOW,
            offSpec = { verdict = "upgrade", ilvlDelta = 5 } }, at = NOW - 30 }),
        drop({ outcome = "received", settledAt = NOW, got = { at = NOW }, me = false }),
    }) }))
    local t = s.totals
    assertEqual(t.gainN, 3); assertEqual(t.gainNone, 1, "no level comparison: no row")
    assertEqual(t.gainSum, 12, "the positive gains summed"); assertEqual(t.gainLegacy, 1)
    assertEqual(#s.received, 3)
    assertEqual(s.received[1].gain, 5, "the off-spec part counts (oldest first)")
    assertEqual(s.received[2].gain, -7); assertTrue(s.received[2].legacy)
    assertEqual(s.received[3].gain, 7, "frozen at the trade, not the post-equip sidegrade 0")
    assertFalse(s.received[3].legacy)
    assertEqual(S.Gain(drop({ me = { verdict = "upgrade", ilvlDelta = 2 } })), 2)
end)

test("insights stats: the days are continuous with empty ones, asks on the day they were sent", function()
    local _, F, S = load()
    local rows = F.Rows({ group(nil, {
        drop({ at = NOW - 4 * DAY, askedAt = NOW - 2 * DAY }), drop({ at = NOW - 4 * DAY, me = UP }),
        drop({ at = NOW, isMine = true, offeredAt = NOW }),
    }) })
    local s = S.Compute(rows, F.Period(rows, 30, "7", NOW))
    assertFalse(s.weekly)
    assertEqual(#s.perDay, 7, "Oct 30 to Nov 5")
    local line = {}
    for _, b in ipairs(s.perDay) do line[#line + 1] = b.drops .. "/" .. b.asks .. "/" .. b.offers .. "/" .. b.upgrades end
    assertEqual(table.concat(line, " "), "0/0/0/0 0/0/0/0 2/0/0/1 0/0/0/0 0/1/0/0 0/0/0/0 1/0/1/0")
    assertEqual(s.perDay[1].day, F.Since("7", NOW))
    assertEqual(s.totals.activeDays, 2, "a day with only an ask sent is no active day")
end)

test("insights stats: a period over 62 days buckets by week", function()
    local _, F, S = load()
    local rows = F.Rows({ group(nil, { drop({ at = NOW - 69 * DAY }), drop({ at = NOW - 68 * DAY }), drop({ at = NOW }) }) })
    local s = S.Compute(rows, F.Period(rows, 0, "all", NOW))
    assertTrue(s.weekly)
    assertEqual(#s.perDay, 10, "70 days in weeks")
    assertEqual(s.perDay[1].drops, 2); assertEqual(s.perDay[1].days, 7)
    assertEqual(s.perDay[10].drops, 1)
    local n = 0
    for _, b in ipairs(s.perDay) do n = n + b.days end
    assertEqual(n, 70)
end)

test("insights stats: the mixes: class, quality, slot, category, verdicts and trade estimates", function()
    local s = compute({ group(nil, {
        drop({ equipLoc = "INVTYPE_ROBE", quality = 3 }), drop({ equipLoc = "INVTYPE_CHEST", class = "MAGE" }),
        drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE", me = UP }),
        drop({ equipLoc = "", category = "mount", me = { verdict = "newCollect", collect = true }, trade = false }),
        drop({ equipLoc = "", category = "toy", me = { verdict = "collected", collect = true }, isMine = true }),
        drop({ equipLoc = "INVTYPE_BAG", me = { verdict = "cantUse", offSpec = { verdict = "sidegrade" } },
            trade = { state = "no" } }),
        drop({ me = false, quality = 5, trade = { state = "yes" } }),
    }) })
    assertEqual(pairsOf(s.byClass), "WARRIOR=6,MAGE=1")
    assertEqual(pairsOf(s.byQuality), "5=1,4=5,3=1")
    assertEqual(pairsOf(s.bySlot), "Chest=2,Head=1,Mount=1,Other=1,Tier token=1,Toy=1",
        "a robe folds into Chest; an old token, a collectible and an unlisted slot by their words")
    assertEqual(pairsOf(s.byCategory), "equipment=4,tierToken=1,mount=1,toy=1")
    assertEqual(pairsOf(s.verdicts), "upgrade=1,downgrade=2,cantUse=1,unknown=1,newCollect=1,collected=1")
    assertEqual(s.cantUseOff, 1, "usable on another spec")
    assertEqual(pairsOf(s.tradeStates), "yes=1,likely=3,no=1,unknown=1", "others' drops only")
end)

-- DW-N1 (review 2026-11-05): History's Watched item is its own category, after every other, and
-- its Slot word when it has no slot of its own.
test("insights stats: a Watched item counts as itself, listed after every category", function()
    local s = compute({ group(nil, {
        drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE", category = "watched", me = { verdict = "unknown", collect = true } }),
        drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE", category = "watched", me = { verdict = "unknown", collect = true } }),
        drop({ equipLoc = "", category = "toy", me = { verdict = "collected", collect = true } }),
        drop(),
    }) })
    assertEqual(pairsOf(s.byCategory), "equipment=1,toy=1,watched=2")
    assertEqual(pairsOf(s.bySlot), "Watched item=2,Head=1,Toy=1")
end)

-- RX-04 (rolls UX design §3.5): a lockbox counts as a Container and a rolled reagent as Other
-- loot, each in the categories' order, and their kind verdicts are counted.
-- red under: the new kinds or their verdicts missing from Insights' orders
test("insights stats: a lockbox and a rolled reagent count as their kinds", function()
    local s = compute({ group(nil, {
        drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE", category = "container", me = { verdict = "lockbox", collect = true } }),
        drop({ equipLoc = "", category = "other", me = { verdict = "item", collect = true } }),
        drop(),
    }) })
    assertEqual(pairsOf(s.byCategory), "equipment=1,container=1,other=1")
    assertEqual(pairsOf(s.bySlot), "Container=1,Head=1,Other loot=1")
    assertEqual(pairsOf(s.verdicts), "downgrade=1,lockbox=1,item=1")
end)

-- ── the pass ────────────────────────────────────────────────────────────────────────────────

test("insights stats: nothing in gives zeros and empty lists", function()
    local _, _, S = load()
    local s = S.Compute({}, nil)
    for _, k in ipairs({ "drops", "asks", "received", "offers", "tradedAway", "activeDays", "gainSum", "givers" }) do
        assertEqual(s.totals[k], 0, k)
    end
    assertNil(s.totals.success); assertNil(s.totals.first)
    for _, k in ipairs({ "byInstance", "byBoss", "topRate", "generous", "received", "perDay", "byClass",
        "byQuality", "bySlot", "byCategory", "verdicts", "tradeStates" }) do
        assertEqual(#s[k], 0, k)
    end
    assertEqual(S.Compute(nil).totals.drops, 0)
end)

test("insights stats: one pass: each reducer sees each row once", function()
    local _, F, S = load()
    local rows = F.Rows({ group(nil, { drop(), drop(), drop() }) })
    local seen, real = {}, S.REDUCERS
    local wrapped = {}
    for i, fn in ipairs(real) do
        wrapped[i] = function(acc, row)
            seen[i] = seen[i] or {}
            seen[i][row] = (seen[i][row] or 0) + 1
            return fn(acc, row)
        end
    end
    S.REDUCERS = wrapped
    S.Compute(rows)
    S.REDUCERS = real
    assertEqual(#seen, #real)
    for i = 1, #real do
        for _, row in ipairs(rows) do assertEqual(seen[i][row], 1, "reducer " .. i) end
    end
end)
