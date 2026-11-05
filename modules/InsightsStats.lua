local _, NS = ...
-- modules/InsightsStats.lua — the Insights tab's numbers (issue #12, Insights design spec §1, §2):
-- one pass over the filtered rows (NS.InsightsFilters.Rows, then Filter) gives the cards' totals and
-- every section's data.
--
-- THE READS (spec §1.1). An upgrade for you is the filter bar's rule (WindowFilterBar's
-- upgradeForMe): `me` an upgrade, or a can't-use whose off-spec part is one. An ask or offer is
-- NS.History.WasAsked / WasOffered, so a legacy entry (settled before `settledAt` existed) counts
-- its trade as one, and `asksLegacy` / `offersLegacy` say how many were inferred so. The item level
-- gained from an item received is its frozen verdict's (`got`, else `me`, as last judged: `legacy`)
-- through NS.OffSpec.EvalFor; one with no level comparison counts in `gainNone` and draws no row.
-- Asks and offers fall on the day they were sent (`askedAt`, `offeredAt`, else the drop's own).
--
-- THE PASS (spec §2.4, DPS Race's shape). REDUCERS are small one-concern functions `(acc, row)`;
-- Compute hands each row to every reducer once, then FINALIZERS sort, cap and bucket: the days are
-- continuous from the period's start (or the first drop, when the group-wise prune kept an older
-- one) to its end, one bucket a local day, or a week once the period passes WEEK_AFTER days. A new
-- section is one reducer and one finalizer.
--
--   stats = { totals = { drops, mine, others, upgrades, upgradesMine, upgradesOff, asks, asksLegacy,
--               askHits, received, givers, success|nil, offers, offersLegacy, tradedAway, activeDays,
--               first, last, gainSum, gainN, gainLegacy, gainNone },
--             outcomes = { others, upgrades = { received, asked, declined, expired, kept },
--                          mine = { tradedAway, offered, declined, expired, kept } },
--             byInstance = { { key, upgrades, mine, others } }, byBoss = { { label, instance,
--             difficulty, upgrades } }, topRate = { { key, upgrades, visits, rate } },
--             generous = { { looter, class, n, last, items } }, received = { { e, looter, gain,
--             legacy, at } }, perDay = { { day, days, drops, asks, offers, upgrades } }, weekly,
--             byClass, byQuality, bySlot, byCategory, verdicts, tradeStates = { { key, n, label? } },
--             cantUseOff }
--
-- PURE: plain tables in, plain tables out; it reads NS.OffSpec, NS.History's two predicates,
-- NS.InsightsFilters' calendar, NS.Constants.CATEGORIES and the label readers
-- (NS.WindowCells.SlotLabel, NS.CollectCells.KindLabel, NS.L) at call time, so its TOC position is
-- conventional. test_insights_stats drives it.

NS.InsightsStats = NS.InsightsStats or {}
local IS = NS.InsightsStats
local L = NS.L

IS.WEEK_AFTER = 62     -- days; a longer period buckets by week
IS.MIN_VISITS = 2      -- Top instances' floor

-- ── the reads ───────────────────────────────────────────────────────────────────────────────

local function verdictOf(side) return type(side) == "table" and side.verdict or nil end

local function offUpgrade(me)
    local off = NS.OffSpec.Of(me)
    return off ~= nil and off.verdict == "upgrade"
end

--- An upgrade for you: on your current spec, or on another when this one can't use it.
--- @param e table a History entry
--- @return boolean
function IS.UpgradeForMe(e)
    return verdictOf(e.me) == "upgrade" or offUpgrade(e.me)
end

local function mine(e) return e.isMine == true end

-- An ask counted only from a legacy received entry (no stamp, no `asked` kept anywhere).
local function legacyAsk(e)
    return e.askedAt == nil and e.beforeExpired ~= "asked" and e.before ~= "asked" and e.outcome ~= "asked"
end

local function legacyOffer(e)
    return e.offeredAt == nil and e.beforeExpired ~= "offered" and e.before ~= "offered" and e.outcome ~= "offered"
end

--- The item level an item received gained you, and whether it is as last judged (legacy).
--- @param e table
--- @return number|nil gain, boolean legacy
function IS.Gain(e)
    local eval = NS.OffSpec.EvalFor(e.got or e.me)
    local gain = type(eval) == "table" and type(eval.ilvlDelta) == "number" and eval.ilvlDelta or nil
    return gain, e.settledAt == nil
end

-- ── the accumulator ─────────────────────────────────────────────────────────────────────────

local TOTALS = { "drops", "mine", "others", "upgrades", "upgradesMine", "upgradesOff", "asks", "asksLegacy",
    "askHits", "received", "givers", "offers", "offersLegacy", "tradedAway", "activeDays", "gainSum", "gainN",
    "gainLegacy", "gainNone" }

IS.SEGMENTS = {
    others = { "received", "asked", "declined", "expired", "kept" },
    mine = { "tradedAway", "offered", "declined", "expired", "kept" },
}
-- Each outcome's segment, by whose drop it is; any other outcome is `kept`.
local OTHERS_SEG = { received = "received", asked = "asked", declined = "declined", expired = "expired" }
local MINE_SEG = { tradedAway = "tradedAway", offered = "offered", declined = "declined", expired = "expired" }

local function zeros(keys)
    local out = {}
    for _, k in ipairs(keys) do out[k] = 0 end
    return out
end

local function newAcc()
    return {
        totals = zeros(TOTALS),
        outcomes = { others = zeros(IS.SEGMENTS.others), upgrades = zeros(IS.SEGMENTS.others),
            mine = zeros(IS.SEGMENTS.mine) },
        inst = {}, visits = {}, boss = {}, givers = {}, received = {}, days = {}, mix = {
            byClass = {}, byQuality = {}, bySlot = {}, byCategory = {}, verdicts = {}, tradeStates = {} },
        cantUseOff = 0,
    }
end

local function bump(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function dayBucket(acc, day)
    local b = acc.days[day]
    if not b then
        b = { drops = 0, asks = 0, offers = 0, upgrades = 0 }
        acc.days[day] = b
    end
    return b
end

-- ── the reducers ────────────────────────────────────────────────────────────────────────────

local function rCounts(acc, row)
    local t, e = acc.totals, row.e
    t.drops = t.drops + 1
    bump(t, mine(e) and "mine" or "others")
    if not IS.UpgradeForMe(e) then return end
    t.upgrades = t.upgrades + 1
    if mine(e) then t.upgradesMine = t.upgradesMine + 1 end
    if verdictOf(e.me) ~= "upgrade" then t.upgradesOff = t.upgradesOff + 1 end
end

local function rAsks(acc, row)
    local t, e = acc.totals, row.e
    if mine(e) then return end
    if e.outcome == "received" then t.received = t.received + 1 end
    if not NS.History.WasAsked(e) then return end
    t.asks = t.asks + 1
    if legacyAsk(e) then t.asksLegacy = t.asksLegacy + 1 end
    if e.outcome == "received" then t.askHits = t.askHits + 1 end
    bump(dayBucket(acc, NS.InsightsFilters.Midnight(e.askedAt or row.at)), "asks")
end

local function rOffers(acc, row)
    local t, e = acc.totals, row.e
    if not mine(e) then return end
    if e.outcome == "tradedAway" then t.tradedAway = t.tradedAway + 1 end
    if not NS.History.WasOffered(e) then return end
    t.offers = t.offers + 1
    if legacyOffer(e) then t.offersLegacy = t.offersLegacy + 1 end
    bump(dayBucket(acc, NS.InsightsFilters.Midnight(e.offeredAt or row.at)), "offers")
end

local function rOutcomes(acc, row)
    local e, o = row.e, acc.outcomes
    if mine(e) then
        bump(o.mine, MINE_SEG[e.outcome] or "kept")
        return
    end
    local seg = OTHERS_SEG[e.outcome] or "kept"
    bump(o.others, seg)
    if IS.UpgradeForMe(e) then bump(o.upgrades, seg) end
end

local function rPlaces(acc, row)
    local e, g, key = row.e, row.g, row.instance
    local v = acc.visits[key]
    if not v then v = {}; acc.visits[key] = v end
    v[g] = true
    if not IS.UpgradeForMe(e) then return end
    local i = acc.inst[key]
    if not i then i = { key = key, upgrades = 0, mine = 0, others = 0 }; acc.inst[key] = i end
    i.upgrades = i.upgrades + 1
    bump(i, mine(e) and "mine" or "others")
    if g.kind ~= "encounter" then return end
    local bkey = tostring(g.label) .. "\0" .. key .. "\0" .. row.difficulty
    local b = acc.boss[bkey]
    if not b then
        b = { label = g.label or L["Unknown"], instance = key, difficulty = row.difficulty, upgrades = 0 }
        acc.boss[bkey] = b
    end
    b.upgrades = b.upgrades + 1
end

local function rReceived(acc, row)
    local e, t = row.e, acc.totals
    if e.outcome ~= "received" or mine(e) then return end
    local who = type(e.looter) == "string" and e.looter or nil
    if who then
        local gv = acc.givers[who]
        if not gv then gv = { looter = who, class = e.class, n = 0, last = 0, items = {} }; acc.givers[who] = gv end
        -- When the member traded it to you (its settle stamp), as section F reads it; the loot time
        -- for an entry from before the stamps.
        gv.n, gv.last = gv.n + 1, math.max(gv.last, tonumber(e.settledAt) or row.at)
        gv.items[#gv.items + 1] = e
    end
    local gain, legacy = IS.Gain(e)
    if gain == nil then t.gainNone = t.gainNone + 1; return end
    t.gainN = t.gainN + 1
    if gain > 0 then t.gainSum = t.gainSum + gain end
    if legacy then t.gainLegacy = t.gainLegacy + 1 end
    acc.received[#acc.received + 1] = { e = e, looter = who, gain = gain, legacy = legacy, at = row.at }
end

local function rDays(acc, row)
    local t, b = acc.totals, dayBucket(acc, row.day)
    b.drops = b.drops + 1
    if IS.UpgradeForMe(row.e) then b.upgrades = b.upgrades + 1 end
    if not t.first or row.at < t.first then t.first = row.at end
    if not t.last or row.at > t.last then t.last = row.at end
end

-- The slot a drop shows under: its slot's word (a robe folds into Chest), else a non-equipment
-- category's word (a tier token from before #13, a collectible), else Other.
local function slotKey(row)
    local slot = NS.WindowCells.SlotLabel(row.e.equipLoc)
    if slot then return slot end
    if row.category ~= "equipment" then return NS.CollectCells.KindLabel(row.category) or L["Other"] end
    return L["Other"]
end

local function rMix(acc, row)
    local e, m = row.e, acc.mix
    bump(m.byClass, type(e.class) == "string" and e.class or "unknown")
    bump(m.byQuality, row.quality)
    bump(m.bySlot, slotKey(row))
    bump(m.byCategory, row.category)
    local verdict = verdictOf(e.me) or "unknown"
    bump(m.verdicts, verdict)
    if verdict == "cantUse" and NS.OffSpec.Of(e.me) then acc.cantUseOff = acc.cantUseOff + 1 end
    if not mine(e) then
        local tr = e.trade
        bump(m.tradeStates, type(tr) == "table" and type(tr.state) == "string" and tr.state or "unknown")
    end
end

IS.REDUCERS = { rCounts, rAsks, rOffers, rOutcomes, rPlaces, rReceived, rDays, rMix }

-- ── the finalizers ──────────────────────────────────────────────────────────────────────────

local function values(t)
    local out = {}
    for _, v in pairs(t) do out[#out + 1] = v end
    return out
end

local function fTotals(acc, out)
    local t = acc.totals
    for _ in pairs(acc.givers) do t.givers = t.givers + 1 end
    local active = 0
    for _, b in pairs(acc.days) do
        if b.drops > 0 then active = active + 1 end
    end
    t.activeDays = active
    t.success = t.asks > 0 and (t.askHits / t.asks) or nil
    out.totals, out.outcomes = t, acc.outcomes
end

local function fPlaces(acc, out)
    local by = values(acc.inst)
    table.sort(by, function(a, b)
        if a.upgrades ~= b.upgrades then return a.upgrades > b.upgrades end
        return a.key < b.key
    end)
    out.byInstance = by
    local rate = {}
    for _, i in ipairs(by) do
        local n = 0
        for _ in pairs(acc.visits[i.key] or {}) do n = n + 1 end
        if n >= IS.MIN_VISITS then
            rate[#rate + 1] = { key = i.key, upgrades = i.upgrades, visits = n, rate = i.upgrades / n }
        end
    end
    table.sort(rate, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        if a.upgrades ~= b.upgrades then return a.upgrades > b.upgrades end
        return a.key < b.key
    end)
    out.topRate = rate
    local boss = values(acc.boss)
    table.sort(boss, function(a, b)
        if a.upgrades ~= b.upgrades then return a.upgrades > b.upgrades end
        return tostring(a.label) < tostring(b.label)
    end)
    out.byBoss = boss
end

local function fTrades(acc, out)
    local gv = values(acc.givers)
    table.sort(gv, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        if a.last ~= b.last then return a.last > b.last end
        return a.looter < b.looter
    end)
    out.generous = gv
    table.sort(acc.received, function(a, b) return a.at < b.at end)
    out.received = acc.received
end

-- The continuous day buckets from `start` to `stop` (local midnights), and the week buckets.
local function walkDays(acc, start, stop)
    local days, d = {}, start
    while d <= stop do
        local b = acc.days[d] or { drops = 0, asks = 0, offers = 0, upgrades = 0 }
        days[#days + 1] = { day = d, days = 1, drops = b.drops, asks = b.asks, offers = b.offers, upgrades = b.upgrades }
        d = NS.InsightsFilters.DayAfter(d, 1)
    end
    return days
end

local function weeks(days)
    local out = {}
    for i, b in ipairs(days) do
        local w = math.floor((i - 1) / 7) + 1
        local into = out[w]
        if not into then
            into = { day = b.day, days = 0, drops = 0, asks = 0, offers = 0, upgrades = 0 }
            out[w] = into
        end
        into.days, into.drops, into.asks = into.days + 1, into.drops + b.drops, into.asks + b.asks
        into.offers, into.upgrades = into.offers + b.offers, into.upgrades + b.upgrades
    end
    return out
end

local function fDays(acc, out, period)
    local first = acc.totals.first
    out.perDay, out.weekly = {}, false
    if not first then return end
    local IF = NS.InsightsFilters
    local from = period and type(period.from) == "number" and math.min(period.from, first) or first
    local to = period and type(period.to) == "number" and math.max(period.to, acc.totals.last) or acc.totals.last
    local days = walkDays(acc, IF.Midnight(from), IF.Midnight(to))
    if #days > IS.WEEK_AFTER then
        out.perDay, out.weekly = weeks(days), true
    else
        out.perDay = days
    end
end

local function byCount(t)
    local out = {}
    for k, n in pairs(t) do out[#out + 1] = { key = k, n = n } end
    table.sort(out, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return tostring(a.key) < tostring(b.key)
    end)
    return out
end

local function inOrder(t, order)
    local out, listed = {}, {}
    for _, k in ipairs(order) do
        listed[k] = true
        if t[k] then out[#out + 1] = { key = k, n = t[k] } end
    end
    local rest = {}
    for k, n in pairs(t) do
        if not listed[k] then rest[k] = n end
    end
    for _, r in ipairs(byCount(rest)) do out[#out + 1] = r end
    return out
end

IS.VERDICT_ORDER = { "upgrade", "sidegrade", "downgrade", "cantUse", "unknown", "newCollect", "collected",
    "collectUnknown" }
IS.TRADE_ORDER = { "yes", "likely", "no", "unknown" }

local function categoryOrder()
    local out = {}
    for i, c in ipairs(NS.Constants.CATEGORIES) do out[i] = c.key end
    return out
end

local function byQuality(t)
    local out = byCount(t)
    table.sort(out, function(a, b)
        local qa = type(a.key) == "number" and a.key or -1
        local qb = type(b.key) == "number" and b.key or -1
        return qa > qb
    end)
    return out
end

local function fMix(acc, out)
    local m = acc.mix
    out.byClass, out.bySlot = byCount(m.byClass), byCount(m.bySlot)
    out.byQuality = byQuality(m.byQuality)
    out.byCategory = inOrder(m.byCategory, categoryOrder())
    out.verdicts = inOrder(m.verdicts, IS.VERDICT_ORDER)
    out.tradeStates = inOrder(m.tradeStates, IS.TRADE_ORDER)
    out.cantUseOff = acc.cantUseOff
end

IS.FINALIZERS = { fTotals, fPlaces, fTrades, fDays, fMix }

--- Every number the Insights tab shows, in one pass over the filtered rows (see the header).
--- @param rows table NS.InsightsFilters.Filter's
--- @param period table|nil NS.InsightsFilters.Period's ({ from, to })
--- @return table stats
function IS.Compute(rows, period)
    local acc = newAcc()
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        for _, reduce in ipairs(IS.REDUCERS) do reduce(acc, row) end
    end
    local out = {}
    for _, finalize in ipairs(IS.FINALIZERS) do finalize(acc, out, period) end
    return out
end
