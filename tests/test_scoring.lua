-- tests/test_scoring.lua — modules/Scoring.lua (design spec §5.4): the Pawn scale import, the
-- weights score and its unknown keys, which adapter is in use for each setting, the Pawn adapter
-- for you and for a looter (its scales, "pending" while Pawn is not ready), and the sidegrade the
-- kernel reaches when item level and score disagree, through the kernel and through the feed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local CRIT, HASTE = "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT"

local PAWN = '( Pawn: v1: "Arms": Class=1, Spec=1, Strength=1.50, CritRating=0.8, HasteRating=0.60,'
    .. ' Versatility=0, Dps=3.2, IsPlate=1, Leech=0.1 )'

local function pure()
    local NS = T.newAddon()
    return NS.Scoring, NS
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- The Pawn scale import
-- ---------------------------------------------------------------------------------------------

test("scoring: a Pawn v1 string imports its stats under GetItemStats' keys", function()
    local S = pure()
    local r = S.ParseImport(PAWN)
    assertEqual(r.name, "Arms")
    assertEqual(r.weights[STR], 1.5)
    assertEqual(r.weights[CRIT], 0.8)
    assertEqual(r.weights[HASTE], 0.6)
    assertEqual(r.weights.ITEM_MOD_CR_LIFESTEAL_SHORT, 0.1)
    assertNil(r.weights.ITEM_MOD_VERSATILITY, "a 0 weight is left out")
    assertEqual(count(r.weights), 4)
    -- Class and Spec are the header, read past quietly; the rest is reported, sorted.
    assertEqual(table.concat(r.skipped, ","), "Dps,IsPlate")
end)

test("scoring: an import that is empty, not a Pawn string, or has no stat is refused with its reason", function()
    local S = pure()
    local r, why = S.ParseImport("   ")
    assertNil(r); assertEqual(why, "empty")
    r, why = S.ParseImport(nil)
    assertNil(r); assertEqual(why, "empty")
    r, why = S.ParseImport("Strength=1, Agility=2")
    assertNil(r); assertEqual(why, "format")
    r, why = S.ParseImport('( Pawn: v2: "X": Strength=1 )')
    assertNil(r); assertEqual(why, "format")
    r, why = S.ParseImport('( Pawn: v1: "Tank": Class=1, Armor=2, Dps=1 )')
    assertNil(r); assertEqual(why, "noStats")
    r = S.ParseImport('(Pawn:v1:"Tight":Intellect=2,Stamina=garbage)')
    assertEqual(r.weights[INT], 2, "spacing is free; a pair without a number is ignored")
end)

test("scoring: ImportInto replaces one spec's weights in a fresh map and keeps the others", function()
    local S = pure()
    local stored = { [71] = { [STR] = 9, [CRIT] = 9 }, [72] = { [HASTE] = 1 } }
    local out, r = S.ImportInto(stored, 71, PAWN)
    assertEqual(r.name, "Arms")
    assertEqual(out[71][STR], 1.5)
    assertNil(out[71].ITEM_MOD_VERSATILITY)
    assertEqual(out[72][HASTE], 1)
    assertTrue(out ~= stored and out[72] ~= stored[72], "a fresh table, nothing shared with the stored one")
    assertEqual(stored[71][STR], 9, "the stored map is untouched")
    local none, why = S.ImportInto(stored, nil, PAWN)
    assertNil(none); assertEqual(why, "noSpec")
    none, why = S.ImportInto(stored, 71, "nope")
    assertNil(none); assertEqual(why, "format")
    assertEqual(S.ImportInto(nil, 73, PAWN)[73][STR], 1.5, "from no map")
end)

-- ---------------------------------------------------------------------------------------------
-- The weights score
-- ---------------------------------------------------------------------------------------------

test("scoring: a weights score is the sum of stat times weight", function()
    local S = pure()
    assertEqual(S.WeightsScore({ [STR] = 100, [CRIT] = 50, [HASTE] = 10 }, { [STR] = 2, [CRIT] = 0.5 }), 225)
    assertEqual(S.WeightsScore({}, { [STR] = 2 }), 0, "an item without the stat scores 0")
    assertNil(S.WeightsScore(nil, { [STR] = 2 }))
    assertNil(S.WeightsScore({ [STR] = 1 }, nil))
    assertNil(S.WeightsScore({ [STR] = 1 }, {}), "no weights is no score")
end)

