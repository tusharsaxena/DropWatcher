-- tests/test_insights_filters.lua — the Insights tab's rows and filters (issue #12, Insights design
-- spec §1.1, §3; modules/InsightsFilters.lua): each facet's legacy fallback, the faceted options
-- (a dropdown counts the rows the other six filters keep, a row failing two counts nowhere, the
-- pick kept at 0, the head's count and choices), the normalize step (in ORDER, `keep` spared, the
-- input never written), the date ranges by the retention, the local midnights, each dropdown's
-- order, the period and the closed label.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DAY = 86400
local ME = "Testchar-Testrealm"
-- A fixed afternoon, so a day count never straddles a midnight the run happens to cross.
local NOW = os.time({ year = 2026, month = 11, day = 5, hour = 15 })

local function IF() return T.newAddon().InsightsFilters end

local function drop(over)
    local e = { itemLink = "x", itemID = 1, looter = "Brakk-Testrealm", outcome = "seen", at = NOW - 3600,
        quality = 4, equipLoc = "INVTYPE_HEAD", seenBy = ME }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local function group(over, drops)
    local g = { key = "k", label = "Boss", kind = "encounter", instance = "Ruby Life Pools", difficulty = "Mythic",
        situation = "dungeon", at = NOW - 3600, drops = drops or { drop() } }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end