test("scoring: a weight on an unknown stat key counts 0 and is logged once per key", function()
    local S, NS = pure()
    local logged = {}
    NS.DebugOnce = function(key, tag) logged[#logged + 1] = tag .. ":" .. tostring(key) end
    local w = { [STR] = 1, ITEM_MOD_MADE_UP = 5 }
    assertEqual(S.WeightsScore({ [STR] = 10, ITEM_MOD_MADE_UP = 99 }, w), 10)
    S.WeightsScore({ [STR] = 10 }, w)
    assertEqual(logged[1], "SCORE:weight:ITEM_MOD_MADE_UP")
    -- DebugOnce is the gate: the same key every time, so the console hears it once.
    assertEqual(logged[2], logged[1])
end)

test("scoring: HasWeights is true once any spec has a weight", function()
    local S = pure()
    assertFalse(S.HasWeights(nil))
    assertFalse(S.HasWeights({}))
    assertFalse(S.HasWeights({ [62] = {} }))
    assertTrue(S.HasWeights({ [62] = { [INT] = 1 } }))
end)

-- ---------------------------------------------------------------------------------------------
-- The adapter in use
-- ---------------------------------------------------------------------------------------------

test("scoring: Resolve picks the adapter for every setting, Pawn presence and weights", function()
    local S = pure()
    local rows = {
        -- configured, pawnReady, hasWeights, in use
        { "auto",    true,  true,  "pawn" },
        { "auto",    false, true,  "weights" },
        { "auto",    false, false, "none" },
        { "pawn",    true,  false, "pawn" },
        { "pawn",    false, true,  "none" },
        { "weights", true,  true,  "weights" },
        { "weights", true,  false, "none" },
        { "none",    true,  true,  "none" },
        { "bogus",   false, true,  "weights" },
        { nil,       true,  false, "pawn" },
    }
    for _, r in ipairs(rows) do
        assertEqual(S.Resolve(r[1], r[2], r[3]), r[4], tostring(r[1]) .. "/" .. tostring(r[2]) .. "/" .. tostring(r[3]))
    end
end)

test("scoring: InUse and Scorer follow the settings and whether Pawn is initialized", function()
    local NS, _, m = T.enableAddon()
    local S, Set = NS.Scoring, NS.SchemaRuntime.Set
    assertEqual(S.InUse(), "none")
    assertNil(S.Scorer(), "no Pawn and no weights: item level alone")
    Set("comparison.weights", { [250] = { [INT] = 1 } })
    assertEqual(S.InUse(), "weights")
    assertEqual(S.Scorer()({ stats = { [INT] = 7 } }, { specID = 250 }), 7)
    -- Loaded is not enough: the adapter is present only once PawnIsInitialized is true (design spec
    -- §5.4; DW-62 review F-003). Until then auto keeps your weights.
    m.loadedAddons.Pawn = true
    -- red under: an InUse that counts a loaded Pawn (modules/Scoring.lua)
    assertEqual(S.InUse(), "weights", "loaded but not initialized: your weights")
    assertEqual(S.Scorer()({ stats = { [INT] = 7 } }, { specID = 250 }), 7)
    Set("comparison.scorer", "pawn")
    assertEqual(S.InUse(), "none", "pawn asked for, not initialized: item level alone")
    m.PawnIsInitialized = true
    assertEqual(S.InUse(), "pawn")
    Set("comparison.scorer", "auto")
    assertEqual(S.InUse(), "pawn", "auto prefers an initialized Pawn")
    Set("comparison.scorer", "weights")
    assertEqual(S.InUse(), "weights")
    Set("comparison.scorer", "none")
    assertNil(S.Scorer())
    m.loadedAddons.Pawn, m.PawnIsInitialized = nil, nil
end)

-- ---------------------------------------------------------------------------------------------
-- The Pawn adapter
-- ---------------------------------------------------------------------------------------------

-- A Pawn fake. `values[scale][link]` is an item's value; `upgrades[link]` the drop's upgrade list
-- against your gear (nil: not read yet). Every call is recorded.
local function installPawn(m, values, upgrades)
    local calls = {}
    m.PawnIsInitialized = true
    m.PawnGetItemData = function(link) return { link = link } end
    m.PawnIsItemAnUpgrade = function(data)
        calls[#calls + 1] = "upgrade:" .. data.link
        return upgrades[data.link]
    end
    m.PawnFindScaleForSpec = function(classID, specID)
        if specID == 999 then return nil end
        return "S" .. classID .. ":" .. specID
    end
    m.PawnGetSingleValueFromItem = function(data, scale)
        calls[#calls + 1] = "value:" .. data.link .. "@" .. scale
        return values[scale] and values[scale][data.link]
    end
    return calls
end

test("scoring: for you, Pawn values the drop and the baseline on the drop's best visible scale", function()
    local NS, _, m = T.enableAddon()
    local calls = installPawn(m, { Tank = { drop = 50, worn = 40 }, Dps = { drop = 80, worn = 60 } },
        { drop = { { ScaleName = "Tank", PercentUpgrade = 0.05 }, { ScaleName = "Dps", PercentUpgrade = 0.2 } } })
    local score = NS.Scoring.PawnScorer()
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "MAGE", specID = 62 }
    assertEqual(score(drop, me, drop), 80)
    assertEqual(score({ link = "worn" }, me, drop), 60)
    local reads = 0
    for _, c in ipairs(calls) do if c == "upgrade:drop" then reads = reads + 1 end end
    assertEqual(reads, 1, "the scale is read once per drop")
end)

test("scoring: for you, a drop that upgrades no scale is valued on your spec's scale", function()
    local NS, _, m = T.enableAddon()
    installPawn(m, { ["S8:62"] = { drop = 10, worn = 12 } }, { drop = {} })
    local score = NS.Scoring.PawnScorer()
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "MAGE", specID = 62 }
    assertEqual(score(drop, me, drop), 10)
    assertEqual(score({ link = "worn" }, me, drop), 12)
end)

test("scoring: for a looter, Pawn uses the scale for their class and spec", function()
    local NS, _, m = T.enableAddon()
    installPawn(m, { ["S1:71"] = { drop = 30, theirs = 25 } }, {})
    local score = NS.Scoring.PawnScorer()
    local drop = { link = "drop" }
    local brakk = { isPlayer = false, classFile = "WARRIOR", specID = 71 }
    assertEqual(score(drop, brakk, drop), 30)
    assertEqual(score({ link = "theirs" }, brakk, drop), 25)
    assertNil(score(drop, { classFile = "WARRIOR", specID = 999 }, drop), "Pawn has no scale for it: no score")
    assertNil(score(drop, { classFile = "WARRIOR" }, drop), "no spec: no score")
    assertNil(score({}, brakk, drop), "no link: no score")
end)

test("scoring: Pawn answers pending while it is not ready or has not read the item", function()
    local NS, _, m = T.enableAddon()
    installPawn(m, { ["S1:71"] = { drop = 30 } }, {})
    local score = NS.Scoring.PawnScorer()
    local drop = { link = "drop" }
    local brakk = { classFile = "WARRIOR", specID = 71 }
    assertEqual(score({ link = "uncached" }, brakk, drop), "pending", "a nil value is not ready")
    assertEqual(score(drop, { isPlayer = true, classFile = "MAGE", specID = 62 }, drop), "pending",
        "your drop's upgrade list not read yet")
    m.PawnIsInitialized = false
    assertEqual(score(drop, brakk, drop), "pending")
end)

-- ---------------------------------------------------------------------------------------------
-- The sidegrade: item level and score through the kernel and the feed
-- ---------------------------------------------------------------------------------------------

local function ring(ilvl, stats)
    return { itemID = 1, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, stats = stats }
end

local function wearer(a, b)
    return { classFile = "MAGE", specID = 62, gear = { [11] = a, [12] = b } }
end

test("scoring: the kernel hands the scorer the drop beside each item", function()
    local NS = T.newAddon()
    local seen = {}
    local drop = ring(610, {})
    NS.Evaluate.Evaluate(drop, wearer(ring(600, {}), ring(600, {})), {
        scorer = function(f, _, d) seen[#seen + 1] = d == drop and (f == drop and "drop" or "base") or "?" return 1 end,
    })
    assertEqual(table.concat(seen, ","), "drop,base")
end)

test("scoring: with weights, a higher item level that scores lower is a sidegrade", function()
    local NS = T.newAddon()
    local scorer = NS.Scoring.WeightsScorer({ [62] = { [CRIT] = 1, [HASTE] = 0.5 } })
    local who = wearer(ring(600, { [CRIT] = 100 }), ring(600, { [CRIT] = 100 }))
    local out = NS.Evaluate.Evaluate(ring(610, { [HASTE] = 100 }), who, { scorer = scorer })
    assertEqual(out.verdict, "sidegrade")
    assertEqual(out.scoreDelta, -50)
    local disagrees = false
    for _, r in ipairs(out.reasons) do if r.key == "scoreDisagrees" then disagrees = true end end
    assertTrue(disagrees, "the reason says why")
    out = NS.Evaluate.Evaluate(ring(610, { [CRIT] = 120 }), who, { scorer = scorer })
    assertEqual(out.verdict, "upgrade", "both agree")
    out = NS.Evaluate.Evaluate(ring(602, { [CRIT] = 120 }), who, { scorer = scorer, sidegradeBand = 5 })
    assertEqual(out.verdict, "sidegrade", "item level within the band, score up")
    out = NS.Evaluate.Evaluate(ring(610, { [CRIT] = 120 }), wearer(ring(600, {}), ring(600, {})),
        { scorer = NS.Scoring.WeightsScorer({ [63] = { [CRIT] = 1 } }) })
    assertNil(out.scoreDelta, "another spec's weights do not score this one")
    assertEqual(out.verdict, "upgrade")
end)

test("scoring: the feed judges your drop with your weights once they are set", function()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end
    local function def(ilvl, stats)
        return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
            subClassID = 0, bindType = 1, stats = stats }
    end
    m.addItem(link(100), def(600, { [CRIT] = 100 }))
    m.addItem(link(101), def(600, { [CRIT] = 100 }))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    NS.Gear.Refresh("test")
    NS.SchemaRuntime.Set("comparison.weights", { [250] = { [CRIT] = 1, [HASTE] = 0.5 } })
    m.addItem(link(300), def(610, { [HASTE] = 100 }))
    NS.LootFeed.Add(link(300))
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.me.scoreDelta, -50)
    assertEqual(rec.me.verdict, "sidegrade")
end)