local function counts(list)
    local out = {}
    for _, o in ipairs(list) do out[#out + 1] = tostring(o.value) .. "=" .. o.count end
    return table.concat(out, ",")
end

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

test("insights filters: Rows reads each facet once, with its legacy fallback", function()
    local F = IF()
    local rows = F.Rows({
        group({ seenBy = "Alt-Testrealm", seenByClass = "MAGE" }, {
            drop({ seenBy = "Main-Testrealm", seenByClass = "PRIEST" }),
            drop({ seenBy = false, quality = false }),
            "not a drop",
        }),
        group({ kind = "area", instance = false, label = "Isle of Dorn", difficulty = false, situation = false },
            { drop({ seenBy = false }) }),
        group({ kind = "run", instance = false, label = "Priory" }, { drop({ category = "mount" }),
            drop({ equipLoc = "INVTYPE_NON_EQUIP_IGNORE" }) }),
        "not a group",
    })
    assertEqual(#rows, 5, "non-tables are skipped")
    assertEqual(rows[1].char, "Main-Testrealm", "the drop's recorder first"); assertEqual(rows[1].charClass, "PRIEST")
    assertEqual(rows[2].char, "Alt-Testrealm", "else the group's"); assertEqual(rows[2].charClass, "MAGE")
    assertEqual(rows[2].quality, "unknown")
    assertEqual(rows[3].char, "unknown", "no recorder anywhere")
    assertEqual(rows[3].instance, "Open world", "an area outside an instance")
    assertEqual(rows[3].difficulty, "none"); assertEqual(rows[3].situation, "unknown")
    assertEqual(rows[4].instance, "Priory", "a run with no instance: its label")
    assertEqual(rows[1].instance, "Ruby Life Pools")
    assertEqual(rows[1].category, "equipment", "an entry from before #13")
    assertEqual(rows[4].category, "mount")
    assertEqual(rows[5].category, "tierToken", "a slot only a token has (run plan #12 Q3)")
    assertEqual(rows[1].day, F.Midnight(NOW - 3600))
    assertEqual(os.date("*t", rows[1].day).hour, 0)
    assertEqual(#F.Rows(nil), 0)
end)

-- ── the dates ───────────────────────────────────────────────────────────────────────────────

test("insights filters: the ranges follow the retention: shorter windows only, all under Never delete", function()
    local F = IF()
    assertEqual(table.concat(F.Ranges(30), ","), "all,today,7,14")
    assertEqual(table.concat(F.Ranges(7), ","), "all,today")
    assertEqual(table.concat(F.Ranges(0), ","), "all,today,7,14,30,60,90,180")
    assertEqual(table.concat(F.Ranges(nil), ","), "all,today,7,14,30,60,90,180")
end)

test("insights filters: Since is a local midnight, N-1 calendar days back; the walk never skips a day", function()
    local F = IF()
    local today = os.date("*t", NOW)
    assertEqual(F.Since("today", NOW), os.time({ year = today.year, month = today.month, day = today.day, hour = 0 }))
    local seven = os.date("*t", F.Since("7", NOW))
    assertEqual(seven.hour, 0); assertEqual(seven.day, 30, "Oct 30 to Nov 5 is seven days")
    assertNil(F.Since("all", NOW)); assertNil(F.Since(nil, NOW))
    -- a year of calendar days, through both DST changes wherever the zone has them
    local d = F.Midnight(os.time({ year = 2026, month = 1, day = 1, hour = 12 }))
    for _ = 1, 366 do
        local nextDay = F.DayAfter(d, 1)
        local a, b = os.date("*t", d), os.date("*t", nextDay)
        assertEqual(b.hour, 0)
        assertTrue(b.yday == a.yday + 1 or (b.yday == 1 and a.month == 12), "one calendar day on")
        d = nextDay
    end
end)

test("insights filters: Period names what the rows cover", function()
    local F = IF()
    local g1, g2 = group(nil, { drop({ at = NOW - 40 * DAY }), drop({ at = NOW - 2 * DAY }) }), group(nil, { drop({ at = NOW - DAY }) })
    local rows = F.Rows({ g1, g2 })
    local p = F.Period(rows, 30, "all", NOW)
    assertEqual(p.from, NOW - 30 * DAY, "the window's start, though a group kept an older drop")
    assertEqual(p.first, NOW - 40 * DAY); assertEqual(p.last, NOW - DAY); assertEqual(p.to, NOW)
    assertEqual(p.groups, 2); assertEqual(p.drops, 3); assertEqual(p.days, 30); assertEqual(p.range, "all")
    assertEqual(F.Period(rows, 0, "all", NOW).from, NOW - 40 * DAY, "Never delete: the first drop")
    assertEqual(F.Period(F.Rows({ g2 }), 30, "all", NOW).from, NOW - DAY, "a first drop inside the window")
    assertEqual(F.Period(rows, 30, "7", NOW).from, F.Since("7", NOW))
    local empty = F.Period({}, 30, "all", NOW)
    assertEqual(empty.drops, 0); assertEqual(empty.from, NOW - 30 * DAY); assertNil(empty.first)
end)

-- ── the filter and the options ──────────────────────────────────────────────────────────────

-- Three instances, two difficulties, two qualities: Ruby (Mythic, epic ×2), Altar (Heroic, rare),
-- Temple (Mythic, rare, 10 days ago).
local function sample(F)
    return F.Rows({
        group({ instance = "Ruby Life Pools" }, { drop(), drop() }),
        group({ instance = "Altar of Fangs", difficulty = "Heroic" }, { drop({ quality = 3 }) }),
        group({ instance = "Temple", at = NOW - 10 * DAY }, { drop({ quality = 3, at = NOW - 10 * DAY }) }),
    })
end

test("insights filters: Filter keeps the rows passing every pick, in order", function()
    local F = IF()
    local rows = sample(F)
    assertEqual(#F.Filter(rows, nil, NOW), 4)
    assertEqual(#F.Filter(rows, { quality = 3 }, NOW), 2)
    assertEqual(#F.Filter(rows, { quality = 3, difficulty = "Mythic" }, NOW), 1)
    assertEqual(#F.Filter(rows, { date = "7" }, NOW), 3)
    assertEqual(F.Filter(rows, { instance = "Altar of Fangs" }, NOW)[1].instance, "Altar of Fangs")
end)

test("insights filters: each dropdown counts the rows the other filters keep; two misses count nowhere", function()
    local F = IF()
    local rows = sample(F)
    local o = F.Options(rows, { quality = 3, instance = "all" }, NOW)
    -- instance sees the quality filter: only the two rare drops
    assertEqual(counts(o.instance), "all=2,Altar of Fangs=1,Temple=1")
    -- quality ignores its own pick: every row
    assertEqual(counts(o.quality), "all=4,4=2,3=2")
    o = F.Options(rows, { quality = 3, difficulty = "Heroic" }, NOW)
    -- Ruby fails both quality and difficulty: it counts toward neither
    assertEqual(counts(o.difficulty), "all=2,Mythic=1,Heroic=1")
    assertEqual(counts(o.quality), "all=1,3=1", "Temple misses the difficulty: only Altar counts")
end)

test("insights filters: the pick stays listed at 0, and the head carries the total and the choices", function()
    local F = IF()
    local rows = sample(F)
    local o = F.Options(rows, { instance = "Gone Hall" }, NOW, { days = 30 })
    assertEqual(counts(o.instance), "all=4,Altar of Fangs=1,Gone Hall=0,Ruby Life Pools=2,Temple=1")
    local head = o.instance[1]
    assertEqual(head.label, "All instances (4)"); assertEqual(head.choices, 4)
    assertEqual(o.instance[3].label, "Gone Hall (0)")
    assertEqual(F.ClosedLabel(o.instance, "all"), "All instances (4)", "closed: the number of values")
    assertEqual(F.ClosedLabel(o.instance, "Temple"), "Temple")
    -- the date ranges nest: every one listed with its count
    assertEqual(counts(o.date), "all=0,today=0,7=0,14=0", "nothing passes Gone Hall")
    o = F.Options(rows, nil, NOW, { days = 30 })
    assertEqual(counts(o.date), "all=4,today=3,7=3,14=4")
    assertEqual(o.date[1].label, "All kept days (4)"); assertEqual(o.date[3].name, "Last 7 days")
end)

test("insights filters: Normalize puts zero-count picks back to all in ORDER, spares `keep`, writes nothing", function()
    local F = IF()
    local rows = sample(F)
    local f = { instance = "Altar of Fangs", quality = 4 }
    local out, o = F.Normalize(rows, f, NOW)
    assertEqual(out.instance, "all", "Altar has no epic: instance comes first in ORDER")
    assertEqual(out.quality, 4)
    assertEqual(f.instance, "Altar of Fangs", "the input is never written")
    assertEqual(counts(o.instance), "all=2,Ruby Life Pools=2")
    out = F.Normalize(rows, f, NOW, "instance")
    assertEqual(out.instance, "Altar of Fangs", "the dropdown just changed keeps its pick")
    assertEqual(out.quality, "all")
    assertEqual(out.char, "all", "a missing key reads all")
end)

-- ── the orders and the names ────────────────────────────────────────────────────────────────

test("insights filters: difficulties in their natural order, situations in the constants' order", function()
    local F = IF()
    local g = {}
    for i, d in ipairs({ "Delves", "Mythic+ 6", "Heroic", "Mythic+ 12", "Zzz", "Mythic", "Looking For Raid",
        "Normal", "Timewalking" }) do
        g[i] = group({ difficulty = d })
    end
    g[#g + 1] = group({ difficulty = false })
    for _, s in ipairs({ "solo", "raid", "mythicPlus" }) do g[#g + 1] = group({ situation = s }) end
    g[#g + 1] = group({ situation = false })
    local o = F.Options(F.Rows(g), nil, NOW)
    local names = {}
    for i = 2, #o.difficulty do names[#names + 1] = o.difficulty[i].value end
    assertEqual(table.concat(names, ","),
        "Mythic+ 12,Mythic+ 6,Mythic,Heroic,Normal,Looking For Raid,Timewalking,Delves,Zzz,none")
    assertEqual(o.difficulty[#o.difficulty].name, "No difficulty")
    names = {}
    for i = 2, #o.situation do names[#names + 1] = o.situation[i].value end
    assertEqual(table.concat(names, ","), "mythicPlus,dungeon,raid,solo,unknown")
    assertEqual(o.situation[2].name, "Mythic+")
end)

test("insights filters: you first among the characters, then by count; qualities and categories ordered", function()
    local F = IF()
    local rows = F.Rows({ group(nil, {
        drop({ seenBy = "Alt-Testrealm", seenByClass = "MAGE" }), drop({ seenBy = "Alt-Testrealm" }),
        drop({ seenBy = ME, seenByClass = "WARRIOR", quality = 3, category = "toy" }),
        drop({ seenBy = "Zed-Testrealm", quality = 5, category = "tierToken" }), drop({ seenBy = false, quality = false }),
    }) })
    local o = F.Options(rows, nil, NOW, { current = ME, classColor = function() return 1, 0.5, 0 end,
        qualityColor = function(q) if q == 5 then return 1, 0.5, 0 end end })
    assertEqual(counts(o.char), "all=5," .. ME .. "=1,Alt-Testrealm=2,Zed-Testrealm=1,unknown=1")
    assertEqual(o.char[2].label, "|A:classicon-warrior:14:14|a " .. ME .. " (1)")
    assertEqual(o.char[2].color[2], 0.5, "the class color, wrapped from its triple")
    assertEqual(o.char[5].name, "Not recorded")
    assertEqual(counts(o.quality), "all=5,5=1,4=2,3=1,unknown=1")
    assertEqual(o.quality[2].name, "Legendary"); assertEqual(o.quality[2].color[1], 1)
    assertNil(o.quality[3].color, "no answer, no color")
    assertEqual(counts(o.category), "all=5,equipment=3,tierToken=1,toy=1")
    assertEqual(o.category[3].name, "Tier token")
    assertFalse(o.char[1].color ~= nil)
end)
